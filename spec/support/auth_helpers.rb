# frozen_string_literal: true

# spec/support/auth_helpers.rb
module AuthHelpers
  def login_user(email: 'user@example.com', password: 'password123')
    post '/api/v1/auth/login', params: { email: email, password: password }
    JSON.parse(response.body)
  end
end
