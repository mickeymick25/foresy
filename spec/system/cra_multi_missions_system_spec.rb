# frozen_string_literal: true

# P7-D2 — System Specs API — UC-5 (CRA multi-missions / pivots)
#
# Propriétés de composition non garanties par les couches inférieures :
# 1. Le garde duplicate (cra, mission, date) lit à travers les pivots
#    (cra_entry_cras + cra_entry_missions) → 409 — inerté avant le fix D1
#    (mission_id perdu avant le service).
# 2. La compensation de création : mission inexistante → 422 et entry +
#    lien CRA détruits — rien ne persiste (INV-17 sur le flow entry).
#
# UC-3 (Company onboarding) : 0 nouvelle spec — succès + échecs avec
# assertions DB déjà garantis par spec/requests/api/v1/companies/companies_spec.rb
# (scénarios 2/3/8/9/11/12) ; l'échec de l'étape 2 de la transaction est
# naturellement injoignable (rôle validé pré-transaction, pivot neuf).

require 'rails_helper'

RSpec.describe 'System API — CRA multi-missions (pivots)', type: :request do
  before do
    RateLimitService.reset_storage!
  end

  after do
    RateLimitService.reset_storage!
  end

  let(:user) { create(:user) }
  let(:token) { AuthenticationService.login(user, '127.0.0.1', 'P7 System Spec')[:token] }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }
  let(:company) { create(:company) }
  let(:mission_a) { create(:mission, :time_based, :with_creator, creator: user) }
  let(:mission_b) { create(:mission, :time_based, :with_creator, creator: user) }
  let(:cra) do
    create(:cra, :with_creator, creator: user, month: Date.current.month,
                                year: Date.current.year)
  end
  let(:unknown_mission_id) { '00000000-0000-0000-0000-000000000000' }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission_a, company: company, role: 'independent')
    create(:mission_company, mission: mission_b, company: company, role: 'independent')
    cra
  end

  def post_entry(mission_id, unit_price)
    post "/api/v1/cras/#{cra.id}/entries",
         params: { date: Date.current.iso8601, quantity: 0.5, unit_price: unit_price,
                   description: 'P7-D2 entry', mission_id: mission_id }.to_json,
         headers: headers
  end

  describe 'garde duplicate (cra, mission, date) à travers les pivots' do
    it 'refuse le doublon (même mission, même date) avec 409 et zéro delta' do
      post_entry(mission_a.id, 60_000)
      expect(response).to have_http_status(:created)
      entries_after_first = cra.reload.cra_entries.active.count
      links_after_first = CraEntryMission.where(mission_id: mission_a.id).count

      post_entry(mission_a.id, 60_000)

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)['code']).to eq('CONFLICT')
      # Zéro delta : ni entry ni pivot en plus malgré le 201 du premier passage
      expect(cra.reload.cra_entries.active.count).to eq(entries_after_first)
      expect(CraEntryMission.where(mission_id: mission_a.id).count).to eq(links_after_first)
    end
  end

  describe 'compensation de création (mission inexistante)' do
    it 'renvoie 422 et détruit entry + lien CRA — rien ne persiste' do
      entries_before = CraEntry.count
      cra_links_before = CraEntryCra.where(cra_id: cra.id).count

      post_entry(unknown_mission_id, 60_000)

      expect(response).to have_http_status(:unprocessable_entity)
      # Compensation : l'entry et son lien CRA ont été créés puis détruits
      expect(CraEntry.count).to eq(entries_before)
      expect(CraEntryCra.where(cra_id: cra.id).count).to eq(cra_links_before)
      expect(cra.reload.cra_entries.active.count).to eq(0)
      expect(cra.total_days.to_f).to eq(0.0)
    end
  end
end
