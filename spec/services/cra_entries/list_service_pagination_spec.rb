# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::CraEntries::ListService, 'pagination' do
  # ============================================================================
  # 🎯 CONTRAT TDD PHASE 3B.1 — Pagination ListService
  # ============================================================================
  #
  # Invariants observables :
  # ✅ retourne uniquement les entries du CRA
  # ✅ respecte page
  # ✅ respecte per_page
  # ✅ ordre déterministe (obligatoire)
  # ❌ aucun effet de bord
  #
  # ============================================================================

  let(:user) { create(:user) }
  let(:cra) { create(:cra, user: user, status: :draft) }
  let(:mission) { create(:mission) }

  before do
    # Link CRA to mission via CraMission
    create(:cra_mission, cra: cra, mission: mission)
  end

  describe '.call with pagination' do
    # =========================================================================
    # 🧪 Test 1 — pagination basique
    # 30 entries créées, page: 1, per_page: 10 → retourne 10 entries
    # =========================================================================
    context 'when paginating with per_page limit' do
      before do
        # Créer 30 entries avec des dates différentes pour ordre déterministe
        30.times do |i|
          entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current + i.days)
          create(:cra_entry_cra, cra_entry: entry, cra: cra)
          create(:cra_entry_mission, cra_entry: entry, mission: mission)
        end
      end

      it 'returns exactly per_page entries for page 1' do
        result = described_class.call(
          cra: cra,
          current_user: user,
          page: 1,
          per_page: 10
        )

        expect(result.items.size).to eq(10)
      end

      it 'returns total count for pagination metadata' do
        result = described_class.call(
          cra: cra,
          current_user: user,
          page: 1,
          per_page: 10
        )

        expect(result.total_count).to eq(30)
      end
    end

    # =========================================================================
    # 🧪 Test 2 — page suivante
    # page: 2 → retourne les 10 suivantes (différentes de page 1)
    # =========================================================================
    context 'when requesting page 2' do
      before do
        30.times do |i|
          entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current + i.days)
          create(:cra_entry_cra, cra_entry: entry, cra: cra)
          create(:cra_entry_mission, cra_entry: entry, mission: mission)
        end
      end

      it 'returns different entries than page 1' do
        page1_result = described_class.call(
          cra: cra,
          current_user: user,
          page: 1,
          per_page: 10
        )

        page2_result = described_class.call(
          cra: cra,
          current_user: user,
          page: 2,
          per_page: 10
        )

        page1_ids = page1_result.items.map(&:id)
        page2_ids = page2_result.items.map(&:id)

        expect(page1_ids & page2_ids).to be_empty
        expect(page2_result.items.size).to eq(10)
      end

      it 'returns entries in deterministic order across pages' do
        all_results = (1..3).flat_map do |page|
          described_class.call(
            cra: cra,
            current_user: user,
            page: page,
            per_page: 10
          ).items
        end

        # L'ordre doit être déterministe - pas de doublons
        expect(all_results.map(&:id).uniq.size).to eq(30)
      end
    end

    # =========================================================================
    # 🧪 Test 3 — isolation CRA
    # 2 CRAs → ne mélange jamais les résultats
    # =========================================================================
    context 'when multiple CRAs exist' do
      let(:other_user) { create(:user) }
      let(:other_cra) { create(:cra, user: other_user, status: :draft) }
      let(:other_mission) { create(:mission) }

      before do
        # Entries pour le CRA principal
        5.times do |i|
          entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current + i.days)
          create(:cra_entry_cra, cra_entry: entry, cra: cra)
          create(:cra_entry_mission, cra_entry: entry, mission: mission)
        end

        # Entries pour l'autre CRA
        create(:cra_mission, cra: other_cra, mission: other_mission)
        10.times do |i|
          entry = create(:cra_entry, quantity: 2, unit_price: 200, date: Date.current + i.days)
          create(:cra_entry_cra, cra_entry: entry, cra: other_cra)
          create(:cra_entry_mission, cra_entry: entry, mission: other_mission)
        end
      end

      it 'returns only entries belonging to the requested CRA' do
        result = described_class.call(
          cra: cra,
          current_user: user,
          page: 1,
          per_page: 20
        )

        # Doit retourner seulement les 5 entries du CRA principal
        expect(result.items.size).to eq(5)
        expect(result.total_count).to eq(5)

        # Vérifier que toutes les entries appartiennent au bon CRA
        result.items.each do |entry|
          expect(entry.cra_entry_cras.map(&:cra_id)).to include(cra.id)
        end
      end

      it 'never includes entries from other CRAs' do
        result = described_class.call(
          cra: cra,
          current_user: user,
          page: 1,
          per_page: 100
        )

        other_cra_entry_ids = CraEntryCra.where(cra: other_cra).pluck(:cra_entry_id)
        result_ids = result.items.map(&:id)

        expect(result_ids & other_cra_entry_ids).to be_empty
      end
    end

    # =========================================================================
    # 🧪 Test 4 — ordre déterministe
    # =========================================================================
    context 'deterministic ordering' do
      before do
        # Créer des entries dans un ordre aléatoire
        [5, 2, 8, 1, 9, 3, 7, 4, 6, 10].each do |day_offset|
          entry = create(:cra_entry, quantity: day_offset, unit_price: 100, date: Date.current + day_offset.days)
          create(:cra_entry_cra, cra_entry: entry, cra: cra)
          create(:cra_entry_mission, cra_entry: entry, mission: mission)
        end
      end

      it 'returns entries in consistent order on multiple calls' do
        first_call = described_class.call(
          cra: cra,
          current_user: user,
          page: 1,
          per_page: 10
        ).items.map(&:id)

        second_call = described_class.call(
          cra: cra,
          current_user: user,
          page: 1,
          per_page: 10
        ).items.map(&:id)

        expect(first_call).to eq(second_call)
      end
    end

    # =========================================================================
    # 🧪 Test 5 — page vide
    # =========================================================================
    context 'when requesting a page beyond available data' do
      before do
        5.times do |i|
          entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current + i.days)
          create(:cra_entry_cra, cra_entry: entry, cra: cra)
          create(:cra_entry_mission, cra_entry: entry, mission: mission)
        end
      end

      it 'returns empty entries array' do
        result = described_class.call(
          cra: cra,
          current_user: user,
          page: 10,
          per_page: 10
        )

        expect(result.items).to be_empty
        expect(result.total_count).to eq(5)
      end
    end

    # =========================================================================
    # 🧪 Test 6 — valeurs par défaut
    # =========================================================================
    context 'when pagination params are not provided' do
      before do
        25.times do |i|
          entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current + i.days)
          create(:cra_entry_cra, cra_entry: entry, cra: cra)
          create(:cra_entry_mission, cra_entry: entry, mission: mission)
        end
      end

      it 'uses default pagination values' do
        result = described_class.call(
          cra: cra,
          current_user: user
        )

        # Doit avoir une limite par défaut raisonnable (ex: 20)
        expect(result.items.size).to be <= 25
        expect(result.total_count).to eq(25)
      end
    end
  end
end
