# frozen_string_literal: true

# app/services/api/v1/cra_entries/destroy_service.rb
# Migration vers ApplicationResult - Étape 2 du plan de migration
# Contrat unique : tous les services retournent ApplicationResult
# Aucune exception métier levée - tout via Result.fail

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
      #   result.ok? # => true/false
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
          # Input validation
          validation_result = validate_inputs
          return validation_result unless validation_result.nil?

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

          # Success response
          Result.ok(
            data: {
              item: serialize_entry(@entry),
              cra: serialize_cra(cra)
            },
            status: :ok
          )
        # No rescue StandardError - let exceptions bubble up for debugging

        private

        attr_reader :entry, :current_user

        # === Validation ===

        def validate_inputs
          # Entry validation
          unless entry.present?
            return Result.fail(
              error: :not_found,
              status: :not_found,
              message: "CRA entry not found"
            )
          end

          # Current user validation
          unless current_user.present?
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Current user is required"
            )
          end

          nil # All validations passed
        end

        def validate_permissions
          # Entry not deleted validation
          if entry.discarded?
            return Result.fail(
              error: :not_found,
              status: :not_found,
              message: "Entry is already deleted"
            )
          end

          # CRA existence validation
          unless entry.present? && entry.cra.present?
            return Result.fail(
              error: :not_found,
              status: :not_found,
              message: "Entry is not associated with a valid CRA"
            )
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
          accessible_cras = Cra.accessible_to(current_user)
          unless accessible_cras.exists?(id: cra.id)
            return Result.fail(
              error: :unauthorized,
              status: :unauthorized,
              message: "User does not have access to this CRA"
            )
          end
          nil
        end

        def validate_cra_modifiable
          if cra.locked?
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: "Cannot delete entries from locked CRAs"
            )
          elsif cra.submitted?
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: "Cannot delete entries from submitted CRAs"
            )
          end
          nil
        end

        def validate_entry_modifiable
          unless entry.modifiable?
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Entry cannot be deleted (CRA is submitted or locked)"
            )
          end
          nil
        end

        # === Delete ===

        def perform_soft_delete
          begin
            ActiveRecord::Base.transaction do
              unless entry.discard
                return Result.fail(
                  error: :internal_error,
                  status: :internal_error,
                  message: "Failed to delete entry"
                )
              end

              entry.reload
            end
            nil # Success
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "[CraEntries::DestroyService] Soft delete failed: #{e.message}"
            Result.fail(
              error: :internal_error,
              status: :internal_error,
              message: "Failed to delete entry"
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

          # Update CRA with new totals
          cra.update!(total_days: total_days, total_amount: total_amount)

          Rails.logger.info "[CraEntries::DestroyService] Recalculated totals for CRA #{cra.id}: " \
                            "#{total_days} days, #{total_amount} amount"
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
