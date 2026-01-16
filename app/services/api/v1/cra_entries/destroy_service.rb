# frozen_string_literal: true

# app/services/api/v1/cra_entries/destroy_service.rb
# Migration vers ApplicationResult - Étape 2 du plan de migration
# Contrat unique : tous les services retournent ApplicationResult
# Aucune exception métier levée - tout via ApplicationResult.fail

require_relative '../../../../../lib/application_result'

module Api
  module V1
    module CraEntries
      # Service for soft-deleting CRA entries with comprehensive business rule validation
      # Uses ApplicationResult contract for consistent Service → Controller communication
      #
      # CONTRACT:
      # - Returns ApplicationResult exclusively
      # - No business exceptions raised
      # - No HTTP concerns in service
      # - Single source of truth for business rules
      #
      # @example
      #   result = DestroyService.call(
      #     entry: entry,
      #     current_user: user
      #   )
      #   result.success? # => true/false
      #   result.data # => { item: { ... }, cra: { ... } }
      #
      class DestroyService
        include Api::V1::CraEntries::Shared::ValidationHelpers

        def self.call(entry:, current_user:)
          new(entry: entry, current_user: current_user).call
        end

        def initialize(entry:, current_user:)
          @entry = entry
          @current_user = current_user
        end

        def call
          # Input validation - CTO SAFE PATCH
          return ApplicationResult.not_found unless entry

          # Permission validation
          permission_result = validate_permissions
          return permission_result unless permission_result.nil?

          # CRA lifecycle validation - Check if CRA can be modified
          lifecycle_result = check_cra_modifiable!(@entry.cra)
          return lifecycle_result unless lifecycle_result.nil?

          # Perform soft delete
          delete_result = perform_soft_delete
          return delete_result unless delete_result.nil?

          # Unlink mission if this was the last active entry for it
          unlink_mission_if_last_entry!

          # Recalculate CRA totals
          recalculate_cra_totals!

          # Success response - CTO SAFE PATCH: ApplicationResult.success
          ApplicationResult.success(
            data: {
              item: serialize_entry(@entry),
              cra: serialize_cra(cra)
            }
          )
        rescue => e
          Rails.logger.error "[CraEntries::DestroyService] Unexpected error: #{e.class}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          ApplicationResult.fail(
            error: :internal_error,
            status: :internal_error,
            message: "An unexpected error occurred while deleting the entry"
          )
        end

        private

        attr_reader :entry, :current_user

        # === Validation ===

        def validate_inputs
          # CTO SAFE PATCH: Removed entry.present? check - moved to call method
          # Current user validation
          unless current_user.present?
            return ApplicationResult.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Current user is required"
            )
          end

          nil # All validations passed
        end

        def validate_permissions
          # Entry not deleted validation
          if entry.discarded?
            return ApplicationResult.not_found(message: "Entry is already deleted")
          end

          # CRA existence validation
          unless entry.present? && entry.cra.present?
            return ApplicationResult.not_found(message: "Entry is not associated with a valid CRA")
          end

          # CRA access validation
          access_result = validate_cra_access
          return access_result unless access_result.nil?

          # CRA modifiable validation
          modifiable_result = validate_cra_modifiable
          return modifiable_result unless modifiable_result.nil?

          # Entry modifiable validation
          entry_modifiable_result = validate_entry_modifiable
          return entry_modifiable_result unless entry_modifiable_result.nil?

          nil # All permissions validated
        end

        def validate_cra_access
          # CTO SAFE PATCH: Check if Cra.accessible_to method exists
          if defined?(Cra.accessible_to)
            accessible_cras = Cra.accessible_to(current_user)
            unless accessible_cras.exists?(id: cra.id)
              return ApplicationResult.fail(
                error: :forbidden,
                status: :forbidden,
                message: "User does not have access to this CRA"
              )
            end
          else
            # Fallback to simple ownership check if accessible_to doesn't exist
            unless cra.created_by_user_id == current_user.id
              return ApplicationResult.fail(
                error: :forbidden,
                status: :forbidden,
                message: "User does not have access to this CRA"
              )
            end
          end
          nil
        rescue => e
          Rails.logger.error "[CraEntries::DestroyService] Error in validate_cra_access: #{e.message}"
          ApplicationResult.fail(
            error: :internal_error,
            status: :internal_error,
            message: "Error validating CRA access"
          )
        end

        def validate_cra_modifiable
          # CTO SAFE PATCH: Add error handling for cra access
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: "CRA not found"
          ) unless cra.present?

          if cra.locked?
            return ApplicationResult.fail(
              error: :conflict,
              status: :conflict,
              message: "Cannot delete entries from locked CRAs"
            )
          elsif cra.submitted?
            return ApplicationResult.fail(
              error: :conflict,
              status: :conflict,
              message: "Cannot delete entries from submitted CRAs"
            )
          end
          nil
        rescue => e
          Rails.logger.error "[CraEntries::DestroyService] Error in validate_cra_modifiable: #{e.message}"
          ApplicationResult.fail(
            error: :internal_error,
            status: :internal_error,
            message: "Error validating CRA modifiable state"
          )
        end

        def validate_entry_modifiable
          # CTO SAFE PATCH: Add error handling for entry access
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: "Entry not found"
          ) unless entry.present?

          unless entry.respond_to?(:modifiable?) && entry.modifiable?
            return ApplicationResult.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Entry cannot be deleted (CRA is submitted or locked)"
            )
          end
          nil
        rescue => e
          Rails.logger.error "[CraEntries::DestroyService] Error in validate_entry_modifiable: #{e.message}"
          ApplicationResult.fail(
            error: :internal_error,
            status: :internal_error,
            message: "Error validating entry modifiable state"
          )
        end

        # === Delete ===

        def perform_soft_delete
          # CTO SAFE PATCH: Enhanced error handling
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: "Entry not found"
          ) unless entry.present?

          begin
            if entry.respond_to?(:discard) && entry.discard
              entry.reload
              return nil # Success
            else
              return ApplicationResult.fail(
                error: :internal_error,
                status: :internal_error,
                message: "Failed to delete entry"
              )
            end
          rescue => e
            Rails.logger.error "[CraEntries::DestroyService] Soft delete failed: #{e.message}"
            ApplicationResult.fail(
              error: :internal_error,
              status: :internal_error,
              message: "Failed to delete entry: #{e.message}"
            )
          end
        end

        # === Helpers ===

        def cra
          @cra ||= entry.cra
        end

        def unlink_mission_if_last_entry!
          entry_mission = entry.cra_entry_missions.first
          return unless entry_mission

          mission = entry_mission.mission
          return unless mission

          # Count remaining active entries for this mission in this CRA
          remaining_count = CraEntry
                            .joins(:cra_entry_cras, :cra_entry_missions)
                            .where(cra_entry_cras: { cra_id: cra.id })
                            .where(cra_entry_missions: { mission_id: mission.id })
                            .where(deleted_at: nil)
                            .where.not(id: entry.id)
                            .count

          # If no remaining entries, unlink the mission
          CraMission.find_by(cra: cra, mission: mission)&.destroy if remaining_count.zero?
        end

        def recalculate_cra_totals!
          # Get all active (non-deleted) entries for this CRA
          active_entries = CraEntry.joins(:cra_entry_cras)
                                   .where(cra_entry_cras: { cra_id: cra.id })
                                   .where(deleted_at: nil)

          # Calculate total days (sum of quantities)
          total_days = active_entries.sum(:quantity)

          # Calculate total amount (sum of quantity * unit_price)
          total_amount = active_entries.sum { |entry| entry.quantity * entry.unit_price }

          # CTO SAFE PATCH: Enhanced error handling for totals recalculation
          return unless cra.present?

          begin
            if cra.update(total_days: total_days, total_amount: total_amount)
              Rails.logger.info "[CraEntries::DestroyService] Recalculated totals for CRA #{cra.id}: " \
                                "#{total_days} days, #{total_amount} amount"
            else
              Rails.logger.error "[CraEntries::DestroyService] Failed to update CRA totals: #{cra.errors.full_messages.join(', ')}"
              # Don't return error here - totals calculation failure shouldn't break deletion
            end
          rescue => e
            Rails.logger.error "[CraEntries::DestroyService] Error recalculating totals: #{e.message}"
            # Don't return error here - totals calculation failure shouldn't break deletion
          end
        end

        # === Serialization ===

        def serialize_entry(entry)
          {
            id: entry.id,
            date: entry.date,
            quantity: entry.quantity,
            unit_price: entry.unit_price,
            description: entry.description,
            created_at: entry.created_at,
            updated_at: entry.updated_at
          }
        end

        def serialize_cra(cra)
          {
            id: cra.id,
            total_days: cra.total_days,
            total_amount: cra.total_amount,
            currency: cra.currency,
            status: cra.status
          }
        end
      end
    end
  end
end
