# frozen_string_literal: true

# app/services/authentication_service.rb
class AuthenticationService
  def self.login(user, remote_ip, user_agent)
    session = user.create_session(ip_address: remote_ip, user_agent: user_agent)
    token = JsonWebToken.encode(user_id: user.id, session_id: session.id)
    refresh_token = JsonWebToken.refresh_token(user.id)

    { token: token, refresh_token: refresh_token, email: user.email }
  end

  def self.refresh(refresh_token, remote_ip, user_agent)
    # Valide le refresh token avant de l'utiliser
    decoded = decode_and_validate_refresh_token(refresh_token)
    return nil unless decoded

    user = User.find_by(id: decoded['user_id'])
    return nil unless user && user.sessions.active.exists?

    session = user.create_session(ip_address: remote_ip, user_agent: user_agent)
    token = JsonWebToken.encode(user_id: user.id, session_id: session.id)
    new_refresh_token = JsonWebToken.refresh_token(user.id)

    { token: token, refresh_token: new_refresh_token, email: user.email }
  end

  def self.decode_and_validate_refresh_token(token)
    # Décode le refresh token
    decoded = JsonWebToken.decode(token)

    # Vérifie que c'est bien un refresh token (doit avoir refresh_exp)
    return nil unless decoded['refresh_exp'].present?

    # Vérifie que le refresh token n'a pas expiré
    return nil if Time.at(decoded['refresh_exp']) < Time.current

    # Vérifie que le user_id est présent et valide
    return nil if decoded['user_id'].blank?

    decoded
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::InvalidIatError
    # En cas d'erreur de décodage ou d'expiration, retourne nil
    nil
  end
end
