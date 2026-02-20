# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'CRAs - Create', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }

  let(:company) { create(:company) }
  let(:mission) { create(:mission, :time_based, created_by_user_id: user.id) }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')

    # Stub RateLimitService
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  path '/api/v1/cras' do
    post 'Creates a new CRA' do
      tags 'CRAs'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'

      parameter name: :cra, in: :body, schema: {
        type: :object,
        properties: {
          month: { type: :integer, description: 'Month (1-12)', example: 1 },
          year: { type: :integer, description: 'Year (e.g., 2026)', example: 2026 },
          currency: { type: :string, description: 'Currency code (e.g., EUR)', example: 'EUR', nullable: true },
          description: { type: :string, description: 'CRA description', nullable: true },
          status: { type: :string, description: 'CRA status (draft, submitted)', example: 'draft', nullable: true }
        },
        required: %w[month year]
      }

      response '201', 'CRA created successfully' do
        let(:cra) do
          {
            month: 1,
            year: 2026,
            currency: 'EUR',
            description: 'CRA for January 2026',
            status: 'draft'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:created)

          data = JSON.parse(response.body)
          expect(data['id']).to be_present
          expect(data['month']).to eq(1)
          expect(data['year']).to eq(2026)
          expect(data['status']).to eq('draft')
        end
      end

      response '401', 'unauthorized - missing token' do
        let(:Authorization) { '' }
        let(:cra) { { month: 1, year: 2026 } }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '401', 'unauthorized - invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:cra) { { month: 1, year: 2026 } }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '422', 'unprocessable entity - missing required fields' do
        let(:cra) { { month: 1 } }

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      response '422', 'unprocessable entity - invalid month' do
        let(:cra) { { month: 13, year: 2026 } }

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end
end
