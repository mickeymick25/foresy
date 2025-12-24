# frozen_string_literal: true

module Api
  module V1
    # Controller for authentication API endpoints
    # Handles user login, logout, token refresh, and OAuth authentication
    class AuthenticationController < ApplicationController
      include ::OAuthConcern
      before_action :authenticate_access_token!, only: %i[logout revoke revoke_all]

      # === POST /api/v1/auth/login ===
      def login
        return render_unauthorized('Email is required') if login_params[:email].blank?
        return render_unauthorized('Password is required') if login_params[:password].blank?

        user = find_and_validate_user
        return render_unauthorized('Invalid credentials') unless user

        unless user.active?
          return render json: { error: 'Forbidden', message: 'Account is inactive' },
                        status: :forbidden
        end

        perform_login(user)
      end

      def find_and_validate_user
        user = User.find_by(email: login_params[:email])
        user&.authenticate(login_params[:password]) ? user : nil
      end

      def perform_login(user)
        result = AuthenticationService.login(user, request.remote_ip, request.user_agent)

        render json: {
          token: result[:token],
          refresh_token: result[:refresh_token],
          email: result[:email]
        }, status: :ok
      end

      # === POST /api/v1/auth/refresh ===
      def refresh
        token = extract_refresh_token
        return render_unauthorized('Refresh token is missing') unless token.present?

        # Utilise AuthenticationService qui valide maintenant directement le refresh token
        result = AuthenticationService.refresh(token, request.remote_ip, request.user_agent)
        return render_unauthorized('Unable to refresh session') if result.nil?

        render json: {
          token: result[:token],
          refresh_token: result[:refresh_token],
          email: result[:email]
        }, status: :ok
      end

      # === DELETE /api/v1/auth/logout ===
      def logout
        return render_unauthorized('No active session') if current_session.nil?
        return render_unauthorized('Session already expired') if current_session.expired?

        current_session.update(expires_at: Time.current)
        render json: { message: 'Logged out successfully' }, status: :ok
      end

      # === DELETE /api/v1/auth/revoke ===
      # Revokes the current session token
      def revoke
        return render_unauthorized('No active session') if current_session.nil?

        current_session.update(expires_at: Time.current)
        Rails.logger.info "[Auth] Token revoked for user #{current_user.id}"

        render json: {
          message: 'Token revoked successfully',
          revoked_at: Time.current.iso8601
        }, status: :ok
      end

      # === DELETE /api/v1/auth/revoke_all ===
      # Revokes all sessions for the current user
      def revoke_all
        return render_unauthorized('No active session') if current_user.nil?

        revoked_count = current_user.sessions.active.count
        current_user.invalidate_all_sessions!

        Rails.logger.info "[Auth] All tokens revoked for user #{current_user.id} (#{revoked_count} sessions)"

        render json: {
          message: 'All tokens revoked successfully',
          revoked_count: revoked_count,
          revoked_at: Time.current.iso8601
        }, status: :ok
      end

      private

      def login_params
        params.permit(:email, :password)
      end

      def extract_refresh_token
        params[:refresh_token] || params.dig(:authentication, :refresh_token)
      end

      # === Error helpers ===
    end
  end
end
