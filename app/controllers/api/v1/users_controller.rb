# frozen_string_literal: true

module Api
  module V1
    # Handles user signup by creating a new user and returning a JWT token upon success.
    # Endpoint: POST /api/v1/signup
    class UsersController < Api::V1::BaseController
      include Common::RateLimitable

      before_action :check_rate_limit!, only: [:create]

      # POST /api/v1/signup
      def create
        user = User.new(user_params)

        if user.save
          # Create session like login does
          result = AuthenticationService.login(user, request.remote_ip, request.user_agent)

          render json: {
            token: result[:token],
            refresh_token: result[:refresh_token],
            email: result[:email]
          }, status: :created
        else
          error_invalid_payload(user.errors.full_messages.join(', '),
                                { errors: user.errors.full_messages, model: 'User' })
        end
      end

      private

      def user_params
        # Handle both parameter structures: nested under 'user' key or at root level
        user_params = params[:user].present? ? params[:user] : params
        user_params.permit(:email, :password, :password_confirmation)
      end

      # Rate limiting check for signup endpoint
      def check_rate_limit!
        endpoint = 'auth/signup'

        # Extract client IP
        client_ip = extract_client_ip_for_rate_limiting

        # Check rate limit using RateLimitService
        allowed, retry_after = RateLimitService.check_rate_limit(endpoint, client_ip)

        # If rate limit exceeded, return 429 response
        unless allowed
          response.headers['Retry-After'] = retry_after.to_s
          error_too_many_requests('Rate limit exceeded', { retry_after: retry_after })
        end
      end
    end
  end
end
