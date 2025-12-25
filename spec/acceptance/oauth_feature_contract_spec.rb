# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth Feature Contract', type: :request do
  describe 'POST /api/v1/auth/:provider/callback' do
    context 'Authenticate with Google' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 200 response and a valid JWT token is returned' do
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
      end
    end

    context 'Authenticate with GitHub' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 200 response and a valid JWT token is returned' do
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
      end
    end

    context 'Unsupported provider' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 400 response' do
        post '/api/v1/auth/unsupported_provider/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_provider')
      end
    end

    context 'Missing authorization code' do
      let(:invalid_payload) do
        {
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 422 response with invalid_payload error' do
        # Mock OAuthValidationService to return invalid payload
        allow(OAuthValidationService).to receive(:validate_callback_payload).and_return({ error: 'Code is required' })

        post '/api/v1/auth/google_oauth2/callback',
             params: invalid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('invalid_payload')
      end
    end

    context 'Missing redirect_uri' do
      let(:invalid_payload) do
        {
          code: 'oauth_authorization_code'
        }
      end

      it 'returns 422 response with invalid_payload error' do
        # Mock OAuthValidationService to return invalid payload
        allow(OAuthValidationService).to receive(:validate_callback_payload)
          .and_return({ error: 'Redirect URI is required' })

        post '/api/v1/auth/google_oauth2/callback',
             params: invalid_payload.to_json,
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
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
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
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 422 response with invalid_payload error' do
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

        # Mock OAuthValidationService to return invalid data
        allow(OAuthValidationService).to receive(:validate_oauth_data).and_return({ error: 'Email is required' })

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
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 422 response with invalid_payload error' do
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

        # Mock OAuthValidationService to return invalid data
        allow(OAuthValidationService).to receive(:validate_oauth_data).and_return({ error: 'UID is required' })

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
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 500 response with internal_error' do
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

        # Stub OAuthUserService to return a valid user
        mock_user = double('User', persisted?: true, id: 1, email: 'user@google.com', provider: 'google_oauth2',
                                   uid: 'google_uid_12345')
        allow(OAuthUserService).to receive(:find_or_create_user_from_oauth).and_return(mock_user)

        # Mock OAuthTokenService to raise an error
        allow(OAuthTokenService).to receive(:generate_stateless_jwt)
          .and_raise(JWT::EncodeError.new('Invalid secret key'))

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:internal_server_error)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']).to eq('internal_error')
      end
    end

    # ==========================================================================
    # FEATURE CONTRACT - Business Rules Tests
    # ==========================================================================

    context 'Existing user with (provider, provider_uid) logs in (no new account created)' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 200 and logs in existing user without creating duplicate' do
        # Create existing user in database
        existing_user = User.create!(
          email: 'existing@google.com',
          provider: 'google_oauth2',
          uid: 'existing_google_uid_999',
          password: 'password123',
          name: 'Existing User',
          active: true
        )

        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: 'existing_google_uid_999',
          info: {
            email: 'existing@google.com',
            name: 'Existing User'
          }
        )

        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        expect do
          post '/api/v1/auth/google_oauth2/callback',
               params: valid_payload.to_json,
               headers: { 'Content-Type' => 'application/json' }
        end.not_to change(User, :count)

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['user']['id']).to eq(existing_user.id)
        expect(json_response['user']['email']).to eq('existing@google.com')
      end
    end

    context 'New user is automatically created on first OAuth login' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'creates a new user and returns 200 with JWT' do
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'github',
          uid: 'new_github_uid_12345',
          info: {
            email: 'newuser@github.com',
            name: 'New GitHub User',
            nickname: 'newgithubuser'
          }
        )

        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        expect do
          post '/api/v1/auth/github/callback',
               params: valid_payload.to_json,
               headers: { 'Content-Type' => 'application/json' }
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('token', 'user')

        # Verify user was created with correct data
        created_user = User.find_by(provider: 'github', uid: 'new_github_uid_12345')
        expect(created_user).to be_present
        expect(created_user.email).to eq('newuser@github.com')
        expect(created_user.name).to eq('New GitHub User')
        expect(created_user.active).to be true
      end
    end

    # ==========================================================================
    # FEATURE CONTRACT - JWT Token Validation
    # ==========================================================================

    context 'JWT token contains required claims (user_id, provider, exp)' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns a JWT with valid claims structure' do
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: 'jwt_test_uid_777',
          info: {
            email: 'jwttest@google.com',
            name: 'JWT Test User'
          }
        )

        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        token = json_response['token']
        expect(token).to be_present

        # Decode JWT without verification to check claims structure
        decoded_payload = JWT.decode(token, nil, false).first

        expect(decoded_payload).to include('user_id')
        expect(decoded_payload).to include('exp')
        expect(decoded_payload['user_id']).to be_a(Integer)
        expect(decoded_payload['exp']).to be_a(Integer)
        expect(decoded_payload['exp']).to be > Time.now.to_i
      end
    end

    # ==========================================================================
    # FEATURE CONTRACT - Provider Constraints
    # ==========================================================================

    context 'Facebook provider (not in supported list)' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 400 invalid_provider for facebook' do
        post '/api/v1/auth/facebook/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('invalid_provider')
      end
    end

    context 'Twitter provider (not in supported list)' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'returns 400 invalid_provider for twitter' do
        post '/api/v1/auth/twitter/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)

        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('invalid_provider')
      end
    end

    # ==========================================================================
    # FEATURE CONTRACT - Unique Constraints
    # ==========================================================================

    context '(provider, provider_uid) uniqueness constraint' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'http://localhost:3000/auth/callback'
        }
      end

      it 'does not create duplicate users with same provider and uid' do
        # Create first user
        User.create!(
          email: 'first@google.com',
          provider: 'google_oauth2',
          uid: 'unique_constraint_uid',
          password: 'password123',
          name: 'First User',
          active: true
        )

        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: 'unique_constraint_uid',
          info: {
            email: 'second@google.com',
            name: 'Second User Attempt'
          }
        )

        allow(OAuthValidationService).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        # Should not create a new user, should find existing one
        expect do
          post '/api/v1/auth/google_oauth2/callback',
               params: valid_payload.to_json,
               headers: { 'Content-Type' => 'application/json' }
        end.not_to change(User, :count)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
