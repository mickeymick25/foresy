# frozen_string_literal: true

# Authenticatable
#
# Concern that provides JWT authentication functionality for controllers.
# Handles token validation, payload verification, and user session management.
#
# == Authentication Flow
#
# 1. `authenticate_access_token!` - Main entry point (before_action)
# 2. `bearer_token` - Extracts JWT from Authorization header
# 3. `decode_token` - Decodes JWT, returns payload or error symbol
# 4. `valid_payload?` - Validates payload structure and content
# 5. `assign_current_user_and_session` - Sets @current_user and @current_session
# 6. `valid_session?` - Verifies session is active
#
# == Usage
#
#   class Api::V1::ProtectedController < ApplicationController
#     include Authenticatable
#     before_action :authenticate_access_token!
#   end
#
module Authenticatable
  extend ActiveSupport::Concern

  included do
    attr_reader :current_user, :current_session
  end

  private

  # Main authentication method - validates token and establishes session
  #
  # @return [void] Sets @current_user and @current_session on success
  # @return [JSON] Renders 401 unauthorized on failure
  def authenticate_access_token!
    Rails.logger.info "[DEBUG L514] authenticate_access_token! called"
    Rails.logger.info "[AUTH] Starting authenticate_access_token!"
    Rails.logger.info "[AUTH] Request headers: #{request.headers.inspect}"

    token = bearer_token
    Rails.logger.info "[AUTH] Bearer token extracted: #{token.present? ? 'present' : 'missing'}"
    return render_unauthorized('Missing token') unless token

    payload = decode_token(token)
    Rails.logger.info "[AUTH] Decode token result: #{payload.inspect}"
    return handle_invalid_payload(payload) unless valid_payload?(payload)

    assign_current_user_and_session(payload)
    Rails.logger.info "[AUTH] User and session assigned - user: #{@current_user.present?}, session: #{@current_session.present?}"
    return handle_invalid_session unless valid_session?

    current_session.refresh!
    Rails.logger.info "[AUTH] Session refreshed successfully - authentication complete"
  end

  # Extracts the JWT token from the Authorization header
  #
  # @return [String, nil] The token without "Bearer " prefix, or nil if missing
  #
  # @example
  #   # With header "Authorization: Bearer eyJhbGc..."
  #   bearer_token # => "eyJhbGc..."
  def bearer_token
    pattern = /^Bearer /
    header = request.headers['Authorization']
    header.gsub(pattern, '') if header&.match(pattern)
  end

  # Decodes JWT token and returns payload or error symbol
  #
  # @param token [String] The JWT token to decode
  # @return [HashWithIndifferentAccess] Decoded payload on success
  # @return [Symbol] :expired_token if JWT::ExpiredSignature
  # @return [Symbol] :invalid_token if JWT::DecodeError
  def decode_token(token)
    JsonWebToken.decode(token)
  rescue JWT::ExpiredSignature
    :expired_token
  rescue JWT::DecodeError
    :invalid_token
  end

  # Validates the decoded payload
  #
  # Checks for:
  # - Error symbols (:expired_token, :invalid_token)
  # - Nil payload
  # - Presence of required fields (user_id, session_id)
  #
  # @param payload [Hash, Symbol, nil] The decoded token payload
  # @return [Boolean] true if payload is valid and contains required fields
  #
  # @example
  #   valid_payload?(:expired_token)                    # => false
  #   valid_payload?(nil)                               # => false
  #   valid_payload?({ user_id: 1 })                    # => false (missing session_id)
  #   valid_payload?({ user_id: 1, session_id: 'abc' }) # => true
  def valid_payload?(payload)
    # Reject error symbols from decode_token
    return false if payload == :expired_token
    return false if payload == :invalid_token
    return false if payload.nil?

    # Verify required fields are present
    user_id_from(payload).present? && session_id_from(payload).present?
  end

  # Renders appropriate error message based on payload type
  #
  # @param payload [Symbol] Error symbol (:expired_token or :invalid_token)
  # @return [void] Renders JSON error with 401 status
  def handle_invalid_payload(payload)
    if payload == :expired_token
      render_unauthorized('Token has expired')
    else
      render_unauthorized('Invalid token')
    end
  end

  # Loads user and session from payload into instance variables
  #
  # @param payload [Hash] Decoded JWT payload with user_id and session_id
  # @return [void] Sets @current_user and @current_session
  def assign_current_user_and_session(payload)
    Rails.logger.info "[AUTH] Assigning user and session from payload: #{payload.inspect}"

    user_id = user_id_from(payload)
    session_id = session_id_from(payload)
    Rails.logger.info "[AUTH] Extracted user_id: #{user_id}, session_id: #{session_id}"

    @current_user = User.find_by(id: user_id)
    Rails.logger.info "[AUTH] User find_by result: #{@current_user.present? ? "found (id: #{@current_user.id})" : 'not found'}"

    @current_session = Session.find_by(id: session_id)
    Rails.logger.info "[AUTH] Session find_by result: #{@current_session.present? ? "found (id: #{@current_session.id})" : 'not found'}"
  end

  # Validates that session exists and is active
  #
  # @return [Boolean] true if user, session exist and session is active
  def valid_session?
    return false unless current_user && current_session
    return false unless current_session.active?

    true
  end

  # Renders appropriate error for invalid session
  #
  # @return [void] Renders JSON error with 401 status
  def handle_invalid_session
    if current_user && current_session
      render_unauthorized('Session already expired')
    else
      render_unauthorized('Invalid token')
    end
  end

  # Extracts user_id from payload (handles both string and symbol keys)
  #
  # @param payload [Hash] Decoded JWT payload
  # @return [String, Integer, nil] The user_id value
  def user_id_from(payload)
    payload['user_id'] || payload[:user_id]
  end

  # Extracts session_id from payload (handles both string and symbol keys)
  #
  # @param payload [Hash] Decoded JWT payload
  # @return [String, nil] The session_id value
  def session_id_from(payload)
    payload['session_id'] || payload[:session_id]
  end

  # Renders JSON response for authentication failures
  #
  # @param message [String] Error message to include in response
  # @return [void] Renders JSON response with 401 status
  def render_unauthorized(message = 'Unauthorized')
    render json: {
      error: 'unauthorized',
      message: message
    }, status: :unauthorized
  end
end
