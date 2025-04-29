module Api
  module V1
    class AuthenticationController < ApplicationController
      before_action :authenticate_access_token!, only: [:logout]

      # POST /api/v1/auth/login
      def login
        @user = User.find_by_email(params[:email])
        if @user&.authenticate(params[:password])
          session = @user.create_session(
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
          token = JsonWebToken.encode(user_id: @user.id, session_id: session.id)
          refresh_token = JsonWebToken.refresh_token(@user.id)
          render json: {
            token: token,
            refresh_token: refresh_token,
            email: @user.email
          }, status: :ok
        else
          render json: { error: 'unauthorized' }, status: :unauthorized
        end
      end

      # POST /api/v1/auth/refresh
      def refresh
        refresh_token = params[:refresh_token] || params.dig(:authentication, :refresh_token)

        unless refresh_token.is_a?(String) && refresh_token.present?
          return render json: { error: 'refresh token missing or invalid' }, status: :unauthorized
        end

        begin
          decoded = JsonWebToken.decode(refresh_token)
        rescue JWT::DecodeError, JWT::ExpiredSignature => e
          return render json: { error: 'invalid or expired refresh token' }, status: :unauthorized
        end

        # Vérification manuelle de l'expiration du refresh token
        if decoded["refresh_exp"].present? && Time.at(decoded["refresh_exp"]) < Time.current
          return render json: { error: 'refresh token expired' }, status: :unauthorized
        end

        if decoded && decoded[:user_id]
          @user = User.find(decoded[:user_id])
          unless @user.sessions.active.exists?
            return render json: { error: 'invalid or expired refresh token' }, status: :unauthorized
          end
          session = @user.create_session(
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
          token = JsonWebToken.encode(user_id: @user.id, session_id: session.id)
          new_refresh_token = JsonWebToken.refresh_token(@user.id)
          render json: {
            token: token,
            refresh_token: new_refresh_token,
            email: @user.email
          }, status: :ok
        else
          render json: { error: 'invalid or expired refresh token' }, status: :unauthorized
        end
      end

      # DELETE /api/v1/auth/logout
      def logout
        Rails.logger.debug "[DEBUG] Authorization header: #{request.headers['Authorization']}"
        Rails.logger.debug "[DEBUG] current_user: #{current_user.inspect}"
        Rails.logger.debug "[DEBUG] current_session: #{current_session.inspect}"
        Rails.logger.debug "[DEBUG] session expired?: #{current_session&.expired?}"

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
    end
  end
end
