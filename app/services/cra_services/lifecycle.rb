# frozen_string_literal: true

# CRA Lifecycle Service - Services Layer Architecture
# Migrated from Api::V1::Cras::LifecycleService to CraServices namespace
# Uses ApplicationResult contract for consistent Service → Controller communication
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
#
# @example Submit a CRA
#   result = CraServices::Lifecycle.call(
#     cra: cra_instance,
#     action: 'submit',
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { cra: {...} }
#
# @example Lock a CRA
#   result = CraServices::Lifecycle.call(
#     cra: cra_instance,
#     action: 'lock',
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { cra: {...} }
#
class CraServices::Lifecycle
  def self.call(cra:, action:, current_user:)
    new(cra: cra, action: action, current_user: current_user).call
  end

  def initialize(cra:, action:, current_user:)
    @cra = cra
    @action = action
    @current_user = current_user
  end

  def call
    # Input validation
    return ApplicationResult.bad_request(
      error: :missing_cra,
      message: "CRA is required"
    ) unless @cra.present?

    return ApplicationResult.bad_request(
      error: :missing_user,
      message: "Current user is required"
    ) unless @current_user.present?

    return ApplicationResult.bad_request(
      error: :missing_action,
      message: "Action is required (submit or lock)"
    ) unless @action.present?

    # Validate action
    unless %w[submit lock].include?(@action)
      return ApplicationResult.bad_request(
        error: :invalid_action,
        message: "Action must be 'submit' or 'lock'"
      )
    end

    # Route to appropriate method
    if @action == 'submit'
      handle_submit
    elsif @action == 'lock'
      handle_lock
    end
  end

  private

  attr_reader :cra, :action, :current_user

  def handle_submit
    # Permission validation
    return ApplicationResult.forbidden(
      error: :insufficient_permissions,
      message: "Only the CRA creator can perform this action"
    ) unless cra.created_by_user_id == current_user.id

    # Status validation - must be draft to submit
    return ApplicationResult.conflict(
      error: :invalid_transition,
      message: "Cannot submit CRA from status #{cra.status}. Only draft CRAs can be submitted."
    ) unless cra.draft?

    # Business rule - must have entries to submit
    return ApplicationResult.bad_request(
      error: :cra_has_no_entries,
      message: "CRA must have at least one entry to be submitted"
    ) unless cra.cra_entries.active.any?

    # Perform submit transition
    perform_submit_transition
  end

  def handle_lock
    # Permission validation
    return ApplicationResult.forbidden(
      error: :insufficient_permissions,
      message: "Only the CRA creator can perform this action"
    ) unless cra.created_by_user_id == current_user.id

    # Status validation - must be submitted to lock
    return ApplicationResult.conflict(
      error: :invalid_transition,
      message: "Cannot lock CRA from status #{cra.status}. Only submitted CRAs can be locked."
    ) unless cra.submitted?

    # Status validation - must not already be locked
    return ApplicationResult.conflict(
      error: :cra_already_locked,
      message: "CRA is already locked"
    ) if cra.locked?

    # Perform lock transition
    perform_lock_transition
  end

  def perform_submit_transition
    begin
      ActiveRecord::Base.transaction do
        # Recalculate totals before submit
        cra.recalculate_totals

        # Submit the CRA
        cra.submit!
        cra.reload

        ApplicationResult.success(
          data: { cra: cra },
          message: "CRA submitted successfully"
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      ApplicationResult.unprocessable_entity(
        error: :validation_failed,
        message: e.record.errors.full_messages.join(', ')
      )
    rescue StandardError => e
      Rails.logger.error "CraServices::Lifecycle submit error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :submit_failed,
        message: "Failed to submit CRA: #{e.message}"
      )
    end
  end

  def perform_lock_transition
    begin
      ActiveRecord::Base.transaction do
        # Recalculate totals before lock
        cra.recalculate_totals

        # Lock the CRA (includes Git Ledger commit)
        cra.lock!
        cra.reload

        ApplicationResult.success(
          data: { cra: cra },
          message: "CRA locked successfully"
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      ApplicationResult.unprocessable_entity(
        error: :validation_failed,
        message: e.record.errors.full_messages.join(', ')
      )
    rescue StandardError => e
      Rails.logger.error "CraServices::Lifecycle lock error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :lock_failed,
        message: "Failed to lock CRA: #{e.message}"
      )
    end
  end
end
