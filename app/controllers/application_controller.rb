class ApplicationController < ActionController::API
  attr_reader :current_user, :current_session

  private

  def authenticate_access_token!
    header = request.headers['Authorization']
    header = header.split(' ').last if header

    unless header
      render json: { error: 'Missing token' }, status: :unauthorized
      return
    end

    begin
      @decoded = JsonWebToken.decode(header)
    rescue JWT::DecodeError, JWT::ExpiredSignature
      render json: { error: 'Invalid token' }, status: :unauthorized
      return
    end

    unless @decoded && (@decoded[:user_id] || @decoded['user_id']) && (@decoded[:session_id] || @decoded['session_id'])
      render json: { error: 'Invalid token' }, status: :unauthorized
      return
    end

    user_id = @decoded[:user_id] || @decoded['user_id']
    session_id = @decoded[:session_id] || @decoded['session_id']
    @current_user = User.find_by(id: user_id)
    @current_session = Session.find_by(id: session_id)

    unless @current_user && @current_session
      render json: { error: 'Invalid token' }, status: :unauthorized
      return
    end

    unless @current_session.active?
      render json: { error: 'Session already expired' }, status: :unprocessable_entity
      return
    end

    @current_session.refresh!
  end
end
