# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Authentication - Logout', type: :request do
  let(:user) { create(:user, email: "logout_test_#{SecureRandom.hex(4)}@example.com", password: 'password123') }
  let(:auth_params) { { email: user.email, password: 'password123' } }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  # Login and extract token before tests
  let!(:token) do
    post '/api/v1/auth/login', params: auth_params.to_json, headers: headers
    JSON.parse(response.body)['token']
  end

  let(:authorization_header) { { 'Authorization' => "Bearer #{token}" } }

  path '/api/v1/auth/logout' do
    delete 'Logs out the user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'

      response '200', 'user logged out' do
        let(:Authorization) { authorization_header['Authorization'] }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to eq('Logged out successfully')
        end
      end

      response '401', 'unauthorized - invalid token' do
        let(:Authorization) { 'Bearer invalid.token.here' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to be_present
        end
      end

      response '401', 'unauthorized - no token provided' do
        let(:Authorization) { nil }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Missing token')
        end
      end

      response '401', 'unauthorized - expired session' do
        let(:Authorization) do
          # Expire session manually
          user.sessions.last.update!(expires_at: 1.hour.ago)
          "Bearer #{token}"
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Session already expired')
        end
      end

      response '401', 'unauthorized - invalid session ID in token' do
        let(:invalid_token) do
          JsonWebToken.encode(user_id: user.id, session_id: -1)
        end
        let(:Authorization) { "Bearer #{invalid_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Invalid token')
        end
      end

      response '401', 'unauthorized - second logout (session already expired)' do
        let(:Authorization) do
          delete '/api/v1/auth/logout', headers: authorization_header
          "Bearer #{token}"
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Session already expired')
        end
      end
    end
  end
end
