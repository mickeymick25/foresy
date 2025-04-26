class ApplicationController < ActionController::API
  before_action :authenticate_request
  attr_reader :current_user, :current_session

  private

  def authenticate_request
    header = request.headers['Authorization']
    header = header.split(' ').last if header

    begin
      @decoded = JsonWebToken.decode(header)
      @current_user = User.find(@decoded[:user_id])
      @current_session = Session.find(@decoded[:session_id])
      
      unless @current_session.active?
        render json: { error: 'Session expired' }, status: :unauthorized
        return
      end

      @current_session.refresh!
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: 'Invalid token' }, status: :unauthorized
    rescue JWT::DecodeError => e
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end
end
