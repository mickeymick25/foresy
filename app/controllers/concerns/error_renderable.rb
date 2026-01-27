# frozen_string_literal: true

# ErrorRenderable
#
# Concern that provides error handling methods for controllers.
# Handles different error rendering strategies based on environment.
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
    render_error(message, :bad_request)
  end

  def render_unauthorized(message = 'Unauthorized')
    render_error(message, :unauthorized)
  end

  def render_forbidden(message = 'Forbidden')
    render_error(message, :forbidden)
  end

  def render_not_found(message = 'Not Found')
    render_error(message, :not_found)
  end

  def render_unprocessable_content(message = 'Unprocessable Entity')
    render_error(message, :unprocessable_content)
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
      render json: {
        error: 'Internal server error',
        exception_class: exception.class.name,
        exception_message: exception.message,
        backtrace: exception.backtrace&.first(5)
      }, status: :internal_server_error
    else
      render_error('Internal server error', :internal_server_error)
    end
  end

  def render_error(message, status)
    render json: {
      error: message
    }, status: status
  end
end
