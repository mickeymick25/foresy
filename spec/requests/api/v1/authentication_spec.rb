require 'swagger_helper'

RSpec.describe 'Authentication API', type: :request do
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
        let(:user) { create(:user, password: 'password123') }
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
        let(:auth) { { email: 'wrong@example.com', password: 'wrong' } }

        run_test!
      end
    end
  end

  path '/api/v1/auth/refresh' do
    post 'Refreshes authentication token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'Refresh-Token', in: :header, type: :string, required: true

      response '200', 'token refreshed' do
        let(:user) { create(:user) }
        let(:refresh_token) { JsonWebToken.refresh_token(user.id) }
        let(:'Refresh-Token') { refresh_token }

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
        let(:'Refresh-Token') { 'invalid_token' }

        run_test!
      end
    end
  end

  path '/api/v1/auth/logout' do
    delete 'Logs out the user' do
      tags 'Authentication'
      security [bearer_auth: []]
      produces 'application/json'

      response '200', 'user logged out' do
        let(:user) { create(:user) }
        let(:session) { create(:session, user: user) }
        let(:token) { JsonWebToken.encode(user_id: user.id, session_id: session.id) }
        let(:Authorization) { "Bearer #{token}" }

        run_test! do |response|
          expect(session.reload.expired?).to be true
          data = JSON.parse(response.body)
          expect(data['message']).to eq('Logged out successfully')
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }

        run_test!
      end
    end
  end
end 