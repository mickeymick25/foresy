# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CRA Export', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:headers) { { 'Authorization' => "Bearer #{user_token}" } }

  let(:company) { create(:company) }
  let(:mission) { create(:mission, :time_based, created_by_user_id: user.id) }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')
  end

  describe 'GET /api/v1/cras/:id/export' do
    let(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1) }

    before do
      # Create CRA entries
      entry1 = create(:cra_entry, date: Date.new(2026, 1, 10), quantity: 1.0, unit_price: 50_000,
                                  description: 'Dev work')
      entry2 = create(:cra_entry, date: Date.new(2026, 1, 11), quantity: 0.5, unit_price: 50_000,
                                  description: 'Meeting')

      create(:cra_entry_cra, cra: cra, cra_entry: entry1)
      create(:cra_entry_cra, cra: cra, cra_entry: entry2)

      create(:cra_entry_mission, cra_entry: entry1, mission: mission)
      create(:cra_entry_mission, cra_entry: entry2, mission: mission)

      cra.reload
    end

    context 'with valid authentication and access' do
      it 'returns CSV file with correct headers' do
        get "/api/v1/cras/#{cra.id}/export", params: { export_format: 'csv' }, headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/csv')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include('cra_2026_01.csv')
      end

      it 'includes TOTAL row in CSV content' do
        get "/api/v1/cras/#{cra.id}/export", params: { export_format: 'csv' }, headers: headers

        expect(response.body).to include('TOTAL')
      end

      it 'includes CSV column headers' do
        get "/api/v1/cras/#{cra.id}/export", params: { export_format: 'csv' }, headers: headers

        expect(response.body).to include('date,mission_name,quantity,unit_price_eur,line_total_eur,description')
      end

      it 'defaults to CSV format when export_format not specified' do
        get "/api/v1/cras/#{cra.id}/export", headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/csv')
      end

      context 'with include_entries=false' do
        it 'exports CSV without entry rows' do
          get "/api/v1/cras/#{cra.id}/export", params: { export_format: 'csv', include_entries: 'false' },
                                               headers: headers

          expect(response).to have_http_status(:ok)
          # Header + TOTAL only = 2 lines
          expect(response.body.lines.count).to eq(2)
          expect(response.body).to include('TOTAL')
        end
      end
    end

    context 'with invalid format' do
      it 'returns 422 for unsupported format' do
        get "/api/v1/cras/#{cra.id}/export", params: { export_format: 'xml' }, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to eq('invalid_payload')
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized' do
        get "/api/v1/cras/#{cra.id}/export", params: { export_format: 'csv' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when CRA does not exist' do
      it 'returns 404 not found' do
        get '/api/v1/cras/non-existent-uuid/export', params: { export_format: 'csv' }, headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user does not have access to CRA' do
      let(:other_user) { create(:user) }
      let(:other_company) { create(:company) }
      let(:other_mission) { create(:mission, :time_based, created_by_user_id: other_user.id) }
      let(:other_cra) { create(:cra, created_by_user_id: other_user.id, year: 2026, month: 2) }

      before do
        create(:user_company, user: other_user, company: other_company, role: 'independent')
        create(:mission_company, mission: other_mission, company: other_company, role: 'independent')
      end

      it 'returns 403 forbidden' do
        get "/api/v1/cras/#{other_cra.id}/export", params: { export_format: 'csv' }, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
