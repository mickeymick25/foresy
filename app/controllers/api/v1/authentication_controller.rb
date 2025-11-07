# frozen_string_literal: true

module Api
  module V1
    class AuthenticationController < ApplicationController
      before_action :authenticate_access_token!, only: [:logout]

      # === POST /api/v1/auth/login ===
      def login
        return render_unauthorized('Email is required') if login_params[:email].blank?
        return render_unauthorized('Password is required') if login_params[:password].blank?

        user = User.find_by(email: login_params[:email])
        return render_unauthorized('Invalid credentials') unless user&.authenticate(login_params[:password])
        return render_forbidden('Account is inactive') unless user.active?
        return render_forbidden('Session blocked') if user_has_blocked_session?(user)

        # Utilise AuthenticationService pour éliminer la duplication de logique
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
        return render_unauthorized('Refresh token is missing') unless valid_refresh_token?(token)

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

      # === GET|POST /auth/:provider/callback (OAuth) ===
      def oauth_callback
        # Supporte à la fois request.env['omniauth.auth'] et Rails.application.env_config['omniauth.auth']
        auth = request.env['omniauth.auth'] || Rails.application.env_config['omniauth.auth']
        return render_unauthorized('OAuth data missing') unless auth

        user = find_or_create_user_from_auth(auth)
        return render_unprocessable_entity('User creation failed') unless user.persisted?

        # Utilise AuthenticationService pour créer la session et les tokens comme le login normal
        result = AuthenticationService.login(user, request.remote_ip, request.user_agent)

        render json: {
          token: result[:token],
          refresh_token: result[:refresh_token],
          user: user
        }, status: :ok
      end

      private

      def login_params
        params.permit(:email, :password)
      end

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

      def user_has_blocked_session?(user)
        user.sessions.expired.exists?
      end

      def find_or_create_user_from_auth(auth)
        # Supporte OmniAuth::AuthHash (méthodes) et hash normal (clés)
        provider = auth.respond_to?(:provider) ? auth.provider : (auth[:provider] || auth['provider'])
        uid = auth.respond_to?(:uid) ? auth.uid : (auth[:uid] || auth['uid'])
        info = auth.respond_to?(:info) ? auth.info : (auth[:info] || auth['info'])

        # Cherche d'abord par provider et uid (pour OAuth)
        user = User.find_or_initialize_by(provider: provider, uid: uid)

        # Extrait les valeurs d'info (supporte OmniAuth::AuthHash et hash normal)
        if info.respond_to?(:email)
          email = info.email
          name = info.name
          nickname = info.nickname
        else
          email = info[:email] || info['email']
          name = info[:name] || info['name']
          nickname = info[:nickname] || info['nickname']
        end

        # Si l'utilisateur existe déjà, on le met à jour si nécessaire
        if user.persisted?
          user.email = email if email.present?
          user.name = name || nickname || user.name || 'No Name'
          user.save
          return user
        end

        # Nouvel utilisateur OAuth
        user.email = email
        user.name = name || nickname || 'No Name'
        user.active = true

        Rails.logger.error "Failed to create OAuth user: #{user.errors.full_messages.join(', ')}" unless user.save

        user
      end

      # === Error helpers ===
      def render_bad_request(message)
        render json: { error: 'Bad Request', message: message }, status: :bad_request
      end

      def render_forbidden(message = 'Forbidden')
        render json: { error: 'Forbidden', message: message }, status: :forbidden
      end
    end
  end
end
