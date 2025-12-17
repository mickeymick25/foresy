# frozen_string_literal: true

# ApplicationController
#
# Base controller from which all other API controllers inherit.
# Handles global configurations, authentication filters, and shared behaviors.
class ApplicationController < ActionController::API
  include Authenticatable
  include ErrorRenderable

  attr_reader :current_user, :current_session

  private

  def authenticate_access_token!
    token = bearer_token
    return render_unauthorized('Missing token') unless token

    payload = decode_token(token)
    return handle_invalid_payload(payload) unless valid_payload?(payload)

    assign_current_user_and_session(payload)
    return handle_invalid_session unless valid_session?

    current_session.refresh!
  end

  # Extracts the token from the Authorization header (e.g., "Bearer <token>")
  def bearer_token
    pattern = /^Bearer /
    header = request.headers['Authorization']
    header.gsub(pattern, '') if header&.match(pattern)
  end

  def decode_token(token)
    JsonWebToken.decode(token)
  rescue JWT::ExpiredSignature
    :expired_token
  rescue JWT::DecodeError
    :invalid_token
  end

  def payload_valid?(payload)
    return false if payload.nil?

    user_id_from(payload).present? && session_id_from(payload).present?
  end

  def handle_invalid_payload(payload)
    if payload == :expired_token
      render_unauthorized('Token has expired')
    else
      render_unauthorized('Invalid token')
    end
  end

  def handle_expired_session
    render_unauthorized('Session already expired')
  end

  def valid_payload?(payload)
    return false if payload == :expired_token
    return false if payload == :invalid_token
    return false if payload.nil?

    payload_valid?(payload)
  end

  def valid_session?
    return false unless current_user && current_session
    return false unless current_session.active?

    true
  end

  def handle_invalid_session
    if current_user && current_session
      handle_expired_session
    else
      render_unauthorized('Invalid token')
    end
  end

  def assign_current_user_and_session(payload)
    @current_user = User.find_by(id: user_id_from(payload))
    @current_session = Session.find_by(id: session_id_from(payload))
  end

  def user_id_from(payload)
    payload['user_id'] || payload[:user_id]
  end

  def session_id_from(payload)
    payload['session_id'] || payload[:session_id]
  end
end
