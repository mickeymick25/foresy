# frozen_string_literal: true

require 'rails_helper'

# W4-D1 — Caractérisation des couches d'erreur et de dispatch des contrôleurs
# CRA et CRA-Entries (P6 Wave 4 — tracker p6_wave4 §W4-D1)
#
# Pattern éprouvé (W1-D3/W1-D4) : stub des services pour traverser les couches
# de rendu/erreurs du contrôleur, avec assertion du contrat standardisé
# { code, message, details }. Aucun stub du contrôleur lui-même.
#
# Familles caractérisées (chemins RÉELLEMENT joignables) :
# - handle_service_error : mapping error → HTTP (L271-291)
# - render_result_error : mapping status → rendu (L174-189)
# - blocs rescue StandardError → error_internal (500 + logs)
#
# NOTE : les handlers `rescue_from CraErrors::*` (L197-249) sont INJOIGNABLES
# via le flow normal — chaque action a un `rescue StandardError` inline qui
# attrape tout avant le rescue_from. Ils sont documentés comme défensifs.
RSpec.describe 'CRA — couches d erreur et de dispatch', type: :request do
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:bearer_token) { "Bearer #{user_token}" }
  let(:company) { create(:company) }
  let(:cra) { create(:cra, :with_creator, creator: user, year: 2026, month: 9, status: 'draft') }
  let(:entry) do
    create(:cra_entry, cra: cra,
                       mission: create(:mission, :time_based, :with_creator, creator: user),
                       date: Date.new(2026, 9, 5))
  end

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  # ============================================================
  # CraEntriesController — rescue StandardError (L57-60, 105-109)
  # ============================================================
  describe 'CraEntriesController — rescue StandardError (imprévu → 500)' do
    it 'create : exception hors-CraErrors → 500 + log_api_error' do
      allow(CraEntryServices::Create).to receive(:call).and_raise(StandardError, 'hors-CraErrors')

      post "/api/v1/cras/#{cra.id}/entries",
           params: { date: '2026-09-05', quantity: 1, unit_price: 10_000 },
           headers: { 'Authorization' => bearer_token }, as: :json

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'update : exception hors-CraErrors → 500' do
      entry
      allow(CraEntryServices::Update).to receive(:call).and_raise(StandardError, 'boom')

      patch "/api/v1/cras/#{cra.id}/entries/#{entry.id}",
            params: { quantity: 2 },
            headers: { 'Authorization' => bearer_token }, as: :json

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'show : exception → 500' do
      entry
      allow(Api::V1::CraEntries::ResponseFormatter).to receive(:single)
        .and_raise(StandardError, 'boom')

      get "/api/v1/cras/#{cra.id}/entries/#{entry.id}",
          headers: { 'Authorization' => bearer_token }

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'index : exception → 500' do
      allow(CraEntryServices::List).to receive(:call).and_raise(StandardError, 'boom')

      get "/api/v1/cras/#{cra.id}/entries", headers: { 'Authorization' => bearer_token }

      expect(response).to have_http_status(:internal_server_error)
    end

    it 'destroy : exception → 500' do
      entry
      allow(CraEntryServices::Destroy).to receive(:call).and_raise(StandardError, 'boom')

      delete "/api/v1/cras/#{cra.id}/entries/#{entry.id}",
             headers: { 'Authorization' => bearer_token }

      expect(response).to have_http_status(:internal_server_error)
    end
  end

  # ============================================================
  # CraEntriesController — handle_service_error : mapping error → HTTP
  # ============================================================
  describe 'CraEntriesController — handle_service_error (résultats en échec)' do
    let(:error_matrix) do
      {
        business_rule_violation: :unprocessable_entity,
        relation_creation_failed: :unprocessable_entity,
        duplicate_entry: :conflict,
        conflict: :conflict,
        invalid_cra_state: :conflict,
        not_found: :not_found,
        forbidden: :forbidden,
        insufficient_permissions: :forbidden,
        validation_failed: :unprocessable_entity,
        missing_cra: :unprocessable_entity,
        create_failed: :internal_server_error,
        update_failed: :internal_server_error,
        destroy_failed: :internal_server_error
      }
    end

    it 'mappe chaque clé d erreur du contrat vers le statut HTTP attendu' do
      entry

      error_matrix.each do |error_key, expected_status|
        allow(CraEntryServices::Update).to receive(:call).and_return(
          ApplicationResult.fail(error: error_key, status: :ok, message: "échec #{error_key}")
        )

        patch "/api/v1/cras/#{cra.id}/entries/#{entry.id}",
              params: { quantity: 2 },
              headers: { 'Authorization' => bearer_token }, as: :json

        expect(response).to have_http_status(expected_status)
      end
    end
  end

  # ============================================================
  # CrasController — index en échec + render_result_error (branches de statut)
  # ============================================================
  describe 'CrasController — index en échec + render_result_error' do
    let(:status_matrix) do
      {
        conflict: :conflict,
        forbidden: :forbidden,
        not_found: :not_found,
        bad_request: :bad_request,
        internal_server_error: :internal_server_error,
        unprocessable_entity: :unprocessable_entity
      }
    end

    it 'index rend le message du résultat en échec (L75-76)' do
      allow(CraServices::List).to receive(:call).and_return(
        ApplicationResult.fail(error: :invalid_payload, status: :bad_request, message: 'payload invalide')
      )

      get '/api/v1/cras', headers: { 'Authorization' => bearer_token }

      expect(response).to have_http_status(:unprocessable_entity)
      data = JSON.parse(response.body)
      expect(data['message']).to eq('invalid_payload')
    end

    it 'render_result_error mappe chaque statut de résultat vers le rendu standardisé' do
      status_matrix.each do |result_status, expected_http|
        allow(CraServices::Lifecycle).to receive(:call).and_return(
          ApplicationResult.fail(error: :arbitraire, status: result_status, message: 'échec caractérisé')
        )

        post "/api/v1/cras/#{cra.id}/submit", headers: { 'Authorization' => bearer_token }

        expect(response).to have_http_status(expected_http)
        data = JSON.parse(response.body)
        expect(data['message']).to eq('échec caractérisé')
      end
    end
  end
end
