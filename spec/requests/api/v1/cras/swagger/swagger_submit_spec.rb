# frozen_string_literal: true

require 'swagger_helper'

# =============================================================================
# RSWAG CANONICAL SPEC — AUTHENTICATED ENDPOINT
#
# This spec is the reference template for:
# - JWT authentication via real login (authenticate(user))
# - RSwag header handling (let(:Authorization))
# - Error handling alignment with backend behavior
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
    create(
      :user,
      email: "cra_submit_#{SecureRandom.hex(4)}@example.com",
      password: 'password123'
    )
  end

  # Canonical auth pattern: let(:Authorization) + authenticate(user)
  let(:Authorization) { "Bearer #{authenticate(user)}" }

  # Data setup minimal - clear and explicit (not over-architected)
  let(:draft_cra_id) do
    mission = create(:mission, created_by_user_id: user.id)
    cra = create(:cra, user: user, status: 'draft')

    entry = create(:cra_entry, :standard_entry)
    create(:cra_entry_mission, cra_entry: entry, mission: mission)
    create(:cra_entry_cra, cra_entry: entry, cra: cra)

    cra.id
  end

  path '/api/v1/cras/{id}/submit' do
    post 'Submit a CRA' do
      tags 'CRA'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string,
                description: 'Bearer token', required: true
      parameter name: :id, in: :path, schema: {
        type: :string,
        format: :uuid,
        example: '550e8400-e29b-41d4-a716-446655440000'
      }, required: true, description: 'CRA ID'

      response '200', 'CRA submitted successfully' do
        let(:id) { draft_cra_id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data).to include('id', 'year', 'month', 'status', 'currency')
          expect(data['status']).to eq('submitted')
          expect(data).to include('total_days', 'total_amount')
        end
      end

      response '401', 'Unauthorized - Missing token' do
        let(:Authorization) { '' }  # Override shared_context to test missing auth
        let(:id) { draft_cra_id }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end

      response '401', 'Unauthorized - Invalid token' do
        let(:Authorization) { "Bearer #{invalid_jwt_token}" }
        let(:id) { draft_cra_id }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end

      response '401', 'Unauthorized - Malformed token' do
        let(:Authorization) { "Bearer #{malformed_jwt_token}" }
        let(:id) { draft_cra_id }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end

      response '422', 'CRA without entries' do
        let(:id) { create(:cra, user: user, status: 'draft').id }

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('invalid_payload')
          expect(body).to include('message')
        end
      end
    end
  end
end
