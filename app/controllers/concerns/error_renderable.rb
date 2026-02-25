# frozen_string_literal: true

# ErrorRenderable
#
# Concern that provides standardized error handling for controllers.
# All API errors follow a unified structure:
#
# {
#   "error": {
#     "code": "not_found",
#     "message": "Resource not found",
#     "details": [...]  # optional
#   }
# }
#
module ErrorRenderable
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing, with: ->(e) { render_bad_request(e.message) }

    rescue_from StandardError, with: :render_conditional_server_error
    rescue_from ApplicationError, with: :render_internal_server_error
  end

  private

  def render_bad_request(message = 'Bad Request')
    render_error('bad_request', message, :bad_request)
  end

  def render_unauthorized(message = 'Unauthorized')
    render_error('unauthorized', message, :unauthorized)
  end

  def render_forbidden(message = 'Forbidden')
    render_error('forbidden', message, :forbidden)
  end

  def render_not_found(message = 'Not Found')
    render_error('not_found', message, :not_found)
  end

  def render_unprocessable_entity(message = 'Unprocessable Entity')
    render_error('validation_failed', message, :unprocessable_entity)
  end

  def render_conditional_server_error(exception = nil)
    # Re-raise in development for better debugging, but render JSON in test/production
    raise exception if Rails.env.development?

    render_internal_server_error(exception)
  end

  def render_internal_server_error(exception = nil)
    Rails.logger.error "Internal server error: #{exception.message}" if exception
    Rails.logger.error exception.backtrace.join("\n") if exception

    # In test env, include exception details for debugging
    if Rails.env.test? && exception
      render_error(
        'internal_error',
        exception.message,
        :internal_server_error,
        [
          { class: exception.class.name, message: exception.message }
        ]
      )
    else
      render_error('internal_error', 'An unexpected error occurred', :internal_server_error)
    end
  end

  # Unified error rendering method
  # @param code [String] Error code (e.g., 'not_found', 'validation_failed')
  # @param message [String] Human-readable error message
  # @param status [Symbol] HTTP status code (e.g., :not_found, :unauthorized)
  # @param details [Array, nil] Optional array of error details
  def render_error(code, message, status, details = nil)
    render json: {
      error: {
        code: code,
        message: message,
        details: details
      }.compact
    }, status: status
  end

  # Renders an ApplicationResult following the standard response format
  # @param result [ApplicationResult] The result object from a service call
  # @param serializer [Symbol, nil] Optional serializer to use (e.g., :mission_serializer)
  def render_result(result, serializer: nil)
    if result.success?
      render_success(result, serializer)
    else
      render_failure(result)
    end
  end

  # Renders a successful result
  # @param result [ApplicationResult]
  # @param serializer [Symbol, nil]
  def render_success(result, serializer)
    data = if serializer && result.data.present?
             serialize_resource(result.data, serializer)
           else
             result.data
           end

    render json: data, status: result.status
  end

  # Renders a failure result
  # @param result [ApplicationResult]
  def render_failure(result)
    error_payload = {
      error: {
        code: result.error,
        message: result.message
      }.compact
    }

    # Add meta information if present
    error_payload[:meta] = result.meta if result.respond_to?(:meta) && result.meta.present?

    render json: error_payload, status: result.status
  end

  # Serializes a resource using the appropriate serializer
  # @param data [Hash, ActiveRecord::Base] The data to serialize
  # @param serializer [Symbol] The serializer name (e.g., :mission)
  def serialize_resource(data, _serializer)
    return data unless data.is_a?(Hash)

    # Handle single resource
    if data[:mission].present?
      data[:mission]
    elsif data[:item].present?
      data[:item]
    else
      data
    end
  end
end
