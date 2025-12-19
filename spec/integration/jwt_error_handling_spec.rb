# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JWT Error Handling Integration', type: :request do
  let(:user) { create(:user) }

  describe 'POST /api/v1/auth/refresh' do
    it 'handles malformed token' do
      expect(Rails.logger).to receive(:warn).at_least(:once)

      post '/api/v1/auth/refresh',
           params: { refresh_token: 'invalid.token' },
           headers: { 'REMOTE_ADDR' => '127.0.0.1' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'handles empty token' do
      # Empty token is detected early by controller, no JWT logging expected
      post '/api/v1/auth/refresh',
           params: { refresh_token: '' },
           headers: { 'REMOTE_ADDR' => '127.0.0.1' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'handles expired token' do
      expired_payload = { user_id: user.id, refresh_exp: Time.now.to_i - 3600 }
      expired_token = JWT.encode(expired_payload, Rails.application.secret_key_base)

      expect(Rails.logger).to receive(:warn).at_least(:once)

      post '/api/v1/auth/refresh',
           params: { refresh_token: expired_token },
           headers: { 'REMOTE_ADDR' => '127.0.0.1' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'handles valid token successfully' do
      user.create_session(ip_address: '127.0.0.1', user_agent: 'Test Agent')

      valid_payload = {
        user_id: user.id,
        refresh_exp: 30.days.from_now.to_i
      }
      valid_token = JWT.encode(valid_payload, Rails.application.secret_key_base)

      expect(Rails.logger).to receive(:info).at_least(:once)

      post '/api/v1/auth/refresh',
           params: { refresh_token: valid_token },
           headers: { 'REMOTE_ADDR' => '127.0.0.1' }

      expect(response).to have_http_status(:success)
    end

    it 'handles multiple invalid requests' do
      responses = []

      3.times do |i|
        # Each test should expect its own logging call
        post '/api/v1/auth/refresh',
             params: { refresh_token: 'invalid.token' },
             headers: { 'REMOTE_ADDR' => "127.0.0.#{i}" }

        responses << response.status
      end

      expect(responses.all? { |status| status == 401 }).to be true
    end

    it 'handles unicode in token gracefully' do
      expect(Rails.logger).to receive(:warn).at_least(:once)

      post '/api/v1/auth/refresh',
           params: { refresh_token: 'tökén.with.ünïcödé.🚀' },
           headers: { 'REMOTE_ADDR' => '127.0.0.1' }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
