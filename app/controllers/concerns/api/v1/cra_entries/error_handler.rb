# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      module ErrorHandler
        extend ActiveSupport::Concern
        include Common::ErrorHandler

        private

        def handle_record_invalid(exception)
          Rails.logger.error "CRA Entry Record invalid: #{exception.record.errors.full_messages.join(', ')}"

          error_invalid_payload(exception.record.errors.full_messages.join(', '))
        end

        def handle_cra_entry_validation_error(error)
          Rails.logger.warn "CRA Entry validation error: #{error}"

          error_invalid_payload(error.to_s)
        end

        def handle_duplicate_entry_error(mission_id, date)
          Rails.logger.warn "Duplicate CRA entry for mission #{mission_id} on date #{date}"

          error_conflict('An entry already exists for this mission and date in this CRA',
                         { mission_id: mission_id, date: date })
        end

        def handle_cra_locked_error(message = 'Cannot modify entries in locked CRA')
          Rails.logger.warn "CRA locked error: #{message}"

          error_conflict(message)
        end

        def handle_cra_submitted_error(message = 'Cannot modify entries in submitted CRA')
          Rails.logger.warn "CRA submitted error: #{message}"

          error_conflict(message)
        end

        def handle_entry_access_error(message)
          Rails.logger.warn "CRA Entry access error: #{message}"

          error_forbidden(message)
        end

        def handle_mission_access_error(message)
          Rails.logger.warn "Mission access error for CRA entry: #{message}"

          error_forbidden(message)
        end

        def handle_business_rule_violation(message = 'Business rule violated for CRA entry')
          Rails.logger.warn "CRA Entry Business rule violated: #{message}"

          error_conflict(message)
        end

        def handle_conflict_error(message = 'Conflict error for CRA entry')
          Rails.logger.warn "CRA Entry Conflict error: #{message}"

          error_conflict(message)
        end

        def handle_rate_limit_exceeded(message = 'Rate limit exceeded for CRA entry operations')
          Rails.logger.warn "CRA Entry Rate limit exceeded: #{message}"

          error_too_many_requests(message)
        end

        def handle_internal_error(error = nil)
          log_api_error(error) if error

          error_internal
        end

        def handle_cra_entry_not_found(entry_id = nil)
          Rails.logger.warn "CRA entry not found: #{entry_id}"

          message = entry_id ? "CRA entry with ID #{entry_id} not found" : 'CRA entry not found'
          error_not_found(message)
        end

        def handle_cra_not_found(cra_id = nil)
          Rails.logger.warn "CRA not found for entry operation: #{cra_id}"

          message = cra_id ? "CRA with ID #{cra_id} not found" : 'CRA not found'
          error_not_found(message)
        end

        def handle_mission_not_found(mission_id = nil)
          Rails.logger.warn "Mission not found for CRA entry: #{mission_id}"

          message = mission_id ? "Mission with ID #{mission_id} not found" : 'Mission not found'
          error_not_found(message)
        end

        def handle_unauthorized_access(message = 'Unauthorized access to CRA entry')
          Rails.logger.warn "Unauthorized CRA entry access: #{message}"

          error_forbidden(message)
        end

        def handle_forbidden(message = 'Access denied to CRA entry')
          Rails.logger.warn "CRA entry access forbidden: #{message}"

          error_forbidden(message)
        end

        def handle_entry_calculation_error(message)
          Rails.logger.error "CRA Entry calculation error: #{message}"

          error_internal
        end

        def handle_entry_date_error(date, reason = nil)
          Rails.logger.warn "Invalid CRA entry date #{date}: #{reason}"

          details = { reason: reason } if reason.present?
          error_bad_request("Invalid entry date: #{date}", details)
        end

        def handle_entry_quantity_error(quantity, reason = nil)
          Rails.logger.warn "Invalid CRA entry quantity #{quantity}: #{reason}"

          details = { reason: reason } if reason.present?
          error_bad_request("Invalid entry quantity: #{quantity}", details)
        end

        def handle_entry_unit_price_error(unit_price, reason = nil)
          Rails.logger.warn "Invalid CRA entry unit_price #{unit_price}: #{reason}"

          details = { reason: reason } if reason.present?
          error_bad_request("Invalid entry unit price: #{unit_price}", details)
        end
      end
    end
  end
end
