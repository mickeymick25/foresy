# frozen_string_literal: true

# OAuth Controller for Feature Contract endpoints
# Handles OAuth authentication for Google & GitHub providers
# Implements stateless JWT authentication without server-side sessions
#
# This controller provides the following endpoints:
# - POST /auth/:provider/callback - OAuth callback for authentication
# - GET /auth/failure - OAuth failure endpoint
#
# Refactored to use specialized services and reduce complexity

# Require OAuth services to ensure they are loaded properly
# Note: These require_relative statements are necessary to avoid autoloading issues
# in production environments while maintaining compatibility with Zeitwerk eager loading

module Api
  module V1
    # OAuth Controller for Feature Contract endpoints
    # Handles OAuth authentication for Google & GitHub providers
    # Implements stateless JWT authentication without server-side sessions
    class OauthController < ApplicationController
      include ErrorRenderable

      # POST /auth/:provider/callback
      # OAuth callback endpoint for Google & GitHub authentication
      def callback
        execute_oauth_flow
      rescue StandardError => e
        Rails.logger.error "OAuth callback error: #{e.class.name} - #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
        Rails.logger.error "Request params at error: #{params.inspect}"
        Rails.logger.error "Request env at error: #{request.env.keys.select { |k| k.include?('omniauth') }.inspect}"
        render_error('internal_error', e.message, :internal_server_error)
      end

      # Execute the complete OAuth authentication flow
      def execute_oauth_flow
        Rails.logger.info "Starting OAuth flow for provider: #{params[:provider]}"

        return render_bad_request('invalid_provider') unless valid_provider?

        validation_result = process_oauth_validation
        return handle_validation_error(validation_result) if validation_result.is_a?(Symbol)

        user = find_or_create_user(validation_result[:data])
        return handle_user_error(user) unless user.persisted?

        token = generate_oauth_token(user)
        render_success_response(token, user)
      end

      # Handle validation results that return symbols
      def handle_validation_error(result)
        case result
        when :oauth_failed
          render_unauthorized('oauth_failed')
        when :invalid_payload
          render_unprocessable_entity('invalid_payload')
        else
          Rails.logger.error "Unknown validation result: #{result}"
          render_error('internal_error', 'An unexpected error occurred', :internal_server_error)
        end
      end

      # Process OAuth validation and data extraction
      def process_oauth_validation
        payload_validation = validate_callback_payload
        return :invalid_payload if payload_validation[:error]

        auth_data = extract_oauth_data
        return :oauth_failed if auth_data.nil?

        auth_validation = validate_oauth_data(auth_data)
        return :invalid_payload if auth_validation[:error]

        auth_validation
      rescue StandardError => e
        Rails.logger.error "OAuth validation error: #{e.class.name} - #{e.message}"
        Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
        :oauth_failed
      end

      # Extract OAuth data - supports both OmniAuth flow and API code exchange
      def extract_oauth_data
        OAuthValidationService.extract_oauth_data(
          request,
          provider: params[:provider],
          code: params[:code],
          redirect_uri: params[:redirect_uri]
        )
      end

      # GET /auth/failure
      # Optional OAuth failure endpoint (recommended by Feature Contract)
      def failure
        render_error('oauth_failed', 'OAuth authentication failed', :unauthorized)
      end

      private

      def valid_provider?
        OAuthValidationService.valid_provider?(params[:provider])
      end

      def validate_callback_payload
        OAuthValidationService.validate_callback_payload(
          code: params[:code],
          redirect_uri: params[:redirect_uri],
          state: params[:state]
        )
      end

      def validate_oauth_data(auth_data)
        OAuthValidationService.validate_oauth_data(auth_data)
      end

      def find_or_create_user(oauth_data)
        OAuthUserService.find_or_create_user_from_oauth(oauth_data)
      end

      def generate_oauth_token(user)
        OAuthTokenService.generate_stateless_jwt(user)
      end

      def render_success_response(token, user)
        response_data = OAuthTokenService.format_success_response(token, user)
        render json: response_data, status: :ok
      end

      # Render helpers for standardized error responses
      def render_bad_request(error_code, message = 'Bad Request')
        render_error(error_code, message, :bad_request)
      end

      def render_unauthorized(error_code, message = 'Unauthorized')
        render_error(error_code, message, :unauthorized)
      end

      def render_unprocessable_entity(error_code, message = 'Unprocessable Entity')
        render_error(error_code, message, :unprocessable_entity)
      end
    end
  end
end
