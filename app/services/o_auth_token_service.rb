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
end
