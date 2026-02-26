# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'CRAs - Show', type: :request do
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
    get 'Shows a specific CRA with full details' do
      tags 'CRAs'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'CRA ID (UUID)'

      response '200', 'Returns CRA details with entries' do
        let(:id) { cra.id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)

          data = JSON.parse(response.body)
          expect(data['id']).to eq(cra.id)
          expect(data['month']).to eq(1)
          expect(data['year']).to eq(2026)
          expect(data['status']).to eq('draft')
          expect(data).to have_key('total_days')
          expect(data).to have_key('total_amount')
          expect(data).to have_key('currency')
          expect(data).to have_key('entries')
          expect(data['entries']).to be_an(Array)
        end
      end

      response '401', 'unauthorized - missing token' do
        let(:Authorization) { '' }
        let(:id) { cra.id }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '401', 'unauthorized - invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:id) { cra.id }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '404', 'CRA not found' do
        let(:id) { 'non-existent-id' }

        run_test! do |response|
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
