# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth Callback', type: :request do
  describe 'POST /auth/:provider/callback' do
    context 'with valid Google OAuth code' do
      let(:valid_google_code) do
        {
          code: 'valid_google_auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 200 and valid JWT token' do
        # Mock Google OAuth response
        allow(GoogleOAuthService).to receive(:fetch_user_info)
          .with('valid_google_auth_code', 'https://client.app/callback')
          .and_return({
            provider: 'google_oauth2',
            uid: '123456789',
            email: 'user@google.com',
            name: 'Google User'
          })

        allow(JWTService).to receive(:encode)
          .with({
            user_id: be_a(String),
            provider: 'google_oauth2',
            exp: be_a(Integer)
          })
          .and_return('jwt_token')

        # Mock User creation/find
        allow(User).to receive(:find_or_create_by!)
          .with(provider: 'google_oauth2', provider_uid: '123456789')
          .and_return(
            double('User',
              id: 'user-uuid-123',
              email: 'user@google.com',
              provider: 'google_oauth2',
              provider_uid: '123456789'
            )
          )

        post '/auth/google_oauth2/callback', params: valid_google_code

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('token', 'user')
        expect(json_response['token']).to eq('jwt_token')
        expect(json_response['user']).to include(
          'id', 'email', 'provider', 'provider_uid'
        )
        expect(json_response['user']['provider']).to eq('google_oauth2')
        expect(json_response['user']['provider_uid']).to eq('123456789')
        expect(json_response['user']['email']).to eq('user@google.com')
      end
    end

    context 'with valid GitHub OAuth code' do
      let(:valid_github_code) do
        {
          code: 'valid_github_auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 200 and valid JWT token' do
        # Mock GitHub OAuth response
        allow(GitHubOAuthService).to receive(:fetch_user_info)
          .with('valid_github_auth_code', 'https://client.app/callback')
          .and_return({
            provider: 'github',
            uid: '987654321',
            email: 'user@github.com',
            name: 'GitHub User'
          })

        allow(JWTService).to receive(:encode)
          .with({
            user_id: be_a(String),
            provider: 'github',
            exp: be_a(Integer)
          })
          .and_return('github_jwt_token')

        # Mock User creation/find
        allow(User).to receive(:find_or_create_by!)
          .with(provider: 'github', provider_uid: '987654321')
          .and_return(
            double('User',
              id: 'user-uuid-456',
              email: 'user@github.com',
              provider: 'github',
              provider_uid: '987654321'
            )
          )

        post '/auth/github/callback', params: valid_github_code

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('token', 'user')
        expect(json_response['token']).to eq('github_jwt_token')
        expect(json_response['user']).to include(
          'id', 'email', 'provider', 'provider_uid'
        )
        expect(json_response['user']['provider']).to eq('github')
        expect(json_response['user']['provider_uid']).to eq('987654321')
        expect(json_response['user']['email']).to eq('user@github.com')
      end
    end

    context 'with unsupported provider' do
      let(:facebook_code) do
        {
          code: 'facebook_auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 400 with invalid_provider error' do
        post '/auth/facebook/callback', params: facebook_code

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_provider')
      end
    end

    context 'with missing authorization code' do
      let(:payload_without_code) do
        {
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 422 with invalid_payload error' do
        post '/auth/google_oauth2/callback', params: payload_without_code

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'with missing redirect_uri' do
      let(:payload_without_redirect) do
        {
          code: 'auth_code'
        }
      end

      it 'returns 422 with invalid_payload error' do
        post '/auth/google_oauth2/callback', params: payload_without_redirect

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'when OAuth fails (provider returns error)' do
      let(:invalid_code) do
        {
          code: 'invalid_auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 401 with oauth_failed error' do
        # Mock Google OAuth service to return error
        allow(GoogleOAuthService).to receive(:fetch_user_info)
          .with('invalid_auth_code', 'https://client.app/callback')
          .and_raise(OAuthError.new('Authorization code expired'))

        post '/auth/google_oauth2/callback', params: invalid_code

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('oauth_failed')
      end
    end

    context 'when provider is down' do
      let(:valid_code) do
        {
          code: 'auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 401 with oauth_failed error' do
        # Mock Google OAuth service to be unavailable
        allow(GoogleOAuthService).to receive(:fetch_user_info)
          .and_raise(Net::OpenTimeout.new('Connection timeout'))

        post '/auth/google_oauth2/callback', params: valid_code

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('oauth_failed')
      end
    end

    context 'when user data is incomplete (missing email)' do
      let(:incomplete_user_data) do
        {
          code: 'auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 422 with invalid_payload error' do
        # Mock Google OAuth service to return data without email
        allow(GoogleOAuthService).to receive(:fetch_user_info)
          .with('auth_code', 'https://client.app/callback')
          .and_return({
            provider: 'google_oauth2',
            uid: '123456789',
            name: 'User Without Email'
            # Missing email
          })

        post '/auth/google_oauth2/callback', params: incomplete_user_data

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'when user data is incomplete (missing uid)' do
      let(:incomplete_uid_data) do
        {
          code: 'auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 422 with invalid_payload error' do
        # Mock Google OAuth service to return data without uid
        allow(GoogleOAuthService).to receive(:fetch_user_info)
          .with('auth_code', 'https://client.app/callback')
          .and_return({
            provider: 'google_oauth2',
            email: 'user@google.com',
            name: 'User Without UID'
            # Missing uid
          })

        post '/auth/google_oauth2/callback', params: incomplete_uid_data

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'when creating new user with Google' do
      let(:new_user_code) do
        {
          code: 'new_user_auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'creates new user and returns JWT token' do
        # Mock Google OAuth response for new user
        allow(GoogleOAuthService).to receive(:fetch_user_info)
          .with('new_user_auth_code', 'https://client.app/callback')
          .and_return({
            provider: 'google_oauth2',
            uid: 'new_user_uid_123',
            email: 'newuser@google.com',
            name: 'New Google User'
          })

        # Mock User creation (no existing user found)
        allow(User).to receive(:find_or_create_by!)
          .with(provider: 'google_oauth2', provider_uid: 'new_user_uid_123')
          .and_return(
            double('User',
              id: 'new-user-uuid',
              email: 'newuser@google.com',
              provider: 'google_oauth2',
              provider_uid: 'new_user_uid_123'
            )
          )

        allow(JWTService).to receive(:encode)
          .with({
            user_id: 'new-user-uuid',
            provider: 'google_oauth2',
            exp: be_a(Integer)
          })
          .and_return('new_user_jwt_token')

        # Mock User.count to verify creation
        allow(User).to receive(:count).and_return(1)

        post '/auth/google_oauth2/callback', params: new_user_code

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('token', 'user')
        expect(json_response['token']).to eq('new_user_jwt_token')
        expect(json_response['user']['email']).to eq('newuser@google.com')

        # Verify User was created with correct attributes
        expect(User).to have_received(:find_or_create_by!)
          .with(provider: 'google_oauth2', provider_uid: 'new_user_uid_123')
      end
    end

    context 'when logging in existing user' do
      let(:existing_user_code) do
        {
          code: 'existing_user_auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'finds existing user and returns JWT token' do
        existing_user = double('User',
          id: 'existing-user-uuid',
          email: 'existing@google.com',
          provider: 'google_oauth2',
          provider_uid: 'existing_user_uid_456'
        )

        # Mock Google OAuth response for existing user
        allow(GoogleOAuthService).to receive(:fetch_user_info)
          .with('existing_user_auth_code', 'https://client.app/callback')
          .and_return({
            provider: 'google_oauth2',
            uid: 'existing_user_uid_456',
            email: 'existing@google.com',
            name: 'Existing Google User'
          })

        # Mock User find (existing user found)
        allow(User).to receive(:find_or_create_by!)
          .with(provider: 'google_oauth2', provider_uid: 'existing_user_uid_456')
          .and_return(existing_user)

        allow(JWTService).to receive(:encode)
          .with({
            user_id: 'existing-user-uuid',
            provider: 'google_oauth2',
            exp: be_a(Integer)
          })
          .and_return('existing_user_jwt_token')

        # Mock User.count to verify no new creation
        allow(User).to receive(:count).and_return(1)

        post '/auth/google_oauth2/callback', params: existing_user_code

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('token', 'user')
        expect(json_response['token']).to eq('existing_user_jwt_token')
        expect(json_response['user']['email']).to eq('existing@google.com')

        # Verify existing user was found
        expect(User).to have_received(:find_or_create_by!)
          .with(provider: 'google_oauth2', provider_uid: 'existing_user_uid_456')
      end
    end

    context 'when JWT encoding fails' do
      let(:valid_code) do
        {
          code: 'auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 500 with internal_error' do
        # Mock Google OAuth service success
        allow(GoogleOAuthService).to receive(:fetch_user_info)
          .and_return({
            provider: 'google_oauth2',
            uid: '123456789',
            email: 'user@google.com',
            name: 'Google User'
          })

        # Mock User creation success
        allow(User).to receive(:find_or_create_by!)
          .and_return(
            double('User',
              id: 'user-uuid',
              email: 'user@google.com',
              provider: 'google_oauth2',
              provider_uid: '123456789'
            )
          )

        # Mock JWT encoding to fail
        allow(JWTService).to receive(:encode)
          .and_raise(JWT::EncodeError.new('Invalid secret key'))

        post '/auth/google_oauth2/callback', params: valid_code

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('internal_error')
      end
    end

    context 'with invalid JSON payload' do
      it 'returns 422 with invalid_payload error' do
        post '/auth/google_oauth2/callback',
          params: '{ invalid json }',
          headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'with empty request body' do
      it 'returns 422 with invalid_payload error' do
        post '/auth/google_oauth2/callback', params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'with malformed request (non-JSON content type)' do
      let(:form_data) do
        {
          code: 'auth_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 422 with invalid_payload error' do
        post '/auth/google_oauth2/callback',
          params: form_data,
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)

        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end
  end
end
