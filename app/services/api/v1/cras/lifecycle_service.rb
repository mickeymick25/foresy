# frozen_string_literal: true

module Api
  module V1
    module Cras
      # Service for managing CRA lifecycle transitions (submit, lock) with Git Ledger integration
      # Uses FC07-compliant business exceptions instead of Result monads
      #
      # @example Submit a CRA
      #   result = LifecycleService.submit!(cra: cra, current_user: user)
      #   result.cra # => Cra (submitted)
      #
      # @example Lock a CRA
      #   result = LifecycleService.lock!(cra: cra, current_user: user)
      #   result.cra # => Cra (locked with Git Ledger)
      #
      # @raise [CraErrors::CraLockedError] if CRA is already locked
      # @raise [CraErrors::CraSubmittedError] if CRA is already submitted (for submit action)
      # @raise [CraErrors::InvalidTransitionError] if status transition is invalid
      # @raise [CraErrors::InvalidPayloadError] if CRA has no entries
      # @raise [CraErrors::UnauthorizedError] if user is not the creator
      #
      class LifecycleService
        Result = Struct.new(:cra, keyword_init: true)

        class << self
          def submit!(cra:, current_user:)
            new(cra: cra, current_user: current_user).submit!
          end

          def lock!(cra:, current_user:)
            new(cra: cra, current_user: current_user).lock!
          end
        end

        def initialize(cra:, current_user:)
          @cra = cra
          @current_user = current_user
        end

        def submit!
          Rails.logger.info "[Cras::LifecycleService] Submitting CRA #{@cra&.id}"

          validate_inputs!
          validate_submit_permissions!
          perform_submit_transition!

          Rails.logger.info "[Cras::LifecycleService] Successfully submitted CRA #{@cra.id}"
          Result.new(cra: @cra)
        end

        def lock!
          Rails.logger.info "[Cras::LifecycleService] Locking CRA #{@cra&.id}"

          validate_inputs!
          validate_lock_permissions!
          perform_lock_transition!

          Rails.logger.info "[Cras::LifecycleService] Successfully locked CRA #{@cra.id}"
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

        def validate_submit_permissions!
          check_ownership!
          check_draft_status!
          check_has_entries!
        end

        def validate_lock_permissions!
          check_ownership!
          check_submitted_status!
          check_not_locked!
        end

        def check_ownership!
          return if cra.created_by_user_id == current_user.id

          raise CraErrors::UnauthorizedError, 'Only the CRA creator can perform this action'
        end

        def check_draft_status!
          return if cra.draft?

          raise CraErrors::InvalidTransitionError.new(cra.status, 'submitted')
        end

        def check_submitted_status!
          return if cra.submitted?

          raise CraErrors::InvalidTransitionError.new(cra.status, 'locked')
        end

        def check_not_locked!
          return unless cra.locked?

          raise CraErrors::CraLockedError, 'CRA is already locked'
        end

        def check_has_entries!
          return if cra.cra_entries.active.any?

          raise CraErrors::InvalidPayloadError, 'CRA must have at least one entry to be submitted'
        end

        # === Transitions ===

        def perform_submit_transition!
          ActiveRecord::Base.transaction do
            Rails.logger.info "[Cras::LifecycleService] Recalculating totals for CRA #{cra.id}"
            cra.recalculate_totals

            handle_submit_error unless cra.submit!

            cra.reload
            Rails.logger.info "[Cras::LifecycleService] CRA #{cra.id} submitted successfully"
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[Cras::LifecycleService] Submit transition failed: #{e.message}"
          raise CraErrors::InvalidPayloadError, e.record.errors.full_messages.join(', ')
        end

        def perform_lock_transition!
          ActiveRecord::Base.transaction do
            Rails.logger.info "[Cras::LifecycleService] Recalculating totals for CRA #{cra.id}"
            cra.recalculate_totals

            Rails.logger.info "[Cras::LifecycleService] Creating Git Ledger commit for CRA #{cra.id}"
            cra.lock!

            handle_lock_error unless cra.locked?

            cra.reload
            Rails.logger.info "[Cras::LifecycleService] CRA #{cra.id} locked successfully with Git Ledger"
          end
        rescue GitLedgerService::CommitError => e
          Rails.logger.error "[Cras::LifecycleService] Git Ledger commit failed: #{e.message}"
          raise CraErrors::InternalError, 'Failed to create Git Ledger commit'
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[Cras::LifecycleService] Lock transition failed: #{e.message}"
          raise CraErrors::InvalidPayloadError, e.record.errors.full_messages.join(', ')
        end

        # === Error Handlers ===

        def handle_submit_error
          errors = cra.errors.full_messages

          if cra.errors[:base]&.any? { |msg| msg.include?('Only draft') }
            raise CraErrors::InvalidTransitionError.new(cra.status, 'submitted')
          elsif cra.errors[:base]&.any? { |msg| msg.include?('entries') }
            raise CraErrors::InvalidPayloadError, 'CRA must have entries to submit'
          else
            raise CraErrors::InvalidPayloadError, errors.join(', ')
          end
        end

        def handle_lock_error
          errors = cra.errors.full_messages

          if cra.errors[:base]&.any? { |msg| msg.include?('Only submitted') }
            raise CraErrors::InvalidTransitionError.new(cra.status, 'locked')
          elsif cra.errors[:base]&.any? { |msg| msg.include?('already locked') }
            raise CraErrors::CraLockedError, 'CRA is already locked'
          else
            raise CraErrors::InvalidPayloadError, errors.join(', ')
          end
        end
      end
    end
  end
end
