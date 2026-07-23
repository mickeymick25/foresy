# frozen_string_literal: true

require 'rails_helper'

# P4.7 — Migration de la colonne legacy `created_by_user_id` vers les tables pivot DDD
#
# Audit point M3 : la colonne `created_by_user_id` (bigint) coexiste avec les tables
# pivot `user_missions` / `user_cras` (rôle 'creator'). Le but est de remplacer toutes
# les références à `created_by_user_id` par des requêtes via les tables pivot, puis
# (dans un second temps) de supprimer la colonne.
#
# Cette spec valide l'étape 1 : le code utilise les pivots, la colonne DB reste
# présente comme fallback.
#
# NOTE : Les tests "la colonne est supprimée" sont volontairement écrits comme des
# assertions sur l'état futur (colonne supprimée). Ils échouent tant que la migration
# DB de suppression n'est pas appliquée — c'est l'audit point M3 qui reste ouvert.
RSpec.describe 'P4.7 — FK legacy migration (created_by_user_id → pivot tables)' do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  # ============================================================
  # Section 1 : La colonne legacy doit être supprimée (état futur)
  # ============================================================
  # Ces tests documentent l'état cible. Ils échouent tant que la migration DB de
  # suppression de `created_by_user_id` n'est pas appliquée (audit point M3 ouvert).
  describe 'colonne legacy supprimée (audit M3 — état futur)' do
    it 'Cra ne définit plus created_by_user_id comme attribut ActiveRecord' do
      expect(Cra.column_names).not_to include('created_by_user_id')
    end

    it 'Mission ne définit plus created_by_user_id comme attribut ActiveRecord' do
      expect(Mission.column_names).not_to include('created_by_user_id')
    end

    it 'Cra ne répond plus à created_by_user_id' do
      cra = create(:cra, :with_creator, creator: user)
      expect(cra).not_to respond_to(:created_by_user_id)
    end

    it 'Mission ne répond plus à created_by_user_id' do
      mission = create(:mission, :with_creator, creator: user)
      expect(mission).not_to respond_to(:created_by_user_id)
    end
  end

  # ============================================================
  # Section 2 : Le code lit le créateur via les tables pivot
  # ============================================================
  describe 'creator lu via les tables pivot (GREEN après migration du code)' do
    describe 'Cra' do
      it '#creator retourne l utilisateur via user_cras (role: creator)' do
        cra = create(:cra)
        create(:user_cra, cra: cra, user: user, role: 'creator')

        expect(cra.creator).to eq(user)
      end

      it '#creator_user_id retourne l id du créateur via user_cras' do
        cra = create(:cra)
        create(:user_cra, cra: cra, user: user, role: 'creator')

        expect(cra.creator_user_id).to eq(user.id)
      end

      it '#creator_user_id retourne nil si pas de créateur' do
        cra = create(:cra)

        expect(cra.creator_user_id).to be_nil
      end

      it '#creator ne lit pas la colonne created_by_user_id' do
        cra = create(:cra)
        # Créateur via pivot uniquement
        create(:user_cra, cra: cra, user: user, role: 'creator')

        expect(cra.creator).to eq(user)
      end
    end

    describe 'Mission' do
      it '#creator retourne l utilisateur via user_missions (role: creator)' do
        mission = create(:mission)
        create(:user_mission, mission: mission, user: user, role: 'creator')

        expect(mission.creator).to eq(user)
      end

      it '#creator_user_id retourne l id du créateur via user_missions' do
        mission = create(:mission)
        create(:user_mission, mission: mission, user: user, role: 'creator')

        expect(mission.creator_user_id).to eq(user.id)
      end

      it '#creator_user_id retourne nil si pas de créateur' do
        mission = create(:mission)

        expect(mission.creator_user_id).to be_nil
      end
    end
  end

  # ============================================================
  # Section 3 : Les permissions fonctionnent via les tables pivot
  # ============================================================
  describe 'permissions via les tables pivot (GREEN après migration du code)' do
    describe 'Cra#modifiable_by?' do
      it 'retourne true pour le créateur (via user_cras)' do
        cra = create(:cra, status: 'draft')
        create(:user_cra, cra: cra, user: user, role: 'creator')

        expect(cra.modifiable_by?(user)).to be true
      end

      it 'retourne false pour un autre utilisateur' do
        cra = create(:cra, status: 'draft')
        create(:user_cra, cra: cra, user: user, role: 'creator')

        expect(cra.modifiable_by?(other_user)).to be false
      end

      it 'retourne false pour un CRA locked (même pour le créateur)' do
        cra = create(:cra, status: 'locked')
        create(:user_cra, cra: cra, user: user, role: 'creator')

        expect(cra.modifiable_by?(user)).to be false
      end
    end

    describe 'Mission#modifiable_by?' do
      it 'retourne true pour le créateur (via user_missions)' do
        mission = create(:mission, status: 'lead')
        create(:user_mission, mission: mission, user: user, role: 'creator')

        expect(mission.modifiable_by?(user)).to be true
      end

      it 'retourne false pour un autre utilisateur' do
        mission = create(:mission, status: 'lead')
        create(:user_mission, mission: mission, user: user, role: 'creator')

        expect(mission.modifiable_by?(other_user)).to be false
      end
    end

    describe 'Cra.accessible_to (scope)' do
      it 'inclut les CRAs où l utilisateur est créateur' do
        cra = create(:cra)
        create(:user_cra, cra: cra, user: user, role: 'creator')

        expect(Cra.accessible_to(user)).to include(cra)
      end

      it 'n inclut pas les CRAs d un autre créateur (sans accès via missions)' do
        cra = create(:cra)
        create(:user_cra, cra: cra, user: other_user, role: 'creator')

        expect(Cra.accessible_to(user)).not_to include(cra)
      end
    end

    describe 'Mission.accessible_to (scope)' do
      it 'inclut les missions où l utilisateur est créateur' do
        mission = create(:mission)
        create(:user_mission, mission: mission, user: user, role: 'creator')

        expect(Mission.accessible_to(user)).to include(mission)
      end

      it 'n inclut pas les missions d un autre créateur (sans accès via companies)' do
        mission = create(:mission)
        create(:user_mission, mission: mission, user: other_user, role: 'creator')

        expect(Mission.accessible_to(user)).not_to include(mission)
      end
    end
  end

  # ============================================================
  # Section 4 : Les services utilisent les pivots pour les permissions
  # ============================================================
  describe 'services utilisent creator_user_id (via pivot) pour les permissions' do
    describe 'CraServices::Destroy' do
      it 'autorise la suppression pour le créateur (via pivot)' do
        cra = create(:cra, status: 'draft')
        create(:user_cra, cra: cra, user: user, role: 'creator')

        result = CraServices::Destroy.call(cra: cra, current_user: user)
        expect(result.success?).to be true
      end

      it 'refuse la suppression pour un non-créateur (via pivot)' do
        cra = create(:cra, status: 'draft')
        create(:user_cra, cra: cra, user: other_user, role: 'creator')

        result = CraServices::Destroy.call(cra: cra, current_user: user)
        expect(result.failure?).to be true
        expect(result.status).to eq(:forbidden)
      end
    end

    describe 'CraEntryServices::Create' do
      it 'autorise la création d entries pour le créateur (via pivot)' do
        cra = create(:cra, status: 'draft')
        create(:user_cra, cra: cra, user: user, role: 'creator')

        result = CraEntryServices::Create.call(
          cra: cra,
          attributes: { date: Date.current, quantity: 1.0, unit_price: 50_000 },
          current_user: user
        )
        expect(result.success?).to be true
      end

      it 'refuse la création d entries pour un non-créateur (via pivot)' do
        cra = create(:cra, status: 'draft')
        create(:user_cra, cra: cra, user: other_user, role: 'creator')

        result = CraEntryServices::Create.call(
          cra: cra,
          attributes: { date: Date.current, quantity: 1.0, unit_price: 50_000 },
          current_user: user
        )
        expect(result.failure?).to be true
        expect(result.status).to eq(:forbidden)
      end
    end
  end

  # ============================================================
  # Section 5 : Le code applicatif ne référence plus created_by_user_id
  # ============================================================
  # Vérifie que le code applicatif (hors migrations/schema/factories de compat)
  # ne lit plus la colonne legacy.
  describe 'code applicatif sans référence à created_by_user_id' do
    it 'les modèles Cra et Mission exposent creator_user_id' do
      expect(Cra.instance_methods).to include(:creator_user_id)
      expect(Mission.instance_methods).to include(:creator_user_id)
    end

    it 'Cra#creator_user_id lit via user_cras (pas via la colonne)' do
      cra = create(:cra)
      create(:user_cra, cra: cra, user: user, role: 'creator')

      # Le résultat vient du pivot
      expect(cra.creator_user_id).to eq(user.id)
      # Même si on modifie la colonne, creator_user_id suit le pivot
      cra.update_column(:created_by_user_id, other_user.id)
      expect(cra.creator_user_id).to eq(user.id)
    end

    it 'Mission#creator_user_id lit via user_missions (pas via la colonne)' do
      mission = create(:mission)
      create(:user_mission, mission: mission, user: user, role: 'creator')

      expect(mission.creator_user_id).to eq(user.id)
      mission.update_column(:created_by_user_id, other_user.id)
      expect(mission.creator_user_id).to eq(user.id)
    end
  end
end
