# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'CRAs - Delete', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }

  let(:company) { create(:company) }
  let(:mission) { create(:mission, :time_based, created_by_user_id: user.id) }

  let!(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft') }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')

    # Stub RateLimitService
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  path '/api/v1/cras/{id}' do
    delete 'Deletes a CRA' do
      tags 'CRAs'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'CRA ID (UUID)'

      response '200', 'CRA deleted successfully' do
        let(:id) { cra.id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
        end
      end

      response '401', 'unauthorized - invalid token' do
        let(:id) { cra.id }
        let(:Authorization) { '' }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '404', 'CRA not found' do
        let(:id) { 'invalid-uuid' }

        run_test! do |response|
          expect(response).to have_http_status(:not_found)
        end
      end

      response '409', 'conflict - CRA is locked or submitted' do
        let(:id) { cra.id }

        before do
          cra.update!(status: 'locked', locked_at: Time.current)
        end

        run_test! do |response|
          expect(response).to have_http_status(:conflict)
        end
      end
    end
  end
end
