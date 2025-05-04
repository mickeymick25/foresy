# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
require 'swagger_helper'

RSpec.describe 'Authentication - Login', type: :request do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:auth) { { email: user.email, password: 'password123' } }

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
        let(:auth) { { email: user.email, password: 'password123' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['refresh_token']).to be_present
          expect(data['email']).to eq(user.email)
          expect(user.sessions.count).to eq(1)
          expect(user.sessions.first.active?).to be true
        end
      end

      response '401', 'unauthorized' do
        let(:auth) { { email: 'wrong@example.com', password: 'wrongpassword' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to be_present
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
