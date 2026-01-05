# frozen_string_literal: true

# spec/support/auth_helpers.rb
module AuthHelpers
  def login_user(email: 'user@example.com', password: 'password123')
    post '/api/v1/auth/login', params: { email: email, password: password }
    JSON.parse(response.body)
  end

  # Generate a valid JWT token for a user in tests
  # Creates a session for the user and returns a valid access token
  def token_for(user)
    session = user.sessions.create!(
      ip_address: '127.0.0.1',
      user_agent: 'RSpec Test',
      expires_at: 30.days.from_now
    )

    payload = {
      user_id: user.id,
      session_id: session.id
    }

    JsonWebToken.encode(payload)
  end
end

RSpec.configure do |_config|
  include AuthHelpers
end
