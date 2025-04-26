module Api
  module V1
    class UsersController < ApplicationController
      skip_before_action :authenticate_request, only: [:create]

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