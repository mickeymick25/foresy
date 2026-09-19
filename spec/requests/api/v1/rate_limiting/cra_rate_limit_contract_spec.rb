# frozen_string_literal: true

# W1-D3 — Caractérisation des deux seuls chemins VIVANTS des concerns
# ErrorHandler ciblés (plan : docs/technical/testing/p6_wave1_tracker.md §3 W1-D3,
# arbitrage CTO 19/09 — D3-A avant toute suppression D3-B).
#
# Chemins réels caractérisés (relocalisés W1-D3-B depuis les concerns supprimés) :
#   CrasController#create       → Common::RateLimitable#check_rate_limit!
#                               → CrasController#handle_rate_limit_exceeded
#                               → error_too_many_requests → 429 + details { resource_type: 'CRA' }
#   CraEntriesController#create → Common::RateLimitable#check_rate_limit!
#                               → CraEntriesController#handle_rate_limit_exceeded
#                               → error_too_many_requests → 429 (sans details)
#
# Le stub fixe uniquement la réponse du limiter (RedisRateLimiter#allow? → false)
# pour rendre le déclenchement déterministe — le flux before_action complet du
# contrôleur s'exécute (auth → set_cra → check_rate_limit! → handler → rendu),
# conformément au patron spec/requests/api/v1/rate_limiting/.
require 'rails_helper'

RSpec.describe 'CRA rate limit error contract', type: :request do
  let(:user) { create(:user) }
  let(:token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  before do
    # Le concern définit la classe lexicalement dans `module Common` (après la
    # fermeture de `module RateLimitable`) : elle ne correspond à aucun fichier
    # géré par Zeitwerk — le chargement du concern doit être forcé pour y accéder.
    # Le stub fixe uniquement la réponse du limiter ; le flux contrôleur
    # (auth → set_cra → check_rate_limit! → handler) s'exécute intégralement.
    Common::RateLimitable.name
    allow_any_instance_of(Common::RedisRateLimiter).to receive(:allow?).and_return(false)
  end

  describe 'POST /api/v1/cras — via CrasController#handle_rate_limit_exceeded' do
    it 'returns 429 with the flat error contract (code, message, details)' do
      post '/api/v1/cras', params: { month: 9, year: 2026, currency: 'EUR' }, headers: headers

      expect(response).to have_http_status(:too_many_requests)

      json = JSON.parse(response.body)
      # Caractérisation du comportement RÉEL : error_too_many_requests rend
      # ERROR_CODES[:rate_limit_exceeded] — divergence vs error_contract.md
      # (qui liste TOO_MANY_REQUESTS ET « RATE_LIMIT_EXCEEDED — alias ») —
      # arbitrage CTO tracé au journal W1-D3.
      expect(json['code']).to eq('RATE_LIMIT_EXCEEDED')
      expect(json['message']).to be_present
      expect(json['details']).to be_present
      expect(json.key?('error')).to be false
      expect(json.key?('timestamp')).to be false
    end

    it 'exposes the CRA resource_type in details' do
      post '/api/v1/cras', params: { month: 9, year: 2026, currency: 'EUR' }, headers: headers

      json = JSON.parse(response.body)
      expect(json['details']).to include('resource_type' => 'CRA')
    end
  end

  describe 'POST /api/v1/cras/:cra_id/entries — via CraEntriesController#handle_rate_limit_exceeded' do
    let(:cra) { create(:cra, :with_creator, creator: user, year: 2026, month: 9) }

    it 'returns 429 with the flat error contract' do
      post "/api/v1/cras/#{cra.id}/entries",
           params: { date: '2026-09-15', quantity: 1, unit_price: 50_000 }, headers: headers

      expect(response).to have_http_status(:too_many_requests)

      json = JSON.parse(response.body)
      expect(json['code']).to eq('RATE_LIMIT_EXCEEDED')
      expect(json['message']).to be_present
      # Caractérisation du comportement réel : ce handler ne passe pas de details
      # (le contrat les rend optionnels — asymétrie vs le chemin CRA, relevée au journal)
      expect(json.key?('details')).to be false
      expect(json.key?('error')).to be false
      expect(json.key?('timestamp')).to be false
    end
  end
end
