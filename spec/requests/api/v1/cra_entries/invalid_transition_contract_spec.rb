# frozen_string_literal: true

# Contrat d'erreur #27/Q-2 — PUT/DELETE /cra_entries sur CRA non-draft
#
# CONSTAT DE L'ANALYSE #27 (C-2) : CraEntryServices::Update/Destroy émettent
# `conflict(:invalid_transition)` pour un CRA non-draft, et `handle_service_error`
# ne connaît pas ce symbole (else → error_internal → 500 théorique).
#
# RÉSULTAT DE CETTE SPEC (points d'entrée publics) : le before_action
# `validate_entry_modifiable!` (cra_entries_controller L23/L166-173) sert **déjà**
# le 409 contractuel AVANT l'appel au service — le 500 C-2 n'est **pas atteignable**
# via l'API. Cette spec éping le comportement public (409 CONFLICT + message) comme
# régression permanente ; la mise à jour de l'analyse #27 (reachability corrigée)
# en découle : pas de mapping à ajouter sans anomalie atteignable (décision CTO 26/09).
require 'rails_helper'

RSpec.describe 'CRA Entries — update/destroy sur CRA non-draft (contrat #27/Q-2)', type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let(:mission) { create(:mission, :time_based, :with_creator, creator: user) }
  let(:cra) { create(:cra, :with_creator, creator: user, year: 2026, month: 1, status: 'draft') }
  let(:cra_entry) do
    create(:cra_entry, date: Date.new(2026, 1, 15), quantity: 1.0, unit_price: 50_000,
                       description: 'Development work')
  end
  let(:token) { AuthenticationService.login(user, '127.0.0.1', 'rspec #27')[:token] }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')
    create(:cra_entry_cra, cra: cra, cra_entry: cra_entry)
    create(:cra_entry_mission, cra_entry: cra_entry, mission: mission)
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  it 'PATCH sur CRA soumis — 409 CONFLICT avec le message métier (pas 500)' do
    cra.submit!
    patch "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}",
          params: { quantity: 0.6 },
          headers: { 'Authorization' => "Bearer #{token}" }

    expect(response).to have_http_status(:conflict)
    body = JSON.parse(response.body)
    expect(body['code']).to eq('CONFLICT')
    expect(body['message']).to eq('Cannot modify entry from submitted or locked CRA')
  end

  it 'DELETE sur CRA verrouillé — 409 CONFLICT avec le message métier (pas 500)' do
    cra.submit!
    cra.lock! # depuis draft : submit! d'abord (lock! seul depuis draft = transition refusée)
    delete "/api/v1/cras/#{cra.id}/entries/#{cra_entry.id}",
           headers: { 'Authorization' => "Bearer #{token}" }

    expect(response).to have_http_status(:conflict)
    body = JSON.parse(response.body)
    expect(body['code']).to eq('CONFLICT')
    expect(body['message']).to eq('Cannot modify entry from submitted or locked CRA')
  end
end
