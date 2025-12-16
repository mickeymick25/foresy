# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Authentication - OAuth Logout', type: :request do
  let(:user_email) { 'oauth@example.com' }
  let(:token) { 'valid.jwt.token' }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.mock_auth[:github] = nil
    Rails.application.env_config['omniauth.auth'] = nil
  end

  %i[google_oauth2 github].each do |provider|
    describe "OAuth login and logout via #{provider.to_s.titleize}" do
      path "/api/v1/oauth/#{provider}/callback" do
        post "Logs in via #{provider}" do
          tags "Authentication via #{provider.to_s.titleize}"
          consumes 'application/json'
          produces 'application/json'

          response '200', 'OAuth login successful' do
            let(:unique_email) { "oauth_#{SecureRandom.hex(4)}_#{provider}@example.com" }
            let(:mock_auth_hash) do
              OmniAuth::AuthHash.new(
                provider: provider.to_s,
                uid: SecureRandom.hex(8),
                info: {
                  email: unique_email,
                  name: 'OAuth Tester'
                }
              )
            end

            before do
              User.where(email: unique_email).destroy_all
              allow_any_instance_of(Api::V1::AuthenticationController).to receive(:oauth_callback) do |controller|
                auth = mock_auth_hash
                user = controller.send(:find_or_create_user_from_auth, auth)

                if user.persisted?
                  result = AuthenticationService.login(user, controller.request.remote_ip,
                                                       controller.request.user_agent)
                  controller.render json: {
                    token: result[:token],
                    refresh_token: result[:refresh_token],
                    user: user
                  }, status: :ok
                else
                  controller.render json: { error: 'Unprocessable entity', message: 'User creation failed' },
                                    status: :unprocessable_entity
                end
              end
            end

            run_test! do
              expect(response).to have_http_status(:ok)
              json = JSON.parse(response.body)
              expect(json['token']).to be_present
            end
          end
        end
      end

      path '/api/v1/auth/logout' do
        delete 'Logs out' do
          tags 'Authentication Logout'
          consumes 'application/json'
          produces 'application/json'
          parameter name: :Authorization, in: :header, type: :string, required: false

          let(:unique_email) { "oauth_logout_#{SecureRandom.hex(4)}_#{provider}@example.com" }
          let(:oauth_user) do
            User.find_or_create_by!(email: unique_email, provider: provider.to_s, uid: SecureRandom.hex(8)) do |u|
              u.name = 'OAuth Tester'
              u.active = true
            end
          end
          let(:oauth_token) do
            session = oauth_user.sessions.create!(
              expires_at: 30.days.from_now,
              ip_address: '127.0.0.1',
              user_agent: 'test'
            )
            JsonWebToken.encode(user_id: oauth_user.id, session_id: session.id)
          end

          response '200', 'Logout successful' do
            let(:Authorization) { "Bearer #{oauth_token}" }

            run_test! do
              expect(response).to have_http_status(:ok)
              json = JSON.parse(response.body)
              expect(json['message']).to eq('Logged out successfully')
            end
          end

          response '401', 'logout fails with invalid token' do
            let(:Authorization) { 'Bearer invalid.token' }

            run_test! do
              expect(response).to have_http_status(:unauthorized)
              json = JSON.parse(response.body)
              expect(json['error']).to eq('Invalid token')
            end
          end

          # Test sans token
          response '401', 'logout fails with no token' do
            let(:Authorization) { nil }

            run_test! do
              expect(response).to have_http_status(:unauthorized)
              json = JSON.parse(response.body)
              expect(json['error']).to eq('Missing token')
            end
          end

          # Test avec token expiré
          response '401', 'logout fails with expired token' do
            let(:Authorization) { 'Bearer expired.token.here' }

            run_test! do
              expect(response).to have_http_status(:unauthorized)
              json = JSON.parse(response.body)
              expect(json['error']).to eq('Invalid token')
            end
          end

          # Test pour erreurs serveur
          response '500', 'internal server error' do
            let(:Authorization) { "Bearer #{oauth_token}" }

            before do
              # Stub pour forcer une erreur dans logout après l'authentification
              allow_any_instance_of(Api::V1::AuthenticationController).to receive(:logout) do |_controller|
                raise ApplicationError::InternalServerError, 'Something went wrong'
              end
            end

            run_test! do
              expect(response).to have_http_status(:internal_server_error)
              json = JSON.parse(response.body)
              expect(json['error']).to eq('Internal server error')
            end
          end
        end
      end
    end
  end
end
