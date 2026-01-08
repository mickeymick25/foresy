# frozen_string_literal: true

require 'swagger_helper'

# =============================================================================
# RSWAG CANONICAL SPEC — CRA SHOW ENDPOINT
#
# This spec follows the canonical RSwag methodology:
# - JWT authentication via real login (authenticate(user))
# - RSwag header handling (let(:Authorization))
# - Error handling alignment with backend behavior
# - Minimal and explicit data setup
# - Full CRA details with entries validation
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
      email: "cra_show_#{SecureRandom.hex(4)}@example.com",
      password: 'password123'
    )

    # Ensure user has an independent company (required for CRA operations)
    company = create(:company)
    create(:user_company, user: user, company: company, role: 'independent')

    user
  end

  # Canonical auth pattern: let(:Authorization) + authenticate(user)
  let(:Authorization) { "Bearer #{authenticate(user)}" }

  # Data setup minimal - clear and explicit (not over-architected)
  # Create a CRA with entries for detailed testing
  let(:cra_with_entries_id) do
    mission = create(:mission, created_by_user_id: user.id)
    cra = create(:cra, user: user, status: 'draft', month: 1, year: 2024, currency: 'EUR')

    # Create entries for the CRA using date attribute instead of year/month
    entry = create(:cra_entry, :standard_entry, date: Date.new(2024, 1, 15))
    create(:cra_entry_mission, cra_entry: entry, mission: mission)
    create(:cra_entry_cra, cra_entry: entry, cra: cra)

    cra.id
  end

  # Create a second user to test access control
  let(:other_user) do
    other_user = create(
      :user,
      email: "other_user_#{SecureRandom.hex(4)}@example.com",
      password: 'password123'
    )

    # Ensure other user also has an independent company
    other_company = create(:company)
    create(:user_company, user: other_user, company: other_company, role: 'independent')

    other_user
  end

  path '/api/v1/cras/{id}' do
    get 'Show CRA details' do
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

      response '200', 'CRA found and returned with details' do
        let(:id) { cra_with_entries_id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)

          # Validate CRA structure
          expect(data).to include('id', 'year', 'month', 'status', 'currency')
          expect(data).to include('total_days', 'total_amount')
          expect(data).to include('entries')

          # Validate CRA basic info
          expect(data['year']).to eq(2024)
          expect(data['month']).to eq(1)
          expect(data['status']).to eq('draft')
          expect(data['currency']).to eq('EUR')

          # Validate entries structure - backend returns date, quantity, unit_price, line_total
          expect(data['entries']).to be_an(Array)

          if data['entries'].any?
            entry = data['entries'].first
            expect(entry).to include('id', 'date', 'quantity', 'unit_price')
            expect(entry).to include('description', 'line_total')
          end
        end
      end

      response '200', 'CRA found without entries' do
        # Create CRA without any entries
        let(:cra_without_entries_id) do
          create(:cra, user: user, status: 'draft').id
        end
        let(:id) { cra_without_entries_id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)

          expect(data).to include('id', 'year', 'month', 'status', 'currency')
          expect(data['entries']).to be_an(Array)
          expect(data['entries']).to be_empty
          # Backend returns total_days as string, adjust expectation
          expect(data['total_days']).to eq('0.0')
          expect(data['total_amount']).to eq(0)
        end
      end

      response '401', 'Unauthorized - Missing token' do
        let(:Authorization) { '' } # Override shared_context to test missing auth
        let(:id) { cra_with_entries_id }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end

      response '401', 'Unauthorized - Invalid token' do
        let(:Authorization) { "Bearer #{invalid_jwt_token}" }
        let(:id) { cra_with_entries_id }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end

      response '401', 'Unauthorized - Malformed token' do
        let(:Authorization) { "Bearer #{malformed_jwt_token}" }
        let(:id) { cra_with_entries_id }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
          data = JSON.parse(response.body)
          expect(data).to include('error')
        end
      end

      response '404', 'CRA not found' do
        let(:id) { '550e8400-e29b-41d4-a716-446655440000' } # Non-existent UUID

        run_test! do |response|
          expect(response).to have_http_status(:not_found)
          data = JSON.parse(response.body)
          expect(data).to include('error')
          expect(data['error']).to eq('not_found')
          expect(data).to include('message')
        end
      end

      response '403', 'CRA not accessible to user' do
        # Create CRA for another user
        let(:inaccessible_cra_id) do
          create(:cra, user: other_user, status: 'draft', month: 3, year: 2024).id
        end
        let(:id) { inaccessible_cra_id }

        run_test! do |response|
          expect(response).to have_http_status(:forbidden)
          data = JSON.parse(response.body)
          expect(data).to include('error')
          expect(data['error']).to eq('unauthorized')
          expect(data).to include('message')
        end
      end

      response '200', 'Submitted CRA with locked status' do
        # Create a submitted CRA
        let(:submitted_cra_id) do
          mission = create(:mission, created_by_user_id: user.id)
          cra = create(:cra, user: user, status: 'submitted', currency: 'EUR')

          entry = create(:cra_entry, :standard_entry, date: Date.new(2024, 4, 10))
          create(:cra_entry_mission, cra_entry: entry, mission: mission)
          create(:cra_entry_cra, cra_entry: entry, cra: cra)

          cra.id
        end
        let(:id) { submitted_cra_id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)

          expect(data['status']).to eq('submitted')
          expect(data).to include('entries')
          expect(data['entries']).to be_an(Array)
        end
      end

      response '200', 'Locked CRA (read-only access)' do
        # Create a locked CRA
        let(:locked_cra_id) do
          mission = create(:mission, created_by_user_id: user.id)
          cra = create(:cra, user: user, status: 'locked', currency: 'EUR')

          entry = create(:cra_entry, :standard_entry, date: Date.new(2024, 5, 20))
          create(:cra_entry_mission, cra_entry: entry, mission: mission)
          create(:cra_entry_cra, cra_entry: entry, cra: cra)

          cra.id
        end
        let(:id) { locked_cra_id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)

          expect(data['status']).to eq('locked')
          expect(data).to include('entries')
          expect(data['entries']).to be_an(Array)

          # Verify locked CRA still returns complete data
          expect(data).to include('total_days', 'total_amount')
        end
      end
    end
  end
end
