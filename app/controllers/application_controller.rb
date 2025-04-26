class ApplicationController < ActionController::API
  before_action :authenticate_request
  attr_reader :current_user, :current_session

  private

  def authenticate_request
    header = request.headers['Authorization']
    header = header.split(' ').last if header

    unless header
      render json: { error: 'Missing token' }, status: :unauthorized
      return
    end

    begin
      @decoded = JsonWebToken.decode(header)
      @current_user = User.find(@decoded[:user_id])
      @current_session = Session.find(@decoded[:session_id])
      
      unless @current_session.active?
        render json: { error: 'Session already expired' }, status: :unprocessable_entity
        return
      end

      @current_session.refresh!
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: 'Invalid token' }, status: :unauthorized
      return
    rescue JWT::DecodeError => e
      render json: { error: 'Invalid token' }, status: :unauthorized
      return
    end
  end
end
