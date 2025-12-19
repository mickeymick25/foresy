# frozen_string_literal: true

# AuthenticationLoggingConcern
#
# Concern providing logging methods for authentication services.
# Extracted from AuthenticationMetricsConcern to reduce module length.
#
module AuthenticationLoggingConcern
  extend ActiveSupport::Concern

  class_methods do
    def log_login_success(user, duration)
      Rails.logger.info "User #{user.email} login successful in #{duration.round(3)}s"
    end

    def log_login_error(user, remote_ip, user_agent, error)
      Rails.logger.error "Login failed for user #{user.email} from IP: #{remote_ip}"
      Rails.logger.error "User-Agent: #{user_agent}"
      Rails.logger.error "Error: #{error.class.name} - #{error.message}"
    end

    def log_and_return_nil(message, token)
      Rails.logger.warn "#{message}: #{token[0..20]}..." if token.present?
      nil
    end

    def log_jwt_decode_error(message, error, token)
      Rails.logger.warn "#{message}: #{error.class.name} - #{error.message}"
      Rails.logger.warn "Token (first 50 chars): #{token[0..50]}..." if token.present?

      # Add APM metrics if available
      if defined?(NewRelic)
        NewRelic::Agent.add_custom_attributes({
                                                jwt_error_type: error.class.name,
                                                jwt_error_message: error.message,
                                                jwt_operation: 'decode',
                                                token_length: token&.length
                                              })
      end

      # Add metrics for other APMs
      if defined?(Datadog)
        Datadog::Tracer.active_span.set_tag('jwt.error_type', error.class.name)
        Datadog::Tracer.active.span.set_tag('jwt.operation', 'decode')
      end
    end

    def log_refresh_validation_error(error, token)
      Rails.logger.warn "Refresh token validation error: #{error.class.name} - #{error.message}"
      Rails.logger.warn "Token (first 50 chars): #{token[0..50]}..." if token.present?
    end

    def log_refresh_success(user, duration)
      Rails.logger.info "User #{user.email} refresh successful in #{duration.round(3)}s"
    end

    def log_refresh_error(error, remote_ip, user_agent, refresh_token)
      Rails.logger.error "Refresh failed from IP: #{remote_ip}"
      Rails.logger.error "User-Agent: #{user_agent}"
      Rails.logger.error "Error: #{error.class.name} - #{error.message}"
      Rails.logger.error "Token (first 50 chars): #{refresh_token[0..50]}..." if refresh_token.present?
    end
  end
end
