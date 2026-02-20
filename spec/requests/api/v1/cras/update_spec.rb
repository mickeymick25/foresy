# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'CRAs - Update', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }

  let(:company) { create(:company) }
  let(:mission) { create(:mission, :time_based, created_by_user_id: user.id) }

  let!(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft') }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')

    # NOTE: CRA factory auto-creates user_cra when created_by_user_id is set
    # So the CRA should be accessible via user_cras

    # Stub RateLimitService
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  path '/api/v1/cras/{id}' do
    patch 'Updates a CRA' do
      tags 'CRAs'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'CRA ID (UUID)'
      parameter name: :cra_params, in: :body, schema: {
        type: :object,
        properties: {
          month: { type: :integer, description: 'Month (1-12)' },
          year: { type: :integer, description: 'Year (e.g., 2026)' },
          currency: { type: :string, description: 'Currency code (e.g., EUR)' },
          description: { type: :string, description: 'CRA description' },
          status: { type: :string, description: 'CRA status (draft, submitted, locked)' }
        }
      }

      response '200', 'CRA updated successfully' do
        let(:id) { cra.id }
        let(:cra_params) do
          {
            month: 2,
            year: 2026,
            currency: 'EUR',
            description: 'Updated CRA for February',
            status: 'draft'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:ok)

          data = JSON.parse(response.body)
          expect(data['month']).to eq(2)
          expect(data['year']).to eq(2026)
          expect(data['status']).to eq('draft')
        end
      end

      response '401', 'unauthorized - missing token' do
        let(:Authorization) { '' }
        let(:id) { cra.id }
        let(:cra_params) { { month: 2 } }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '401', 'unauthorized - invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:id) { cra.id }
        let(:cra_params) { { month: 2 } }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '404', 'CRA not found' do
        let(:id) { 'non-existent-id' }
        let(:cra_params) { { month: 2 } }

        run_test! do |response|
          expect(response).to have_http_status(:not_found)
        end
      end

      response '422', 'unprocessable entity - validation failed' do
        let(:id) { cra.id }
        let(:cra_params) { { month: 13 } }

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      response '409', 'conflict - CRA is locked or submitted' do
        let(:locked_cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 2, status: 'locked') }
        let(:id) { locked_cra.id }
        let(:cra_params) { { status: 'locked' } }

        run_test! do |response|
          expect(response).to have_http_status(:conflict)
        end
      end
    end
  end
end
