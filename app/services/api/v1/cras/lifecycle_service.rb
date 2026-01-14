# frozen_string_literal: true

# app/services/api/v1/cras/lifecycle_service.rb
# Migration vers ApplicationResult - Étape 2 du plan de migration
# Contrat unique : tous les services retournent ApplicationResult
# Aucune exception métier levée - tout via Result.fail

require_relative '../../../../../lib/application_result'
require_relative '../../../../../app/services/git_ledger_service'

module Api
  module V1
    module Cras
      # Service for managing CRA lifecycle transitions (submit, lock) with Git Ledger integration
      # Uses ApplicationResult contract for consistent Service → Controller communication
      #
      # CONTRACT:
      # - Returns ApplicationResult exclusively
      # - No business exceptions raised
      # - No HTTP concerns in service
      # - Single source of truth for business rules
      #
      # @example Submit a CRA
      #   result = LifecycleService.submit!(cra: cra, current_user: user)
      #   result.ok? # => true/false
      #   result.data # => { item: { ... } }
      #
      # @example Lock a CRA
      #   result = LifecycleService.lock!(cra: cra, current_user: user)
      #   result.ok? # => true/false
      #   result.data # => { item: { ... } }
      #
      class LifecycleService
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
          # Input validation
          validation_result = validate_inputs
          return validation_result unless validation_result.nil?

          # Permission validation
          permission_result = validate_submit_permissions
          return permission_result unless permission_result.nil?

          # Perform submit transition
          transition_result = perform_submit_transition
          return transition_result unless transition_result.nil?

          # Success response
          Result.ok(
            data: {
              item: serialize_cra(@cra)
            },
            status: :ok
          )
        # No rescue StandardError - let exceptions bubble up for debugging

        def lock!
          # Input validation
          validation_result = validate_inputs
          return validation_result unless validation_result.nil?

          # Permission validation
          permission_result = validate_lock_permissions
          return permission_result unless permission_result.nil?

          # Perform lock transition
          transition_result = perform_lock_transition
          return transition_result unless transition_result.nil?

          # Success response
          Result.ok(
            data: {
              item: serialize_cra(@cra)
            },
            status: :ok
          )
        # No rescue StandardError - let exceptions bubble up for debugging

        private

        attr_reader :cra, :current_user

        # === Validation ===

        def validate_inputs
          # CRA validation
          unless cra.present?
            return Result.fail(
              error: :not_found,
              status: :not_found,
              message: "CRA not found"
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

        def validate_submit_permissions
          # Ownership validation
          ownership_result = validate_ownership
          return ownership_result unless ownership_result.nil?

          # Draft status validation
          draft_result = validate_draft_status
          return draft_result unless draft_result.nil?

          # Has entries validation
          entries_result = validate_has_entries
          return entries_result unless entries_result.nil?

          nil # All permissions validated
        end

        def validate_lock_permissions
          # Ownership validation
          ownership_result = validate_ownership
          return ownership_result unless ownership_result.nil?

          # Submitted status validation
          submitted_result = validate_submitted_status
          return submitted_result unless submitted_result.nil?

          # Not locked validation
          locked_result = validate_not_locked
          return locked_result unless locked_result.nil?

          nil # All permissions validated
        end

        def validate_ownership
          unless cra.created_by_user_id == current_user.id
            return Result.fail(
              error: :unauthorized,
              status: :unauthorized,
              message: "Only the CRA creator can perform this action"
            )
          end
          nil
        end

        def validate_draft_status
          unless cra.draft?
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "CRA must be in draft status to submit"
            )
          end
          nil
        end

        def validate_submitted_status
          unless cra.submitted?
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "CRA must be in submitted status to lock"
            )
          end
          nil
        end

        def validate_not_locked
          if cra.locked?
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: "CRA is already locked"
            )
          end
          nil
        end

        def validate_has_entries
          unless cra.cra_entries.active.any?
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "CRA must have at least one entry to be submitted"
            )
          end
          nil
        end

        # === Transitions ===

        def perform_submit_transition
          begin
            ActiveRecord::Base.transaction do
              Rails.logger.info "[Cras::LifecycleService] Recalculating totals for CRA #{cra.id}"
              cra.recalculate_totals

              unless cra.submit!
                return handle_submit_error
              end

              cra.reload
              Rails.logger.info "[Cras::LifecycleService] CRA #{cra.id} submitted successfully"
            end
            nil # Success
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "[Cras::LifecycleService] Submit transition failed: #{e.message}"
            handle_submit_error(e.record)
          end
        end

        def perform_lock_transition
          begin
            ActiveRecord::Base.transaction do
              Rails.logger.info "[Cras::LifecycleService] Recalculating totals for CRA #{cra.id}"
              cra.recalculate_totals

              Rails.logger.info "[Cras::LifecycleService] Creating Git Ledger commit for CRA #{cra.id}"

              # Commit CRA to Git Ledger for immutability (FC-07 requirement)
              GitLedgerService.commit_cra_lock!(cra)

              unless cra.lock!
                return handle_lock_error
              end

              cra.reload
              Rails.logger.info "[Cras::LifecycleService] CRA #{cra.id} locked successfully with Git Ledger"
            end
            nil # Success
          rescue GitLedgerService::CommitError => e
            Rails.logger.error "[Cras::LifecycleService] Git Ledger commit failed: #{e.message}"
            Result.fail(
              error: :internal_error,
              status: :internal_error,
              message: "Failed to create Git Ledger commit"
            )
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "[Cras::LifecycleService] Lock transition failed: #{e.message}"
            handle_lock_error(e.record)
          end
        end

        # === Error Handlers ===

        def handle_submit_error(record = nil)
          errors = (record&.errors&.full_messages || cra.errors.full_messages)

          if errors.any? { |msg| msg.include?('Only draft') }
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "CRA must be in draft status to submit"
            )
          elsif errors.any? { |msg| msg.include?('entries') }
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "CRA must have entries to submit"
            )
          else
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: errors.join(', ')
            )
          end
        end

        def handle_lock_error(record = nil)
          errors = (record&.errors&.full_messages || cra.errors.full_messages)

          if errors.any? { |msg| msg.include?('Only submitted') }
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "CRA must be in submitted status to lock"
            )
          elsif errors.any? { |msg| msg.include?('already locked') }
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: "CRA is already locked"
            )
          else
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: errors.join(', ')
            )
          end
        end

        # === Serialization ===

        def serialize_cra(cra)
          {
            id: cra.id,
            month: cra.month,
            year: cra.year,
            description: cra.description,
            currency: cra.currency,
            status: cra.status,
            total_days: cra.total_days,
            total_amount: cra.total_amount,
            created_at: cra.created_at,
            updated_at: cra.updated_at
          }
        end
      end
    end
  end
end
