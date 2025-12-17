# frozen_string_literal: true

# OAuth Controller for Feature Contract endpoints
# Handles OAuth authentication for Google & GitHub providers
# Implements stateless JWT authentication without server-side sessions
#
# This controller provides the following endpoints:
# - POST /auth/:provider/callback - OAuth callback for authentication
# - GET /auth/failure - OAuth failure endpoint
#
# Load OAuthConcern explicitly to avoid autoloading issues
require_relative '../../concerns/oauth_concern'

module Api
  module V1
    # OAuth Controller for Feature Contract endpoints
    # Handles OAuth authentication for Google & GitHub providers
    # Implements stateless JWT authentication without server-side sessions
    class OauthController < ApplicationController
      include ::OAuthConcern

  # POST /auth/:provider/callback
  # OAuth callback endpoint for Google & GitHub authentication
  def callback
    return render_bad_request('invalid_provider') unless valid_provider?(params[:provider])

    payload_validation = validate_callback_payload
    return render_unprocessable_entity('invalid_payload') if payload_validation[:error]

    auth_data = extract_oauth_data
    return render_unauthorized('oauth_failed') if auth_data.nil?

    auth_validation = validate_oauth_data(auth_data)
    return render_unprocessable_entity('invalid_payload') if auth_validation[:error]

    user = find_or_create_user_from_oauth(auth_validation[:data])
    return render_unprocessable_entity('invalid_payload') unless user.persisted?

    token = generate_stateless_jwt(user)
    render_success_response(token, user)
  rescue StandardError => e
    Rails.logger.error "OAuth callback error: #{e.message}"
    render json: { error: 'internal_error' }, status: :internal_server_error
  end

  # GET /auth/failure
  # Optional OAuth failure endpoint (recommended by Feature Contract)
  def failure
    render json: { error: 'oauth_failed', message: 'OAuth authentication failed' }, status: :unauthorized
  end

  private

  # Validate that the provider is supported according to Feature Contract
  def valid_provider?(provider)
    %w[google_oauth2 github].include?(provider)
  end

  # Validate the callback payload according to Feature Contract
  def validate_callback_payload
    code = params[:code]
    redirect_uri = params[:redirect_uri]

    if code.blank?
      return { error: 'missing_code' }
    elsif redirect_uri.blank?
      return { error: 'missing_redirect_uri' }
    end

    { valid: true, code: code, redirect_uri: redirect_uri }
  end

  # Validate OAuth data completeness according to Feature Contract
  def validate_oauth_data(auth)
    return { error: 'missing_auth_data' } if auth.blank?

    provider = auth.respond_to?(:provider) ? auth.provider : (auth[:provider] || auth['provider'])
    uid = auth.respond_to?(:uid) ? auth.uid : (auth[:uid] || auth['uid'])
    info = auth.respond_to?(:info) ? auth.info : (auth[:info] || auth['info'])
    email = extract_info_field(info, :email)

    return { error: 'missing_provider' } if provider.blank?
    return { error: 'missing_uid' } if uid.blank?
    return { error: 'missing_email' } if email.blank?

    {
      valid: true,
      data: {
        provider: provider,
        uid: uid,
        email: email,
        name: extract_info_field(info, :name),
        nickname: extract_info_field(info, :nickname)
      }
    }
  end

  # Extract info field from OAuth info hash
  def extract_info_field(info, field)
    return nil if info.blank?

    if info.respond_to?(field)
      info.send(field)
    else
      info[field] || info[field.to_s]
    end
  end

  # Find or create user from OAuth data using existing User model
  def find_or_create_user_from_oauth(oauth_data)
    # Use existing User.find_or_initialize_by with provider and uid
    user = User.find_or_initialize_by(provider: oauth_data[:provider], uid: oauth_data[:uid])

    if user.persisted?
      # Update existing user
      update_existing_oauth_user!(user, oauth_data)
    else
      # Create new user
      create_oauth_user!(user, oauth_data)
    end

    user
  end

  # Update existing OAuth user with latest data
  def update_existing_oauth_user!(user, oauth_data)
    user.email = oauth_data[:email] if oauth_data[:email].present?
    user.name = oauth_data[:name] || oauth_data[:nickname] || 'No Name'
    user.active = true
    user.save!
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to update OAuth user: #{e.message}"
    raise
  end

  # Create new OAuth user
  def create_oauth_user!(user, oauth_data)
    user.email = oauth_data[:email]
    user.name = oauth_data[:name] || oauth_data[:nickname] || 'No Name'
    user.active = true
    user.save!
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create OAuth user: #{e.message}"
    raise
  end

  # Generate stateless JWT token according to Feature Contract
  # Must include: user_id, provider, exp
  def generate_stateless_jwt(user)
    JsonWebToken.encode(
      user_id: user.id,
      provider: user.provider,
      exp: 15.minutes.from_now.to_i
    )
  end

  # Render success response with token and user data
  def render_success_response(token, user)
    render json: {
      token: token,
      user: {
        id: user.id,
        email: user.email,
        provider: user.provider,
        provider_uid: user.uid
      }
    }, status: :ok
  end

  # Render helpers for standardized error responses
  def render_bad_request(error_code)
    render json: { error: error_code }, status: :bad_request
  end

  def render_unauthorized(error_code)
    render json: { error: error_code }, status: :unauthorized
  end

  def render_unprocessable_entity(error_code)
    render json: { error: error_code }, status: :unprocessable_entity
  end
    end
  end
end
