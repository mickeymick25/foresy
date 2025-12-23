# frozen_string_literal: true

# AuthenticationLoggingConcern
#
# Concern providing logging methods for authentication services.
# Extracted from AuthenticationMetricsConcern to reduce module length.
#
# SECURITY NOTE: Tokens are NEVER logged to prevent secret leakage in logs.
# Only token presence and length are logged for debugging purposes.
#
module AuthenticationLoggingConcern
  extend ActiveSupport::Concern

  class_methods do
    def log_login_success(user, duration)
      Rails.logger.info "User #{user.id} login successful in #{duration.round(3)}s"
    end

    def log_login_error(user, remote_ip, _user_agent, error)
      Rails.logger.error "Login failed for user #{user.id} from IP: #{mask_ip(remote_ip)}"
      Rails.logger.error "Error: #{error.class.name}"
    end

    def log_and_return_nil(message, _context = nil)
      Rails.logger.warn "Auth validation failed: #{message}"
      nil
    end

    def log_jwt_decode_error(message, error, token)
      Rails.logger.warn "#{message}: #{error.class.name}"
      Rails.logger.debug "Token present: #{token.present?}, length: #{token&.length}" if Rails.env.development?

      # Add APM metrics if available (no token data)
      JsonWebToken.add_datadog_tags({
                                      jwt_error_type: error.class.name,
                                      jwt_operation: 'decode'
                                    })
    end

    def log_refresh_validation_error(error, _token)
      Rails.logger.warn "Refresh token validation error: #{error.class.name}"
    end

    def log_refresh_success(user, duration)
      Rails.logger.info "User #{user.id} refresh successful in #{duration.round(3)}s"
    end

    def log_refresh_error(error, remote_ip, _user_agent, _refresh_token)
      Rails.logger.error "Refresh failed from IP: #{mask_ip(remote_ip)}"
      Rails.logger.error "Error: #{error.class.name}"
    end

    private

    # Mask IP address for privacy (show only first two octets for IPv4)
    def mask_ip(ip)
      return 'unknown' if ip.blank?

      parts = ip.to_s.split('.')
      return ip if parts.length != 4

      "#{parts[0]}.#{parts[1]}.*.*"
    end
  end
end
