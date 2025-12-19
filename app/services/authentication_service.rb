# frozen_string_literal: true

# AuthenticationService - Service d'authentification avec logging et métriques
#
# Améliorations (Déc 2025):
# - Logging structuré et gestion d'erreurs robuste
# - Métriques de performance pour monitoring
#
class AuthenticationService
  include AuthenticationLoggingConcern
  include AuthenticationMetricsConcern
  include AuthenticationValidationConcern
  def self.login(user, remote_ip, user_agent)
    Rails.logger.info "User #{user.email} login attempt from IP: #{remote_ip}"

    start_time = Time.current

    session = user.create_session(ip_address: remote_ip, user_agent: user_agent)
    token = JsonWebToken.encode(user_id: user.id, session_id: session.id)
    refresh_token = JsonWebToken.refresh_token(user.id)

    duration = Time.current - start_time
    log_login_success(user, duration)
    record_login_metrics(user, session, duration)

    { token: token, refresh_token: refresh_token, email: user.email }
  rescue StandardError => e
    log_login_error(user, remote_ip, user_agent, e)
    record_login_error_metrics(e)

    raise "Authentication failed: #{e.message}"
  end

  def self.refresh(refresh_token, remote_ip, user_agent)
    Rails.logger.debug "Processing refresh token for IP: #{remote_ip}"

    start_time = Time.current

    # Valide le refresh token avant de l'utiliser
    decoded = decode_and_validate_refresh_token(refresh_token)
    return log_and_return_nil('Refresh token validation failed', remote_ip) if decoded.nil?

    validation_result = validate_user_and_session(decoded, remote_ip)
    return validation_result unless validation_result.is_a?(Hash)

    user = validation_result[:user]
    session = validation_result[:session]

    token = JsonWebToken.encode(user_id: user.id, session_id: session.id)
    new_refresh_token = JsonWebToken.refresh_token(user.id)

    # Logging de succès avec métriques
    duration = Time.current - start_time
    log_refresh_success(user, duration)
    record_refresh_metrics(user, session, duration)

    { token: token, refresh_token: new_refresh_token, email: user.email }
  rescue StandardError => e
    log_refresh_error(e, remote_ip, user_agent, refresh_token)
    record_refresh_error_metrics(e)

    nil # Retourner nil en cas d'erreur pour ne pas bloquer l'API
  end

  def self.decode_and_validate_refresh_token(token)
    Rails.logger.debug "Validating refresh token: #{token[0..20]}..." if token.present?

    decoded = JsonWebToken.decode(token)
    return log_and_return_nil('Refresh token decode failed', token) if decoded.nil?

    validation_result = perform_validations(decoded, token)
    return validation_result if validation_result.nil?

    Rails.logger.debug "Refresh token validation successful for user #{validation_result[:user_id]}"
    decoded
  rescue JWT::DecodeError => e
    log_jwt_decode_error('Refresh token decode error', e, token)
    nil
  rescue JWT::ExpiredSignature => e
    log_jwt_decode_error('Refresh token expired signature', e, token)
    nil
  rescue JWT::InvalidIatError => e
    log_jwt_decode_error('Refresh token invalid IAT', e, token)
    nil
  rescue StandardError => e
    log_refresh_validation_error(e, token)
    nil
  end
end
