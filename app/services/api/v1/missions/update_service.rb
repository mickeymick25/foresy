# frozen_string_literal: true

module Api
  module V1
    module Missions
      # Service for updating missions with comprehensive business rule validation
      # Uses FC06-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = UpdateService.call(
      #     mission: mission,
      #     mission_params: { description: 'Updated description' },
      #     current_user: user
      #   )
      #   result.mission # => Mission
      #
      # @raise [CraErrors::MissionLockedError] if mission is locked
      # @raise [CraErrors::InvalidPayloadError] if parameters are invalid
      # @raise [CraErrors::InvalidTransitionError] if status transition is invalid
      # @raise [CraErrors::UnauthorizedError] if user is not the creator
      #
      class UpdateService
        Result = Struct.new(:mission, keyword_init: true)

        def self.call(mission:, mission_params:, current_user:)
          new(mission: mission, mission_params: mission_params, current_user: current_user).call
        end

        def initialize(mission:, mission_params:, current_user:)
          @mission = mission
          @mission_params = mission_params
          @current_user = current_user
        end

        def call
          Rails.logger.info "[Missions::UpdateService] Updating mission #{@mission&.id} for user #{@current_user&.id}"

          validate_inputs!
          check_permissions!
          perform_update!

          Rails.logger.info "[Missions::UpdateService] Successfully updated mission #{@mission.id}"
          Result.new(mission: @mission)
        end

        private

        attr_reader :mission, :mission_params, :current_user

        # === Validation ===

        def validate_inputs!
          raise CraErrors::MissionNotFoundError unless mission.present?

          unless mission_params.present?
            raise CraErrors::InvalidPayloadError.new('Mission parameters are required',
                                                   field: :mission_params)
          end
          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                   field: :current_user)
          end
        end

        # === Permissions ===

        def check_permissions!
          check_ownership!
          check_mission_modifiable!
          check_status_transition! if mission_params[:status].present?
        end

        def check_ownership!
          return if mission.created_by_user_id == current_user.id

          raise CraErrors::UnauthorizedError, 'Only the mission creator can modify this mission'
        end

        def check_mission_modifiable!
          raise CraErrors::MissionLockedError if mission.locked?
          # Missions can be modified in draft, lead, and active status
          allowed_statuses = %w[draft lead active]
          return if allowed_statuses.include?(mission.status)

          raise CraErrors::InvalidPayloadError, 'Mission cannot be modified in current status'
        end

        def check_status_transition!
          new_status = mission_params[:status].to_s
          return if new_status == mission.status
          return if mission.can_transition_to?(new_status)

          raise CraErrors::InvalidTransitionError.new(mission.status, new_status)
        end

        # === Update ===

        def perform_update!
          ActiveRecord::Base.transaction do
            update_attributes = build_update_attributes

            handle_update_error unless mission.update(update_attributes)

            mission.reload
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "[Missions::UpdateService] Validation failed: #{e.record.errors.full_messages.join(', ')}"
          handle_record_invalid(e.record)
        end

        def build_update_attributes
          attributes = {}

          if mission_params[:name].present?
            name = mission_params[:name].to_s.strip
            attributes[:name] = name if name.length >= 3 && name.length <= 200
          end

          if mission_params[:description].present?
            description = mission_params[:description].to_s.strip
            attributes[:description] = description[0..1000]
          end

          if mission_params[:mission_type].present?
            mission_type = mission_params[:mission_type].to_s
            valid_types = %w[time_based fixed_price]
            attributes[:mission_type] = mission_type if valid_types.include?(mission_type)
          end

          if mission_params[:status].present?
            new_status = mission_params[:status].to_s
            attributes[:status] = new_status if Mission::VALID_STATUSES.include?(new_status)
          end

          if mission_params[:start_date].present?
            start_date = parse_date(mission_params[:start_date])
            attributes[:start_date] = start_date if start_date.present?
          end

          if mission_params[:end_date].present?
            end_date = parse_date(mission_params[:end_date])
            attributes[:end_date] = end_date if end_date.present?
          end

          if mission_params[:daily_rate].present?
            daily_rate = mission_params[:daily_rate].to_i
            attributes[:daily_rate] = daily_rate if daily_rate.positive? && daily_rate <= 100_000_000
          end

          if mission_params[:fixed_price].present?
            fixed_price = mission_params[:fixed_price].to_i
            attributes[:fixed_price] = fixed_price if fixed_price.positive? && fixed_price <= 1_000_000_000
          end

          if mission_params[:currency].present?
            currency = mission_params[:currency].to_s.upcase
            attributes[:currency] = currency if currency.match?(/\A[A-Z]{3}\z/)
          end

          # Validate date consistency if both dates are being updated
          if attributes[:start_date].present? && attributes[:end_date].present?
            if attributes[:start_date] > attributes[:end_date]
              raise CraErrors::InvalidPayloadError, 'Start date must be before end date'
            end
          end

          attributes
        end

        def handle_update_error
          errors = mission.errors.full_messages

          if mission.errors[:status]&.any? { |msg| msg.include?('invalid_transition') }
            raise CraErrors::InvalidTransitionError.new(mission.status, mission_params[:status])
          elsif errors.any? { |msg| msg.include?('already exists') }
            raise CraErrors::DuplicateEntryError, 'A mission with this name already exists'
          else
            raise CraErrors::InvalidPayloadError, errors.join(', ')
          end
        end

        def handle_record_invalid(record)
          if record.errors[:status]&.any? { |msg| msg.include?('invalid_transition') }
            raise CraErrors::InvalidTransitionError.new(mission.status, mission_params[:status])
          elsif record.errors.full_messages.any? { |msg| msg.include?('already exists') }
            raise CraErrors::DuplicateEntryError, 'A mission with this name already exists'
          else
            raise CraErrors::InvalidPayloadError, record.errors.full_messages.join(', ')
          end
        end

        # === Helpers ===

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
