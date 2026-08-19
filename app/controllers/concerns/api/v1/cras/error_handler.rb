# frozen_string_literal: true

module Api
  module V1
    module Cras
      module ErrorHandler
        extend ActiveSupport::Concern
        include Common::ErrorHandler

        private

        def handle_record_invalid(exception)
          Rails.logger.error "CRA Record invalid: #{exception.record.errors.full_messages.join(', ')}"

          error_invalid_payload(
            exception.record.errors.full_messages.join(', '),
            { errors: exception.record.errors.full_messages, model: 'CRA' }
          )
        end

        def handle_cra_validation_error(error)
          Rails.logger.warn "CRA validation error: #{error}"

          error_invalid_payload(error, { resource_type: 'CRA' })
        end

        def handle_duplicate_cra_error(month, year, user_id)
          Rails.logger.warn "Duplicate CRA for user #{user_id} in month #{month}/#{year}"

          error_conflict(
            'A CRA already exists for this user, month, and year',
            { month: month, year: year, user_id: user_id }
          )
        end

        def handle_cra_locked_error(message = 'Cannot modify locked CRA')
          Rails.logger.warn "CRA locked error: #{message}"

          error_conflict(message, { resource_type: 'CRA' })
        end

        def handle_cra_submitted_error(message = 'Cannot modify submitted CRA')
          Rails.logger.warn "CRA submitted error: #{message}"

          error_conflict(message, { resource_type: 'CRA' })
        end

        def handle_cra_access_error(message)
          Rails.logger.warn "CRA access error: #{message}"

          error_forbidden(message, { resource_type: 'CRA' })
        end

        def handle_no_independent_company_error(message = nil)
          message ||= 'User must have an independent company to perform this action'
          Rails.logger.warn "No independent company error: #{message}"

          error_forbidden(message, { resource_type: 'CRA' })
        end

        def handle_business_rule_violation(message = 'Business rule violated for CRA')
          Rails.logger.warn "CRA Business rule violated: #{message}"

          error_conflict(message, { resource_type: 'CRA' })
        end

        def handle_invalid_transition_error(from_status, to_status)
          Rails.logger.warn "Invalid CRA transition from #{from_status} to #{to_status}"

          error_unprocessable_entity(
            "Invalid transition from '#{from_status}' to '#{to_status}'",
            { from_status: from_status, to_status: to_status, resource_type: 'CRA' }
          )
        end

        def handle_conflict_error(message = 'Conflict error for CRA')
          Rails.logger.warn "CRA Conflict error: #{message}"

          error_conflict(message, { resource_type: 'CRA' })
        end

        def handle_rate_limit_exceeded(message = 'Rate limit exceeded for CRA operations')
          Rails.logger.warn "CRA Rate limit exceeded: #{message}"

          error_too_many_requests(message, { resource_type: 'CRA' })
        end

        def handle_internal_error(error = nil)
          error ? "#{error.class}: #{error.message}" : 'Internal server error'
          log_api_error(error) if error

          error_internal(error&.message, { resource_type: 'CRA' })
        end

        def handle_cra_not_found(cra_id = nil)
          message = cra_id ? "CRA with ID #{cra_id} not found" : 'CRA not found'
          Rails.logger.warn "CRA not found: #{cra_id}"

          error_not_found(message, { resource_type: 'CRA' })
        end

        def handle_unauthorized_access(message = 'Unauthorized access to CRA')
          Rails.logger.warn "Unauthorized CRA access: #{message}"

          error_forbidden(message, { resource_type: 'CRA' })
        end

        def handle_forbidden(message = 'Access denied to CRA')
          Rails.logger.warn "CRA access forbidden: #{message}"

          error_forbidden(message, { resource_type: 'CRA' })
        end

        def handle_cra_calculation_error(message)
          Rails.logger.error "CRA calculation error: #{message}"

          error_internal(message, { resource_type: 'CRA' })
        end

        def handle_cra_month_error(month, reason = nil)
          Rails.logger.warn "Invalid CRA month #{month}: #{reason}"

          details = { month: month, resource_type: 'CRA' }
          details[:reason] = reason if reason.present?

          error_bad_request("Invalid CRA month: #{month}", details)
        end

        def handle_cra_year_error(year, reason = nil)
          Rails.logger.warn "Invalid CRA year #{year}: #{reason}"

          details = { year: year, resource_type: 'CRA' }
          details[:reason] = reason if reason.present?

          error_bad_request("Invalid CRA year: #{year}", details)
        end

        def handle_cra_currency_error(currency, reason = nil)
          Rails.logger.warn "Invalid CRA currency #{currency}: #{reason}"

          details = { currency: currency, resource_type: 'CRA' }
          details[:reason] = reason if reason.present?

          error_bad_request("Invalid CRA currency: #{currency}", details)
        end

        def handle_cra_mission_error(message)
          Rails.logger.warn "CRA Mission error: #{message}"

          error_invalid_payload(message, { resource_type: 'CRA' })
        end
      end
    end
  end
end
