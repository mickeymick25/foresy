module Api
  module V1
    class AuthenticationController < ApplicationController
      skip_before_action :authenticate_request, only: [:login]

      # POST /api/v1/auth/login
      def login
        @user = User.find_by_email(params[:email])
        if @user&.authenticate(params[:password])
          token = JsonWebToken.encode(user_id: @user.id)
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
        refresh_token = request.headers['Refresh-Token']
        if refresh_token
          decoded = JsonWebToken.decode(refresh_token)
          if decoded && decoded[:user_id]
            @user = User.find(decoded[:user_id])
            token = JsonWebToken.encode(user_id: @user.id)
            new_refresh_token = JsonWebToken.refresh_token(@user.id)
            render json: { 
              token: token, 
              refresh_token: new_refresh_token,
              email: @user.email 
            }, status: :ok
          else
            render json: { error: 'invalid refresh token' }, status: :unauthorized
          end
        else
          render json: { error: 'refresh token missing' }, status: :unauthorized
        end
      end

      private

      def login_params
        params.permit(:email, :password)
      end
    end
  end
end 