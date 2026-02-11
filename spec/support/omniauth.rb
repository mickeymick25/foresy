# frozen_string_literal: true

# ============================================
# 🚀 OmniAuth Test Configuration
# ============================================
# Configure OmniAuth for deterministic testing
# with proper cleanup between tests.

# Active OmniAuth test mode to avoid real external requests
OmniAuth.config.test_mode = true

# Default mock auth hash factory
def create_oauth_mock(provider:, uid:, email:, name:, nickname: nil)
  OmniAuth::AuthHash.new({
                           provider: provider,
                           uid: uid,
                           info: {
                             email: email,
                             name: name,
                             nickname: nickname
                           }.compact,
                           credentials: {
                             token: 'mock_oauth_token_test_deterministic',
                             refresh_token: 'mock_oauth_refresh_token_test',
                             expires_at: 1.week.from_now.to_i
                           }
                         })
end

# Mocked auth hash for Google OAuth2
GOOGLE_OAUTH_MOCK = create_oauth_mock(
  provider: 'google_oauth2',
  uid: '1234567890_google_test',
  email: 'oauth_google_test@example.com',
  name: 'Google Test User'
)

# Mocked auth hash for GitHub
GITHUB_OAUTH_MOCK = create_oauth_mock(
  provider: 'github',
  uid: '0987654321_github_test',
  email: 'oauth_github_test@example.com',
  name: 'GitHub Test User',
  nickname: 'githubtestuser'
)

# Set default mocks
OmniAuth.config.mock_auth[:google_oauth2] = GOOGLE_OAUTH_MOCK
OmniAuth.config.mock_auth[:github] = GITHUB_OAUTH_MOCK

# Cleanup after each test to prevent state pollution
RSpec.configure do |config|
  config.before(:each) do
    # Reset mocks to defaults before each test
    OmniAuth.config.mock_auth[:google_oauth2] = GOOGLE_OAUTH_MOCK
    OmniAuth.config.mock_auth[:github] = GITHUB_OAUTH_MOCK
    OmniAuth.config.mock_auth[:default] = nil
  end

  config.after(:each) do
    # Clear all mocks after each test
    OmniAuth.config.mock_auth.clear
  end
end
