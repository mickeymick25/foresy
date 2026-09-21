# frozen_string_literal: true

require 'rails_helper'

# W3-D1 — Caractérisation de CraServices::List (P6 Wave 3)
#
# Plan : docs/technical/testing/2026_09_20_p6_wave3_tracker.md §3/§4
#
# Contexte de reconnaissance :
# - AUCUN spec unitaire n'existait pour ce service (grep exhaustif) — les specs
#   requête index/deprecation le STUBBENT (« avoid domain setup issues »)
# - les 16 specs Mini-FC-01 visaient l'ancien namespace Api::V1::Cras::ListService
#   et ont disparu à la migration unifiée du 11/01 → contrat de filtrage sans filet
# - DIVERGENCE documentée : Mini-FC-01 fige per_page défaut 25, le code fait 20
#   (caractérisé tel quel — arbitrage doc/contrat CTO attendu)
#
# Règle P6.0 : caractérisation du comportement EXISTANT — stubs limités au strict
# nécessaire (déclenchement du rescue) ; tout le reste est réel (factories, DB).
RSpec.describe CraServices::List do
  let(:company) { create(:company) }
  let(:user) { create(:user) }
  let!(:membership) { create(:user_company, user: user, company: company, role: 'independent') }

  def create_cra(creator, attrs = {})
    create(:cra, :with_creator, creator: creator,
                                year: 2026, month: 1, status: 'draft', **attrs)
  end

  describe 'current_user absent' do
    it 'retourne bad_request :missing_user' do
      result = described_class.call(current_user: nil)

      expect(result).to be_failure
      expect(result.status).to eq(:bad_request)
      expect(result.error).to eq(:missing_user)
      expect(result.message).to eq('Current user is required')
    end
  end

  describe 'validation des filtres' do
    it 'rejette un status hors contrat (invalid_status_filter)' do
      result = described_class.call(current_user: user, filters: { status: 'archived' })

      expect(result).to be_failure
      expect(result.status).to eq(:bad_request)
      expect(result.error).to eq(:invalid_status_filter)
      expect(result.message).to eq('Invalid status filter. Must be: draft, submitted, or locked')
    end

    it 'exige year quand month est présent (Mini-FC-01 : missing_year_for_month)' do
      result = described_class.call(current_user: user, filters: { month: 2 })

      expect(result).to be_failure
      expect(result.error).to eq(:missing_year_for_month)
      expect(result.message).to eq('year is required when month is specified')
    end

    it 'rejette un month hors 1..12 (invalid_month_filter)' do
      result = described_class.call(current_user: user, filters: { month: 13, year: 2026 })

      expect(result).to be_failure
      expect(result.error).to eq(:invalid_month_filter)
      expect(result.message).to eq('Invalid month filter. Must be between 1 and 12')
    end

    it 'rejette une year antérieure à 2000 (invalid_year_filter)' do
      result = described_class.call(current_user: user, filters: { year: 1999 })

      expect(result).to be_failure
      expect(result.error).to eq(:invalid_year_filter)
      expect(result.message).to eq('Year must be 2000 or later')
    end

    it 'rejette une currency hors ISO 4217 (invalid_currency_filter)' do
      result = described_class.call(current_user: user, filters: { currency: 'EURO' })

      expect(result).to be_failure
      expect(result.error).to eq(:invalid_currency_filter)
      expect(result.message).to eq('Invalid currency filter. Must be a valid ISO 4217 code')
    end
  end

  describe 'application des filtres (AND)' do
    before do
      create_cra(user, year: 2026, month: 1, status: 'draft', description: 'Audit trimestriel')
      create_cra(user, year: 2026, month: 2, status: 'submitted', description: 'Relevé bancaire')
      create_cra(user, year: 2025, month: 12, status: 'draft', description: 'Audit annuel')
      create_cra(user, year: 2025, month: 6, status: 'locked', currency: 'USD')
    end

    it 'filtre par year seul' do
      result = described_class.call(current_user: user, filters: { year: 2026 })

      expect(result).to be_success
      expect(result.data[:pagination][:total]).to eq(2)
      expect(result.data[:cras].map(&:month)).to contain_exactly(1, 2)
    end

    it 'applique year + month (AND)' do
      result = described_class.call(current_user: user, filters: { year: 2026, month: 2 })

      expect(result.data[:pagination][:total]).to eq(1)
      expect(result.data[:cras].first.status).to eq('submitted')
    end

    it 'filtre par status seul' do
      result = described_class.call(current_user: user, filters: { status: 'submitted' })

      expect(result.data[:pagination][:total]).to eq(1)
      expect(result.data[:cras].first.status).to eq('submitted')
    end

    it 'filtre par currency (filtre hors Mini-FC-01, présent dans le code)' do
      result = described_class.call(current_user: user, filters: { currency: 'USD' })

      expect(result.data[:pagination][:total]).to eq(1)
      expect(result.data[:cras].first.currency).to eq('USD')
    end

    it 'recherche dans description avec ILIKE insensible à la casse' do
      result = described_class.call(current_user: user, filters: { description: 'AUDIT' })

      expect(result).to be_success
      expect(result.data[:pagination][:total]).to eq(2)
      expect(result.data[:cras].map(&:description)).to all(match(/audit/i))
    end

    it 'combine les filtres (AND) : year + status' do
      result = described_class.call(current_user: user, filters: { year: 2026, status: 'draft' })

      expect(result.data[:pagination][:total]).to eq(1)
      expect(result.data[:cras].first.month).to eq(1)
    end

    it 'retourne le message de succès contractuel' do
      result = described_class.call(current_user: user)

      expect(result).to be_success
      expect(result.message).to eq('CRAs listed successfully')
      expect(result.data.keys).to contain_exactly(:cras, :pagination)
    end
  end

  describe 'soft delete' do
    it 'ne retourne jamais un CRA soft-deleté (Mini-FC-01)' do
      cra = create_cra(user, year: 2026, month: 3)
      cra.destroy

      result = described_class.call(current_user: user, filters: { year: 2026 })

      expect(result).to be_success
      expect(result.data[:pagination][:total]).to eq(0)
      expect(result.data[:cras]).to be_empty
    end
  end

  describe 'pagination' do
    it 'caractérise le défaut per_page 20 (DIVERGENCE Mini-FC-01 qui fige 25) + hash complet + order desc' do
      21.times { |i| create_cra(user, year: 2001 + i, month: 1) }

      result = described_class.call(current_user: user)

      pagination = result.data[:pagination]
      expect(pagination).to include(total: 21, page: 1, per_page: 20, pages: 2,
                                    prev: nil)
      expect(pagination[:next]).to eq(2)
      expect(result.data[:cras].size).to eq(20)
      expect(result.data[:cras].first.year).to eq(2021) # order year: :desc
      expect(result.data[:cras].last.year).to eq(2002)
    end

    it 'limite per_page à 100 maximum (clamp)' do
      3.times { create_cra(user) }

      result = described_class.call(current_user: user, page: 1, per_page: 500)

      expect(result.data[:pagination][:per_page]).to eq(100)
    end

    it 'borne la page à 1 minimum (page 0 → page 1)' do
      create_cra(user, year: 2026, month: 5)

      result = described_class.call(current_user: user, page: 0, per_page: 10)

      expect(result.data[:pagination][:page]).to eq(1)
      expect(result.data[:pagination][:total]).to eq(1)
    end
  end

  describe 'sécurité — Cra.accessible_to (scope W1-D2)' do
    it 'ne retourne rien pour un utilisateur sans relation' do
      other = create(:user)
      create_cra(user, year: 2026, month: 4)

      result = described_class.call(current_user: other)

      expect(result).to be_success
      expect(result.data[:cras]).to be_empty
      expect(result.data[:pagination][:total]).to eq(0)
    end
  end

  describe 'résilience — fetch_cras' do
    it 'retourne internal_error :query_failed quand la requête échoue' do
      allow(Cra).to receive(:accessible_to).and_raise(StandardError, 'boom')

      result = described_class.call(current_user: user)

      expect(result).to be_failure
      expect(result.status).to eq(:internal_error)
      expect(result.error).to eq(:query_failed)
      expect(result.message).to eq('Failed to query CRAs')
    end
  end
end