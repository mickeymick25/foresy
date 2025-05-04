# frozen_string_literal: true

# ApplicationController
#
# Base controller from which all other API controllers inherit.
# Handles global configurations, authentication filters, and shared behaviors.
class ApplicationController < ActionController::API
  attr_reader :current_user, :current_session

  private

  def authenticate_access_token!
    token = extract_token_from_header
    return render_unauthorized('Missing token') unless token

    payload = decode_token(token)
    return render_unauthorized('Invalid token') unless valid_payload?(payload)

    assign_current_user_and_session(payload)
    return render_unauthorized('Invalid token') unless current_user && current_session
    return render_unauthorized('Session already expired') unless current_session.active?

    current_session.refresh!
  end

  def extract_token_from_header
    header = request.headers['Authorization']
    header&.split(' ')&.last
  end

  def decode_token(token)
    JsonWebToken.decode(token)
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end

  def valid_payload?(payload)
    user_id_from_payload(payload).present? && session_id_from_payload(payload).present?
  end

  def assign_current_user_and_session(payload)
    @current_user = User.find_by(id: user_id_from_payload(payload))
    @current_session = Session.find_by(id: session_id_from_payload(payload))
  end

  def user_id_from_payload(payload)
    payload&.dig(:user_id) || payload&.dig('user_id')
  end

  def session_id_from_payload(payload)
    payload&.dig(:session_id) || payload&.dig('session_id')
  end

  def render_unauthorized(message)
    render json: { error: message }, status: :unauthorized
  end
end
