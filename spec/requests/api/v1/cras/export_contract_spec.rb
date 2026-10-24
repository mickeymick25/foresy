# frozen_string_literal: true

require 'swagger_helper'

# BACKLOG #17 (audit S-1) — le path export CSV était absent du contrat OpenAPI et exclu de l'audit CI
# via EXCLUDED_ENDPOINTS. Le path est désormais documenté (200 text/csv + codes d'erreur FC-07 réels)
# et l'exclusion correspondante est retirée de lib/tasks/swagger_audit.rake.
# NB : le spec fonctionnel existant (cette fonction, spec/requests/api/v1/cras/export_spec.rb) est conservé
# tel quel — le présent fichier ajoute UNIQUEMENT la documentation contrat OpenAPI (pattern rswag).
RSpec.describe 'CRAs - Export CSV (contrat OpenAPI)', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }

  let(:cra) { create(:cra, :with_creator, creator: user, year: 2026, month: 1, status: 'submitted') }

  before do
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  path '/api/v1/cras/{id}/export' do
    get 'Exports a CRA as CSV' do
      tags 'CRAs'
      consumes 'application/json'
      produces 'text/csv'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'CRA ID (UUID)'
      parameter name: :include_entries, in: :query, type: :string, required: false,
                description: "Include CRA entries in the CSV ('false' to exclude)"

      response '200', 'CSV exported successfully' do
        let(:id) { cra.id }

        before do
          entry = create(:cra_entry, quantity: 1, unit_price: 50_000, description: 'Probe work')
          create(:cra_entry_cra, cra: cra, cra_entry: entry)
        end

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          expect(response.content_type.split(';').first).to eq('text/csv')

          csv_body = response.body
          expect(csv_body).to include('date')
          expect(csv_body).to include('mission_name')
          expect(csv_body).to include('Probe work')

          expect(response.headers['Content-Disposition']).to include('attachment')
          expect(response.headers['Content-Disposition']).to include('cra_2026_01.csv')
        end
      end

      response '401', 'unauthorized - invalid token' do
        let(:id) { cra.id }
        let(:Authorization) { '' }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '403', 'forbidden - user is not the CRA creator' do
        let(:other_user) { create(:user) }
        let(:other_token) { AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token] }
        let(:id) { cra.id }
        let(:Authorization) { "Bearer #{other_token}" }

        run_test! do |response|
          expect(response).to have_http_status(:forbidden)
        end
      end

      response '404', 'CRA not found' do
        let(:id) { 'invalid-uuid' }

        run_test! do |response|
          expect(response).to have_http_status(:not_found)
        end
      end

      response '409', 'conflict - CRA in draft status (not exportable)' do
        let(:cra_draft) { create(:cra, :with_creator, creator: user, year: 2026, month: 2, status: 'draft') }
        let(:id) { cra_draft.id }

        run_test! do |response|
          expect(response).to have_http_status(:conflict)
        end
      end
    end
  end
end
