# frozen_string_literal: true



# OAuthTokenService
#
# Service responsible for OAuth token generation and response formatting.
# Handles stateless JWT token creation and standardized success responses
# for OAuth authentication flows.
#
# This service extracts token generation and response formatting logic from
# OauthController to reduce complexity and improve maintainability.
class OAuthTokenService
  OAUTH_TOKEN_EXPIRATION = 15.minutes

  # Generate stateless JWT token according to Feature Contract
  # Must include: user_id, provider, exp
  def self.generate_stateless_jwt(user)
    raise ArgumentError, 'User must be persisted' unless user.persisted?

    payload = {
      user_id: user.id,
      provider: user.provider,
      exp: OAUTH_TOKEN_EXPIRATION.from_now.to_i
    }

    JsonWebToken.encode(payload)
  rescue JWT::EncodeError => e
    Rails.logger.error "Failed to generate JWT token: #{e.message}"
    raise ApplicationError::InternalServerError, 'Token generation failed'
  end

  # Render success response with token and user data
  def self.format_success_response(token, user)
    {
      token: token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        provider: user.provider,
        provider_uid: user.uid
      }
    }
  end

  # Validate if token generation is possible for user
  def self.can_generate_token?(user)
    return false unless user.present?
    return false unless user.persisted?
    return false unless user.active?

    true
  end

  # Extract user info for response formatting
  def self.extract_user_info(user)
    {
      id: user.id,
      email: user.email,
      provider: user.provider,
      provider_uid: user.uid
    }
  end

  # Generate token with custom expiration
  def self.generate_stateless_jwt_with_expiration(user, expiration_duration)
    raise ArgumentError, 'User must be persisted' unless user.persisted?

    payload = {
      user_id: user.id,
      provider: user.provider,
      exp: expiration_duration.from_now.to_i
    }

    JsonWebToken.encode(payload)
  end

  # Get OAuth token expiration time
  def self.token_expiration_time
    OAUTH_TOKEN_EXPIRATION
  end

  # Check if user can authenticate via OAuth
  def self.can_authenticate_oauth?(user)
    return false unless user.present?
    return false unless user.persisted?
    return false unless user.active?
    return false unless user.provider.present?
    return false unless user.uid.present?

    true
  end
end
