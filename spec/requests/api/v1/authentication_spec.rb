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
      parameter name: :refresh, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string }
        },
        required: ['refresh_token']
      }

      response '200', 'token refreshed' do
        let(:user) { create(:user) }
        before { user.create_session(ip_address: '127.0.0.1', user_agent: 'rspec') }
        let(:refresh_token) { JsonWebToken.refresh_token(user.id) }
        let(:refresh) { { refresh_token: refresh_token } }
        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['refresh_token']).to be_present
          expect(data['email']).to eq(user.email)
          expect(user.sessions.count).to eq(2)
          expect(user.sessions.last.active?).to be true
        end
      end

      response '401', 'unauthorized' do
        let(:refresh) { { refresh_token: 'invalid_token' } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('invalid or expired refresh token')
        end
      end

      response '401', 'refresh token missing or invalid' do
        let(:refresh) { { refresh_token: '' } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('refresh token missing or invalid')
        end
      end

      response '401', 'refresh token expired' do
        let(:user) { create(:user) }
        let(:expired_refresh_token) { JsonWebToken.encode({ user_id: user.id }, 1.hour.ago.to_i) }
        let(:refresh) { { refresh_token: expired_refresh_token } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('invalid or expired refresh token')
        end
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
        let(:Authorization) { nil }
        run_test!
      end

      response '422', 'session already expired' do
        let(:user) { create(:user) }
        let(:session) { create(:session, user: user, expires_at: 1.hour.ago) }
        let(:token) { JsonWebToken.encode(user_id: user.id, session_id: session.id) }
        let(:Authorization) { "Bearer #{token}" }

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Session already expired')
        end
      end

      response '401', 'no active session' do
        let(:user) { create(:user) }
        let(:session) { create(:session, user: user) }
        let(:token) { JsonWebToken.encode(user_id: user.id, session_id: session.id) }
        let(:Authorization) { "Bearer #{token}" }
        before { session.destroy }
        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Invalid token')
        end
      end
    end
  end

  describe 'refresh token invalidé après invalidate_all_sessions!' do
    it 'refuse le refresh token après invalidation' do
      user = create(:user)
      refresh_token = JsonWebToken.refresh_token(user.id)
      user.invalidate_all_sessions!

      post '/api/v1/auth/refresh', params: { refresh_token: refresh_token }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Access token invalidé après logout' do
    it "refuse l'accès avec un access token après logout" do
      user = create(:user)
      session = user.create_session(ip_address: '127.0.0.1', user_agent: 'rspec')
      token = JsonWebToken.encode(user_id: user.id, session_id: session.id)

      # Déconnexion
      delete '/api/v1/auth/logout', headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      # Tentative d'accès à un endpoint protégé (logout à nouveau)
      delete '/api/v1/auth/logout', headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end