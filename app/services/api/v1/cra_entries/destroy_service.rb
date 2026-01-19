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
          puts "[CraEntries::DestroyService] Initialized with entry: #{entry&.id}, current_user: #{current_user&.id}"
        end

        def call
          puts "[CraEntries::DestroyService] === DEBUT CALL METHOD ==="

          # ✅ CORRECTION L803: Gestion correcte des sous-méthodes et résultats

          # 1️⃣ Validation: Entry existe
          puts "[CraEntries::DestroyService] STEP 1: Checking if entry exists..."
          puts "[CraEntries::DestroyService] entry.present? = #{entry.present?}"
          return ApplicationResult.not_found(message: "Entry not found") unless entry.present?
          puts "[CraEntries::DestroyService] ✅ Entry exists check passed"

          # Validation: Entry déjà supprimée ?
          puts "[CraEntries::DestroyService] STEP 2: Checking if entry is already deleted..."
          puts "[CraEntries::DestroyService] entry.discarded? = #{entry.discarded?}"
          if entry.discarded?
            puts "[CraEntries::DestroyService] ❌ Entry is already deleted"
            return ApplicationResult.not_found(message: "Entry is already deleted")
          end
          puts "[CraEntries::DestroyService] ✅ Entry not deleted check passed"

          # Validation: CRA existence ?
          puts "[CraEntries::DestroyService] STEP 3: Checking if CRA exists..."
          puts "[CraEntries::DestroyService] entry.cras.first.present? = #{entry.cras.first.present?}"
          unless entry.cras.first.present?
            puts "[CraEntries::DestroyService] ❌ CRA does not exist"
            return ApplicationResult.not_found(message: "Entry is not associated with a valid CRA")
          end
          puts "[CraEntries::DestroyService] ✅ CRA exists check passed"

          # 2️⃣ Validation: Permissions et règles métier
          puts "[CraEntries::DestroyService] STEP 4: Validating permissions..."
          permission_result = validate_permissions
          puts "[CraEntries::DestroyService] permission_result = #{permission_result.inspect}"
          if permission_result.is_a?(ApplicationResult) && !permission_result.success?
            puts "[CraEntries::DestroyService] ❌ Permissions validation failed - returning immediately"
            return permission_result
          end
          puts "[CraEntries::DestroyService] ✅ Permissions validation passed"

          # 3️⃣ Soft delete avec gestion d'erreurs appropriée
          puts "[CraEntries::DestroyService] STEP 5: Performing soft delete..."
          delete_result = perform_soft_delete
          puts "[CraEntries::DestroyService] delete_result = #{delete_result.inspect}"
          if delete_result.is_a?(ApplicationResult) && !delete_result.success?
            puts "[CraEntries::DestroyService] ❌ Soft delete failed - returning immediately"
            return delete_result
          end
          puts "[CraEntries::DestroyService] ✅ Soft delete passed"

          # 4️⃣ Désassocier mission si c'est la dernière entry
          puts "[CraEntries::DestroyService] STEP 6: Unlinking mission if needed..."
          unlink_mission_if_last_entry!
          puts "[CraEntries::DestroyService] ✅ Mission unlink completed"

          # 5️⃣ Recalculer les totaux du CRA
          puts "[CraEntries::DestroyService] STEP 7: Recalculating CRA totals..."
          recalculate_cra_totals!
          puts "[CraEntries::DestroyService] ✅ CRA totals recalculated"

          # 6️⃣ Retourner succès avec les données nécessaires
          puts "[CraEntries::DestroyService] STEP 8: Returning success"
          ApplicationResult.success(
            data: {
              item: serialize_entry(entry),
              cra: serialize_cra(entry.cras.first)
            }
          )
        rescue => e
          puts "[CraEntries::DestroyService] ❌ Error in call: #{e.class}: #{e.message}"
          puts "[CraEntries::DestroyService] Backtrace: #{e.backtrace.first(5).join("\n")}"
          Rails.logger.error "[CraEntries::DestroyService] Unexpected error in call: #{e.class}: #{e.message}"
          Rails.logger.error "[CraEntries::DestroyService] Backtrace: #{e.backtrace.first(5).join("\n")}"
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
          puts "[CraEntries::DestroyService] Starting validate_entry_discarded?"
          # Entry not deleted validation
          if entry.discarded?
            puts "[CraEntries::DestroyService] validate_entry_discarded FAILED: Entry is already deleted"
            return ApplicationResult.not_found(message: "Entry is already deleted")
          end
          puts "[CraEntries::DestroyService] validate_entry_discarded PASSED"

          # CRA existence validation (Architecture DDD: entry.cras.first)
          unless entry.present? && entry.cras.first.present?
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
            unless accessible_cras.exists?(id: entry.cras.first.id)
              return ApplicationResult.fail(
                error: :forbidden,
                status: :forbidden,
                message: "User does not have access to this CRA"
              )
            end
          else
            # Fallback to simple ownership check if accessible_to doesn't exist
            unless entry.cras.first.created_by_user_id == current_user.id
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
          current_cra = entry.cras.first
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: "CRA not found"
          ) unless current_cra.present?

          if current_cra.locked?
            return ApplicationResult.fail(
              error: :conflict,
              status: :conflict,
              message: "Cannot delete entries from locked CRAs"
            )
          elsif current_cra.submitted?
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
          # ✅ SOFT DELETE SÉCURISÉ: Gestion d'erreurs et logs optimisés
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: "Entry not found"
          ) unless entry.present?

          begin
            # ✅ L803-CORRECTION: update! garantit le succès du soft delete
            entry.update!(deleted_at: Time.current)
            entry.reload

            Rails.logger.info "[CraEntries::DestroyService] Entry soft-deleted successfully: #{entry.id}"
            nil # Success - return nil to indicate success
          rescue => e
            Rails.logger.error "[CraEntries::DestroyService] Soft delete failed: #{e.message}"
            Rails.logger.error "[CraEntries::DestroyService] Entry errors: #{entry.errors.full_messages.join(', ')}"

            ApplicationResult.fail(
              error: :internal_error,
              status: :internal_error,
              message: "Failed to delete entry: #{e.message}"
            )
          end
        end

        # === Helpers ===

        def cra
          @cra ||= entry.cras.first
        end

        def unlink_mission_if_last_entry!
          entry_mission = entry.cra_entry_missions.first
          return unless entry_mission

          mission = entry_mission.mission
          return unless mission

          # Count remaining active entries for this mission in this CRA
          current_cra = cra
          remaining_count = CraEntry
                            .joins(:cra_entry_cras, :cra_entry_missions)
                            .where(cra_entry_cras: { cra_id: current_cra.id })
                            .where(cra_entry_missions: { mission_id: mission.id })
                            .where(deleted_at: nil)
                            .where.not(id: entry.id)
                            .count

          # If no remaining entries, unlink the mission
          CraMission.find_by(cra: current_cra, mission: mission)&.destroy if remaining_count.zero?
        end

        def recalculate_cra_totals!
          # Get all active (non-deleted) entries for this CRA
          current_cra = entry.cras.first
          active_entries = CraEntry.joins(:cra_entry_cras)
                                   .where(cra_entry_cras: { cra_id: current_cra.id })
                                   .where(deleted_at: nil)

          # Calculate total days (sum of quantities)
          total_days = active_entries.sum(:quantity)

          # Calculate total amount (sum of quantity * unit_price)
          total_amount = active_entries.sum { |entry| entry.quantity * entry.unit_price }

          # CTO SAFE PATCH: Enhanced error handling for totals recalculation
          return unless current_cra.present?

          begin
            if current_cra.update(total_days: total_days, total_amount: total_amount)
              Rails.logger.info "[CraEntries::DestroyService] Recalculated totals for CRA #{current_cra.id}: " \
                                "#{total_days} days, #{total_amount} amount"
            else
              Rails.logger.error "[CraEntries::DestroyService] Failed to update CRA totals: #{current_cra.errors.full_messages.join(', ')}"
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

        def serialize_cra(current_cra)
          {
            id: current_cra.id,
            total_days: current_cra.total_days,
            total_amount: current_cra.total_amount,
            currency: current_cra.currency,
            status: current_cra.status
          }
        end
      end
    end
  end
end
