# frozen_string_literal: true

require 'rails_helper'

# Test to validate JWT rescue_from behavior in concerns Authenticatable and ErrorRenderable
# This test verifies that JWT-specific rescue_from handlers take precedence over StandardError handler
RSpec.describe 'JWT Rescue From Behavior', type: :request do
  let(:headers) { { 'Authorization' => 'Bearer invalid_token' } }

  describe 'JWT::DecodeError handling' do
    let(:user) { create(:user) }
    let(:session) { user.sessions.create!(expires_at: 1.hour.from_now) }

    it 'should handle JWT::DecodeError with specific handler from Authenticatable' do
      # Mock JsonWebToken.decode to raise JWT::DecodeError
      allow(JsonWebToken).to receive(:decode).and_raise(JWT::DecodeError)

      # Use existing authenticated endpoint (logout) that requires authentication
      delete '/api/v1/auth/logout', headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include('error' => 'Invalid token')
    end

    it 'should handle JWT::ExpiredSignature with specific handler from Authenticatable' do
      # Mock JsonWebToken.decode to raise JWT::ExpiredSignature
      allow(JsonWebToken).to receive(:decode).and_raise(JWT::ExpiredSignature)

      delete '/api/v1/auth/logout', headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include('error' => 'Token has expired')
    end
  end

  describe 'Interaction with ErrorRenderable StandardError handler' do
    it 'should NOT trigger StandardError handler for JWT errors in development' do
      # This test ensures that JWT errors are handled by Authenticatable
      # and NOT by ErrorRenderable's StandardError handler

      # Create a controller action that will trigger JWT::DecodeError
      allow(JsonWebToken).to receive(:decode).and_raise(JWT::DecodeError)

      # In development/test, StandardError handler should re-raise (not render)
      # JWT errors should be handled by Authenticatable lambdas instead

      delete '/api/v1/auth/logout', headers: headers

      # If we get here, it means JWT::DecodeError was handled by Authenticatable
      # If we get a 500 error, it means StandardError caught it (problematic)
      expect(response).not_to have_http_status(:internal_server_error)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'should verify concern order does not interfere with JWT handling' do
      # This test verifies that the order of concern inclusion doesn't
      # cause StandardError to override JWT-specific handlers

      # Test both error types to ensure neither is intercepted by StandardError
      jwt_errors = [JWT::DecodeError.new, JWT::ExpiredSignature.new]

      jwt_errors.each do |error|
        allow(JsonWebToken).to receive(:decode).and_raise(error)

        delete '/api/v1/auth/logout', headers: headers

        # Should get specific JWT error response, not generic 500 error
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to include('error')

        # Should NOT get internal server error from StandardError handler
        expect(response).not_to have_http_status(:internal_server_error)
      end
    end
  end
end
