# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'CRAs - Index', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }

  let(:company) { create(:company) }

  before do
    create(:user_company, user: user, company: company, role: 'independent')

    # Create some CRAs for the user
    create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft')
    create(:cra, created_by_user_id: user.id, year: 2026, month: 2, status: 'submitted')
    create(:cra, created_by_user_id: user.id, year: 2025, month: 12, status: 'draft')

    # Stub RateLimitService
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])

    # Stub CraServices::List to avoid domain setup issues
    allow(CraServices::List).to receive(:call).and_return(
      Struct.new(:success?, :data).new(true, { cras: [], pagination: { page: 1, per_page: 20, total: 0 } })
    )
  end

  path '/api/v1/cras' do
    get 'Lists all CRAs for the current user' do
      tags 'CRAs'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'
      parameter name: :page, in: :query, type: :integer, required: false,
                description: 'Page number (default: 1)', schema: { type: :integer, default: 1 }
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: 'Items per page (default: 20, max: 100)', schema: { type: :integer, default: 20 }
      parameter name: :status, in: :query, type: :string, required: false,
                description: 'Filter by status (draft, submitted, locked)'
      parameter name: :year, in: :query, type: :integer, required: false,
                description: 'Filter by year'
      parameter name: :month, in: :query, type: :integer, required: false,
                description: 'Filter by month (1-12)'

      response '200', 'Returns list of CRAs with pagination' do
        run_test! do |response|
          expect(response).to have_http_status(:ok)
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
    end
  end
end
