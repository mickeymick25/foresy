# frozen_string_literal: true

# ============================================
# 🔐 Auth Helpers for Tests
# ============================================
# Provides deterministic authentication helpers
# that use the locked-down JWT secret from rails_helper.rb

module AuthHelpers
  def login_user(email: 'user@example.com', password: 'password123')
    post '/api/v1/auth/login', params: { email: email, password: password }
    JSON.parse(response.body)
  end

  # Generate a valid JWT token for a user in tests
  # Uses the DETERMINISTIC JWT_SECRET from ENV (set in rails_helper.rb)
  def token_for(user)
    # Ensure session exists
    session = user.sessions.first || user.sessions.create!(
      ip_address: '127.0.0.1',
      user_agent: 'RSpec Test',
      expires_at: 30.days.from_now
    )

    payload = {
      user_id: user.id,
      session_id: session.id,
      exp: 1.hour.from_now.to_i
    }

    # Use JWT.encode with the deterministic secret from ENV
    # This matches what AuthenticationService uses in test
    JWT.encode(payload, ENV.fetch('JWT_SECRET'))
  end

  # Shorthand for Authorization header
  def auth_headers_for(user)
    {
      'Authorization' => "Bearer #{token_for(user)}",
      'Content-Type' => 'application/json'
    }
  end
end

RSpec.configure do |_config|
  include AuthHelpers
end
