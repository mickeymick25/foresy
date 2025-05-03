# frozen_string_literal: true

# Controller responsible for user authentication via JWT.
#
# This controller exposes three main endpoints:
#
# - POST /api/v1/login: Authenticates a user with email and password.
#   Returns a JWT access token, a refresh token, and the user email.
#
#   Example request payload:
#   {
#     "email": "user@example.com",
#     "password": "password123"
#   }
#
#   Example successful response:
#   {
#     "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#     "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#     "email": "user@example.com"
#   }
#
#   Example failure response:
#   {
#     "error": "unauthorized"
#   }
#
# - POST /api/v1/refresh: Refreshes an access token using a valid refresh token.
#   Requires a `refresh_token` in the request payload.
#
#   Example request:
#   {
#     "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
#   }
#
#   Example response:
#   {
#     "token": "...",
#     "refresh_token": "...",
#     "email": "user@example.com"
#   }
#
# - DELETE /api/v1/logout: Invalidates the current user session.
#
#   Example response:
#   {
#     "message": "Logged out successfully"
#   }
#
# All endpoints return HTTP 401 (unauthorized) if the tokens are invalid or expired.

module Api
  module V1
    # Controller responsible for user authentication via login, refresh and logout actions.
    # Handles JWT token generation and validation.
    class AuthenticationController < ApplicationController
      before_action :authenticate_access_token!, only: [:logout]

      def login
        @user = find_user_by_email

        if valid_password?
          result = AuthenticationService.login(@user, request.remote_ip, request.user_agent)
          render json: result, status: :ok
        else
          render_unauthorized
        end
      end

      def refresh
        refresh_token = extract_refresh_token
        return render_missing_token unless valid_refresh_token?(refresh_token)

        decoded = decode_refresh_token(refresh_token)
        return render_invalid_token unless decoded
        return render_expired_token if refresh_token_expired?(decoded)

        user = find_user_by_id(decoded[:user_id])
        return render_invalid_token unless user_has_active_session?(user)

        session = create_user_session(user)
        render_new_tokens(user, session)
      end

      def logout
        if !current_session
          render json: { error: 'No active session' }, status: :unauthorized
        elsif current_session.expired?
          render json: { error: 'Session already expired' }, status: :unauthorized
        else
          current_session.update(expires_at: Time.current)
          render json: { message: 'Logged out successfully' }, status: :ok
        end
      end

      private

      def login_params
        params.permit(:email, :password)
      end

      # Private methods for login
      def find_user_by_email
        User.find_by_email(params[:email])
      end

      def find_user_by_id(user_id)
        User.find_by(id: user_id)
      end

      def valid_password?
        @user&.authenticate(params[:password])
      end

      def render_unauthorized(message = 'unauthorized')
        render json: { error: message }, status: :unauthorized
      end

      # Private methods for refresh
      def extract_refresh_token
        params[:refresh_token] || params.dig(:authentication, :refresh_token)
      end

      def valid_refresh_token?(token)
        token.is_a?(String) && token.present?
      end

      def decode_refresh_token(token)
        JsonWebToken.decode(token)
      rescue JWT::DecodeError, JWT::ExpiredSignature
        nil
      end

      def refresh_token_expired?(decoded)
        decoded['refresh_exp'].present? && Time.at(decoded['refresh_exp']) < Time.current
      end

      def user_has_active_session?(user)
        user&.sessions&.active&.exists?
      end

      def create_user_session(user)
        user.create_session(
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
      end

      # Private methods for rendering responses
      def render_new_tokens(user, session)
        render json: {
          token: JsonWebToken.encode(user_id: user.id, session_id: session.id),
          refresh_token: JsonWebToken.refresh_token(user.id),
          email: user.email
        }, status: :ok
      end

      def render_missing_token
        render json: { error: 'refresh token missing or invalid' }, status: :unauthorized
      end

      def render_invalid_token
        render json: { error: 'invalid or expired refresh token' }, status: :unauthorized
      end

      def render_expired_token
        render json: { error: 'refresh token expired' }, status: :unauthorized
      end
    end
  end
end
