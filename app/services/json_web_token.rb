# frozen_string_literal: true

require 'jwt'

# JsonWebToken
#
# Service responsible for encoding and decoding JSON Web Tokens (JWT).
# Provides methods to generate access and refresh tokens used for user authentication.
#
# Constants:
# - SECRET_KEY: Used to sign and verify JWTs (based on Rails secret_key_base)
# - ACCESS_TOKEN_EXPIRATION: Default expiration time for access tokens (15 minutes)
# - REFRESH_TOKEN_EXPIRATION: Default expiration time for refresh tokens (30 days)
#
# Class Methods:
# - .encode(payload, exp = ACCESS_TOKEN_EXPIRATION.from_now): Encodes a payload into a JWT token
# - .refresh_token(user_id): Creates a refresh token with extended expiration
# - .decode(token): Decodes a JWT token and returns its payload as a HashWithIndifferentAccess
#
# SECURITY NOTE: Tokens are NEVER logged to prevent secret leakage in logs.
# Only operation success/failure and timing metrics are logged.
#
# Example:
#   token = JsonWebToken.encode(user_id: 123)
#   payload = JsonWebToken.decode(token)
#
class JsonWebToken
  SECRET_KEY = Rails.application.secret_key_base
  ACCESS_TOKEN_EXPIRATION = 15.minutes
  REFRESH_TOKEN_EXPIRATION = 30.days

  def self.encode(payload, exp = ACCESS_TOKEN_EXPIRATION.from_now)
    payload[:exp] = exp.to_i

    start_time = Time.current
    token = JWT.encode(payload, SECRET_KEY)
    duration = Time.current - start_time

    Rails.logger.debug "JWT encoded successfully in #{duration.round(3)}s"

    token
  rescue JWT::EncodeError => e
    Rails.logger.error "JWT encode failed: #{e.class.name}"
    raise "JWT encoding failed: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected JWT encode error: #{e.class.name}"
    raise "JWT encoding failed unexpectedly: #{e.message}"
  end

  def self.refresh_token(user_id)
    payload = {
      user_id: user_id,
      refresh_exp: REFRESH_TOKEN_EXPIRATION.from_now.to_i
    }

    start_time = Time.current
    token = JWT.encode(payload, SECRET_KEY)
    duration = Time.current - start_time

    Rails.logger.debug "JWT refresh token encoded in #{duration.round(3)}s for user #{user_id}"

    token
  rescue JWT::EncodeError => e
    Rails.logger.error "JWT refresh token encode failed: #{e.class.name}"
    raise "JWT refresh token encoding failed: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected JWT refresh token error: #{e.class.name}"
    raise "JWT refresh token encoding failed unexpectedly: #{e.message}"
  end

  def self.decode(token)
    start_time = Time.current

    decoded = JWT.decode(token, SECRET_KEY)[0]
    decoded = HashWithIndifferentAccess.new(decoded)

    duration = Time.current - start_time
    Rails.logger.debug "JWT decoded successfully in #{duration.round(3)}s"

    decoded
  rescue JWT::ExpiredSignature => e
    log_jwt_error('JWT token expired', e)
    raise
  rescue JWT::VerificationError => e
    log_jwt_error('JWT signature verification failed', e)
    raise
  rescue JWT::DecodeError => e
    log_jwt_error('JWT decode failed', e)
    raise
  rescue StandardError => e
    Rails.logger.error "Unexpected JWT decode error: #{e.class.name}"
    raise "JWT decode failed unexpectedly: #{e.message}"
  end

  # Private helper for JWT error logging (no token data logged)
  def self.log_jwt_error(message, error)
    Rails.logger.warn "#{message}: #{error.class.name}"

    # Add APM metrics if available (no sensitive data)
    if defined?(NewRelic)
      NewRelic::Agent.add_custom_attributes({
                                              jwt_error_type: error.class.name,
                                              jwt_operation: 'decode'
                                            })
    end

    if defined?(Datadog)
      Datadog::Tracer.active_span&.set_tag('jwt.error_type', error.class.name)
      Datadog::Tracer.active_span&.set_tag('jwt.operation', 'decode')
    end
  end

  private_class_method :log_jwt_error
end
