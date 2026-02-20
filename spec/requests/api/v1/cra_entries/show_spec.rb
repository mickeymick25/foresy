# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'CRA Entries - Show', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }

  let(:company) { create(:company) }
  let(:mission) { create(:mission, :time_based, created_by_user_id: user.id) }

  let!(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft') }
  let!(:cra_entry) { create(:cra_entry, date: Date.new(2026, 1, 15), quantity: 1.0, unit_price: 50_000, description: 'Development work') }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')
    create(:cra_entry_cra, cra: cra, cra_entry: cra_entry)
    create(:cra_entry_mission, cra_entry: cra_entry, mission: mission)

    # Stub RateLimitService
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  path '/api/v1/cras/{cra_id}/entries/{id}' do
    get 'Shows a specific CRA entry' do
      tags 'CRA Entries'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'
      parameter name: :cra_id, in: :path, type: :string, required: true,
                description: 'CRA ID (UUID)'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'CRA Entry ID (UUID)'

      response '200', 'Returns CRA entry details' do
        let(:cra_id) { cra.id }
        let(:id) { cra_entry.id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)

          data = JSON.parse(response.body)
          expect(data['id']).to eq(cra_entry.id)
          expect(data['date']).to eq('2026-01-15')
          expect(data['quantity']).to eq(1.0)
        end
      end

      response '401', 'unauthorized - invalid token' do
        let(:cra_id) { cra.id }
        let(:id) { cra_entry.id }
        let(:Authorization) { '' }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '404', 'CRA or entry not found' do
        let(:cra_id) { 'invalid-uuid' }
        let(:id) { cra_entry.id }

        run_test! do |response|
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
