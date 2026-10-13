# frozen_string_literal: true

# Contrat d'erreur #27/Q-1 — POST /api/v1/missions avec client_company_id INCONNU
#
# RED attendu avant correction (anomalie C-1, audit #27) : ForeignKeyViolation sur
# mission_companies → rescue StandardError du service → internal_error → **HTTP 500**
# (l'assertion 422 ci-dessous échoue avec `got: 500`).
# GREEN attendu après correction (validation du client AVANT toute écriture) :
# **HTTP 422 INVALID_PAYLOAD / UNPROCESSABLE_ENTITY + message service** + zéro persistance.
require 'rails_helper'

RSpec.describe 'POST /api/v1/missions — client_company_id inconnu (contrat #27/Q-1)', type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let(:unknown_company_id) { '00000000-0000-0000-0000-000000000001' }
  let(:mission_params) do
    {
      name: 'Contrat #27 — client inconnu',
      mission_type: 'time_based',
      status: 'lead',
      start_date: Date.current.to_s,
      daily_rate: 60_000,
      currency: 'EUR',
      client_company_id: unknown_company_id
    }
  end
  let(:token) { AuthenticationService.login(user, '127.0.0.1', 'rspec #27')[:token] }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    allow(RateLimitService).to receive(:check_rate_limit).and_return([true, nil])
  end

  it 'retourne 422 (et non 500) avec le message service, et ne persiste rien' do
    post '/api/v1/missions',
         params: mission_params,
         as: :json,
         headers: { 'Authorization' => "Bearer #{token}" }

    expect(response).to have_http_status(:unprocessable_entity)
    body = JSON.parse(response.body)
    expect(body['code']).to eq('UNPROCESSABLE_ENTITY')
    expect(body['message']).to match(/client/i)
    expect(Mission.where(name: mission_params[:name]).count).to eq(0)
  end
end
