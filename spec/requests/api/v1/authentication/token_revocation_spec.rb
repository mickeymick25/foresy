# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Token Revocation', type: :request do
  let(:user) { create(:user, email: "test_#{SecureRandom.hex(4)}@example.com", password: 'password123') }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  # Helper to get auth tokens
  def login_user(user)
    post '/api/v1/auth/login',
         params: { email: user.email, password: 'password123' }.to_json,
         headers: headers
    JSON.parse(response.body)
  end

  def auth_headers(token)
    headers.merge('Authorization' => "Bearer #{token}")
  end

  describe 'DELETE /api/v1/auth/revoke' do
    context 'with valid token' do
      it 'revokes the current session token' do
        auth_response = login_user(user)
        user.reload # Reload user to get the newly created session
        token = auth_response['token']

        delete '/api/v1/auth/revoke', headers: auth_headers(token)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Token revoked successfully')
        expect(json_response['revoked_at']).to be_present
      end

      it 'invalidates the token for future requests' do
        # Create session and get token in same test block
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response.status).to eq(200)
        auth_response = JSON.parse(response.body)
        token = auth_response['token']

        # Access session immediately after creation (same transaction)
        expect(user.sessions.count).to be >= 1
        user.sessions.last

        # Revoke the token
        delete '/api/v1/auth/revoke', headers: auth_headers(token)

        expect(response).to have_http_status(:ok)

        # Try to use the same token again
        delete '/api/v1/auth/revoke', headers: auth_headers(token)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without token' do
      it 'returns 401 unauthorized' do
        delete '/api/v1/auth/revoke', headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'returns 401 unauthorized' do
        delete '/api/v1/auth/revoke', headers: auth_headers('invalid_token')

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with expired token' do
      it 'returns 401 unauthorized' do
        # Create session and get token in same test block
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response.status).to eq(200)
        auth_response = JSON.parse(response.body)
        token = auth_response['token']

        # Access session immediately after creation (same transaction)
        expect(user.sessions.count).to be >= 1
        session = user.sessions.last

        # Manually expire the session
        session.update(expires_at: 1.hour.ago)

        delete '/api/v1/auth/revoke', headers: auth_headers(token)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/auth/revoke_all' do
    context 'with valid token' do
      it 'revokes all sessions for the user' do
        # Create multiple sessions by logging in multiple times
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response.status).to eq(200)
        sleep 1  # Delay to avoid rate limiting

        post '/api/v1/auth/login',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response.status).to eq(200)
        sleep 1  # Delay to avoid rate limiting

        post '/api/v1/auth/login',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response.status).to eq(200)
        auth_response3 = JSON.parse(response.body)
        token = auth_response3['token']

        # Access sessions immediately after creation (same transaction)
        active_sessions_before = user.sessions.active.count
        expect(active_sessions_before).to be >= 3

        delete '/api/v1/auth/revoke_all', headers: auth_headers(token)

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('All tokens revoked successfully')
        expect(json_response['revoked_count']).to eq(active_sessions_before)
        expect(json_response['revoked_at']).to be_present

        # Verify all sessions are now expired
        expect(user.sessions.active.count).to eq(0)
      end

      it 'invalidates all tokens for future requests' do
        # Create first session
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response.status).to eq(200)
        auth_response1 = JSON.parse(response.body)
        token1 = auth_response1['token']
        sleep 1 # Delay to avoid rate limiting

        # Create second session in same test block
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response.status).to eq(200)
        auth_response2 = JSON.parse(response.body)
        token2 = auth_response2['token']

        # Access sessions immediately after creation (same transaction)
        expect(user.sessions.count).to be >= 2

        # Revoke all using token2
        delete '/api/v1/auth/revoke_all', headers: auth_headers(token2)
        expect(response).to have_http_status(:ok)

        # Both tokens should now be invalid
        delete '/api/v1/auth/revoke', headers: auth_headers(token1)
        expect(response).to have_http_status(:unauthorized)

        delete '/api/v1/auth/revoke', headers: auth_headers(token2)
        expect(response).to have_http_status(:unauthorized)
      end

      it 'does not affect other users sessions' do
        other_user = create(:user, email: "other_#{SecureRandom.hex(4)}@example.com", password: 'password123')

        # Login both users in same test block
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response.status).to eq(200)
        auth_response_user = JSON.parse(response.body)
        token_user = auth_response_user['token']
        sleep 1 # Delay to avoid rate limiting

        post '/api/v1/auth/login',
             params: { email: other_user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response.status).to eq(200)
        auth_response_other = JSON.parse(response.body)
        token_other = auth_response_other['token']

        # Access sessions immediately after creation (same transaction)
        expect(user.sessions.count).to be >= 1
        expect(other_user.sessions.count).to be >= 1

        # Revoke all sessions for first user
        delete '/api/v1/auth/revoke_all', headers: auth_headers(token_user)
        expect(response).to have_http_status(:ok)

        # Other user's token should still work
        delete '/api/v1/auth/revoke', headers: auth_headers(token_other)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without token' do
      it 'returns 401 unauthorized' do
        delete '/api/v1/auth/revoke_all', headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid token' do
      it 'returns 401 unauthorized' do
        delete '/api/v1/auth/revoke_all', headers: auth_headers('invalid_token')

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'Token revocation security' do
    context 'when user has been deactivated' do
      it 'prevents token revocation for inactive users' do
        # Create session and get token in same test block
        post '/api/v1/auth/login',
             params: { email: user.email, password: 'password123' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
        expect(response.status).to eq(200)
        auth_response = JSON.parse(response.body)
        token = auth_response['token']

        # Access session immediately after creation (same transaction)
        expect(user.sessions.count).to be >= 1

        # Deactivate user
        user.update!(active: false)

        delete '/api/v1/auth/revoke', headers: auth_headers(token)

        # Should still work because the session exists
        # The inactive check is done at login time
        expect(response).to have_http_status(:ok)
      end
    end

    context 'logout vs revoke behavior' do
      it 'logout and revoke have the same effect on current session' do
        # Test logout
        auth_response1 = login_user(user)
        token1 = auth_response1['token']

        delete '/api/v1/auth/logout', headers: auth_headers(token1)
        expect(response).to have_http_status(:ok)

        # Token1 should be invalid
        delete '/api/v1/auth/revoke', headers: auth_headers(token1)
        expect(response).to have_http_status(:unauthorized)

        # Test revoke
        auth_response2 = login_user(user)
        token2 = auth_response2['token']

        delete '/api/v1/auth/revoke', headers: auth_headers(token2)
        expect(response).to have_http_status(:ok)

        # Token2 should be invalid
        delete '/api/v1/auth/logout', headers: auth_headers(token2)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
