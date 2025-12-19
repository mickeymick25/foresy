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
# Improvements (Dec 2025):
# - Robust exception handling with structured logging
# - Performance metrics for monitoring
# - Enhanced debugging capabilities
# - Consistent error reporting across the authentication system
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

    log_encode_success(duration)

    token
  rescue JWT::EncodeError => e
    log_encode_error('JWT encode failed', e, payload, exp)
    raise "JWT encoding failed: #{e.message}"
  rescue StandardError => e
    log_encode_error('Unexpected JWT encode error', e, payload, exp)
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

    log_refresh_encode_success(duration, user_id)

    token
  rescue JWT::EncodeError => e
    log_refresh_encode_error('JWT refresh token encode failed', e, user_id)
    raise "JWT refresh token encoding failed: #{e.message}"
  rescue StandardError => e
    log_refresh_encode_error('Unexpected JWT refresh token error', e, user_id)
    raise "JWT refresh token encoding failed unexpectedly: #{e.message}"
  end

  def self.decode(token)
    log_decode_start(token)

    start_time = Time.current

    decoded = JWT.decode(token, SECRET_KEY)[0]
    decoded = HashWithIndifferentAccess.new(decoded)

    duration = Time.current - start_time
    log_decode_success(duration)

    decoded
  rescue JWT::DecodeError => e
    log_decode_error('JWT decode failed', e, token)
    raise
  rescue JWT::ExpiredSignature => e
    log_decode_error('JWT token expired', e, token)
    raise
  rescue JWT::VerificationError => e
    log_decode_error('JWT signature verification failed', e, token)
    raise
  rescue StandardError => e
    log_unexpected_decode_error(e, token)
    raise "JWT decode failed unexpectedly: #{e.message}"
  end

  # Private methods for logging to reduce complexity
  def self.log_decode_start(token)
    Rails.logger.debug "Decoding JWT token: #{token[0..20]}..." if token.present?
  end

  def self.log_unexpected_decode_error(error, token)
    Rails.logger.error "Unexpected JWT decode error: #{error.class.name} - #{error.message}"
    Rails.logger.error "Token: #{token[0..50]}..." if token.present?
    Rails.logger.error "Backtrace: #{error.backtrace[0..3].join("\n")}" if error.backtrace
  end

  def self.log_encode_success(duration)
    Rails.logger.debug "JWT encoded successfully in #{duration.round(3)}s"
  end

  def self.log_encode_error(message, error, payload, exp)
    Rails.logger.error "#{message}: #{error.class.name} - #{error.message}"
    Rails.logger.error "Payload: #{payload.inspect}"
    Rails.logger.error "Expiration: #{exp}"
  end

  def self.log_decode_success(duration)
    Rails.logger.debug "JWT decoded successfully in #{duration.round(3)}s"
  end

  def self.log_decode_error(message, error, token)
    Rails.logger.warn "#{message}: #{error.class.name} - #{error.message}"
    Rails.logger.warn "Token (first 50 chars): #{token[0..50]}..." if token.present?

    # Ajouter des métriques pour le monitoring (si APM disponible)
    if defined?(NewRelic)
      NewRelic::Agent.add_custom_attributes({
                                              jwt_error_type: error.class.name,
                                              jwt_error_message: error.message,
                                              jwt_operation: 'decode',
                                              token_length: token&.length
                                            })
    end

    # Ajouter des métriques pour d'autres APMs
    if defined?(Datadog)
      Datadog::Tracer.active_span.set_tag('jwt.error_type', error.class.name)
      Datadog::Tracer.active_span.set_tag('jwt.operation', 'decode')
    end
  end

  def self.log_refresh_encode_success(duration, user_id)
    Rails.logger.debug "JWT refresh token encoded in #{duration.round(3)}s for user #{user_id}"
  end

  def self.log_refresh_encode_error(message, error, user_id)
    Rails.logger.error "#{message}: #{error.class.name} - #{error.message}"
    Rails.logger.error "User ID: #{user_id}"
  end

  def self.log_jwt_decode_error(message, error, token)
    Rails.logger.warn "#{message}: #{error.class.name} - #{error.message}"
    Rails.logger.warn "Token (first 50 chars): #{token[0..50]}..." if token.present?

    # Ajouter des métriques pour le monitoring (si APM disponible)
    if defined?(NewRelic)
      NewRelic::Agent.add_custom_attributes({
                                              jwt_error_type: error.class.name,
                                              jwt_error_message: error.message,
                                              jwt_operation: 'decode',
                                              token_length: token&.length
                                            })
    end

    # Ajouter des métriques pour d'autres APMs
    if defined?(Datadog)
      Datadog::Tracer.active_span.set_tag('jwt.error_type', error.class.name)
      Datadog::Tracer.active_span.set_tag('jwt.operation', 'decode')
    end
  end
end
