# frozen_string_literal: true

module Api
  module V1
    # Controller for authentication API endpoints
    # Handles user login, logout, token refresh, and OAuth authentication
    class AuthenticationController < ApplicationController
      before_action :authenticate_access_token!, only: [:logout]

      # === POST /api/v1/auth/login ===
      def login
        return render_unauthorized('Email is required') if login_params[:email].blank?
        return render_unauthorized('Password is required') if login_params[:password].blank?

        user = find_and_validate_user
        return render_unauthorized('Invalid credentials') unless user

        return render_forbidden('Account is inactive') unless user.active?
        return render_forbidden('Session blocked') if user_has_blocked_session?(user)

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
        auth = extract_oauth_data
        return render_unauthorized('OAuth data missing') unless auth

        user = find_or_create_user_from_auth(auth)
        return render_unprocessable_entity('User creation failed') unless user.persisted?

        perform_oauth_login(user)
      end

      def extract_oauth_data
        request.env['omniauth.auth'] || Rails.application.env_config['omniauth.auth']
      end

      def perform_oauth_login(user)
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
        # Extrait les données d'authentification
        auth_data = extract_auth_data(auth)

        # Trouve ou initialise l'utilisateur
        user = find_or_initialize_user(auth_data[:provider], auth_data[:uid])

        # Met à jour ou crée l'utilisateur
        if user.persisted?
          update_existing_user!(user, auth_data[:email], auth_data[:name], auth_data[:nickname])
        else
          create_oauth_user!(user, auth_data[:email], auth_data[:name], auth_data[:nickname])
        end

        user
      end

      def extract_auth_data(auth)
        provider_and_uid = extract_provider_and_uid(auth)
        info = extract_info_data(auth)
        extracted_fields = extract_all_info_fields(info)

        {
          provider: provider_and_uid[:provider],
          uid: provider_and_uid[:uid],
          email: extracted_fields[:email],
          name: extracted_fields[:name],
          nickname: extracted_fields[:nickname]
        }
      end

      def extract_provider_and_uid(auth)
        provider = auth.respond_to?(:provider) ? auth.provider : (auth[:provider] || auth['provider'])
        uid = auth.respond_to?(:uid) ? auth.uid : (auth[:uid] || auth['uid'])

        {
          provider: provider,
          uid: uid
        }
      end

      def extract_all_info_fields(info)
        {
          email: extract_info_field(info, :email),
          name: extract_info_field(info, :name),
          nickname: extract_info_field(info, :nickname)
        }
      end

      def extract_info_data(auth)
        auth.respond_to?(:info) ? auth.info : (auth[:info] || auth['info'])
      end

      def extract_info_field(info, field)
        return nil if info.blank?

        if info.respond_to?(field)
          info.send(field)
        else
          info[field] || info[field.to_s]
        end
      end

      def find_or_initialize_user(provider, uid)
        User.find_or_initialize_by(provider: provider, uid: uid)
      end

      def update_existing_user!(user, email, name, nickname)
        user.email = email if email.present?
        user.name = name || nickname || user.name || 'No Name'
        user.save
      end

      def create_oauth_user!(user, email, name, nickname)
        user.email = email
        user.name = name || nickname || 'No Name'
        user.active = true

        Rails.logger.error "Failed to create OAuth user: #{user.errors.full_messages.join(', ')}" unless user.save
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
