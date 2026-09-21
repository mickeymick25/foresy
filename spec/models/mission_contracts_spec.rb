# frozen_string_literal: true

require 'rails_helper'

# W3-D4 — Contrats et invariants du modèle Mission (P6 Wave 3)
#
# Types (time_based / fixed_price) avec exclusivité des champs financiers,
# cycle de vie (lead → pending → won → in_progress → completed), discard
# protégé par la présence de CRA entries, helpers de présentation.
RSpec.describe Mission, type: :model do
  let(:creator) { create(:user) }
  let(:mission) { create(:mission, :time_based, :with_creator, creator: creator) }

  describe 'soft delete — discard/undiscard' do
    it 'soft-delette une mission sans CRA entries' do
      mission.discard

      expect(mission.reload.discarded?).to be(true)
    end

    it 'undiscard restaure la mission' do
      mission.discard

      mission.undiscard

      expect(mission.reload.discarded?).to be(false)
    end

    it 'refuse le discard d une mission utilisée par des CRA entries (garde métier)' do
      company = create(:company)
      cra = create(:cra, :with_creator, creator: creator, year: 2026, month: 9)
      create(:cra_entry, cra: cra, mission: mission, date: Date.new(2026, 9, 5))

      expect(mission.discard).to be(false)
      expect(mission.errors[:base]).to be_present
      expect(mission.reload.discarded?).to be(false)
      company
    end
  end

  describe 'helpers d état et de type' do
    it 'active? / completed? / current? reflètent le cycle de vie' do
      expect(mission.active?).to be(true)
      expect(mission.current?).to be(true)
      expect(mission.completed?).to be(false)

      mission.update!(status: 'completed')
      expect(mission.completed?).to be(true)
      expect(mission.current?).to be(false)
    end

    it 'time_based? / fixed_price? reflètent le type' do
      expect(mission.time_based?).to be(true)
      expect(mission.fixed_price?).to be(false)

      mission.update!(mission_type: 'fixed_price', daily_rate: nil, fixed_price: 100_000)
      expect(mission.fixed_price?).to be(true)
      expect(mission.time_based?).to be(false)
    end
  end

  describe 'présentation et calculs' do
    it 'display_name expose le nom et le statut humanisé' do
      expect(mission.display_name).to eq("#{mission.name} (#{mission.status.humanize})")
    end

    it 'duration_in_days calcule inclusif, et nil sans end_date' do
      mission.update!(start_date: Date.new(2026, 9, 1), end_date: Date.new(2026, 9, 10))
      expect(mission.duration_in_days).to eq(10)

      mission.update!(end_date: nil)
      expect(mission.duration_in_days).to be_nil
    end

    it 'total_amount suit le type : daily_rate (time_based) vs fixed_price' do
      mission.update!(daily_rate: 500)
      expect(mission.total_amount).to eq(500.0)

      mission.update!(mission_type: 'fixed_price', daily_rate: nil, fixed_price: 100_000)
      expect(mission.total_amount).to eq(100_000.0)
    end

    it 'currency_symbol expose EUR/USD/GBP et retombe sur le code brut' do
      mission.update!(currency: 'EUR')
      expect(mission.currency_symbol).to eq('€')
      mission.update!(currency: 'USD')
      expect(mission.currency_symbol).to eq('$')
      mission.update!(currency: 'GBP')
      expect(mission.currency_symbol).to eq('£')
      mission.update!(currency: 'CHF')
      expect(mission.currency_symbol).to eq('CHF')
    end
  end

  describe 'notifications post-won' do
    # BUG PRODUCTION DÉMONTRÉ (W3-D4 — RED) : client? → client_company (has_one :through
    # une collection) lève HasOneThroughCantAssociateThroughCollection → client? et
    # should_send_post_won_notification? sont inopérants. Arbitrage CTO requis.
    it 'client? lève HasOneThroughCantAssociateThroughCollection (association invalide)' do
      company = create(:company)
      mission.update!(status: 'won')
      create(:mission_company, mission: mission, company: company, role: 'client')

      expect { mission.client? }
        .to raise_error(ActiveRecord::HasOneThroughCantAssociateThroughCollection)
    end

    it 'should_send_post_won_notification? hérite de l erreur via client?' do
      company = create(:company)
      mission.update!(status: 'won')
      create(:mission_company, mission: mission, company: company, role: 'client')

      expect { mission.should_send_post_won_notification? }
        .to raise_error(ActiveRecord::HasOneThroughCantAssociateThroughCollection)
    end

    it 'ne propose pas de notification hors won' do
      mission.update!(status: 'pending')

      expect(mission.should_send_post_won_notification?).to be(false)
    end
  end

  describe 'validations financières (exclusivité par type)' do
    it 'exige daily_rate pour une mission time_based' do
      mission.daily_rate = nil

      expect(mission).not_to be_valid
      expect(mission.errors[:daily_rate]).to be_present
    end

    it 'rejette fixed_price sur une mission time_based' do
      mission.fixed_price = 50_000

      expect(mission).not_to be_valid
      expect(mission.errors[:fixed_price]).to be_present
    end

    it 'exige fixed_price pour une mission fixed_price' do
      mission.update!(mission_type: 'fixed_price', daily_rate: nil, fixed_price: 100_000)
      mission.fixed_price = nil

      expect(mission).not_to be_valid
      expect(mission.errors[:fixed_price]).to be_present
    end

    it 'rejette daily_rate sur une mission fixed_price' do
      mission.update!(mission_type: 'fixed_price', daily_rate: nil, fixed_price: 100_000)
      mission.daily_rate = 500

      expect(mission).not_to be_valid
      expect(mission.errors[:daily_rate]).to be_present
    end
  end

  describe 'validations enum (avant contrainte PostgreSQL)' do
    it 'rejette un mission_type hors contrat (ArgumentError du setter enum)' do
      expect { mission.mission_type = 'retainer' }
        .to raise_error(ArgumentError, /not a valid mission_type/)
    end

    it 'rejette un statut hors contrat (ArgumentError du setter enum)' do
      expect { mission.status = 'archived' }
        .to raise_error(ArgumentError, /not a valid status/)
    end
  end
end
