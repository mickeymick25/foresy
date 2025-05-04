# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
require 'swagger_helper'

RSpec.describe 'Authentication - Token Refresh', type: :request do
  let(:user) { create(:user, password: 'password123') }

  path '/api/v1/auth/refresh' do
    post 'Refreshes authentication token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :refresh, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string }
        },
        required: ['refresh_token']
      }

      response '200', 'token refreshed' do
        let(:refresh_token) do
          res = login_user(email: user.email, password: 'password123')
          res['refresh_token']
        end

        let(:refresh) { { refresh_token: refresh_token } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['refresh_token']).to be_present
          expect(data['email']).to eq(user.email)
        end
      end

      response '401', 'invalid or expired refresh token' do
        let(:refresh) { { refresh_token: 'invalid_token' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to be_present
          expect(data['error']).to match(/invalid|expired/i)
        end
      end

      response '401', 'refresh token missing' do
        let(:refresh) { { refresh_token: '' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to be_present
          expect(data['error']).to match(/missing|invalid/i)
        end
      end

      response '401', 'refresh token expired' do
        let(:expired_refresh_token) do
          payload = {
            user_id: user.id,
            refresh_exp: 1.hour.ago.to_i
          }
          JWT.encode(payload, Rails.application.secret_key_base)
        end

        let(:refresh) { { refresh_token: expired_refresh_token } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to match(/expired|invalid/i)
        end
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
