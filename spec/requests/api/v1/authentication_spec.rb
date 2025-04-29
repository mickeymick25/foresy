require 'swagger_helper'

RSpec.describe 'Authentication API', type: :request do
  let(:user) { create(:user, email: 'test@example.com', password: 'password123') }
  let(:auth) { { email: user.email, password: 'password123' } }

  # Helper methods for repeated actions
  def login_user
    post '/api/v1/auth/login', params: auth
    response_data = JSON.parse(response.body)
    puts "Login response: #{response_data}"
    response_data
  end

  def get_authorization_header
    token = login_user['token']
    user.reload # 🔧 Recharger l'utilisateur pour synchroniser les sessions
    puts "TOKEN: #{token}"
    puts "SESSIONS AFTER LOGIN: #{user.sessions.inspect}"
    "Bearer #{token}"
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
        required: ['email', 'password']
      }

      response '200', 'user authenticated' do
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
        let(:refresh_token) do
          res = login_user
          puts "Refresh token obtenu : #{res['refresh_token']}" # Ajout de log pour debug
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
        let(:Authorization) { get_authorization_header }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to eq('Logged out successfully')
        end
      end

      response '401', 'session already expired' do
        let(:Authorization) do
          post '/api/v1/auth/login', params: auth
          token = JSON.parse(response.body)['token']
          user.sessions.last.update!(expires_at: 1.hour.ago)
          "Bearer #{token}"
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Session already expired')
        end
      end

      response '401', 'no active session' do
        let(:Authorization) do
          post '/api/v1/auth/login', params: auth
          token = JSON.parse(response.body)['token']
          user.sessions.last.destroy
          "Bearer #{token}"
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('Invalid token')
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  describe 'Refresh token invalidé après invalidate_all_sessions!' do
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
      user = create(:user, email: 'test@example.com', password: 'password123')
      auth = { email: user.email, password: 'password123' }

      post '/api/v1/auth/login', params: auth
      token = JSON.parse(response.body)['token']

      delete '/api/v1/auth/logout', headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      delete '/api/v1/auth/logout', headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'Contrôle du before_action sur logout' do
    it 'refuse le logout sans Authorization' do
      delete '/api/v1/auth/logout'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DEBUG – refresh_token presence' do
    it 'génère un refresh_token via login_user' do
      result = login_user
      RSpec.configuration.output_stream.puts "REFRESH TOKEN: #{result['refresh_token']}"
      expect(result['refresh_token']).to be_present
    end
  end
  

end
