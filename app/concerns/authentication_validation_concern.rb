# frozen_string_literal: true

# AuthenticationValidationConcern
#
# Concern providing validation methods for authentication services.
# Extracted from AuthenticationMetricsConcern to reduce module length.
#
# SECURITY NOTE: Tokens are NEVER logged to prevent secret leakage in logs.
#
module AuthenticationValidationConcern
  extend ActiveSupport::Concern

  class_methods do
    def validate_user_and_session(decoded, _remote_ip)
      user_id = decoded[:user_id]

      return log_and_return_nil('Missing user_id in token') if user_id.nil?

      user = User.find_by(id: user_id)
      return log_and_return_nil("User not found with id: #{user_id}") if user.nil?

      # Pour les refresh tokens, session_id peut être absent
      # Dans ce cas, on utilise la dernière session active de l'utilisateur
      session_id = decoded[:session_id]
      session = if session_id.present?
                  user.sessions.find_by(id: session_id, active: true)
                else
                  user.sessions.where(active: true).order(created_at: :desc).first
                end

      return log_and_return_nil("Active session not found for user #{user.id}") if session.nil?

      { user: user, session: session }
    end

    def perform_validations(decoded, _token)
      validate_refresh_exp(decoded)
      validate_token_expiration(decoded[:refresh_exp])
      validate_user_id(decoded)
    end

    def validate_refresh_exp(decoded)
      refresh_exp = decoded[:refresh_exp]
      return log_and_return_nil('Missing refresh_exp in token') if refresh_exp.nil?

      return log_and_return_nil('Refresh token expired') if refresh_exp < Time.current.to_i

      true
    end

    def validate_token_expiration(refresh_exp)
      return log_and_return_nil('Refresh token expired') if refresh_exp < Time.current.to_i

      true
    end

    def validate_user_id(decoded)
      user_id = decoded[:user_id]
      return log_and_return_nil('Missing user_id in token') if user_id.nil?

      user = User.find_by(id: user_id)
      return log_and_return_nil("User not found with id: #{user_id}") if user.nil?

      user
    end
  end
end
