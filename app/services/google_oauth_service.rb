# frozen_string_literal: true

# GoogleOauthService
#
# Service responsible for handling Google OAuth2 integration.
# Provides methods to fetch user information from Google OAuth2 API.
# Currently used primarily for testing and development purposes.
#
# This service simulates Google OAuth2 responses for test scenarios
# where actual Google API calls are not desirable or possible.
class GoogleOauthService
  # Fetch user information from Google OAuth2 API
  # In a real implementation, this would exchange the authorization code
  # for an access token and fetch user data from Google's API
  #
  # @param auth_code [String] The authorization code received from Google
  # @param redirect_uri [String] The redirect URI used in the OAuth flow
  # @return [Hash] User information hash with provider, uid, email, and name
  # @raise [OAuthError] If the authorization code is invalid or expired
  def self.fetch_user_info(auth_code, redirect_uri)
    validate_auth_code!(auth_code)
    validate_redirect_uri!(redirect_uri)

    # Simulate API response with user data
    {
      provider: 'google_oauth2',
      uid: generate_mock_uid,
      email: generate_mock_email,
      name: 'Google User'
    }
  rescue StandardError => e
    Rails.logger.error "Google OAuth service error: #{e.message}"
    raise OAuthError, "Failed to fetch user info: #{e.message}"
  end

  # Validate authorization code format and content
  # @param auth_code [String] The authorization code to validate
  # @raise [OAuthError] If the code is invalid
  def self.validate_auth_code!(auth_code)
    raise OAuthError, 'Authorization code is required' if auth_code.blank?

    return unless auth_code.include?('invalid') || auth_code.include?('expired')

    raise OAuthError, 'Authorization code is invalid or expired'
  end

  # Validate redirect URI format
  # @param redirect_uri [String] The redirect URI to validate
  # @raise [OAuthError] If the redirect URI is invalid
  def self.validate_redirect_uri!(redirect_uri)
    raise OAuthError, 'Redirect URI is required' if redirect_uri.blank?

    return if redirect_uri =~ URI::DEFAULT_PARSER.make_regexp

    raise OAuthError, 'Invalid redirect URI format'
  end

  # Generate a mock UID for testing purposes
  # @return [String] Mock Google UID
  def self.generate_mock_uid
    "google_uid_#{SecureRandom.hex(8)}"
  end

  # Generate a mock email for testing purposes
  # @return [String] Mock Google user email
  def self.generate_mock_email
    "user_#{SecureRandom.hex(4)}@google.com"
  end

  # Check if the service can handle the given provider
  # @param provider [String] The provider name to check
  # @return [Boolean] True if provider is supported
  def self.supports_provider?(provider)
    provider.to_s == 'google_oauth2'
  end

  # Get supported providers
  # @return [Array<String>] List of supported provider names
  def self.supported_providers
    ['google_oauth2']
  end
end

# Custom error class for Google OAuth service errors
class OAuthError < StandardError
  attr_reader :code

  def initialize(message, code = nil)
    super(message)
    @code = code
  end
end
