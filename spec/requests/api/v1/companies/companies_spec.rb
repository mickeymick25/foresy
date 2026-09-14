# frozen_string_literal: true

require 'swagger_helper'

# Request specs for Company API — FC-08 v3.2.3 (§36, §38-44, §55)
#
# Covers Gherkin scenarios: 1 (no company), 2-4 (creation independent/client/multiple),
# 8-11 (invalid/duplicate SIREN, absent/duplicate SIRET), 12 (atomicity),
# 13 (unauthorized access), 14 (soft delete), 15 (flat JSON)
#
# @see docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]
#
RSpec.describe 'API V1 Companies', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }
  let(:other_user) { create(:user) }

  before do
    # Rate limiting stubbed for API contract testing (house pattern)
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  # ============================================================
  # GET /api/v1/companies — §36.1
  # ============================================================
  path '/api/v1/companies' do
    get 'Lists companies accessible to the authenticated user' do
      tags 'Companies'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'returns an empty collection when user has no company (Scenario 1)' do
        let(:Authorization) { "Bearer #{AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token]}" }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data['data']).to eq([])
          expect(data['meta']['total']).to eq(0)
        end
      end

      response '200', 'returns only companies with active relationships' do
        before do
          @company_a = create(:company)
          create(:user_company, user: user, company: @company_a, role: 'independent')

          @company_b = create(:company)
          create(:user_company, user: user, company: @company_b, role: 'client')

          # Company of another user must not leak
          create(:user_company, user: other_user, company: create(:company), role: 'independent')

          # Soft-deleted relationship must be excluded (§31 — explicit active scope)
          create(:user_company, user: user, company: create(:company), role: 'independent').discard
        end

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          ids = data['data'].map { |c| c['id'] }
          expect(ids).to contain_exactly(@company_a.id, @company_b.id)
          expect(data['meta']['total']).to eq(2)
        end
      end

      response '401', 'unauthorized - missing token' do
        let(:Authorization) { '' }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    # ==========================================================
    # POST /api/v1/companies — §36.2, §38 (atomic onboarding)
    # ==========================================================
    post 'Creates a company with its initial UserCompany relationship (atomic)' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :company_params, in: :body, required: true

      response '201', 'creates Company + independent UserCompany (Scenario 2)' do
        let(:company_params) do
          {
            company: {
              name: 'Example Consulting',
              siren: '123456789',
              siret: '12345678900012',
              legal_form: 'EI',
              country: 'FR',
              currency: 'EUR',
              vat_regime: 'franchise'
            },
            role: 'independent'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:created)
          data = JSON.parse(response.body)
          expect(data['id']).to be_present
          expect(data['name']).to eq('Example Consulting')
          expect(data['siren']).to eq('123456789')
          expect(data['vat_regime']).to eq('franchise')

          company = Company.find(data['id'])
          relationship = UserCompany.find_by(company: company)
          expect(relationship.user_id).to eq(user.id)
          expect(relationship.role).to eq('independent')
        end
      end

      response '201', 'creates Company + client UserCompany (Scenario 3)' do
        let(:company_params) do
          {
            company: { name: 'Client Corp', siren: '987654321' },
            role: 'client'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:created)
          company = Company.find(JSON.parse(response.body)['id'])
          expect(UserCompany.find_by(company: company).role).to eq('client')
        end
      end

      response '201', 'creates Company without SIRET (Scenario 10)' do
        let(:company_params) do
          {
            company: { name: 'No Siret Corp', siren: '111222333' },
            role: 'independent'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:created)
          company = Company.find(JSON.parse(response.body)['id'])
          expect(company.siret).to be_nil
        end
      end

      response '201', 'processes flat JSON payload (Scenario 15, §41)' do
        let(:company_params) do
          {
            name: 'Flat Corp',
            siren: '222333444',
            role: 'independent'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:created)
          company = Company.find(JSON.parse(response.body)['id'])
          expect(company.name).to eq('Flat Corp')
          expect(UserCompany.find_by(company: company).role).to eq('independent')
        end
      end

      response '422', 'rejects invalid SIREN and persists nothing (Scenario 8, INV-08)' do
        let(:company_params) do
          {
            company: { name: 'Bad Siren', siren: '12345' },
            role: 'independent'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
          expect(Company.count).to eq(0)
          expect(UserCompany.count).to eq(0)
        end
      end

      response '422', 'rejects duplicate SIREN (Scenario 9, INV-09)' do
        before { create(:company, siren: '123456789') }

        let(:company_params) do
          {
            company: { name: 'Duplicate Siren', siren: '123456789' },
            role: 'independent'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
          expect(Company.count).to eq(1)
        end
      end

      response '422', 'rejects duplicate SIRET (Scenario 11, INV-12)' do
        before { create(:company, siret: '12345678900012') }

        let(:company_params) do
          {
            company: { name: 'Duplicate Siret', siren: '444555666', siret: '12345678900012' },
            role: 'independent'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
          expect(Company.count).to eq(1)
        end
      end

      response '422', 'rolls back everything when relationship creation fails (Scenario 12, INV-16/17)' do
        let(:company_params) do
          {
            company: { name: 'Atomic Corp', siren: '333444555' },
            role: 'unsupported_role'
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
          expect(Company.count).to eq(0)
          expect(UserCompany.count).to eq(0)
        end
      end

      response '401', 'unauthorized - missing token' do
        let(:Authorization) { '' }
        let(:company_params) { { company: { name: 'X', siren: '123456789' }, role: 'independent' } }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  # ============================================================
  # /api/v1/companies/:id — §36.3-36.5, §43
  # ============================================================
  path '/api/v1/companies/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true

    let(:company) { create(:company) }

    before do
      create(:user_company, user: user, company: company, role: 'independent')
    end

    get 'Returns a company accessible to the authenticated user' do
      tags 'Companies'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'returns the company for an authorized user' do
        let(:id) { company.id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data['id']).to eq(company.id)
          expect(data['name']).to eq(company.name)
        end
      end

      response '403', 'rejects cross-user access (Scenario 13, §43)' do
        let(:id) { company.id }
        let(:Authorization) { "Bearer #{AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token]}" }

        run_test! do |response|
          expect(response).to have_http_status(:forbidden)
          data = JSON.parse(response.body)
          expect(data['code']).to eq('FORBIDDEN')
        end
      end

      response '404', 'not found for unknown company' do
        let(:id) { SecureRandom.uuid }

        run_test! do |response|
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    patch 'Updates permitted company attributes' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :company_params, in: :body, required: true

      response '200', 'updates company attributes for an authorized user' do
        let(:id) { company.id }
        let(:company_params) do
          { company: { name: 'Updated Name', vat_regime: 'reelle_simplifiee' } }
        end

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          company.reload
          expect(company.name).to eq('Updated Name')
          expect(company.vat_regime).to eq('reelle_simplifiee')
        end
      end

      response '403', 'rejects cross-user update (§43)' do
        let(:id) { company.id }
        let(:Authorization) { "Bearer #{AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token]}" }
        let(:company_params) { { company: { name: 'Hacked Name' } } }

        run_test! do |response|
          expect(response).to have_http_status(:forbidden)
          expect(company.reload.name).not_to eq('Hacked Name')
        end
      end
    end

    delete 'Soft-deletes the company (§36.5, Scenario 14)' do
      tags 'Companies'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'soft-deletes the company' do
        let(:id) { company.id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          company.reload
          expect(company.deleted_at).to be_present
          expect(Company.exists?(company.id)).to be true
        end
      end

      response '403', 'rejects cross-user deletion (§43)' do
        let(:id) { company.id }
        let(:Authorization) { "Bearer #{AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token]}" }

        run_test! do |response|
          expect(response).to have_http_status(:forbidden)
          expect(company.reload.deleted_at).to be_nil
        end
      end
    end
  end
end
