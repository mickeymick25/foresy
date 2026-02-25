# frozen_string_literal: true

# Mission Delete Service - Services Layer Architecture
# Handles mission deletion (soft delete) with business rule validation
# Uses ApplicationResult contract for consistent Service → Controller communication
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
#
# @example
#   result = MissionServices::Delete.call(
#     mission: mission,
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { mission: {...} }
#
class MissionServices
  class Delete
    def self.call(mission:, current_user:)
      new(mission: mission, current_user: current_user).call
    end

    def initialize(mission:, current_user:)
      @mission = mission
      @current_user = current_user
    end

    def call
      # Permission check: only creator can delete
      permission_result = check_permissions
      return permission_result if permission_result.failure?

      # Business rule: cannot delete if mission has CRA entries
      business_rule_result = check_business_rules
      return business_rule_result if business_rule_result.failure?

      # Perform soft delete
      delete_result = perform_delete
      return delete_result if delete_result.failure?

      # Success
      ApplicationResult.success(
        data: { mission: @mission },
        message: 'Mission archived successfully'
      )
    rescue StandardError => e
      Rails.logger.error "MissionServices::Delete error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :internal_error,
        message: 'An unexpected error occurred while archiving the mission'
      )
    end

    private

    attr_reader :mission, :current_user

    # === Permissions ===

    def check_permissions
      unless mission.modifiable_by?(current_user)
        return ApplicationResult.forbidden(
          error: :forbidden,
          message: 'Only the mission creator can archive this mission'
        )
      end

      ApplicationResult.success(data: {})
    end

    # === Business Rules ===

    def check_business_rules
      # Check if mission has CRA entries (cannot delete if linked to CRAs)
      if mission.cra_entries?
        return ApplicationResult.conflict(
          error: :mission_in_use,
          message: 'Mission cannot be deleted as it has CRA entries'
        )
      end

      # Check if mission is already deleted
      if mission.discarded?
        return ApplicationResult.not_found(
          error: :mission_not_found,
          message: 'Mission is already archived'
        )
      end

      ApplicationResult.success(data: {})
    end

    # === Delete ===

    def perform_delete
      begin
        unless mission.discard
          return ApplicationResult.conflict(
            error: :delete_failed,
            message: mission.errors.full_messages.join(', ')
          )
        end

        ApplicationResult.success(data: { mission: mission })
      rescue ActiveRecord::RecordInvalid => e
        ApplicationResult.conflict(
          error: :delete_failed,
          message: e.record.errors.full_messages.join(', ')
        )
      end
    end
  end
end
