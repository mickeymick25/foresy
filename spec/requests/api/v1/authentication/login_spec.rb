# frozen_string_literal: true

require 'swagger_helper'
require 'securerandom'

RSpec.describe 'Authentication - Login', type: :request do
  let(:valid_user) { create(:user, email: "test_#{SecureRandom.hex(4)}@example.com", password: 'password123') }
  let(:inactive_user) do
    create(:user, email: "inactive_#{SecureRandom.hex(4)}@example.com", password: 'password123', active: false)
  end

  before do
    # Clear rate limiting state before each test to avoid interference
    RateLimitService.clear_rate_limit('auth/login', '127.0.0.1')
    RateLimitService.clear_rate_limit('auth/signup', '127.0.0.1')
    RateLimitService.clear_rate_limit('auth/refresh', '127.0.0.1')
  end

  path '/api/v1/auth/login' do
    post 'Authenticates a user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :auth, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string }
        },
        required: %w[email password]
      }

      response '200', 'user authenticated' do
        let(:auth) { { email: valid_user.email, password: 'password123' } }

        run_test! do |response|
          expect(response).to have_http_status(:ok)

          data = begin
            JSON.parse(response.body)
          rescue StandardError
            {}
          end
          expect(data['token']).to be_present
          expect(data['refresh_token']).to be_present
          expect(data['email']).to eq(valid_user.email)

          expect(valid_user.sessions.count).to eq(1)
          expect(valid_user.sessions.first.active?).to be true
        end
      end

      response '401', 'invalid credentials' do
        let(:auth) { { email: 'wrong@example.com', password: 'wrongpassword' } }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = begin
            JSON.parse(response.body)
          rescue StandardError
            {}
          end
          expect(data['error']).to be_present
        end
      end

      response '401', 'missing password' do
        let(:auth) { { email: valid_user.email, password: '' } }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = begin
            JSON.parse(response.body)
          rescue StandardError
            {}
          end
          expect(data['error']).to eq('Password is required')
        end
      end

      response '401', 'missing email' do
        let(:auth) { { email: '', password: 'password123' } }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = begin
            JSON.parse(response.body)
          rescue StandardError
            {}
          end
          expect(data['error']).to eq('Email is required')
        end
      end

      response '403', 'inactive user' do
        let(:auth) { { email: inactive_user.email, password: 'password123' } }

        run_test! do |response|
          expect(response).to have_http_status(:forbidden)
          data = begin
            JSON.parse(response.body)
          rescue StandardError
            {}
          end
          expect(data['error']).to eq('Forbidden')
          expect(data['message']).to include('Account is inactive')
        end
      end
    end
  end
end
