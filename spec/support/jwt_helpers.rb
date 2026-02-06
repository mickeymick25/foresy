# frozen_string_literal: true

# JWT Test Helper Module
#
# Provides utilities to stub JWT authentication in tests.
# Use this to bypass authentication and focus on business logic testing.
#
# Usage:
#   RSpec.configure do |config|
#     config.include JwtHelpers, type: :request
#   end
#
#   describe 'some feature' do
#     before { authenticate_test_user }
#     # ... tests now bypass JWT auth
#   end
module JwtHelpers
  # Stub authentication to allow tests to reach business logic
  # Creates a mock user and bypasses token validation
  def authenticate_test_user
    # Stub the authenticate_access_token! method to do nothing
    allow_any_instance_of(ApplicationController).to receive(:authenticate_access_token!).and_return(true)

    # Create or stub current_user to return a valid user
    user = create(:user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

    # Set up JWT token validation to return the user
    allow(JWT).to receive(:decode).and_return([
                                                { 'sub' => user.id, 'exp' => 1.hour.from_now.to_i },
                                                Rails.application.credentials.jwt_secret
                                              ])
  end

  # Stub authentication with a specific user
  def authenticate_with_user(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_access_token!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  # Allow requests without valid JWT (for testing unauthenticated scenarios)
  def allow_unauthenticated
    allow_any_instance_of(ApplicationController).to receive(:authenticate_access_token!).and_raise(
      ApiErrors::AuthenticationError.new('Invalid token')
    )
  end
end

RSpec.configure do |config|
  config.include JwtHelpers, type: :request
end
