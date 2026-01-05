# frozen_string_literal: true

module Api
  module V1
    module Cras
      # Service for soft-deleting CRAs with comprehensive business rule validation
      # Uses FC07-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = DestroyService.call(cra: cra, current_user: user)
      #   result.cra # => Cra (soft deleted)
      #
      # @raise [CraErrors::CraLockedError] if CRA is locked
      # @raise [CraErrors::CraSubmittedError] if CRA is submitted
      # @raise [CraErrors::CraNotFoundError] if CRA not found or already deleted
      # @raise [CraErrors::UnauthorizedError] if user is not the creator
      # @raise [CraErrors::InvalidPayloadError] if CRA has active entries
      #
      class DestroyService
        Result = Struct.new(:cra, keyword_init: true)

        def self.call(cra:, current_user:)
          new(cra: cra, current_user: current_user).call
        end

        def initialize(cra:, current_user:)
          @cra = cra
          @current_user = current_user
        end

        def call
          Rails.logger.info "[Cras::DestroyService] Deleting CRA #{@cra&.id}"

          validate_inputs!
          check_permissions!
          perform_soft_delete!

          Rails.logger.info "[Cras::DestroyService] Successfully deleted CRA #{@cra.id}"
          Result.new(cra: @cra)
        end

        private

        attr_reader :cra, :current_user

        # === Validation ===

        def validate_inputs!
          raise CraErrors::CraNotFoundError unless cra.present?

          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                     field: :current_user)
          end
        end

        # === Permissions ===

        def check_permissions!
          check_not_deleted!
          check_ownership!
          check_cra_deletable!
          check_no_active_entries!
        end

        def check_not_deleted!
          raise CraErrors::CraNotFoundError, 'CRA is already deleted' if cra.discarded?
        end

        def check_ownership!
          return if cra.created_by_user_id == current_user.id

          raise CraErrors::UnauthorizedError, 'Only the CRA creator can delete this CRA'
        end

        def check_cra_deletable!
          raise CraErrors::CraLockedError, 'Locked CRAs cannot be deleted' if cra.locked?
          raise CraErrors::CraSubmittedError, 'Submitted CRAs cannot be deleted' if cra.submitted?
        end

        def check_no_active_entries!
          return unless cra.cra_entries.active.any?

          raise CraErrors::InvalidPayloadError,
                'Cannot delete CRA with active entries. Please delete all entries first.'
        end

        # === Delete ===

        def perform_soft_delete!
          ActiveRecord::Base.transaction do
            raise CraErrors::InternalError, 'Failed to delete CRA' unless cra.discard

            cra.reload
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[Cras::DestroyService] Soft delete failed: #{e.message}"
          raise CraErrors::InternalError, 'Failed to delete CRA'
        end
      end
    end
  end
end
