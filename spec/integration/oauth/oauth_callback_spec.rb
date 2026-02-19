# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'OAuth Callback Integration', type: :request do
  describe 'POST /api/v1/auth/:provider/callback' do
    shared_examples 'successful OAuth authentication' do
      it 'returns 200 response with valid JWT token' do
        subject
        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('token', 'user')
        expect(json_response['token']).to be_present

        # Verify JWT token structure
        decoded_token = JsonWebToken.decode(json_response['token'])
        expect(decoded_token['user_id']).to be_present
        expect(decoded_token['provider']).to eq(provider_name)
        expect(decoded_token['exp']).to be_present

        # Verify user data
        user_data = json_response['user']
        expect(user_data).to include('id', 'email', 'provider', 'provider_uid')
        expect(user_data['provider']).to eq(provider_name)
        expect(user_data['email']).to eq(user_email)
      end
    end

    context 'Authenticate with Google successfully' do
      let(:provider_name) { 'google_oauth2' }
      let(:user_email) { 'user@google.com' }
      let(:provider_uid) { 'google_uid_12345' }
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      subject do
        # Mock successful OAuth data
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: provider_name,
          uid: provider_uid,
          info: {
            email: user_email,
            name: 'Google User'
          }
        )

        # Use the same approach as acceptance tests that work
        allow_any_instance_of(Api::V1::OauthController).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        post "/api/v1/auth/#{provider_name}/callback",
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }
      end

      it_behaves_like 'successful OAuth authentication'

      it 'creates a new user when one does not exist' do
        expect { subject }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq(user_email)
        expect(user.provider).to eq('google_oauth2')
        expect(user.uid).to eq(provider_uid)
      end

      context 'when user already exists' do
        let(:existing_user) do
          User.create!(
            email: user_email,
            provider: provider_name,
            uid: provider_uid,
            name: 'Existing User'
          )
        end

        before do
          existing_user
        end

        it 'returns a token for the existing user without creating a new one' do
          expect { subject }.not_to change(User, :count)

          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['user']['email']).to eq(existing_user.email)
          expect(json['token']).to be_present
        end
      end
    end

    context 'Authenticate with GitHub successfully' do
      let(:provider_name) { 'github' }
      let(:user_email) { 'user@github.com' }
      let(:provider_uid) { 'github_uid_98765' }
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      subject do
        # Mock successful OAuth data
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: provider_name,
          uid: provider_uid,
          info: {
            email: user_email,
            name: 'GitHub User'
          }
        )

        # Use the same approach as acceptance tests that work
        allow_any_instance_of(Api::V1::OauthController).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        post "/api/v1/auth/#{provider_name}/callback",
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }
      end

      it_behaves_like 'successful OAuth authentication'

      it 'creates a new GitHub user' do
        expect { subject }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq(user_email)
        expect(user.provider).to eq('github')
        expect(user.uid).to eq(provider_uid)
      end
    end

    context 'OAuth extraction failure' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 401 response when OAuth data is missing' do
        # Use the same approach as acceptance tests but simulate failure
        allow_any_instance_of(Api::V1::OauthController).to receive(:extract_oauth_data).and_return(nil)

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']['code']).to eq('oauth_failed')
      end
    end

    context 'Unsupported provider' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 400 response for unsupported provider' do
        # No stubbing needed - the controller automatically validates provider support
        post '/api/v1/auth/facebook/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:bad_request)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']['code']).to eq('invalid_provider')
      end
    end

    context 'Invalid OAuth data' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 422 response when OAuth data is incomplete (missing email)' do
        # Mock OAuth data with missing email
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: 'google_uid_12345',
          info: {
            name: 'User Without Email'
            # Missing email
          }
        )

        # Use the same approach as acceptance tests
        allow_any_instance_of(Api::V1::OauthController).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_content)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']['code']).to eq('invalid_payload')
      end
    end

    context 'JWT encoding failure' do
      let(:valid_payload) do
        {
          code: 'oauth_authorization_code',
          redirect_uri: 'https://client.app/callback'
        }
      end

      it 'returns 500 response when JWT encoding fails' do
        mock_auth_hash = OmniAuth::AuthHash.new(
          provider: 'google_oauth2',
          uid: 'google_uid_12345',
          info: {
            email: 'user@google.com',
            name: 'Google User'
          }
        )

        # Use the same approach as acceptance tests
        allow_any_instance_of(Api::V1::OauthController).to receive(:extract_oauth_data).and_return(mock_auth_hash)

        # Simulate JWT encoding failure
        allow(JsonWebToken).to receive(:encode).and_raise(JWT::EncodeError.new('Invalid secret key'))

        post '/api/v1/auth/google_oauth2/callback',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:internal_server_error)

        json_response = JSON.parse(response.body)
        expect(json_response).to include('error')
        expect(json_response['error']['code']).to eq('internal_error')
      end
    end
  end

  describe 'GET /api/v1/auth/failure' do
    it 'returns oauth_failed error with 401 status' do
      get '/api/v1/auth/failure'

      expect(response).to have_http_status(:unauthorized)

      json_response = JSON.parse(response.body)
      expect(json_response).to include('error')
      expect(json_response['error']['code']).to eq('oauth_failed')
    end
  end
end
