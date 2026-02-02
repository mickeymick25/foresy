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

          render json: {
            error: 'CRA Validation Failed',
            message: exception.record.errors.full_messages,
            resource_type: 'CRA'
          }, status: :unprocessable_entity
        end

        def handle_cra_validation_error(error)
          Rails.logger.warn "CRA validation error: #{error}"

          render json: {
            error: 'cra_validation_error',
            message: error,
            resource_type: 'CRA'
          }, status: :unprocessable_entity
        end

        def handle_duplicate_cra_error(month, year, user_id)
          Rails.logger.warn "Duplicate CRA for user #{user_id} in month #{month}/#{year}"

          render json: {
            error: 'duplicate_cra',
            message: 'A CRA already exists for this user, month, and year',
            resource_type: 'CRA',
            details: {
              month: month,
              year: year,
              user_id: user_id
            }
          }, status: :conflict
        end

        def handle_cra_locked_error(message = 'Cannot modify locked CRA')
          Rails.logger.warn "CRA locked error: #{message}"

          render json: {
            error: 'cra_locked',
            message: message,
            resource_type: 'CRA'
          }, status: :conflict
        end

        def handle_cra_submitted_error(message = 'Cannot modify submitted CRA')
          Rails.logger.warn "CRA submitted error: #{message}"

          render json: {
            error: 'cra_submitted',
            message: message,
            resource_type: 'CRA'
          }, status: :conflict
        end

        def handle_cra_access_error(message)
          Rails.logger.warn "CRA access error: #{message}"

          render json: {
            error: 'cra_access_error',
            message: message,
            resource_type: 'CRA'
          }, status: :forbidden
        end

        def handle_no_independent_company_error(message = nil)
          message ||= 'User must have an independent company to perform this action'
          Rails.logger.warn "No independent company error: #{message}"

          render json: {
            error: 'no_independent_company',
            message: message,
            resource_type: 'CRA'
          }, status: :forbidden
        end

        def handle_business_rule_violation(message = 'Business rule violated for CRA')
          Rails.logger.warn "CRA Business rule violated: #{message}"

          render json: {
            error: 'cra_business_rule_violation',
            message: message,
            resource_type: 'CRA'
          }, status: :conflict
        end

        def handle_invalid_transition_error(from_status, to_status)
          Rails.logger.warn "Invalid CRA transition from #{from_status} to #{to_status}"

          render json: {
            error: 'invalid_transition',
            message: "Invalid transition from '#{from_status}' to '#{to_status}'",
            resource_type: 'CRA',
            details: {
              from_status: from_status,
              to_status: to_status
            }
          }, status: :unprocessable_entity
        end

        def handle_conflict_error(message = 'Conflict error for CRA')
          Rails.logger.warn "CRA Conflict error: #{message}"

          render json: {
            error: 'cra_conflict',
            message: message,
            resource_type: 'CRA'
          }, status: :conflict
        end

        def handle_rate_limit_exceeded(message = 'Rate limit exceeded for CRA operations')
          Rails.logger.warn "CRA Rate limit exceeded: #{message}"

          render json: {
            error: 'cra_rate_limit_exceeded',
            message: message,
            resource_type: 'CRA'
          }, status: :too_many_requests
        end

        def handle_internal_error(error = nil)
          error ? "#{error.class}: #{error.message}" : 'Internal server error'
          log_api_error(error) if error

          render json: {
            error: 'cra_internal_error',
            message: 'An unexpected error occurred',
            resource_type: 'CRA'
          }, status: :internal_server_error
        end

        def handle_cra_not_found(cra_id = nil)
          Rails.logger.warn "CRA not found: #{cra_id}"

          render json: {
            error: 'cra_not_found',
            message: cra_id ? "CRA with ID #{cra_id} not found" : 'CRA not found',
            resource_type: 'CRA'
          }, status: :not_found
        end

        def handle_unauthorized_access(message = 'Unauthorized access to CRA')
          Rails.logger.warn "Unauthorized CRA access: #{message}"

          render json: {
            error: 'cra_unauthorized',
            message: message,
            resource_type: 'CRA'
          }, status: :forbidden
        end

        def handle_forbidden(message = 'Access denied to CRA')
          Rails.logger.warn "CRA access forbidden: #{message}"

          render json: {
            error: 'cra_forbidden',
            message: message,
            resource_type: 'CRA'
          }, status: :forbidden
        end

        def handle_cra_calculation_error(message)
          Rails.logger.error "CRA calculation error: #{message}"

          render json: {
            error: 'cra_calculation_error',
            message: message,
            resource_type: 'CRA'
          }, status: :internal_server_error
        end

        def handle_cra_month_error(month, reason = nil)
          Rails.logger.warn "Invalid CRA month #{month}: #{reason}"

          error_data = {
            error: 'invalid_cra_month',
            message: "Invalid CRA month: #{month}",
            resource_type: 'CRA'
          }

          error_data[:reason] = reason if reason.present?

          render json: error_data, status: :bad_request
        end

        def handle_cra_year_error(year, reason = nil)
          Rails.logger.warn "Invalid CRA year #{year}: #{reason}"

          error_data = {
            error: 'invalid_cra_year',
            message: "Invalid CRA year: #{year}",
            resource_type: 'CRA'
          }

          error_data[:reason] = reason if reason.present?

          render json: error_data, status: :bad_request
        end

        def handle_cra_currency_error(currency, reason = nil)
          Rails.logger.warn "Invalid CRA currency #{currency}: #{reason}"

          error_data = {
            error: 'invalid_cra_currency',
            message: "Invalid CRA currency: #{currency}",
            resource_type: 'CRA'
          }

          error_data[:reason] = reason if reason.present?

          render json: error_data, status: :bad_request
        end

        def handle_cra_mission_error(message)
          Rails.logger.warn "CRA Mission error: #{message}"

          render json: {
            error: 'cra_mission_error',
            message: message,
            resource_type: 'CRA'
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
