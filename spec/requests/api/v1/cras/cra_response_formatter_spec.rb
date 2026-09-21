# frozen_string_literal: true

require 'rails_helper'

# W4-D2 — Caractérisation de Common::ResponseFormatter + StandardizedError
# via les contrôleurs réels (approche C — arbitrage CTO 20/09)
#
# Ces concerns utilisent render, response.headers, et le flow applicatif réel.
# Ils sont exercés à travers les contrôleurs qui les incluent réellement.
RSpec.describe 'ResponseFormatter + StandardizedError via les contrôleurs (W4-D2)', type: :request do
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

  describe 'ResponseFormatter — rendus CRA-entries (via CraEntriesController)' do
    it 'create rend le contrat single via ResponseFormatter (L53)' do
      cra.update!(status: 'draft')
      create(:user_cra, user: user, cra: cra, role: 'creator') unless UserCra.exists?(cra_id: cra.id, user_id: user.id)

      post "/api/v1/cras/#{cra.id}/entries",
           params: { date: '2026-09-05', quantity: 1, unit_price: 10_000,
                     mission_id: create(:mission, :time_based, :with_creator, creator: user).id },
           headers: { 'Authorization' => bearer_token }, as: :json

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)
      expect(data).to include('id', 'date', 'quantity', 'unit_price', 'line_total')
    end

    it 'index rend le contrat collection via ResponseFormatter (L73)' do
      entry

      get "/api/v1/cras/#{cra.id}/entries", headers: { 'Authorization' => bearer_token }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data).to be_an(Array)
    end
  end

  describe 'StandardizedError — error_internal masque/expose les détails' do
    it 'expose le message en test (Rails.env.test?)' do
      allow(CraEntryServices::Create).to receive(:call).and_raise(StandardError, 'message interne')

      post "/api/v1/cras/#{cra.id}/entries",
           params: { date: '2026-09-05', quantity: 1, unit_price: 10_000 },
           headers: { 'Authorization' => bearer_token }, as: :json

      expect(response).to have_http_status(:internal_server_error)
      data = JSON.parse(response.body)
      expect(data['code']).to eq('INTERNAL_SERVER_ERROR')
    end
  end
end