# frozen_string_literal: true

# Controller handling user registration for the API.
#
# This controller exposes a `POST /api/v1/signup` endpoint to allow clients
# to create new users by providing email, password, and password confirmation.
# On successful registration, it returns a JWT token and the user's email.
# On failure, it returns validation error messages.
#
# Example request payload:
# {
#   "email": "user@example.com",
#   "password": "password123",
#   "password_confirmation": "password123"
# }
#
# Example successful response:
# {
#   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "email": "user@example.com"
# }
#
# Example failure response:
# {
#   "errors": ["Email has already been taken"]
# }

module Api
  module V1
    # Api::V1::UsersController
    #
    # Handles user signup by creating a new user and returning a JWT token upon success.
    # Endpoint: POST /api/v1/signup
    class UsersController < ApplicationController
      # POST /api/v1/signup
      def create
        @user = User.new(user_params)
        if @user.save
          token = JsonWebToken.encode(user_id: @user.id)
          render json: { token: token, email: @user.email }, status: :created
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.permit(:email, :password, :password_confirmation)
      end
    end
  end
end
