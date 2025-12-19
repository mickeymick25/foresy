# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 OAuth', type: :request do
  path '/api/v1/auth/{provider}/callback' do
    post 'OAuth callback for provider authentication' do
      tags 'OAuth'
      description 'Authenticates a user via OAuth provider (Google or GitHub). Returns a JWT token on success.'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :provider, in: :path, type: :string, required: true,
                description: 'OAuth provider (google_oauth2 or github)',
                schema: { type: :string, enum: %w[google_oauth2 github] }

      parameter name: :body, in: :body, required: true,
                description: 'OAuth authorization code and redirect URI',
                schema: {
                  type: :object,
                  properties: {
                    code: { type: :string, description: 'OAuth authorization code from provider' },
                    redirect_uri: { type: :string, format: :uri, description: 'Redirect URI used in OAuth flow' }
                  },
                  required: %w[code redirect_uri]
                }

      # ============================================================
      # SUCCESS CASES - 200 OK
      # ============================================================

      # NOTE: Feature Contract specifies UUID for id, but current implementation uses integer.
      # TODO: Consider migrating to UUID in future version.
      response '200', 'successful OAuth authentication with Google' do
        schema type: :object,
               properties: {
                 token: { type: :string, description: 'JWT authentication token' },
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer, description: 'User unique identifier' },
                     email: { type: :string, format: :email, description: 'User email address' },
                     provider: { type: :string, description: 'OAuth provider used' },
                     provider_uid: { type: :string, description: 'User unique identifier from OAuth provider' }
                   },
                   required: %w[id email provider provider_uid]
                 }
               },
               required: %w[token user]

        let(:provider) { 'google_oauth2' }
        let(:body) { { code: 'valid_auth_code', redirect_uri: 'https://client.app/callback' } }

        let(:mock_user) do
          User.create!(
            email: 'user@google.com',
            password: 'password123',
            password_confirmation: 'password123',
            provider: 'google_oauth2',
            uid: 'google_uid_12345',
            active: true
          )
        end

        let(:mock_auth_hash) do
          OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            uid: 'google_uid_12345',
            info: {
              email: 'user@google.com',
              name: 'Google User'
            }
          )
        end

        before do
          allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)
          allow(OAuthValidationService).to receive(:validate_oauth_data).and_return({
                                                                                      valid: true,
                                                                                      data: {
                                                                                        provider: 'google_oauth2',
                                                                                        uid: 'google_uid_12345',
                                                                                        email: 'user@google.com',
                                                                                        name: 'Google User'
                                                                                      }
                                                                                    })
          allow(OAuthUserService).to receive(:find_or_create_user_from_oauth).and_return(mock_user)
          allow(OAuthTokenService).to receive(:generate_stateless_jwt).and_return('fake_jwt_token_google')
          allow(OAuthTokenService).to receive(:format_success_response).and_return({
                                                                                     token: 'fake_jwt_token_google',
                                                                                     user: {
                                                                                       id: mock_user.id,
                                                                                       email: mock_user.email,
                                                                                       provider: mock_user.provider,
                                                                                       provider_uid: mock_user.uid
                                                                                     }
                                                                                   })
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to include('id', 'email', 'provider', 'provider_uid')
          expect(data['user']['provider']).to eq('google_oauth2')
        end
      end

      response '200', 'successful OAuth authentication with GitHub' do
        schema type: :object,
               properties: {
                 token: { type: :string, description: 'JWT authentication token' },
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer, description: 'User unique identifier' },
                     email: { type: :string, format: :email, description: 'User email address' },
                     provider: { type: :string, description: 'OAuth provider used' },
                     provider_uid: { type: :string, description: 'User unique identifier from OAuth provider' }
                   },
                   required: %w[id email provider provider_uid]
                 }
               },
               required: %w[token user]

        let(:provider) { 'github' }
        let(:body) { { code: 'valid_github_auth_code', redirect_uri: 'https://client.app/callback' } }

        let(:mock_user) do
          User.create!(
            email: 'user@github.com',
            password: 'password123',
            password_confirmation: 'password123',
            provider: 'github',
            uid: 'github_uid_98765',
            active: true
          )
        end

        let(:mock_auth_hash) do
          OmniAuth::AuthHash.new(
            provider: 'github',
            uid: 'github_uid_98765',
            info: {
              email: 'user@github.com',
              name: 'GitHub User'
            }
          )
        end

        before do
          allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)
          allow(OAuthValidationService).to receive(:validate_oauth_data).and_return({
                                                                                      valid: true,
                                                                                      data: {
                                                                                        provider: 'github',
                                                                                        uid: 'github_uid_98765',
                                                                                        email: 'user@github.com',
                                                                                        name: 'GitHub User'
                                                                                      }
                                                                                    })
          allow(OAuthUserService).to receive(:find_or_create_user_from_oauth).and_return(mock_user)
          allow(OAuthTokenService).to receive(:generate_stateless_jwt).and_return('fake_jwt_token_github')
          allow(OAuthTokenService).to receive(:format_success_response).and_return({
                                                                                     token: 'fake_jwt_token_github',
                                                                                     user: {
                                                                                       id: mock_user.id,
                                                                                       email: mock_user.email,
                                                                                       provider: mock_user.provider,
                                                                                       provider_uid: mock_user.uid
                                                                                     }
                                                                                   })
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to include('id', 'email', 'provider', 'provider_uid')
          expect(data['user']['provider']).to eq('github')
        end
      end

      # ============================================================
      # ERROR CASES - As per Feature Contract
      # ============================================================

      response '400', 'invalid provider - provider not supported' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'invalid_provider', description: 'Error code' }
               },
               required: %w[error]

        let(:provider) { 'facebook' }
        let(:body) { { code: 'auth_code', redirect_uri: 'https://client.app/callback' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('invalid_provider')
        end
      end

      response '401', 'OAuth authentication failed - provider returns error' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'oauth_failed', description: 'Error code' }
               },
               required: %w[error]

        let(:provider) { 'google_oauth2' }
        let(:body) { { code: 'invalid_auth_code', redirect_uri: 'https://client.app/callback' } }

        before do
          allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(nil)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('oauth_failed')
        end
      end

      response '422', 'invalid payload - missing authorization code' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'invalid_payload', description: 'Error code' }
               },
               required: %w[error]

        let(:provider) { 'google_oauth2' }
        let(:body) { { redirect_uri: 'https://client.app/callback' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('invalid_payload')
        end
      end

      response '422', 'invalid payload - missing redirect_uri' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'invalid_payload', description: 'Error code' }
               },
               required: %w[error]

        let(:provider) { 'google_oauth2' }
        let(:body) { { code: 'auth_code' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('invalid_payload')
        end
      end

      response '422', 'invalid payload - missing email from provider' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'invalid_payload', description: 'Error code' }
               },
               required: %w[error]

        let(:provider) { 'google_oauth2' }
        let(:body) { { code: 'auth_code', redirect_uri: 'https://client.app/callback' } }

        let(:incomplete_auth_hash) do
          OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            uid: 'google_uid_12345',
            info: {
              name: 'User Without Email'
            }
          )
        end

        before do
          allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(incomplete_auth_hash)
          allow(OAuthValidationService).to receive(:validate_oauth_data).and_return({ error: 'missing_email' })
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('invalid_payload')
        end
      end

      response '422', 'invalid payload - missing UID from provider' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'invalid_payload', description: 'Error code' }
               },
               required: %w[error]

        let(:provider) { 'google_oauth2' }
        let(:body) { { code: 'auth_code', redirect_uri: 'https://client.app/callback' } }

        let(:incomplete_auth_hash) do
          OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            info: {
              email: 'user@google.com',
              name: 'User Without UID'
            }
          )
        end

        before do
          allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(incomplete_auth_hash)
          allow(OAuthValidationService).to receive(:validate_oauth_data).and_return({ error: 'missing_uid' })
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('invalid_payload')
        end
      end

      response '500', 'internal server error - token generation failed' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'internal_error', description: 'Error code' }
               },
               required: %w[error]

        let(:provider) { 'google_oauth2' }
        let(:body) { { code: 'auth_code', redirect_uri: 'https://client.app/callback' } }

        let(:mock_auth_hash) do
          OmniAuth::AuthHash.new(
            provider: 'google_oauth2',
            uid: 'google_uid_12345',
            info: {
              email: 'user@google.com',
              name: 'Google User'
            }
          )
        end

        let(:mock_user) do
          User.create!(
            email: 'error_user@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            provider: 'google_oauth2',
            uid: 'google_uid_error',
            active: true
          )
        end

        before do
          allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)
          allow(OAuthValidationService).to receive(:validate_oauth_data).and_return({
                                                                                      valid: true,
                                                                                      data: {
                                                                                        provider: 'google_oauth2',
                                                                                        uid: 'google_uid_12345',
                                                                                        email: 'user@google.com'
                                                                                      }
                                                                                    })
          allow(OAuthUserService).to receive(:find_or_create_user_from_oauth).and_return(mock_user)
          allow(OAuthTokenService).to receive(:generate_stateless_jwt)
            .and_raise(StandardError, 'Token generation failed')
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('internal_error')
        end
      end
    end
  end

  path '/api/v1/auth/failure' do
    get 'OAuth failure endpoint' do
      tags 'OAuth'
      description 'Endpoint called when OAuth authentication fails at the provider level'
      produces 'application/json'

      response '401', 'OAuth authentication failed' do
        schema type: :object,
               properties: {
                 error: { type: :string, example: 'oauth_failed', description: 'Error code' },
                 message: { type: :string, example: 'OAuth authentication failed', description: 'Error message' }
               },
               required: %w[error message]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to eq('oauth_failed')
          expect(data['message']).to be_present
        end
      end
    end
  end
end
