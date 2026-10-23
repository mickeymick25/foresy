# frozen_string_literal: true

require 'jwt'

# JsonWebToken
#
# Service responsible for encoding and decoding JSON Web Tokens (JWT).
# Provides methods to generate access and refresh tokens used for user authentication.
#
# Signature key (#22 — O-1, GO CTO 23/10): JWT_SECRET when present and non-blank;
# fail-fast in production when absent or blank (ConfigurationError, mirrors
# RateLimit::RedisConfigurationError — FC-05 contract A1); falls back to Rails
# secret_key_base in development/test (compatibility, contract spec R-3).
#
# Constants:
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
  class ConfigurationError < StandardError; end

  # Fail-fast at boot in production (#22 O-1 — CTO §3): the dedicated key must be configured
  # before any traffic; a BLANK value fails the same as an ABSENT one. In production the class
  # is eager-loaded at boot, so this aborts the deploy (health check never passes).
  if Rails.env.production? && ENV['JWT_SECRET'].blank?
    raise ConfigurationError, 'JWT_SECRET not configured for production environment'
  end

  ACCESS_TOKEN_EXPIRATION = 15.minutes
  REFRESH_TOKEN_EXPIRATION = 30.days

  # Key provenance: JWT_SECRET (explicit, non-blank check) else fail-fast in production else
  # secret_key_base fallback. Read at call time so the contract spec can stub ENV per example
  # (R-1/R-2/R-3) and so configuration changes take effect on the next process, not on re-deploy only.
  def self.signature_key
    jwt_secret = ENV.fetch('JWT_SECRET', nil)
    return jwt_secret if jwt_secret.present?

    raise ConfigurationError, 'JWT_SECRET not configured for production environment' if Rails.env.production?

    Rails.application.secret_key_base
  end

  def self.encode(payload, exp = ACCESS_TOKEN_EXPIRATION.from_now)
    payload[:exp] = exp.to_i

    start_time = Time.current
    token = JWT.encode(payload, signature_key, 'HS256')
    duration = Time.current - start_time

    Rails.logger.debug "JWT encoded successfully in #{duration.round(3)}s"

    token
  rescue ConfigurationError => e
    Rails.logger.error "JWT encode failed: #{e.class.name}"
    raise
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
    token = JWT.encode(payload, signature_key, 'HS256')
    duration = Time.current - start_time

    Rails.logger.debug "JWT refresh token encoded in #{duration.round(3)}s for user #{user_id}"

    token
  rescue ConfigurationError => e
    Rails.logger.error "JWT refresh token encode failed: #{e.class.name}"
    raise
  rescue JWT::EncodeError => e
    Rails.logger.error "JWT refresh token encode failed: #{e.class.name}"
    raise "JWT refresh token encoding failed: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Unexpected JWT refresh token error: #{e.class.name}"
    raise "JWT refresh token encoding failed unexpectedly: #{e.message}"
  end

  def self.decode(token)
    start_time = Time.current

    decoded = JWT.decode(token, signature_key, true, { algorithm: 'HS256' })[0]
    decoded = HashWithIndifferentAccess.new(decoded)

    duration = Time.current - start_time
    Rails.logger.debug "JWT decoded successfully in #{duration.round(3)}s"

    decoded
  rescue ConfigurationError
    raise
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
    add_datadog_tags({
                       jwt_error_type: error.class.name,
                       jwt_operation: 'decode'
                     })
  end

  # Helper method to standardize Datadog APM usage across different API versions
  # Handles both active_span (modern) and active.span (legacy) APIs
  def self.add_datadog_tags(tags)
    return unless defined?(Datadog)

    tracer = Datadog::Tracer
    return unless tracer_respond_to_methods?(tracer)

    set_tags_with_modern_api(tracer, tags) || set_tags_with_legacy_api(tracer, tags)
  rescue StandardError => e
    Rails.logger.debug "Datadog APM error: #{e.message}" if defined?(Rails)
    # Graceful handling - don't crash the application
  end

  # Check if tracer responds to required methods
  # @param tracer [Object] Datadog::Tracer
  # @return [Boolean]
  def self.tracer_respond_to_methods?(tracer)
    tracer.respond_to?(:active_span) || tracer.respond_to?(:active)
  end

  # Set tags using modern API (active_span)
  # @param tracer [Object] Datadog::Tracer
  # @param tags [Hash] Tags to set
  # @return [Boolean] true if tags were set successfully
  def self.set_tags_with_modern_api(tracer, tags)
    return false unless tracer.respond_to?(:active_span)

    span = tracer.active_span
    return false unless span

    set_tags_on_span(span, tags)
    true
  end

  # Set tags using legacy API (active.span)
  # @param tracer [Object] Datadog::Tracer
  # @param tags [Hash] Tags to set
  # @return [Boolean] true if tags were set successfully
  def self.set_tags_with_legacy_api(tracer, tags)
    return false unless tracer.respond_to?(:active)
    return false unless tracer.active.respond_to?(:span)

    span = tracer.active.span
    return false unless span

    set_tags_on_span(span, tags)
    true
  end

  # Apply tags on a span
  # @param span [Object] Datadog span
  # @param tags [Hash] Tags to set
  # @return [void]
  def self.set_tags_on_span(span, tags)
    tags.each do |key, value|
      span.set_tag(key, value)
    end
  end

  private_class_method :log_jwt_error
end
