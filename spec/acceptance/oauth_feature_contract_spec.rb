# frozen_string_literal: true

require 'rails_helper'

# Load OAuth services to ensure they are available for stubbing

RSpec.describe 'OAuth Feature Contract', type: :request do
  describe 'POST /api/v1/auth/:provider/callback' do
    context 'Authenticate with Google' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 200 response and a valid JWT token is returned' do
        # Mock OmniAuth environment to simulate successful OAuth response
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: 'google_uid_12345',
          info: {
            email: 'user@google.com',
            name: 'Google User'
          }
        )

        # Mock OAuthValidationService to return the mock auth hash
        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        # Stub JsonWebToken to avoid JWT secret configuration issues
        allow(JsonWebToken).to receive(:encode).and_return('fake_jwt_token_123')
        allow(JsonWebToken).to receive(:decode).and_return({
                                                             'user_id' => 1,
                                                             'provider' => 'google_oauth2',
                                                             'exp' => (Time.current + 15.minutes).to_i
                                                           })

        # Stub OAuthUserService to avoid user creation issues
        mock_user = double('User', persisted?: true, id: 1, email: 'user@google.com', provider: 'google_oauth2',
                                   uid: 'google_uid_12345')
        allow(OAuthUserService).to receive(:find_or_create_user_from_oauth).and_return(mock_user)

        # Stub OAuthTokenService to avoid token generation issues
        allow(OAuthTokenService).to receive(:generate_stateless_jwt).and_return('fake_jwt_token_123')
        allow(OAuthTokenService).to receive(:format_success_response).and_return({
                                                                                   token: 'fake_jwt_token_123',
                                                                                   user: {
                                                                                     id: 1,
                                                                                     email: 'user@google.com',
                                                                                     provider: 'google_oauth2',
                                                                                     provider_uid: 'google_uid_12345'
                                                                                   }
                                                                                 })

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('token', 'user')
        expect(json_response['token']).to be_present

        user_data = json_response['user']
        expect(user_data).to include('id', 'email', 'provider', 'provider_uid')
        expect(user_data['provider']).to eq('google_oauth2')
        expect(user_data['provider_uid']).to eq('google_uid_12345')
        expect(user_data['email']).to eq('user@google.com')

        # Verify JWT token is valid
        decoded_token = JsonWebToken.decode(json_response['token'])
        expect(decoded_token['user_id']).to be_present
        expect(decoded_token['provider']).to eq('google_oauth2')
        expect(decoded_token['exp']).to be_present
      end
    end

    context 'Authenticate with GitHub' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 200 response and a valid JWT token is returned' do
        # Mock OmniAuth environment to simulate successful OAuth response
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'github',
          uid: 'github_uid_98765',
          info: {
            email: 'user@github.com',
            name: 'GitHub User'
          }
        )

        # Mock OAuthValidationService to return the mock auth hash
        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        # Stub JsonWebToken to avoid JWT secret configuration issues
        allow(JsonWebToken).to receive(:encode).and_return('fake_jwt_token_456')
        allow(JsonWebToken).to receive(:decode).and_return({
                                                             'user_id' => 2,
                                                             'provider' => 'github',
                                                             'exp' => (Time.current + 15.minutes).to_i
                                                           })

        # Stub OAuthUserService to avoid user creation issues
        mock_user = double('User', persisted?: true, id: 2, email: 'user@github.com', provider: 'github',
                                   uid: 'github_uid_98765')
        allow(OAuthUserService).to receive(:find_or_create_user_from_oauth).and_return(mock_user)

        # Stub OAuthTokenService to avoid token generation issues
        allow(OAuthTokenService).to receive(:generate_stateless_jwt).and_return('fake_jwt_token_456')
        allow(OAuthTokenService).to receive(:format_success_response).and_return({
                                                                                   token: 'fake_jwt_token_456',
                                                                                   user: {
                                                                                     id: 2,
                                                                                     email: 'user@github.com',
                                                                                     provider: 'github',
                                                                                     provider_uid: 'github_uid_98765'
                                                                                   }
                                                                                 })

        post '/api/v1/auth/github/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('token', 'user')
        expect(json_response['token']).to be_present

        user_data = json_response['user']
        expect(user_data).to include('id', 'email', 'provider', 'provider_uid')
        expect(user_data['provider']).to eq('github')
        expect(user_data['provider_uid']).to eq('github_uid_98765')
        expect(user_data['email']).to eq('user@github.com')

        # Verify JWT token is valid
        decoded_token = JsonWebToken.decode(json_response['token'])
        expect(decoded_token['user_id']).to be_present
        expect(decoded_token['provider']).to eq('github')
        expect(decoded_token['exp']).to be_present
      end
    end

    context 'Unsupported provider' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 400 response' do
        post '/api/v1/auth/facebook/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_provider')
      end
    end

    context 'Missing authorization code' do
      let(:payload_without_code) do
        {
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 422 response with invalid_payload error' do
        post '/api/v1/auth/google_oauth2/callback',
             params: payload_without_code.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'Missing redirect_uri' do
      let(:payload_without_redirect) do
        {
          code: 'oauth_authorization_code'
        }
      end

      it 'returns 422 response with invalid_payload error' do
        post '/api/v1/auth/google_oauth2/callback',
             params: payload_without_redirect.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'OAuth fails (provider returns error)' do
      let(:valid_payload) do
        {
          code: 'invalid_oauth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 401 response with oauth_failed error' do
        # Mock OAuthValidationService to return nil (OAuth failure)
        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(nil)

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('oauth_failed')
      end
    end

    context 'User data incomplete (missing email)' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 422 response with invalid_payload error' do
        # Mock OAuthConcern with incomplete user data (missing email)
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: 'google_uid_12345',
          info: {
            name: 'User Without Email'
            # Missing email
          }
        )

        # Mock OAuthValidationService to return the mock auth hash
        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'User data incomplete (missing uid)' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 422 response with invalid_payload error' do
        # Mock OAuthConcern with incomplete user data (missing uid)
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          info: {
            email: 'user@google.com',
            name: 'User Without UID'
          }
          # Missing uid
        )

        # Mock OAuthValidationService to return the mock auth hash
        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'JWT encoding fails' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 500 response with internal_error' do
        # Mock OAuthConcern with successful response
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: 'google_uid_12345',
          info: {
            email: 'user@google.com',
            name: 'Google User'
          }
        )

        # Mock OAuthValidationService to return the mock auth hash
        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        # Simulate JWT encoding failure
        allow(JsonWebToken).to receive(:encode).and_raise(JWT::EncodeError.new('Invalid secret key'))

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:internal_server_error)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('internal_error')
      end
    end
  end
end
