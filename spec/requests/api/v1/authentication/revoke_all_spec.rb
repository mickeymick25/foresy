# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Authentication - Revoke All', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }

  before do
    # Stub RateLimitService
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  path '/api/v1/auth/revoke_all' do
    delete 'Revoke all session tokens for current user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      security [bearerAuth: []]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'

      response '200', 'All tokens revoked successfully' do
        let(:Authorization) { "Bearer #{user_token}" }

        run_test! do |response|
          expect(response).to have_http_status(:ok)

          data = JSON.parse(response.body)
          expect(data['message']).to include('revoked')
          expect(data['revoked_count']).to be >= 1
        end
      end

      response '401', 'unauthorized - missing token' do
        let(:Authorization) { '' }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '401', 'unauthorized - invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '401', 'unauthorized - no active session' do
        let(:user_without_session) { create(:user) }
        let(:user_token_without_session) { 'expired_or_invalid_token' }
        let(:Authorization) { "Bearer #{user_token_without_session}" }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end
end
