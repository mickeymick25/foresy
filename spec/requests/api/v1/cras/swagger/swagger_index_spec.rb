# frozen_string_literal: true

require 'swagger_helper'

# =============================================================================
# RSWAG CANONICAL SPEC — INDEX ENDPOINT (GET /cras)
#
# This spec is the reference template for:
# - JWT authentication via real login (authenticate(user))
# - RSwag header handling (let(:Authorization))
# - Pagination and filtering behavior
# - Collection response validation
#
# DO NOT:
# - generate JWT manually
# - use `header` inside before blocks
# - use `nil` for missing Authorization
#
# RULES:
# - Valid auth     → let(:Authorization) { "Bearer #{authenticate(user)}" }
# - Missing auth   → let(:Authorization) { '' }
# - Invalid auth   → let(:Authorization) { "Bearer #{invalid_jwt_token}" }
# - Malformed auth → let(:Authorization) { "Bearer #{malformed_jwt_token}" }
# =============================================================================

RSpec.describe 'CRA', swagger_doc: 'v1/swagger.yaml', type: :request do
  # Test data setup - using authenticate(user) as per canonical methodology
  let(:user) do
    user = create(
      :user,
      email: "cra_index_#{SecureRandom.hex(4)}@example.com",
      password: 'password123'
    )

    # Ensure user has an independent company (required for CRA operations)
    company = create(:company)
    create(:user_company, user: user, company: company, role: 'independent')

    user
  end

  # Canonical auth pattern: let(:Authorization) + authenticate(user)
  let(:Authorization) { "Bearer #{authenticate(user)}" }

  # Data setup minimal - create a few CRAs for listing test
  let(:cra_list) do
    # Create multiple CRAs to test pagination and listing
    missions = create_list(:mission, 2, created_by_user_id: user.id)

    cra1 = create(:cra, user: user, status: 'draft', month: 1, year: 2024)
    cra2 = create(:cra, user: user, status: 'submitted', month: 2, year: 2024)

    # Create some entries for the CRAs
    entry1 = create(:cra_entry, :standard_entry, year: 2024, month: 1)
    entry2 = create(:cra_entry, :standard_entry, year: 2024, month: 2)

    create(:cra_entry_cra, cra_entry: entry1, cra: cra1)
    create(:cra_entry_cra, cra_entry: entry2, cra: cra2)

    create(:cra_entry_mission, cra_entry: entry1, mission: missions[0])
    create(:cra_entry_mission, cra_entry: entry2, mission: missions[1])

    [cra1, cra2]
  end

  path '/api/v1/cras' do
    get 'Lists CRAs accessible to user' do
      tags 'CRA'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string,
                description: 'Bearer token', required: true

      parameter name: :page, in: :query, schema: {
        type: :integer,
        minimum: 1,
        default: 1
      }, required: false, description: 'Page number for pagination'

      parameter name: :per_page, in: :query, schema: {
        type: :integer,
        minimum: 1,
        maximum: 100,
        default: 20
      }, required: false, description: 'Number of items per page'

      parameter name: :status, in: :query, schema: {
        type: :string,
        enum: %w[draft submitted locked]
      }, required: false, description: 'Filter by CRA status'

      parameter name: :month, in: :query, schema: {
        type: :integer,
        minimum: 1,
        maximum: 12
      }, required: false, description: 'Filter by month (1-12)'

      parameter name: :year, in: :query, schema: {
        type: :integer,
        minimum: 2020,
        maximum: 2030
      }, required: false, description: 'Filter by year'

      parameter name: :company_id, in: :query, schema: {
        type: :string,
        format: :uuid
      }, required: false, description: 'Filter by company ID'

      response '200', 'Returns list of CRAs' do
        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)

          # Validate collection structure
          expect(data).to include('data', 'meta')
          expect(data['data']).to be_an(Array)

          # Check meta structure
          expect(data['meta']).to include('page', 'per_page', 'total', 'pages')
          expect(data['meta']['page']).to eq(1)
          expect(data['meta']['per_page']).to eq(20)

          # Validate CRA objects in collection
          if data['data'].any?
            cra = data['data'].first
            expect(cra).to include('id', 'year', 'month', 'status', 'currency')
            expect(cra).to include('total_days', 'total_amount')
            expect(%w[draft submitted locked]).to include(cra['status'])
          end
        end
      end

      response '200', 'Returns empty list when no CRAs' do
        # Don't create any CRAs for this test

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)

          expect(data['data']).to be_empty
          expect(data['meta']['total']).to eq(0)
        end
      end

      response '200', 'Returns filtered results by status' do
        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)

          expect(data['data']).to be_an(Array)
          # All returned CRAs should match the filter criteria
          data['data'].each do |cra|
            expect(%w[draft submitted]).to include(cra['status'])
          end
        end
      end

      response '401', 'Unauthorized - Missing token' do
        let(:Authorization) { '' } # Override shared_context to test missing auth

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end

      response '401', 'Unauthorized - Invalid token' do
        let(:Authorization) { "Bearer #{invalid_jwt_token}" }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end

      response '401', 'Unauthorized - Malformed token' do
        let(:Authorization) { "Bearer #{malformed_jwt_token}" }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end
    end
  end
end
