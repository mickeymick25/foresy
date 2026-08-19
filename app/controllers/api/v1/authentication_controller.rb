# frozen_string_literal: true

module Api
  module V1
    # Controller for authentication API endpoints
    # Handles user login, logout, token refresh, and OAuth authentication
    class AuthenticationController < Api::V1::BaseController
      include ::OAuthConcern
      include Common::RateLimitable

      before_action :authenticate_access_token!, only: %i[logout revoke revoke_all]
      before_action :check_rate_limit!, only: %i[login refresh]

      # === POST /api/v1/auth/login ===
      def login
        return error_unauthorized('Email is required') if login_params[:email].blank?
        return error_unauthorized('Password is required') if login_params[:password].blank?

        user = find_and_validate_user
        return error_unauthorized('Invalid credentials') unless user

        return error_forbidden('Account is inactive') unless user.active?

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
        return error_unauthorized('Refresh token is missing') unless token.present?

        # Utilise AuthenticationService qui valide maintenant directement le refresh token
        result = AuthenticationService.refresh(token, request.remote_ip, request.user_agent)
        return error_unauthorized('Unable to refresh session') if result.nil?

        render json: {
          token: result[:token],
          refresh_token: result[:refresh_token],
          email: result[:email]
        }, status: :ok
      end

      # === DELETE /api/v1/auth/logout ===
      def logout
        return error_unauthorized('No active session') if current_session.nil?
        return error_unauthorized('Session already expired') if current_session.expired?

        current_session.update(expires_at: Time.current)
        render json: { message: 'Logged out successfully' }, status: :ok
      end

      # === DELETE /api/v1/auth/revoke ===
      # Revokes the current session token
      def revoke
        return error_unauthorized('No active session') if current_session.nil?

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
        return error_unauthorized('No active session') if current_user.nil?

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

      # Rate limiting check for authentication endpoints
      def check_rate_limit!
        # Determine which endpoint we're checking based on the action
        case action_name
        when 'login'
          endpoint = 'auth/login'
        when 'refresh'
          endpoint = 'auth/refresh'
        else
          return # Don't rate limit other actions
        end

        # Extract client IP
        client_ip = extract_client_ip_for_rate_limiting

        # Check rate limit using RateLimitService
        allowed, retry_after = RateLimitService.check_rate_limit(endpoint, client_ip, request)

        # If rate limit exceeded, return 429 response
        unless allowed
          response.headers['Retry-After'] = retry_after.to_s
          error_too_many_requests('Rate limit exceeded', { retry_after: retry_after })
        end
      end
    end
  end
end
