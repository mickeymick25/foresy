# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'CRA Entries - Create', type: :request do
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

  path '/api/v1/cras/{cra_id}/entries' do
    post 'Creates a new CRA entry' do
      tags 'CRA Entries'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'
      parameter name: :cra_id, in: :path, type: :string, required: true,
                description: 'CRA ID (UUID)'
      parameter name: :entry, in: :body, schema: {
        type: :object,
        properties: {
          date: { type: :string, format: :date, description: 'Entry date' },
          quantity: { type: :number, description: 'Quantity (days or hours)' },
          unit_price: { type: :integer, description: 'Unit price in cents' },
          description: { type: :string, description: 'Entry description' },
          mission_id: { type: :string, format: :uuid, description: 'Mission ID (UUID)' }
        },
        required: %w[date quantity]
      }

      response '201', 'CRA entry created successfully' do
        let(:cra_id) { cra.id }
        let(:entry) do
          {
            date: '2026-01-15',
            quantity: 1.0,
            unit_price: 50_000,
            description: 'Development work on feature X',
            mission_id: mission.id
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:created)

          data = JSON.parse(response.body)
          expect(data['id']).to be_present
          expect(data['date']).to eq('2026-01-15')
          expect(data['quantity']).to eq(1.0)
        end
      end

      response '401', 'unauthorized - invalid token' do
        let(:cra_id) { cra.id }
        let(:entry) { { date: '2026-01-15', quantity: 1.0 } }
        let(:Authorization) { '' }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '404', 'CRA not found' do
        let(:cra_id) { 'invalid-uuid' }
        let(:entry) { { date: '2026-01-15', quantity: 1.0 } }

        run_test! do |response|
          expect(response).to have_http_status(:not_found)
        end
      end

      response '422', 'validation error' do
        let(:cra_id) { cra.id }
        let(:entry) do
          {
            date: 'invalid-date',
            quantity: 'not-a-number'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end
end
