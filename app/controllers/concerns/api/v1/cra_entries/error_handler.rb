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

          render json: {
            error: 'CRA Entry Validation Failed',
            message: exception.record.errors.full_messages,
            resource_type: 'CRA Entry'
          }, status: :unprocessable_entity
        end

        def handle_cra_entry_validation_error(error)
          Rails.logger.warn "CRA Entry validation error: #{error}"

          render json: {
            error: 'cra_entry_validation_error',
            message: error,
            resource_type: 'CRA Entry'
          }, status: :unprocessable_entity
        end

        def handle_duplicate_entry_error(mission_id, date)
          Rails.logger.warn "Duplicate CRA entry for mission #{mission_id} on date #{date}"

          render json: {
            error: 'duplicate_entry',
            message: 'An entry already exists for this mission and date in this CRA',
            resource_type: 'CRA Entry',
            details: {
              mission_id: mission_id,
              date: date
            }
          }, status: :conflict
        end

        def handle_cra_locked_error(message = 'Cannot modify entries in locked CRA')
          Rails.logger.warn "CRA locked error: #{message}"

          render json: {
            error: 'cra_locked',
            message: message,
            resource_type: 'CRA Entry'
          }, status: :conflict
        end

        def handle_cra_submitted_error(message = 'Cannot modify entries in submitted CRA')
          Rails.logger.warn "CRA submitted error: #{message}"

          render json: {
            error: 'cra_submitted',
            message: message,
            resource_type: 'CRA Entry'
          }, status: :conflict
        end

        def handle_entry_access_error(message)
          Rails.logger.warn "CRA Entry access error: #{message}"

          render json: {
            error: 'cra_entry_access_error',
            message: message,
            resource_type: 'CRA Entry'
          }, status: :forbidden
        end

        def handle_mission_access_error(message)
          Rails.logger.warn "Mission access error for CRA entry: #{message}"

          render json: {
            error: 'mission_access_error',
            message: message,
            resource_type: 'Mission'
          }, status: :forbidden
        end

        def handle_business_rule_violation(message = 'Business rule violated for CRA entry')
          Rails.logger.warn "CRA Entry Business rule violated: #{message}"

          render json: {
            error: 'cra_entry_business_rule_violation',
            message: message,
            resource_type: 'CRA Entry'
          }, status: :conflict
        end

        def handle_conflict_error(message = 'Conflict error for CRA entry')
          Rails.logger.warn "CRA Entry Conflict error: #{message}"

          render json: {
            error: 'cra_entry_conflict',
            message: message,
            resource_type: 'CRA Entry'
          }, status: :conflict
        end

        def handle_rate_limit_exceeded(message = 'Rate limit exceeded for CRA entry operations')
          Rails.logger.warn "CRA Entry Rate limit exceeded: #{message}"

          render json: {
            error: 'cra_entry_rate_limit_exceeded',
            message: message,
            resource_type: 'CRA Entry'
          }, status: :too_many_requests
        end

        def handle_internal_error(error = nil)
          log_api_error(error) if error

          render json: {
            error: 'cra_entry_internal_error',
            message: 'An unexpected error occurred',
            resource_type: 'CRA Entry'
          }, status: :internal_server_error
        end

        def handle_cra_entry_not_found(entry_id = nil)
          Rails.logger.warn "CRA entry not found: #{entry_id}"

          render json: {
            error: 'cra_entry_not_found',
            message: entry_id ? "CRA entry with ID #{entry_id} not found" : 'CRA entry not found',
            resource_type: 'CRA Entry'
          }, status: :not_found
        end

        def handle_cra_not_found(cra_id = nil)
          Rails.logger.warn "CRA not found for entry operation: #{cra_id}"

          render json: {
            error: 'cra_not_found',
            message: cra_id ? "CRA with ID #{cra_id} not found" : 'CRA not found',
            resource_type: 'CRA'
          }, status: :not_found
        end

        def handle_mission_not_found(mission_id = nil)
          Rails.logger.warn "Mission not found for CRA entry: #{mission_id}"

          render json: {
            error: 'mission_not_found',
            message: mission_id ? "Mission with ID #{mission_id} not found" : 'Mission not found',
            resource_type: 'Mission'
          }, status: :not_found
        end

        def handle_unauthorized_access(message = 'Unauthorized access to CRA entry')
          Rails.logger.warn "Unauthorized CRA entry access: #{message}"

          render json: {
            error: 'cra_entry_unauthorized',
            message: message,
            resource_type: 'CRA Entry'
          }, status: :forbidden
        end

        def handle_forbidden(message = 'Access denied to CRA entry')
          Rails.logger.warn "CRA entry access forbidden: #{message}"

          render json: {
            error: 'cra_entry_forbidden',
            message: message,
            resource_type: 'CRA Entry'
          }, status: :forbidden
        end

        def handle_entry_calculation_error(message)
          Rails.logger.error "CRA Entry calculation error: #{message}"

          render json: {
            error: 'entry_calculation_error',
            message: message,
            resource_type: 'CRA Entry'
          }, status: :internal_server_error
        end

        def handle_entry_date_error(date, reason = nil)
          Rails.logger.warn "Invalid CRA entry date #{date}: #{reason}"

          error_data = {
            error: 'invalid_entry_date',
            message: "Invalid entry date: #{date}",
            resource_type: 'CRA Entry'
          }

          error_data[:reason] = reason if reason.present?

          render json: error_data, status: :bad_request
        end

        def handle_entry_quantity_error(quantity, reason = nil)
          Rails.logger.warn "Invalid CRA entry quantity #{quantity}: #{reason}"

          error_data = {
            error: 'invalid_entry_quantity',
            message: "Invalid entry quantity: #{quantity}",
            resource_type: 'CRA Entry'
          }

          error_data[:reason] = reason if reason.present?

          render json: error_data, status: :bad_request
        end

        def handle_entry_unit_price_error(unit_price, reason = nil)
          Rails.logger.warn "Invalid CRA entry unit_price #{unit_price}: #{reason}"

          error_data = {
            error: 'invalid_entry_unit_price',
            message: "Invalid entry unit price: #{unit_price}",
            resource_type: 'CRA Entry'
          }

          error_data[:reason] = reason if reason.present?

          render json: error_data, status: :bad_request
        end
      end
    end
  end
end
