# frozen_string_literal: true

require 'swagger_helper'

# Request specs for UserCompany API — FC-08 v3.2.3 (§37, §43-44, §55)
#
# Covers: list own relationships, add role to existing company (Scenario 5),
# duplicate role (Scenario 6), invalid role, role-only update (§37.3),
# soft deletion, authentication and cross-user authorization (§43)
#
# @see docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]
#
RSpec.describe 'API V1 UserCompanies', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }
  let(:other_user) { create(:user) }
  let(:company) { create(:company) }

  before do
    # Rate limiting stubbed for API contract testing (house pattern)
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  # ============================================================
  # GET /api/v1/user_companies — §37.1
  # ============================================================
  path '/api/v1/user_companies' do
    get 'Lists relationships belonging to the authenticated user' do
      tags 'UserCompanies'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'returns only the authenticated user active relationships' do
        before do
          @own_active = create(:user_company, user: user, company: company, role: 'independent')
          @own_deleted = create(:user_company, user: user, company: create(:company), role: 'client')
          @own_deleted.discard

          # Relationship of another user must not leak
          create(:user_company, user: other_user, company: create(:company), role: 'independent')
        end

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          ids = data['data'].map { |r| r['id'] }
          expect(ids).to contain_exactly(@own_active.id)
          expect(data['meta']['total']).to eq(1)
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
    # POST /api/v1/user_companies — §37.2
    # ==========================================================
    post 'Adds a new role to an existing company' do
      tags 'UserCompanies'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :user_company_params, in: :body, required: true

      response '201', 'adds a client role to an existing company (Scenario 5)' do
        before { create(:user_company, user: user, company: company, role: 'independent') }

        let(:user_company_params) do
          { company_id: company.id, role: 'client' }
        end

        run_test! do |response|
          expect(response).to have_http_status(:created)
          data = JSON.parse(response.body)
          expect(data['id']).to be_present
          expect(data['role']).to eq('client')
          expect(UserCompany.for_user(user).for_company(company).count).to eq(2)
        end
      end

      response '422', 'rejects duplicate identical role (Scenario 6, INV-18)' do
        before { create(:user_company, user: user, company: company, role: 'independent') }

        let(:user_company_params) do
          { company_id: company.id, role: 'independent' }
        end

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
          expect(UserCompany.for_user(user).for_company(company).count).to eq(1)
        end
      end

      response '422', 'rejects invalid role' do
        let(:user_company_params) do
          { company_id: company.id, role: 'unsupported_role' }
        end

        run_test! do |response|
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      response '201', 'ignores user_id and creates the relationship for the authenticated user (§42)' do
        let(:user_company_params) do
          { company_id: company.id, role: 'independent', user_id: other_user.id }
        end

        run_test! do |response|
          expect(response).to have_http_status(:created)
          relationship = UserCompany.find(JSON.parse(response.body)['id'])
          expect(relationship.user_id).to eq(user.id)
          expect(relationship.user_id).not_to eq(other_user.id)
        end
      end

      response '401', 'unauthorized - missing token' do
        let(:Authorization) { '' }
        let(:user_company_params) { { company_id: company.id, role: 'independent' } }

        run_test! do |response|
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  # ============================================================
  # /api/v1/user_companies/:id — §37.3-37.4, §43
  # ============================================================
  path '/api/v1/user_companies/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid, required: true

    let(:relationship) { create(:user_company, user: user, company: company, role: 'independent') }

    get 'Returns a relationship belonging to the authenticated user' do
      tags 'UserCompanies'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'returns the relationship for its owner' do
        let(:id) { relationship.id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data['id']).to eq(relationship.id)
          expect(data['role']).to eq('independent')
        end
      end

      response '403', 'rejects cross-user access (§43)' do
        let(:id) { relationship.id }
        let(:Authorization) { "Bearer #{AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token]}" }

        run_test! do |response|
          expect(response).to have_http_status(:forbidden)
          data = JSON.parse(response.body)
          expect(data['code']).to eq('FORBIDDEN')
        end
      end
    end

    patch 'Updates the role only (§37.3)' do
      tags 'UserCompanies'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :user_company_params, in: :body, required: true

      response '200', 'updates the role and ignores protected attributes' do
        let(:id) { relationship.id }
        let(:other_company) { create(:company) }
        let(:user_company_params) do
          {
            role: 'client',
            user_id: other_user.id,
            company_id: other_company.id,
            deleted_at: Time.current.iso8601
          }
        end

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          relationship.reload
          expect(relationship.role).to eq('client')
          expect(relationship.user_id).to eq(user.id)
          expect(relationship.company_id).to eq(company.id)
          expect(relationship.deleted_at).to be_nil
        end
      end

      response '403', 'rejects cross-user update (§43)' do
        let(:id) { relationship.id }
        let(:Authorization) { "Bearer #{AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token]}" }
        let(:user_company_params) { { role: 'client' } }

        run_test! do |response|
          expect(response).to have_http_status(:forbidden)
          expect(relationship.reload.role).to eq('independent')
        end
      end
    end

    delete 'Soft-deletes the relationship (§37.4)' do
      tags 'UserCompanies'
      produces 'application/json'
      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'soft-deletes the relationship' do
        let(:id) { relationship.id }

        run_test! do |response|
          expect(response).to have_http_status(:ok)
          relationship.reload
          expect(relationship.deleted_at).to be_present
          expect(UserCompany.exists?(relationship.id)).to be true
        end
      end

      response '403', 'rejects cross-user deletion (§43)' do
        let(:id) { relationship.id }
        let(:Authorization) { "Bearer #{AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token]}" }

        run_test! do |response|
          expect(response).to have_http_status(:forbidden)
          expect(relationship.reload.deleted_at).to be_nil
        end
      end
    end
  end
end
