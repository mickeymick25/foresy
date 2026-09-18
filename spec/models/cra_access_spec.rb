# frozen_string_literal: true

# W1-D2 — Caractérisation de la sécurité vivante : `Cra.accessible_to`
# (plan : docs/technical/testing/p6_wave1_tracker.md §3 W1-D2)
#
# Le scope est la source d'autorisation RÉELLE de l'API CRA :
# - CrasController#validate_cra_access! → Cra.accessible_to(user).active
# - CraEntriesController#validate_cra_access! → idem
# - CraServices::List#build_base_query → idem
#
# Règles de caractérisation (P6.0) : observer le comportement EXISTANT.
# Toute divergence avec le comportement attendu devient un cycle RED explicite,
# jamais contourné pour préserver la baseline.
#
# Les chemins créateur / non-créateur sont déjà caractérisés dans la gate DDD
# (spec/integration/p4_7_fk_legacy_migration_spec.rb) — le présent fichier
# caractérise la voie via-missions FC06 et ses frontières.
require 'rails_helper'

RSpec.describe 'Cra.accessible_to', type: :model do
  # Le membre : lié à la société S via un user_company, mais PAS créateur des CRAs testés
  let(:member) { create(:user) }
  let(:member_company) { create(:company) }

  let(:creator) { create(:user) }
  let(:linked_mission) do
    create(:mission, :time_based, :with_creator, creator: creator)
  end

  before do
    create(:user_company, user: member, company: member_company, role: 'independent')
    # FC06 : la société du membre est liée à la mission du créateur
    create(:mission_company, mission: linked_mission, company: member_company, role: 'independent')
  end

  describe 'voie via-missions FC06 (chemin de sécurité vivant)' do
    it 'inclut un CRA d un autre créateur lorsque le membre a accès via sa société et la mission' do
      cra = create(:cra, :with_creator, creator: creator, year: 2026, month: 5)
      create(:cra_mission, cra: cra, mission: linked_mission)

      expect(Cra.accessible_to(member)).to include(cra)
    end

    it 'inclut le CRA quel que soit le rôle pivot du membre (client également)' do
      client_member = create(:user)
      client_company = create(:company)
      create(:user_company, user: client_member, company: client_company, role: 'client')
      create(:mission_company, mission: linked_mission, company: client_company, role: 'client')

      cra = create(:cra, :with_creator, creator: creator, year: 2026, month: 6)
      create(:cra_mission, cra: cra, mission: linked_mission)

      expect(Cra.accessible_to(client_member)).to include(cra)
    end

    it 'exclut le CRA si le membre n a aucune société liée à une mission du CRA' do
      cra = create(:cra, :with_creator, creator: creator, year: 2026, month: 7)
      create(:cra_mission, cra: cra, mission: linked_mission)

      stranger = create(:user)
      stranger_company = create(:company)
      create(:user_company, user: stranger, company: stranger_company, role: 'independent')
      # La société du stranger est liée à une AUTRE mission — pas celle du CRA
      other_mission = create(:mission, :time_based, :with_creator, creator: creator)
      create(:mission_company, mission: other_mission, company: stranger_company, role: 'independent')

      expect(Cra.accessible_to(stranger)).not_to include(cra)
    end

    it 'exclut le CRA lié à aucune mission (aucune voie ouverte pour un non-créateur)' do
      cra = create(:cra, :with_creator, creator: creator, year: 2026, month: 8)

      expect(Cra.accessible_to(member)).not_to include(cra)
    end
  end

  describe 'comportement observé aux frontières (soft delete) — relevé pour décision' do
    it 'OBSERVATION : un CRA soft-deleté reste retourné par le scope nu (les appelants chaînent .active)' do
      cra = create(:cra, :with_creator, creator: creator, year: 2026, month: 1)
      create(:cra_mission, cra: cra, mission: linked_mission)
      cra.update!(deleted_at: Time.current)

      expect(Cra.accessible_to(member)).to include(cra)
      expect(Cra.accessible_to(member).active).not_to include(cra)
    end

    it 'OBSERVATION : une mission soft-deletée continue d octroyer l accès via-missions' do
      cra = create(:cra, :with_creator, creator: creator, year: 2026, month: 2)
      create(:cra_mission, cra: cra, mission: linked_mission)
      linked_mission.update!(deleted_at: Time.current)

      expect(Cra.accessible_to(member)).to include(cra)
    end

    it 'OBSERVATION : un user_company soft-deleté (FC-08) continue d octroyer l accès via-missions' do
      cra = create(:cra, :with_creator, creator: creator, year: 2026, month: 3)
      create(:cra_mission, cra: cra, mission: linked_mission)

      member.user_companies.update_all(deleted_at: Time.current)

      expect(Cra.accessible_to(member)).to include(cra)
    end
  end
end
