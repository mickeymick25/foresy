# frozen_string_literal: true

module Api
  module V1
    module Cras
      # Service for creating CRAs with comprehensive business rule validation
      # Uses FC07-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = CreateService.call(
      #     cra_params: { month: 1, year: 2025, currency: 'EUR' },
      #     current_user: user
      #   )
      #   result.cra # => Cra
      #
      # @raise [CraErrors::InvalidPayloadError] if parameters are invalid
      # @raise [CraErrors::NoIndependentCompanyError] if user lacks independent company
      # @raise [CraErrors::DuplicateEntryError] if CRA already exists for period
      #
      class CreateService
        Result = Struct.new(:cra, keyword_init: true)

        def self.call(cra_params:, current_user:)
          new(cra_params: cra_params, current_user: current_user).call
        end

        def initialize(cra_params:, current_user:)
          @cra_params = cra_params
          @current_user = current_user
        end

        def call
          Rails.logger.info "[Cras::CreateService] Creating CRA for user #{@current_user&.id}"

          validate_inputs!
          check_permissions!
          cra = build_cra!
          save_cra!(cra)

          Rails.logger.info "[Cras::CreateService] Successfully created CRA #{cra.id}"
          Result.new(cra: cra)
        end

        private

        attr_reader :cra_params, :current_user

        # === Validation ===

        def validate_inputs!
          unless cra_params.present?
            raise CraErrors::InvalidPayloadError.new('CRA parameters are required',
                                                     field: :cra_params)
          end
          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                     field: :current_user)
          end

          validate_required_params!
          validate_month!
          validate_year!
          validate_currency! if cra_params[:currency].present?
          validate_description! if cra_params[:description].present?
        end

        def validate_required_params!
          unless cra_params[:month].present?
            raise CraErrors::InvalidPayloadError.new('Month is required',
                                                     field: :month)
          end
          raise CraErrors::InvalidPayloadError.new('Year is required', field: :year) unless cra_params[:year].present?
        end

        def validate_month!
          month = cra_params[:month].to_i
          return if (1..12).include?(month)

          raise CraErrors::InvalidPayloadError.new('Month must be between 1 and 12', field: :month)
        end

        def validate_year!
          year = cra_params[:year].to_i

          raise CraErrors::InvalidPayloadError.new('Year must be 2000 or later', field: :year) if year < 2000

          if year > (Date.current.year + 5)
            raise CraErrors::InvalidPayloadError.new('Year cannot be more than 5 years in the future',
                                                     field: :year)
          end
        end

        def validate_currency!
          currency = cra_params[:currency].to_s
          return if currency.match?(/\A[A-Z]{3}\z/)

          raise CraErrors::InvalidPayloadError.new('Currency must be a valid ISO 4217 code', field: :currency)
        end

        def validate_description!
          description = cra_params[:description].to_s
          return if description.length <= 2000

          raise CraErrors::InvalidPayloadError.new('Description cannot exceed 2000 characters', field: :description)
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

        def build_cra!
          cra = Cra.new(
            month: cra_params[:month].to_i,
            year: cra_params[:year].to_i,
            description: cra_params[:description].to_s,
            currency: cra_params[:currency]&.to_s || 'EUR',
            status: 'draft',
            created_by_user_id: current_user.id
          )

          raise CraErrors::InvalidPayloadError, cra.errors.full_messages.join(', ') unless cra.valid?

          cra
        end

        # === Save ===

        def save_cra!(cra)
          ActiveRecord::Base.transaction do
            cra.save!
            cra.reload
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "[Cras::CreateService] Validation failed: #{e.record.errors.full_messages.join(', ')}"
          handle_save_error(e.record)
        end

        def handle_save_error(record)
          if record.errors[:base]&.any? { |msg| msg.include?('already exists') }
            raise CraErrors::DuplicateEntryError, 'A CRA already exists for this user, month, and year'
          end

          raise CraErrors::InvalidPayloadError, record.errors.full_messages.join(', ')
        end
      end
    end
  end
end
