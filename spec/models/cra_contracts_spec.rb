# frozen_string_literal: true

require 'rails_helper'

# W3-D4 — Contrats et invariants du modèle Cra (P6 Wave 3)
#
# Cycle de vie (draft → submitted → locked), transitions, discard/undiscard,
# invariants FC-07 PLATINUM (lock atomique avec Git Ledger : tout échec Git
# = rollback complet, CRA reste unlocked), validations métier.
RSpec.describe Cra, type: :model do
  let(:company) { create(:company) }
  let(:creator) { create(:user) }
  let(:cra) do
    create(:cra, :with_creator, creator: creator, year: 2026, month: 2, status: 'draft')
  end

  describe 'soft delete — discard/undiscard (contrat)' do
    it 'soft-delette un CRA draft' do
      cra.discard

      expect(cra.reload.discarded?).to be(true)
    end

    it 'refuse le discard d un CRA submitted (garde métier)' do
      cra.update!(status: 'submitted')

      expect(cra.discard).to be(false)
      expect(cra.errors[:base]).to include('Submitted or locked CRAs cannot be deleted')
      expect(cra.reload.discarded?).to be(false)
    end

    it 'refuse le discard d un CRA locked' do
      cra.update!(status: 'locked')

      expect(cra.discard).to be(false)
      expect(cra.reload.discarded?).to be(false)
    end

    it 'undiscard restaure le CRA (voie active)' do
      cra.discard

      cra.undiscard

      expect(cra.reload.discarded?).to be(false)
    end
  end

  describe 'modifiable? / display_name' do
    it 'draft et submitted sont modifiables, locked non' do
      cra.update!(status: 'draft')
      expect(cra.modifiable?).to be(true)
      cra.update!(status: 'submitted')
      expect(cra.modifiable?).to be(true)
      cra.update!(status: 'locked')
      expect(cra.modifiable?).to be(false)
    end

    it 'display_name expose mois/année et statut humanisé' do
      expect(cra.display_name).to eq('2/2026 (Draft)')
    end
  end

  describe 'modifiable_by? (DDD relation-driven)' do
    it 'autorise le créateur' do
      expect(cra.modifiable_by?(creator)).to be(true)
    end

    it 'refuse un utilisateur sans pivot créateur' do
      member = create(:user)
      expect(cra.modifiable_by?(member)).to be(false)
    end

    it 'refuse un utilisateur nil' do
      expect(cra.modifiable_by?(nil)).to be(false)
    end

    it 'refuse sur un CRA verrouillé (même le créateur)' do
      cra.update!(status: 'locked')
      expect(cra.modifiable_by?(creator)).to be(false)
    end
  end

  describe 'can_transition_to? (machine à états)' do
    it 'draft → submitted seulement' do
      cra
      expect(cra.can_transition_to?('submitted')).to be(true)
      expect(cra.can_transition_to?('locked')).to be(false)
    end

    it 'submitted → locked seulement' do
      cra.update!(status: 'submitted')
      expect(cra.can_transition_to?('locked')).to be(true)
      expect(cra.can_transition_to?('draft')).to be(false)
    end

    it 'locked est terminal' do
      cra.update!(status: 'locked')
      expect(cra.can_transition_to?('draft')).to be(false)
      expect(cra.can_transition_to?('submitted')).to be(false)
    end
  end

  describe 'transition_to!' do
    it 'applique une transition valide' do
      cra.transition_to!('submitted')

      expect(cra.reload.status).to eq('submitted')
    end

    it 'refuse une transition invalide (false + erreur)' do
      expect(cra.transition_to!('locked')).to be(false)
      expect(cra.reload.status).to eq('draft')
      expect(cra.errors[:status].join).to match(/Cannot transition from draft to locked/)
    end
  end

  describe 'submit! (draft → submitted, totaux recalculés côté serveur)' do
    it 'refuse un CRA non-draft' do
      cra.update!(status: 'locked')

      expect(cra.submit!).to be(false)
      expect(cra.errors[:base]).to include('Only draft CRAs can be submitted')
      expect(cra.reload.status).to eq('locked')
    end

    it 'soumet un draft et recalcule les totaux' do
      cra.submit!

      expect(cra.reload.status).to eq('submitted')
      expect(cra.total_days).to be_present
    end
  end

  describe 'lock! (FC-07 PLATINUM — transaction atomique avec Git Ledger)' do
    it 'refuse un CRA non-submitted' do
      cra.update!(status: 'draft')

      expect(cra.lock!).to be(false)
      expect(cra.errors[:base]).to include('Only submitted CRAs can be locked')
      expect(cra.reload.status).to eq('draft')
    end

    it 'verrouille en test avec le fake commit (INV-D12-01)' do
      cra.update!(status: 'submitted')

      result = cra.lock!

      expect(cra.reload.status).to eq('locked')
      expect(result[:commit_hash]).to eq("test-commit-#{cra.id}")
    end

    it 'annule le lock si le Git Ledger échoue (atomicité — CRA reste unlocked)' do
      cra.update!(status: 'submitted')
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GIT_LEDGER_REAL').and_return('true')

      Dir.mktmpdir do |dir|
        blocked = File.join(dir, 'blocked')
        FileUtils.touch(blocked)
        sc = GitLedgerRepository.singleton_class
        sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
        sc.const_set(:LEDGER_PATH, blocked)

        begin
          expect { cra.lock! }
            .to raise_error(StandardError, /Git Ledger commit failed/)
        ensure
          sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
          sc.const_set(:LEDGER_PATH, ENV.fetch('GIT_LEDGER_PATH', '/app/cra-ledger'))
        end
      end

      expect(cra.reload.status).to eq('submitted') # rollback complet — CRA remains unlocked
      expect(cra.errors[:base]).to include(/Failed to create immutable audit trail/)
    end
  end

  describe 'validations métier' do
    it 'rejette une currency hors ISO 4217' do
      cra.currency = 'EURO'

      expect(cra).not_to be_valid
      expect(cra.errors[:currency]).to be_present
    end

    it 'rejette un doublon à la re-validation (validate_uniqueness — la pivot existe à jour)' do
      cra

      # Le garde s exerce sur re-validation (update) : le pivot créateur existe
      # déjà en base à ce stade — la création initiale n est pas couverte par ce
      # garde Ruby (comportement observé, documenté au journal).
      create(:cra, :with_creator, creator: creator, year: 2026, month: 2)

      expect(cra.valid?).to be(false)
      expect(cra.errors[:base])
        .to include('A CRA already exists for this user, month, and year')
    end

    it 'rejette un statut hors contrat (ArgumentError du setter enum)' do
      expect { cra.status = 'archived' }
        .to raise_error(ArgumentError, /not a valid status/)
    end
  end

  describe 'relations (DDD — pivots uniques source de vérité)' do
    it 'expose le créateur, son id et les utilisateurs associés via user_cras' do
      expect(cra.creator).to eq(creator)
      expect(cra.creator_user_id).to eq(creator.id)
      expect(cra.relation_users).to include(creator)
    end
  end
end
