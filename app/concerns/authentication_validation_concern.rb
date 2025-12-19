# frozen_string_literal: true

# AuthenticationValidationConcern
#
# Concern providing validation methods for authentication services.
# Extracted from AuthenticationMetricsConcern to reduce module length.
#
module AuthenticationValidationConcern
  extend ActiveSupport::Concern

  class_methods do
    def validate_user_and_session(decoded, remote_ip)
      user_id = decoded[:user_id]

      return log_and_return_nil('Missing user_id in token', remote_ip) if user_id.nil?

      user = User.find_by(id: user_id)
      return log_and_return_nil("User not found with id: #{user_id}", remote_ip) if user.nil?

      # Pour les refresh tokens, session_id peut être absent
      # Dans ce cas, on utilise la dernière session active de l'utilisateur
      session_id = decoded[:session_id]
      session = if session_id.present?
                  user.sessions.find_by(id: session_id, active: true)
                else
                  user.sessions.where(active: true).order(created_at: :desc).first
                end

      return log_and_return_nil("Active session not found for user #{user.email}", remote_ip) if session.nil?

      { user: user, session: session }
    end

    def perform_validations(decoded, token)
      validate_refresh_exp(decoded, token)
      validate_token_expiration(decoded[:refresh_exp], token)
      validate_user_id(decoded, token)
    end

    def validate_refresh_exp(decoded, token)
      refresh_exp = decoded[:refresh_exp]
      return log_and_return_nil('Missing refresh_exp in token', token) if refresh_exp.nil?

      return log_and_return_nil('Refresh token expired', token) if refresh_exp < Time.current.to_i

      true
    end

    def validate_token_expiration(refresh_exp, token)
      return log_and_return_nil('Refresh token expired', token) if refresh_exp < Time.current.to_i

      true
    end

    def validate_user_id(decoded, token)
      user_id = decoded[:user_id]
      return log_and_return_nil('Missing user_id in token', token) if user_id.nil?

      user = User.find_by(id: user_id)
      return log_and_return_nil("User not found with id: #{user_id}", token) if user.nil?

      user
    end
  end
end
