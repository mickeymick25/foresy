# frozen_string_literal: true

# app/services/api/v1/cras/create_service.rb
# Migration vers ApplicationResult - Façade unique Platinum Architecture
# Contrat unique : tous les services utilisent ApplicationResult
# Aucune exception métier levée - tout via ApplicationResult.fail

require_relative '../../../../../lib/application_result'

module Api
  module V1
    module Cras
      # Service for creating CRAs with comprehensive business rule validation
      # Uses ApplicationResult contract for consistent Service → Controller communication
      #
      # CONTRACT:
      # - Returns ApplicationResult exclusively
      # - No business exceptions raised
      # - No HTTP concerns in service
      # - Single source of truth for business rules
      #
      # @example
      #   result = CreateService.call(
      #     cra_params: { month: 1, year: 2025, currency: 'EUR' },
      #     current_user: user
      #   )
      #   result.success? # => true/false
      #   result.data # => { item: { ... } }
      #
      class CreateService
        def self.call(cra_params:, current_user:)
          new(cra_params: cra_params, current_user: current_user).call
        end

        def initialize(cra_params:, current_user:)
          @cra_params = cra_params
          @current_user = current_user
        end

        def call
          # Input validation
          return ApplicationResult.bad_request(
            error: :missing_parameters,
            message: "CRA parameters are required"
          ) unless cra_params.present?

          return ApplicationResult.bad_request(
            error: :missing_parameters,
            message: "Current user is required"
          ) unless current_user.present?

          # Parameter validation
          validation_result = validate_cra_params
          return validation_result unless validation_result.nil?

          # Permission validation
          permission_result = check_permissions
          return permission_result unless permission_result.nil?

          # Build and save CRA
          cra = build_cra
          save_cra!(cra)

          # Success response
          ApplicationResult.created(data: { item: cra })
        rescue StandardError => e
          # Log the error for debugging
          Rails.logger.error "CreateService error: #{e.message}" if defined?(Rails)
          ApplicationResult.internal_error(
            error: :internal_error,
            message: "An unexpected error occurred while creating the CRA"
          )
        end

        private

        attr_reader :cra_params, :current_user

        # === Validation ===

        def validate_cra_params
          # Month validation
          unless cra_params[:month].present?
            return ApplicationResult.unprocessable_entity(
              error: :invalid_month,
              message: "Month is required"
            )
          end

          month = cra_params[:month].to_i
          unless (1..12).include?(month)
            return ApplicationResult.unprocessable_entity(
              error: :invalid_month,
              message: "Month must be between 1 and 12"
            )
          end

          # Year validation
          unless cra_params[:year].present?
            return ApplicationResult.unprocessable_entity(
              error: :invalid_year,
              message: "Year is required"
            )
          end

          year = cra_params[:year].to_i
          if year < 2000
            return ApplicationResult.unprocessable_entity(
              error: :invalid_year,
              message: "Year must be 2000 or later"
            )
          end

          if year > (Date.current.year + 5)
            return ApplicationResult.unprocessable_entity(
              error: :invalid_year,
              message: "Year cannot be more than 5 years in the future"
            )
          end

          # Currency validation
          if cra_params[:currency].present?
            currency = cra_params[:currency].to_s
            unless currency.match?(/\A[A-Z]{3}\z/)
              return ApplicationResult.unprocessable_entity(
                error: :invalid_currency,
                message: "Currency must be a valid ISO 4217 code"
              )
            end
          end

          # Description validation
          if cra_params[:description].present?
            description = cra_params[:description].to_s
            if description.length > 2000
              return ApplicationResult.unprocessable_entity(
                error: :description_too_long,
                message: "Description cannot exceed 2000 characters"
              )
            end
          end

          nil # All validations passed
        end

        # === Permissions ===

        def check_permissions
          unless user_has_independent_company_access?
            return ApplicationResult.forbidden(
              error: :insufficient_permissions,
              message: "User must have an independent company to create CRAs"
            )
          end

          nil # Permission check passed
        end

        def user_has_independent_company_access?
          return false unless current_user.present?

          current_user.user_companies.joins(:company).where(role: 'independent').exists?
        end

        # === Build ===

        def build_cra
          Cra.new(
            month: cra_params[:month].to_i,
            year: cra_params[:year].to_i,
            description: cra_params[:description].to_s,
            currency: cra_params[:currency]&.to_s || 'EUR',
            status: 'draft',
            created_by_user_id: current_user.id
          )
        end

        # === Save ===

        def save_cra!(cra)
          ActiveRecord::Base.transaction do
            cra.save!
            cra.reload
          end
        rescue ActiveRecord::RecordInvalid => e
          # Check for duplicate CRA error
          if e.record.errors[:base]&.any? { |msg| msg.include?('already exists') }
            return ApplicationResult.conflict(
              error: :cra_already_exists,
              message: "A CRA already exists for this user, month, and year"
            )
          end

          # Generic validation error
          ApplicationResult.unprocessable_entity(
            error: :validation_failed,
            message: e.record.errors.full_messages.join(', ')
          )
        rescue ActiveRecord::RecordNotUnique => e
          ApplicationResult.conflict(
            error: :cra_already_exists,
            message: "A CRA already exists for this user, month, and year"
          )
        end
      end
    end
  end
end
