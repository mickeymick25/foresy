# frozen_string_literal: true

# app/services/authentication_service.rb
class AuthenticationService
  def self.login(user, remote_ip, user_agent)
    session = user.create_session(ip_address: remote_ip, user_agent: user_agent)
    token = JsonWebToken.encode(user_id: user.id, session_id: session.id)
    refresh_token = JsonWebToken.refresh_token(user.id)

    { token: token, refresh_token: refresh_token, email: user.email }
  end

  def self.refresh(decoded, remote_ip, user_agent)
    user = User.find_by(id: decoded[:user_id])
    return nil unless user && user.sessions.active.exists?

    session = user.create_session(ip_address: remote_ip, user_agent: user_agent)
    token = JsonWebToken.encode(user_id: user.id, session_id: session.id)
    refresh_token = JsonWebToken.refresh_token(user.id)

    { token: token, refresh_token: refresh_token, email: user.email }
  end
end
