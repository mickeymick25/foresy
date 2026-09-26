# frozen_string_literal: true

# BACKLOG #14 — RED : l'invariant d'unicité (créateur + mois + année) est-il protégé à la création ?
#
# Hypothèse (W3-D4 + lecture code, à confirmer empiriquement) :
#   - `Cra#validate_uniqueness` lit le pivot `user_cras` — créé post-insert par
#     CraServices::Create → à la validation de création, `creator_user_id` est nil →
#     `return if nil` → garde inerte ;
#   - aucune contrainte DB ne protège cet invariant (schéma : `cras` sans index d'unicité
#     créateur ; les index uniques de `user_cras` protègent un créateur PAR CRA) ;
#   - aucun garde service-level (CraServices::Create : params → permissions → build → save).
#
# Le spec asserte l'invariant ATTENDU — son échec démontre la violation (RED).
# Aucun mock/stub métier — flow réel HTTP → controller → service → model → DB.

require 'rails_helper'

RSpec.describe 'BACKLOG #14 — invariant unicité créateur+mois+année à la création', type: :request do
  before do
    RateLimitService.reset_storage!
  end

  after do
    RateLimitService.reset_storage!
  end

  let(:user) { create(:user) }
  let(:token) { AuthenticationService.login(user, '127.0.0.1', 'BACKLOG #14')[:token] }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }
  let(:company) { create(:company) }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
  end

  def post_cra
    post '/api/v1/cras',
         params: { month: Date.current.month, year: Date.current.year,
                   currency: 'EUR', description: 'BACKLOG #14 — probe unicité' }.to_json,
         headers: headers
  end

  def cras_of_creator_same_period
    Cra.joins(:user_cras)
       .where(user_cras: { user_id: user.id, role: 'creator' })
       .where(month: Date.current.month, year: Date.current.year, deleted_at: nil)
  end

  it 'refuse un second CRA identique (créateur + mois + année) — invariant attendu' do
    post_cra
    expect(response).to have_http_status(:created)
    # le pivot créateur est créé post-insert (relation-driven)
    expect(user.user_cras.where(role: 'creator').count).to eq(1)

    post_cra

    # L'invariant attendu : la création d'un doublon est refusée
    expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:conflict)

    # Et rien ne persiste : un seul CRA pour ce créateur sur cette période
    expect(cras_of_creator_same_period.count).to eq(1)
  end
end
