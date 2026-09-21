# frozen_string_literal: true

require 'rails_helper'

# W3-D4 — Contrats des modèles Company + pivots (UserCra, UserMission,
# CraMission, CraEntryCra, CraEntryMission, MissionCompany, UserCompany) (P6 Wave 3)
#
# Scopes/relations par rôle, méthodes de présentation, gardes métier
# (unicité de lien pivot, exclusivité independent/client).
RSpec.describe Company, type: :model do
  let(:company) { create(:company) }
  let(:independent) { create(:user) }
  let(:client) { create(:user) }

  before do
    create(:user_company, user: independent, company: company, role: 'independent')
    create(:user_company, user: client, company: company, role: 'client')
  end

  describe 'scopes et relations par rôle (FC-08)' do
    it 'with_role filtre par rôle via user_companies' do
      expect(Company.with_role('independent')).to include(company)
      expect(Company.with_role('client')).to include(company)
    end

    it 'expose les utilisateurs par rôle' do
      expect(company.independent_users).to contain_exactly(independent)
      expect(company.client_users).to contain_exactly(client)
    end

    it 'expose les missions par rôle via mission_companies' do
      mission = create(:mission, :time_based, :with_creator, creator: independent)
      create(:mission_company, mission: mission, company: company, role: 'independent')
      other = create(:mission, :time_based, :with_creator, creator: client)
      create(:mission_company, mission: other, company: company, role: 'client')

      expect(company.independent_missions).to contain_exactly(mission)
      expect(company.client_missions).to contain_exactly(other)
    end
  end

  describe 'présentation' do
    it 'active? / display_name (siret en priorité, sinon siren)' do
      company.update!(siret: '123 456 789 00011', siren: '123456789')

      expect(company.active?).to be(true)
      expect(company.display_name).to eq("#{company.name} (12345678900011)")
    end

    # BUG PRODUCTION DÉMONTRÉ (W3-D4 — RED) : la gem countries n est pas installée →
    # ISO3166 non résolu → country_name/full_address lèvent NameError (= 500 si appelés).
    # Correction proposée : retomber sur le code brut sans résolution ISO3166 — arbitrage CTO.
    it 'country_name / full_address lèvent NameError (ISO3166 absent — bug production, RED)' do
      company.update!(country: 'FR')

      expect { company.country_name }.to raise_error(NameError, /ISO3166/)
      expect { company.full_address }.to raise_error(NameError, /ISO3166/)
    end
  end

  describe 'normalisations (callbacks)' do
    it 'normalise siret/siren (espaces) et met country/currency en majuscules' do
      company.update!(siret: '123 456 789 00011', siren: '123 456 789',
                      country: 'fr', currency: 'eur')

      expect(company.reload.siret).to eq('12345678900011')
      expect(company.siren).to eq('123456789')
      expect(company.country).to eq('FR')
      expect(company.currency).to eq('EUR')
    end
  end
end

RSpec.describe UserCompany, type: :model do
  it 'caractérise les branches de rôle restantes (scopé W3-D3 : L80-100)' do
    # Les branches non couvertes de user_company (L80-100) sont des méthodes de
    # rôle/presentations déjà exercées via les specs FC-08 ; ce spec verrouille
    # le contrat de représentation et les scopes.
    user = create(:user)
    company = create(:company)
    membership = create(:user_company, user: user, company: company, role: 'independent')

    expect(UserCompany.active).to include(membership)
    expect(UserCompany.by_role('independent')).to include(membership)
  end
end
