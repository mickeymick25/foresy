# frozen_string_literal: true

# StandardizedError
#
# Concern that provides standardized error response formatting for all API endpoints.
# Enforces Phase 1.9 - Negative Contract Hardening requirements:
#
# - All error responses follow a consistent JSON schema
# - Proper HTTP status codes are returned (400, 401, 403, 404, 422, 500)
# - Error responses include: code, message, details (optional)
#
# Usage:
#   include StandardizedError
#   render_error(:bad_request, 'INVALID_PARAMETER', 'Missing required field', { field: 'name' })
#
module StandardizedError
  extend ActiveSupport::Concern

  # Standard error codes - these are the ONLY allowed error codes
  ERROR_CODES = {
    # 4xx Client Errors
    bad_request: 'BAD_REQUEST',
    unauthorized: 'UNAUTHORIZED',
    forbidden: 'FORBIDDEN',
    not_found: 'NOT_FOUND',
    unprocessable_entity: 'UNPROCESSABLE_ENTITY',
    conflict: 'CONFLICT',
    too_many_requests: 'TOO_MANY_REQUESTS',
    invalid_payload: 'INVALID_PAYLOAD',
    invalid_parameter: 'INVALID_PARAMETER',
    missing_parameter: 'MISSING_PARAMETER',
    invalid_enum: 'INVALID_ENUM',
    malformed_json: 'MALFORMED_JSON',
    rate_limit_exceeded: 'RATE_LIMIT_EXCEEDED',

    # 5xx Server Errors
    internal_server_error: 'INTERNAL_SERVER_ERROR',
    service_unavailable: 'SERVICE_UNAVAILABLE'
  }.freeze

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ActionController::UnpermittedParameters, with: :handle_unpermitted_parameters
    rescue_from StandardError, with: :handle_standard_error
  end

  private

  # ============================================================
  # Standardized Error Rendering Methods
  # ============================================================

  # Render a standardized error response
  # @param status [Symbol] HTTP status (e.g., :bad_request, :not_found)
  # @param code [String] Error code (e.g., 'INVALID_PARAMETER')
  # @param message [String] Human-readable error message
  # @param details [Hash, nil] Additional error details (optional)
  def render_error(status, code, message, details = nil)
    response = {
      code: code,
      message: message
    }
    response[:details] = details if details.present?

    render json: response, status: status
  end

  # ============================================================
  # Convenience Methods for Common Errors
  # ============================================================

  def error_bad_request(message = 'Bad request', details = nil)
    render_error(:bad_request, ERROR_CODES[:bad_request], message, details)
  end

  def error_unauthorized(message = 'Unauthorized', details = nil)
    render_error(:unauthorized, ERROR_CODES[:unauthorized], message, details)
  end

  def error_forbidden(message = 'Forbidden', details = nil)
    render_error(:forbidden, ERROR_CODES[:forbidden], message, details)
  end

  def error_not_found(message = 'Resource not found', details = nil)
    render_error(:not_found, ERROR_CODES[:not_found], message, details)
  end

  def error_unprocessable_entity(message = 'Unprocessable entity', details = nil)
    render_error(:unprocessable_entity, ERROR_CODES[:unprocessable_entity], message, details)
  end

  def error_conflict(message = 'Conflict', details = nil)
    render_error(:conflict, ERROR_CODES[:conflict], message, details)
  end

  def error_too_many_requests(message = 'Too many requests', details = nil)
    render_error(:too_many_requests, ERROR_CODES[:rate_limit_exceeded], message, details)
  end

  def error_invalid_payload(message = 'Invalid payload', details = nil)
    render_error(:unprocessable_entity, ERROR_CODES[:invalid_payload], message, details)
  end

  def error_invalid_parameter(message = 'Invalid parameter', details = nil)
    render_error(:bad_request, ERROR_CODES[:invalid_parameter], message, details)
  end

  def error_missing_parameter(parameter_name, details = nil)
    details ||= {}
    details[:parameter] = parameter_name
    render_error(:bad_request, ERROR_CODES[:missing_parameter],
                 "Required parameter missing: #{parameter_name}", details)
  end

  def error_invalid_enum(field, value, valid_values, details = nil)
    details ||= {}
    details[:field] = field
    details[:provided_value] = value
    details[:valid_values] = valid_values
    render_error(:bad_request, ERROR_CODES[:invalid_enum],
                 "Invalid value '#{value}' for field '#{field}'. Valid values: #{valid_values.join(', ')}",
                 details)
  end

  def error_malformed_json(details = nil)
    render_error(:bad_request, ERROR_CODES[:malformed_json], 'Malformed JSON payload', details)
  end

  def error_internal(message = 'Internal server error', details = nil)
    # In production, don't leak internal details
    if Rails.env.production?
      render_error(:internal_server_error, ERROR_CODES[:internal_server_error],
                   'An unexpected error occurred', nil)
    else
      render_error(:internal_server_error, ERROR_CODES[:internal_server_error], message, details)
    end
  end

  # ============================================================
  # Rescue Handlers
  # ============================================================

  def handle_record_not_found(exception)
    details = {}
    details[:model] = exception.model if exception.respond_to?(:model)
    details[:id] = exception.id if exception.respond_to?(:id)

    render_error(:not_found, ERROR_CODES[:not_found],
                 'Resource not found', details)
  end

  def handle_record_invalid(exception)
    details = {}
    if exception.record&.errors
      details[:errors] = exception.record.errors.full_messages
      details[:model] = exception.record.class.name
    end

    render_error(:unprocessable_entity, ERROR_CODES[:invalid_payload],
                 exception.record&.errors&.full_messages&.join(', ') || 'Validation failed',
                 details)
  end

  def handle_parameter_missing(exception)
    details = { parameter: exception.param }
    error_missing_parameter(exception.param, details)
  end

  def handle_unpermitted_parameters(exception)
    details = { parameters: exception.params }
    render_error(:bad_request, ERROR_CODES[:invalid_parameter],
                 "Unpermitted parameters: #{exception.params.join(', ')}", details)
  end

  def handle_standard_error(exception = nil)
    Rails.logger.error "Internal server error: #{exception&.message}"
    Rails.logger.error exception&.backtrace&.join("\n") if exception

    details = {}
    if exception && Rails.env.test?
      details[:exception_class] = exception.class.name
      details[:exception_message] = exception.message
      details[:backtrace] = exception.backtrace&.first(5)
    end

    error_internal(exception&.message, details)
  end

  # ============================================================
  # Validation Helpers
  # ============================================================

  # Validate that a required parameter is present
  # @param params [ActionController::Parameters] params hash
  # @param required_fields [Array<Symbol>] list of required field names
  # @return [Array<Symbol>] list of missing fields (empty if all present)
  def validate_required_params(params, *required_fields)
    missing = []
    required_fields.each do |field|
      missing << field if params[field].blank? && params[field.to_s].blank?
    end
    missing
  end

  # Validate that a value is one of the allowed enum values
  # @param value [Object] the value to validate
  # @param allowed_values [Array] list of allowed values
  # @param field_name [String] name of the field for error messages
  # @return [Boolean] true if valid
  def validate_enum(value, allowed_values, _field_name)
    allowed_values.include?(value)
  end

  # Validate JSON parsing
  # @param json_string [String] JSON string to parse
  # @return [Hash, nil] parsed hash or nil if invalid
  def validate_json(json_string)
    JSON.parse(json_string)
  rescue JSON::ParserError
    nil
  end
end
