# frozen_string_literal: true

module Api
  module V1
    module Missions
      # Service for creating missions with comprehensive business rule validation
      # Uses FC06-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = CreateService.call(
      #     mission_params: { name: 'Test Mission', mission_type: 'time_based' },
      #     current_user: user,
      #     client_company_id: company_id
      #   )
      #   result.mission # => Mission
      #
      # @raise [CraErrors::InvalidPayloadError] if parameters are invalid
      # @raise [CraErrors::NoIndependentCompanyError] if user lacks independent company
      # @raise [CraErrors::UnauthorizedError] if user lacks permissions
      #
      class CreateService
        Result = Struct.new(:mission, keyword_init: true)

        def self.call(mission_params:, current_user:, client_company_id: nil)
          new(mission_params: mission_params, current_user: current_user, client_company_id: client_company_id).call
        end

        def initialize(mission_params:, current_user:, client_company_id: nil)
          @mission_params = mission_params
          @current_user = current_user
          @client_company_id = client_company_id
        end

        def call
          Rails.logger.info "[Missions::CreateService] Creating mission for user #{@current_user&.id}"

          validate_inputs!
          check_permissions!
          mission = build_mission!
          save_mission!(mission)

          Rails.logger.info "[Missions::CreateService] Successfully created mission #{mission.id}"
          Result.new(mission: mission)
        end

        private

        attr_reader :mission_params, :current_user, :client_company_id

        # === Validation ===

        def validate_inputs!
          unless mission_params.present?
            raise CraErrors::InvalidPayloadError.new('Mission parameters are required',
                                                     field: :mission_params)
          end
          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                     field: :current_user)
          end

          validate_required_params!
          validate_mission_type!
          validate_dates!
          validate_financial_fields!
          validate_description! if mission_params[:description].present?
        end

        def validate_required_params!
          required_fields = [:name, :mission_type, :status]
          missing_fields = required_fields.select { |field| mission_params[field].blank? }

          if missing_fields.any?
            raise CraErrors::InvalidPayloadError.new("Required fields missing: #{missing_fields.join(', ')}",
                                                     field: :required_fields)
          end
        end

        def validate_mission_type!
          mission_type = mission_params[:mission_type].to_s
          valid_types = %w[time_based fixed_price]

          unless valid_types.include?(mission_type)
            raise CraErrors::InvalidPayloadError.new(
              "Mission type must be one of: #{valid_types.join(', ')}",
              field: :mission_type
            )
          end
        end

        def validate_dates!
          if mission_params[:start_date].present?
            start_date = parse_date(mission_params[:start_date])
            raise CraErrors::InvalidPayloadError.new('Invalid start date format', field: :start_date) if start_date.nil?
          end

          if mission_params[:end_date].present?
            end_date = parse_date(mission_params[:end_date])
            raise CraErrors::InvalidPayloadError.new('Invalid end date format', field: :end_date) if end_date.nil?
          end

          # Validate date logic
          if mission_params[:start_date].present? && mission_params[:end_date].present?
            start_date = parse_date(mission_params[:start_date])
            end_date = parse_date(mission_params[:end_date])

            if start_date > end_date
              raise CraErrors::InvalidPayloadError.new('Start date must be before end date', field: :dates)
            end
          end
        end

        def validate_financial_fields!
          mission_type = mission_params[:mission_type].to_s

          case mission_type
          when 'time_based'
            validate_daily_rate!
          when 'fixed_price'
            validate_fixed_price!
          end
        end

        def validate_daily_rate!
          return unless mission_params[:daily_rate].present?

          daily_rate = mission_params[:daily_rate].to_i
          unless daily_rate.positive?
            raise CraErrors::InvalidPayloadError.new('Daily rate must be greater than 0', field: :daily_rate)
          end

          if daily_rate > 100_000_000
            raise CraErrors::InvalidPayloadError.new('Daily rate cannot exceed 100,000,000', field: :daily_rate)
          end
        end

        def validate_fixed_price!
          return unless mission_params[:fixed_price].present?

          fixed_price = mission_params[:fixed_price].to_i
          unless fixed_price.positive?
            raise CraErrors::InvalidPayloadError.new('Fixed price must be greater than 0', field: :fixed_price)
          end

          if fixed_price > 1_000_000_000
            raise CraErrors::InvalidPayloadError.new('Fixed price cannot exceed 1,000,000,000', field: :fixed_price)
          end
        end

        def validate_description!
          description = mission_params[:description].to_s
          return if description.length <= 1000

          raise CraErrors::InvalidPayloadError.new('Description cannot exceed 1000 characters', field: :description)
        end

        # === Permissions ===

        def check_permissions!
          return if user_has_independent_company_access?

          raise CraErrors::NoIndependentCompanyError
        end

        def user_has_independent_company_access?
          return false unless current_user.present?

          current_user.user_companies.joins(:company).where(role: 'independent').exists?
        end

        # === Build ===

        def build_mission!
          mission = Mission.new(
            name: mission_params[:name].to_s.strip,
            description: mission_params[:description]&.to_s&.strip,
            mission_type: mission_params[:mission_type].to_s,
            status: mission_params[:status].to_s,
            start_date: parse_date(mission_params[:start_date]),
            end_date: parse_date(mission_params[:end_date]),
            daily_rate: mission_params[:daily_rate]&.to_i,
            fixed_price: mission_params[:fixed_price]&.to_i,
            currency: mission_params[:currency]&.to_s || 'EUR',
            created_by_user_id: current_user.id
          )

          raise CraErrors::InvalidPayloadError, mission.errors.full_messages.join(', ') unless mission.valid?

          mission
        end

        # === Save ===

        def save_mission!(mission)
          ActiveRecord::Base.transaction do
            mission.save!
            mission.reload

            # Create MissionCompany relationships
            create_mission_companies!(mission)
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "[Missions::CreateService] Validation failed: #{e.record.errors.full_messages.join(', ')}"
          handle_save_error(e.record)
        end

        def create_mission_companies!(mission)
          # Create relationship for independent company
          independent_company = get_user_independent_company
          mission.mission_companies.create!(
            company_id: independent_company.id,
            role: 'independent'
          )

          # Create relationship for client company if provided
          if client_company_id.present?
            mission.mission_companies.create!(
              company_id: client_company_id,
              role: 'client'
            )
          end
        end

        def handle_save_error(record)
          if record.errors[:name]&.any? { |msg| msg.include?('already exists') }
            raise CraErrors::DuplicateEntryError, 'A mission with this name already exists'
          end

          raise CraErrors::InvalidPayloadError, record.errors.full_messages.join(', ')
        end

        # === Helpers ===

        def get_user_independent_company
          current_user.user_companies.joins(:company).where(role: 'independent').first.company
        end

        def parse_date(date_param)
          return nil if date_param.blank?

          Date.parse(date_param.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
