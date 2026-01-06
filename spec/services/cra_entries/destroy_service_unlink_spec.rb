# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::CraEntries::DestroyService, 'unlink mission' do
  # ============================================================================
  # 🎯 CONTRAT TDD PHASE 3B.2 — DestroyService Unlink Mission
  # ============================================================================
  #
  # Invariants observables :
  # ✅ suppression de la dernière entry d'une mission → unlink CraMission
  # ✅ suppression d'une entry non-dernière → CraMission préservé
  # ✅ unlink inexistant → pas d'erreur (idempotent)
  # ❌ aucun effet de bord non souhaité
  #
  # ============================================================================

  let(:user) { create(:user) }
  let(:cra) { create(:cra, user: user, status: :draft) }
  let(:mission) { create(:mission) }

  before do
    # Link CRA to mission via CraMission
    create(:cra_mission, cra: cra, mission: mission)
  end

  describe '.call unlink mission behavior' do
    # =========================================================================
    # 🧪 Test 1 — suppression de la dernière entry d'une mission
    # Quand on supprime la dernière entry liée à une mission,
    # le lien CraMission doit être supprimé
    # =========================================================================
    context 'when deleting the last entry for a mission' do
      let!(:entry) do
        entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current)
        create(:cra_entry_cra, cra_entry: entry, cra: cra)
        create(:cra_entry_mission, cra_entry: entry, mission: mission)
        entry
      end

      it 'removes the CraMission link' do
        expect do
          described_class.call(entry: entry, current_user: user)
        end.to change { CraMission.where(cra: cra, mission: mission).count }.from(1).to(0)
      end

      it 'soft deletes the entry' do
        result = described_class.call(entry: entry, current_user: user)

        expect(result.entry).to be_discarded
      end
    end

    # =========================================================================
    # 🧪 Test 2 — suppression d'une entry non-dernière
    # Quand il reste d'autres entries pour cette mission,
    # le lien CraMission doit être préservé
    # =========================================================================
    context 'when other entries exist for the same mission' do
      let!(:entry_to_delete) do
        entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current)
        create(:cra_entry_cra, cra_entry: entry, cra: cra)
        create(:cra_entry_mission, cra_entry: entry, mission: mission)
        entry
      end

      let!(:other_entry) do
        entry = create(:cra_entry, quantity: 2, unit_price: 200, date: Date.current + 1.day)
        create(:cra_entry_cra, cra_entry: entry, cra: cra)
        create(:cra_entry_mission, cra_entry: entry, mission: mission)
        entry
      end

      it 'preserves the CraMission link' do
        expect do
          described_class.call(entry: entry_to_delete, current_user: user)
        end.not_to(change { CraMission.where(cra: cra, mission: mission).count })
      end

      it 'soft deletes only the specified entry' do
        described_class.call(entry: entry_to_delete, current_user: user)

        expect(entry_to_delete.reload).to be_discarded
        expect(other_entry.reload).not_to be_discarded
      end
    end

    # =========================================================================
    # 🧪 Test 3 — suppression avec plusieurs missions
    # Ne doit unlink que la mission concernée, pas les autres
    # =========================================================================
    context 'when CRA has entries for multiple missions' do
      let(:other_mission) { create(:mission) }

      let!(:entry_mission_1) do
        entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current)
        create(:cra_entry_cra, cra_entry: entry, cra: cra)
        create(:cra_entry_mission, cra_entry: entry, mission: mission)
        entry
      end

      let!(:entry_mission_2) do
        create(:cra_mission, cra: cra, mission: other_mission)
        entry = create(:cra_entry, quantity: 2, unit_price: 200, date: Date.current + 1.day)
        create(:cra_entry_cra, cra_entry: entry, cra: cra)
        create(:cra_entry_mission, cra_entry: entry, mission: other_mission)
        entry
      end

      it 'only unlinks the mission of the deleted entry' do
        described_class.call(entry: entry_mission_1, current_user: user)

        # Mission 1 should be unlinked (last entry deleted)
        expect(CraMission.where(cra: cra, mission: mission).count).to eq(0)
        # Mission 2 should remain linked
        expect(CraMission.where(cra: cra, mission: other_mission).count).to eq(1)
      end
    end

    # =========================================================================
    # 🧪 Test 4 — idempotence : CraMission déjà absent
    # Si le lien CraMission n'existe pas, pas d'erreur
    # =========================================================================
    context 'when CraMission link does not exist' do
      let!(:entry_without_cra_mission) do
        # Supprimer le CraMission créé dans le before
        CraMission.where(cra: cra, mission: mission).destroy_all

        entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current)
        create(:cra_entry_cra, cra_entry: entry, cra: cra)
        create(:cra_entry_mission, cra_entry: entry, mission: mission)
        entry
      end

      it 'does not raise an error' do
        expect do
          described_class.call(entry: entry_without_cra_mission, current_user: user)
        end.not_to raise_error
      end

      it 'still soft deletes the entry' do
        result = described_class.call(entry: entry_without_cra_mission, current_user: user)

        expect(result.entry).to be_discarded
      end
    end

    # =========================================================================
    # 🧪 Test 5 — comptage correct des entries actives
    # Seules les entries non-supprimées comptent pour le unlink
    # =========================================================================
    context 'when other entries for the mission are already deleted' do
      let!(:active_entry) do
        entry = create(:cra_entry, quantity: 1, unit_price: 100, date: Date.current)
        create(:cra_entry_cra, cra_entry: entry, cra: cra)
        create(:cra_entry_mission, cra_entry: entry, mission: mission)
        entry
      end

      let!(:deleted_entry) do
        entry = create(:cra_entry, :deleted, quantity: 2, unit_price: 200, date: Date.current + 1.day)
        create(:cra_entry_cra, cra_entry: entry, cra: cra)
        create(:cra_entry_mission, cra_entry: entry, mission: mission)
        entry
      end

      it 'unlinks mission when deleting the last active entry' do
        # deleted_entry doesn't count - active_entry is the last one
        expect do
          described_class.call(entry: active_entry, current_user: user)
        end.to change { CraMission.where(cra: cra, mission: mission).count }.from(1).to(0)
      end
    end
  end
end
