# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      # Service for soft-deleting CRA entries with business rule validation
      # Uses FC07-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = DestroyService.call(entry: entry, current_user: user)
      #   result.entry # => CraEntry (soft deleted)
      #
      # @raise [CraErrors::CraLockedError] if CRA is locked
      # @raise [CraErrors::CraSubmittedError] if CRA is submitted
      # @raise [CraErrors::EntryNotFoundError] if entry not found or already deleted
      # @raise [CraErrors::UnauthorizedError] if user lacks access
      #
      class DestroyService
        Result = Struct.new(:entry, keyword_init: true)

        def self.call(entry:, current_user:)
          new(entry: entry, current_user: current_user).call
        end

        def initialize(entry:, current_user:)
          @entry = entry
          @current_user = current_user
        end

        def call
          Rails.logger.info "[CraEntries::DestroyService] Deleting entry #{@entry&.id}"

          validate_inputs!
          check_permissions!
          perform_soft_delete!

          # Unlink mission if this was the last active entry for it
          unlink_mission_if_last_entry!

          # Recalculate CRA totals after deleting the entry
          recalculate_cra_totals!

          Rails.logger.info "[CraEntries::DestroyService] Successfully deleted entry #{@entry.id}"
          Result.new(entry: @entry)
        end

        private

        attr_reader :entry, :current_user

        # === Validation ===

        def validate_inputs!
          raise CraErrors::EntryNotFoundError unless entry.present?

          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                     field: :current_user)
          end
        end

        def check_permissions!
          check_entry_not_deleted!
          check_cra_exists!
          check_cra_access!
          check_cra_modifiable!
          check_entry_modifiable!
        end

        def check_entry_not_deleted!
          raise CraErrors::EntryNotFoundError, 'Entry is already deleted' if entry.discarded?
        end

        def check_cra_exists!
          raise CraErrors::CraNotFoundError, 'Entry is not associated with a valid CRA' unless cra.present?
        end

        def check_cra_access!
          accessible_cras = Cra.accessible_to(current_user)
          return if accessible_cras.exists?(id: cra.id)

          raise CraErrors::UnauthorizedError, 'User does not have access to this CRA'
        end

        def check_cra_modifiable!
          raise CraErrors::CraLockedError if cra.locked?
          raise CraErrors::CraSubmittedError, 'Cannot delete entries from submitted CRAs' if cra.submitted?
        end

        def check_entry_modifiable!
          return if entry.modifiable?

          raise CraErrors::InvalidPayloadError, 'Entry cannot be deleted (CRA is submitted or locked)'
        end

        # === Delete ===

        def perform_soft_delete!
          ActiveRecord::Base.transaction do
            raise CraErrors::InternalError, 'Failed to delete entry' unless entry.discard

            entry.reload
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[CraEntries::DestroyService] Soft delete failed: #{e.message}"
          raise CraErrors::InternalError, 'Failed to delete entry'
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
      end
    end
  end
end
