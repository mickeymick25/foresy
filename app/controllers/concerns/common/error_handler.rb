# frozen_string_literal: true

module Common
  module ErrorHandler
    extend ActiveSupport::Concern

    included do
      rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
      rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
      rescue_from ActionController::UnpermittedParameters, with: :handle_unpermitted_parameters
    end

    private

    def handle_record_invalid(exception)
      Rails.logger.error "Record invalid: #{exception.record.errors.full_messages.join(', ')}"

      render json: {
        error: 'validation_error',
        message: exception.record.errors.full_messages,
        resource_type: exception.record.class.name
      }, status: :unprocessable_entity
    end

    def handle_record_not_found(exception)
      Rails.logger.warn "Record not found: #{exception.model} #{exception.id}"

      render json: {
        error: 'not_found',
        message: "#{exception.model} not found"
      }, status: :not_found
    end

    def handle_parameter_missing(exception)
      Rails.logger.warn "Parameter missing: #{exception.param}"

      render json: {
        error: 'parameter_missing',
        message: "Required parameter missing: #{exception.param}"
      }, status: :bad_request
    end

    def handle_unpermitted_parameters(exception)
      Rails.logger.warn "Unpermitted parameters: #{exception.params.join(', ')}"

      render json: {
        error: 'unpermitted_parameters',
        message: "Unpermitted parameters: #{exception.params.join(', ')}"
      }, status: :bad_request
    end

    def log_api_error(error, context = {})
      Rails.logger.error "API Error: #{error.class} - #{error.message}"
      Rails.logger.error "Context: #{context.inspect}"
      Rails.logger.error error.backtrace&.first(5)&.join("\n")
    end

    def handle_forbidden(message = 'Access denied')
      render json: {
        error: 'forbidden',
        message: message
      }, status: :forbidden
    end

    def handle_business_rule_violation(message = 'Business rule violated')
      render json: {
        error: 'business_rule_violation',
        message: message
      }, status: :conflict
    end

    def handle_conflict_error(message = 'Conflict error')
      render json: {
        error: 'conflict',
        message: message
      }, status: :conflict
    end

    def handle_rate_limit_exceeded(message = 'Rate limit exceeded')
      render json: {
        error: 'rate_limit_exceeded',
        message: message
      }, status: :too_many_requests
    end

    def handle_internal_error(error = nil)
      log_api_error(error) if error

      render json: {
        error: 'internal_error',
        message: 'An unexpected error occurred'
      }, status: :internal_server_error
    end
  end
end
