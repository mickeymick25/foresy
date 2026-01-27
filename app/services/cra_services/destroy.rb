# frozen_string_literal: true

# CRA Destroy Service - Zeitwerk Compliant Architecture
# Uses CraServices namespace to avoid model conflicts
# Architecture: app/services/cra_services/destroy.rb → CraServices::Destroy

module CraServices
  # Service for destroying CRAs with comprehensive business rule validation
  # Uses ApplicationResult contract for consistent Service → Controller communication
  #
  # CONTRACT:
  # - Returns ApplicationResult exclusively
  # - No business exceptions raised
  # - No HTTP concerns in service
  # - Single source of truth for business rules
  #
  # @example
  #   result = CraServices::Destroy.call(
  #     cra: cra_instance,
  #     current_user: user
  #   )
  #   result.success? # => true/false
  #   result.data # => { cra: {...} }
  #
class CraServices::Destroy
    def self.call(cra:, current_user:)
      new(cra: cra, current_user: current_user).call
    end

    def initialize(cra:, current_user:)
      @cra = cra
      @current_user = current_user
    end

    def call
      # Input validation
      return ApplicationResult.bad_request(
        error: :missing_parameters,
        message: "CRA is required"
      ) unless cra.present?

      return ApplicationResult.bad_request(
        error: :missing_parameters,
        message: "Current user is required"
      ) unless current_user.present?

      # Parameter validation
      validation_result = validate_cra
      return validation_result if validation_result.failure?

      # Permission check
      permission_check = check_user_permissions
      return permission_check if permission_check.failure?

      # Check if CRA can be destroyed
      state_check = check_cra_state
      return state_check if state_check.failure?

      # Destroy CRA
      destroy_result = destroy_cra
      return destroy_result if destroy_result.failure?

      # Success
      ApplicationResult.success(
        data: { cra: cra },
        message: "CRA destroyed successfully"
      )
    rescue StandardError => e
      Rails.logger.error "CraServices::Destroy error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :internal_error,
        message: "An unexpected error occurred while destroying the CRA"
      )
    end

    private

    attr_reader :cra, :current_user

    # === Validation ===

    def validate_cra
      # Check if CRA exists and belongs to user
      unless cra.present? && cra.is_a?(Cra)
        return ApplicationResult.not_found(
          error: :cra_not_found,
          message: "CRA not found"
        )
      end

      # Check if CRA belongs to current user
      unless cra.created_by_user_id == current_user.id
        return ApplicationResult.forbidden(
          error: :insufficient_permissions,
          message: "You can only destroy your own CRAs"
        )
      end

      ApplicationResult.success
    end

    # === Permissions ===

    def check_user_permissions
      return ApplicationResult.forbidden(
        error: :insufficient_permissions,
        message: "User does not have permission to destroy CRAs"
      ) unless user_has_destroy_permission?

      nil # Permission check passed
    end

    def user_has_destroy_permission?
      return false unless current_user.present?

      # User can destroy if they are the creator or have admin/manager role
      cra.created_by_user_id == current_user.id ||
      current_user.user_companies.joins(:company).where(role: ['admin', 'manager']).exists?
    end

    # === State Check ===

    def check_cra_state
      # Check if CRA is in a destroyable state
      if cra.submitted?
        return ApplicationResult.conflict(
          error: :cra_submitted,
          message: "Cannot destroy a submitted CRA. Use unlock first."
        )
      end

      if cra.locked?
        return ApplicationResult.conflict(
          error: :cra_locked,
          message: "Cannot destroy a locked CRA"
        )
      end

      ApplicationResult.success
    end

    # === Destroy ===

    def destroy_cra
      ActiveRecord::Base.transaction do
        cra.update!(deleted_at: Time.current)
      rescue ActiveRecord::RecordInvalid => e
        ApplicationResult.unprocessable_entity(
          error: :validation_failed,
          message: e.record.errors.full_messages.join(', ')
        )
      rescue ActiveRecord::RecordNotFound => e
        ApplicationResult.not_found(
          error: :cra_not_found,
          message: "CRA not found"
        )
      end

      ApplicationResult.success
    end
  end
