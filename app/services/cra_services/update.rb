# frozen_string_literal: true

# CRA Update Service - Services Layer Architecture
# Migrated from Api::V1::Cras::UpdateService to CraServices namespace
# Uses ApplicationResult contract for consistent Service → Controller communication
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
#
# @example
#   result = CraServices::Update.call(
#     cra: cra_instance,
#     cra_params: { description: 'Updated description' },
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { cra: {...} }
#
class CraServices
  class Update
    def self.call(cra:, cra_params:, current_user:)
      new(cra: cra, cra_params: cra_params, current_user: current_user).call
    end

    def initialize(cra:, cra_params:, current_user:)
      @cra = cra
      @cra_params = cra_params
      @current_user = current_user
    end

    def call
      # Input validation
      unless cra.present?
        return ApplicationResult.bad_request(
          error: :missing_cra,
          message: 'CRA is required'
        )
      end

      unless cra_params.present?
        return ApplicationResult.bad_request(
          error: :missing_parameters,
          message: 'CRA parameters are required'
        )
      end

      unless current_user.present?
        return ApplicationResult.bad_request(
          error: :missing_user,
          message: 'Current user is required'
        )
      end

      # Parameter validation
      validation_result = validate_cra_params
      return validation_result if validation_result.failure?

      # Permission check
      permission_check = check_user_permissions
      return permission_check if permission_check.failure?

      # Build update attributes
      build_result = build_update_attributes
      return build_result if build_result.failure?

      # Perform update
      update_result = perform_update(build_result.data[:attributes])
      return update_result if update_result.failure?

      # Success
      ApplicationResult.success(
        data: { cra: cra },
        message: 'CRA updated successfully'
      )
    rescue StandardError => e
      Rails.logger.error "CraServices::Update error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :internal_error,
        message: 'An unexpected error occurred while updating the CRA'
      )
    end

    private

    attr_reader :cra, :cra_params, :current_user

    # === Validation ===

    def validate_cra_params
      # Validate month if provided
      if cra_params[:month].present?
        month = cra_params[:month].to_i
        unless month.between?(1, 12)
          return ApplicationResult.bad_request(
            error: :invalid_month,
            message: 'Month must be between 1 and 12'
          )
        end
      end

      # Validate year if provided
      if cra_params[:year].present?
        year = cra_params[:year].to_i
        if year < 2000
          return ApplicationResult.bad_request(
            error: :invalid_year,
            message: 'Year must be 2000 or later'
          )
        end
      end

      # Validate status if provided
      if cra_params[:status].present?
        new_status = cra_params[:status].to_s
        unless Cra::VALID_STATUSES.include?(new_status)
          return ApplicationResult.bad_request(
            error: :invalid_status,
            message: "Status must be one of: #{Cra::VALID_STATUSES.join(', ')}"
          )
        end
      end

      # Validate description if provided
      if cra_params[:description].present?
        description = cra_params[:description].to_s.strip
        if description.length > 2000
          return ApplicationResult.bad_request(
            error: :description_too_long,
            message: 'Description cannot exceed 2000 characters'
          )
        end
      end

      # Validate currency if provided
      if cra_params[:currency].present?
        currency = cra_params[:currency].to_s.upcase
        unless currency.match?(/\A[A-Z]{3}\z/)
          return ApplicationResult.bad_request(
            error: :invalid_currency,
            message: 'Currency must be a valid ISO 4217 code'
          )
        end
      end

      ApplicationResult.success
    end

    # === Permissions ===

    def check_user_permissions
      # Check ownership using modifiable_by? (handles both flag ON and OFF)
      unless cra.modifiable_by?(current_user)
        return ApplicationResult.forbidden(
          error: :insufficient_permissions,
          message: 'Only the CRA creator can modify this CRA'
        )
      end

      # Check if CRA is modifiable
      if cra.locked?
        return ApplicationResult.conflict(
          error: :cra_locked,
          message: 'Locked CRAs cannot be modified'
        )
      end

      if cra.submitted?
        return ApplicationResult.conflict(
          error: :cra_submitted,
          message: 'Submitted CRAs cannot be modified'
        )
      end

      # Check status transition if status is being changed
      if cra_params[:status].present? && cra_params[:status].to_s != cra.status
        return check_status_transition(cra_params[:status].to_s)
      end

      nil # Permission checks passed
    end

    def check_status_transition(new_status)
      unless cra.can_transition_to?(new_status)
        return ApplicationResult.conflict(
          error: :invalid_transition,
          message: "Cannot transition from #{cra.status} to #{new_status}"
        )
      end

      ApplicationResult.success
    end

    # === Build Update Attributes ===

    def build_update_attributes
      attributes = {}

      # Update month if provided and valid
      if cra_params[:month].present?
        month = cra_params[:month].to_i
        attributes[:month] = month if month.between?(1, 12)
      end

      # Update year if provided and valid
      if cra_params[:year].present?
        year = cra_params[:year].to_i
        attributes[:year] = year if year >= 2000
      end

      # Update status if provided and valid
      if cra_params[:status].present?
        new_status = cra_params[:status].to_s
        attributes[:status] = new_status if Cra::VALID_STATUSES.include?(new_status)
      end

      # Update description if provided
      if cra_params[:description].present?
        description = cra_params[:description].to_s.strip
        attributes[:description] = description[0..2000] # Ensure max length
      end

      # Update currency if provided and valid
      if cra_params[:currency].present?
        currency = cra_params[:currency].to_s.upcase
        attributes[:currency] = currency if currency.match?(/\A[A-Z]{3}\z/)
      end

      # Check if there are any attributes to update
      if attributes.empty?
        return ApplicationResult.bad_request(
          error: :no_valid_attributes,
          message: 'No valid attributes provided for update'
        )
      end

      ApplicationResult.success(data: { attributes: attributes })
    rescue StandardError => e
      ApplicationResult.internal_error(
        error: :build_failed,
        message: "Failed to build update attributes: #{e.message}"
      )
    end

    # === Perform Update ===

    def perform_update(attributes)
      ActiveRecord::Base.transaction do
        return handle_update_errors unless cra.update(attributes)

        cra.reload
      rescue ActiveRecord::RecordInvalid => e
        return handle_record_invalid_errors(e.record)
      rescue ActiveRecord::RecordNotFound
        return ApplicationResult.not_found(
          error: :cra_not_found,
          message: 'CRA not found during update'
        )
      end

      ApplicationResult.success(data: { cra: cra })
    rescue StandardError => e
      ApplicationResult.internal_error(
        error: :update_failed,
        message: "Failed to update CRA: #{e.message}"
      )
    end

    def handle_update_errors
      # Handle specific CRA errors
      if cra.errors[:status]&.any? { |msg| msg.include?('invalid_transition') }
        return ApplicationResult.conflict(
          error: :invalid_transition,
          message: "Cannot transition from #{cra.status} to #{cra_params[:status]}"
        )
      end

      if cra.errors.full_messages.any? { |msg| msg.include?('already exists') }
        return ApplicationResult.conflict(
          error: :cra_already_exists,
          message: 'A CRA already exists for this period'
        )
      end

      # Generic validation error
      ApplicationResult.unprocessable_entity(
        error: :validation_failed,
        message: cra.errors.full_messages.join(', ')
      )
    end

    def handle_record_invalid_errors(record)
      # Handle specific CRA errors from ActiveRecord
      if record.errors[:status]&.any? { |msg| msg.include?('invalid_transition') }
        return ApplicationResult.conflict(
          error: :invalid_transition,
          message: "Cannot transition from #{cra.status} to #{cra_params[:status]}"
        )
      end

      if record.errors.full_messages.any? { |msg| msg.include?('already exists') }
        return ApplicationResult.conflict(
          error: :cra_already_exists,
          message: 'A CRA already exists for this period'
        )
      end

      # Generic validation error
      ApplicationResult.unprocessable_entity(
        error: :validation_failed,
        message: record.errors.full_messages.join(', ')
      )
    end
  end
end
