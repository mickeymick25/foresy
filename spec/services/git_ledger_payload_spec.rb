# frozen_string_literal: true

require 'rails_helper'

# W3-D2 — Caractérisation de GitLedgerPayload (P6 Wave 3)
#
# Le payload canonique est le contenu immuable engagé dans le commit Git Ledger :
# missions triées, entries mappées puis ordonnées (date, id), totaux calculés
# côté serveur uniquement (jamais approuvés par le client), horodatages ISO 8601.
RSpec.describe GitLedgerPayload, type: :model do
  let(:creator) { create(:user) }
  let(:cra) do
    create(:cra, :with_creator, creator: creator, year: 2026, month: 9,
                                status: 'locked', locked_at: Time.current,
                                description: 'Payload canonique')
  end
  let(:mission_a) { create(:mission, :time_based, :with_creator, creator: creator) }
  let(:mission_b) { create(:mission, :time_based, :with_creator, creator: creator) }
  let(:entry_a) do
    create(:cra_entry, cra: cra, mission: mission_a, date: Date.new(2026, 9, 1),
                       quantity: 1.5, unit_price: 10_000, description: 'Développement')
  end
  let(:entry_b) do
    create(:cra_entry, cra: cra, mission: mission_b, date: Date.new(2026, 9, 15),
                       quantity: 0.5, unit_price: 20_000, description: 'Revue')
  end
  let!(:cra_mission_a) { create(:cra_mission, cra: cra, mission: mission_a) }
  let!(:cra_mission_b) { create(:cra_mission, cra: cra, mission: mission_b) }
  let!(:entries) { [entry_a, entry_b] }

  describe '.build' do
    it 'construit le payload contractuel : missions triées, entries mappées et ordonnées, totals serveur' do
      payload = described_class.build(cra)

      expect(payload['cra_id']).to eq(cra.id)
      expect(payload['month']).to eq(9)
      expect(payload['year']).to eq(2026)
      expect(payload['missions']).to eq([mission_a.id, mission_b.id].sort)
      expect(payload['status']).to eq('locked')
      expect(payload['currency']).to eq(cra.currency)
      expect(payload['description']).to eq('Payload canonique')
      expect(payload['locked_at']).to eq(cra.locked_at.iso8601)
      expect(payload['created_by_user_id']).to eq(cra.creator_user_id)
      expect(payload['created_at']).to eq(cra.created_at.iso8601)
      expect(payload['updated_at']).to eq(cra.updated_at.iso8601)
    end

    it 'mappe les entries actives avec le contrat FC-07 et l ordre déterministe (date, id)' do
      payload = described_class.build(cra)

      expect(payload['entries'].size).to eq(2)
      expect(payload['entries']).to contain_exactly(
        hash_including('id' => entry_a.id, 'quantity' => 1.5, 'unit_price' => 10_000,
                       'description' => 'Développement', 'mission_id' => mission_a.id),
        hash_including('id' => entry_b.id, 'quantity' => 0.5, 'unit_price' => 20_000,
                       'description' => 'Revue', 'mission_id' => mission_b.id)
      )
      expect(payload['entries'].map { |e| e['date'] }).to eq(payload['entries'].map { |e|
        e['date']
      }.sort) # ordre déterministe par date
    end

    it 'calcule les totals côté serveur (total_days en Float, total_amount en centimes)' do
      payload = described_class.build(cra)

      expect(payload['totals']['total_days']).to be_a(Float)
      expect(payload['totals']['total_days']).to eq(cra.total_days || cra.calculate_total_days)
      expect(payload['totals']['total_amount'])
        .to eq(cra.total_amount || cra.calculate_total_amount)
    end

    it 'exclut les entries soft-deletées du payload (voie active uniquement)' do
      entry_b.destroy # soft delete CraEntry (deleted_at)

      payload = described_class.build(cra)

      expect(payload['entries'].map { |e| e['id'] }).to contain_exactly(entry_a.id)
    end
  end
end
