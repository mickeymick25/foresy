# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
require 'swagger_helper'

RSpec.describe 'Authentication - Logout', type: :request do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:auth) { { email: user.email, password: 'password123' } }

  before do
    post '/api/v1/auth/login', params: auth
    @token = JSON.parse(response.body)['token']
  end

  path '/api/v1/auth/logout' do
    delete 'Logs out the user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'

      response '200', 'user logged out' do
        let(:Authorization) { "Bearer #{@token}" }

        run_test! do
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
    end
  end
end
# rubocop:enable Metrics/BlockLength
