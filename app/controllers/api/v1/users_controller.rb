# frozen_string_literal: true

module Api
  module V1
    # Handles user signup by creating a new user and returning a JWT token upon success.
    # Endpoint: POST /api/v1/signup
    class UsersController < ApplicationController
      # POST /api/v1/signup
      def create
        user = User.new(user_params)

        if user.save
          token = JsonWebToken.encode(user_id: user.id)
          render json: {
            token: token,
            email: user.email
          }, status: :created
        else
          render json: { error: 'Validation Failed', message: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.permit(:email, :password, :password_confirmation)
      end
    end
  end
end
