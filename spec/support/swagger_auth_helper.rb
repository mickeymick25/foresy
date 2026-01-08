# frozen_string_literal: true

# SwaggerAuthHelper - Canonical RSwag authentication helpers
#
# Rules:
# - Use real auth API (authenticate method)
# - No handcrafted JWT.encode
# - Tests reflect real backend behavior
# - Authentication via actual API endpoints
#
module SwaggerAuthHelper
  # Uses real authentication API to get JWT token
  # This ensures token compatibility with backend validation
  #
  # @param user [User] the user to authenticate
  # @return [String] the JWT token from the login response
  # @raise [StandardError] if authentication fails
  def authenticate(user)
    post '/api/v1/auth/login',
         params: { email: user.email, password: user.password }.to_json,
         headers: { 'Content-Type' => 'application/json' }

    JSON.parse(response.body)['token']
  rescue StandardError => e
    # Authentication failure - let the test fail naturally
    raise "Authentication failed for user #{user.email}: #{e.message}"
  end

  # Invalid token for testing error scenarios
  # This will be naturally rejected by the backend
  #
  # @return [String] an obviously invalid token
  def invalid_jwt_token
    "invalid.token.here"
  end

  # Generate a properly formatted but invalid JWT token
  # for more realistic error testing
  #
  # @return [String] malformed JWT token
  def malformed_jwt_token
    # Valid JWT structure but wrong signature/claims
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
  end
end

# RSpec configuration to include helpers
RSpec.configure do |config|
  config.include SwaggerAuthHelper, type: :request
end
