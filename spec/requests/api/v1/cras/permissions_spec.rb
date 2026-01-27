# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CRA Permissions', type: :request do
  # User 1 - Owner of CRAs
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:headers) { { 'Authorization' => "Bearer #{user_token}" } }

  let(:company) { create(:company) }
  let(:mission) { create(:mission, :time_based, created_by_user_id: user.id) }

  # User 2 - Different user (should NOT have access)
  let(:other_user) { create(:user) }
  let(:other_user_token) { AuthenticationService.login(other_user, '127.0.0.1', 'Test Agent')[:token] }
  let(:other_headers) { { 'Authorization' => "Bearer #{other_user_token}" } }

  let(:other_company) { create(:company) }
  let(:other_mission) { create(:mission, :time_based, created_by_user_id: other_user.id) }

  before do
    # Setup user 1 associations
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')

    # Setup user 2 associations (separate company)
    create(:user_company, user: other_user, company: other_company, role: 'independent')
    create(:mission_company, mission: other_mission, company: other_company, role: 'independent')
  end

  # ===========================================
  # GET /api/v1/cras/:id - Show
  # ===========================================
  describe 'GET /api/v1/cras/:id' do
    let!(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1) }

    context 'when user owns the CRA' do
      it 'returns 200 OK' do
        get "/api/v1/cras/#{cra.id}", headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when another user tries to access' do
      it 'returns 403 forbidden' do
        get "/api/v1/cras/#{cra.id}", headers: other_headers

        expect(response).to have_http_status(:forbidden)
      end

      it 'returns appropriate error message' do
        get "/api/v1/cras/#{cra.id}", headers: other_headers

        json = JSON.parse(response.body)
        expect(json['error']).to eq('unauthorized')
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        get "/api/v1/cras/#{cra.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================
  # PATCH /api/v1/cras/:id - Update (permissions only)
  # ===========================================
  describe 'PATCH /api/v1/cras/:id' do
    let!(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 2, status: 'draft') }

    context 'when another user tries to update' do
      it 'returns 403 forbidden' do
        patch "/api/v1/cras/#{cra.id}",
              params: { description: 'Malicious update' },
              headers: other_headers

        expect(response).to have_http_status(:forbidden)
      end

      it 'does not modify the CRA' do
        original_description = cra.description

        patch "/api/v1/cras/#{cra.id}",
              params: { description: 'Malicious update' },
              headers: other_headers

        cra.reload
        expect(cra.description).to eq(original_description)
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        patch "/api/v1/cras/#{cra.id}",
              params: { description: 'No auth update' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================
  # DELETE /api/v1/cras/:id - Destroy
  # ===========================================
  describe 'DELETE /api/v1/cras/:id' do
    let!(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 3, status: 'draft') }

    context 'when another user tries to delete' do
      it 'returns 403 forbidden' do
        delete "/api/v1/cras/#{cra.id}", headers: other_headers

        expect(response).to have_http_status(:forbidden)
      end

      it 'does not delete the CRA' do
        delete "/api/v1/cras/#{cra.id}", headers: other_headers

        expect(Cra.find_by(id: cra.id)).to be_present
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        delete "/api/v1/cras/#{cra.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================
  # POST /api/v1/cras/:id/submit - Submit (permissions only)
  # ===========================================
  describe 'POST /api/v1/cras/:id/submit' do
    let!(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 4, status: 'draft') }

    context 'when another user tries to submit' do
      it 'returns 403 forbidden' do
        post "/api/v1/cras/#{cra.id}/submit", headers: other_headers

        expect(response).to have_http_status(:forbidden)
      end

      it 'does not change status' do
        post "/api/v1/cras/#{cra.id}/submit", headers: other_headers

        cra.reload
        expect(cra.status).to eq('draft')
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        post "/api/v1/cras/#{cra.id}/submit"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================
  # POST /api/v1/cras/:id/lock - Lock (permissions only)
  # ===========================================
  describe 'POST /api/v1/cras/:id/lock' do
    let!(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 5, status: 'submitted') }

    context 'when another user tries to lock' do
      it 'returns 403 forbidden' do
        post "/api/v1/cras/#{cra.id}/lock", headers: other_headers

        expect(response).to have_http_status(:forbidden)
      end

      it 'does not change status' do
        post "/api/v1/cras/#{cra.id}/lock", headers: other_headers

        cra.reload
        expect(cra.status).to eq('submitted')
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        post "/api/v1/cras/#{cra.id}/lock"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================
  # GET /api/v1/cras/:id/export - Export
  # ===========================================
  describe 'GET /api/v1/cras/:id/export' do
    let!(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 6) }

    before do
      # DDD: Transition CRA to submitted state (required for export)
      result = CraServices::Lifecycle.call(
        cra: cra,
        action: 'submit',
        current_user: user
      )
      raise "CRA lifecycle transition failed: #{result.message}" unless result.success?
      cra.reload
    end

    context 'when user owns the CRA' do
      it 'returns 200 OK with CSV' do
        get "/api/v1/cras/#{cra.id}/export", headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/csv')
      end
    end

    context 'when another user tries to export' do
      it 'returns 403 forbidden' do
        get "/api/v1/cras/#{cra.id}/export", headers: other_headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        get "/api/v1/cras/#{cra.id}/export"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================
  # GET /api/v1/cras - List (isolation)
  # ===========================================
  describe 'GET /api/v1/cras (list)' do
    let!(:user_cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 7) }
    let!(:other_user_cra) { create(:cra, created_by_user_id: other_user.id, year: 2026, month: 8) }

    context 'when user lists CRAs' do
      it 'returns only their own CRAs' do
        get '/api/v1/cras', headers: headers

        json = JSON.parse(response.body)
        cra_ids = json['data'].map { |c| c['id'] }

        expect(cra_ids).to include(user_cra.id)
        expect(cra_ids).not_to include(other_user_cra.id)
      end
    end

    context 'when other user lists CRAs' do
      it 'returns only their own CRAs' do
        get '/api/v1/cras', headers: other_headers

        json = JSON.parse(response.body)
        cra_ids = json['data'].map { |c| c['id'] }

        expect(cra_ids).to include(other_user_cra.id)
        expect(cra_ids).not_to include(user_cra.id)
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        get '/api/v1/cras'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
