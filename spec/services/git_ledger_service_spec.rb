# frozen_string_literal: true

# D-12 — Gate du Git Ledger : résolution ENV de LEDGER_PATH + trois états de GIT_LEDGER_REAL
#
# Invariants du chantier (chiffrage D-12, validés co-CTO 17/09) :
#   INV-D12-01 — En l'absence de GIT_LEDGER_REAL=true, aucun test RSpec n'exécute
#                le chemin Git Ledger réel (fake commit, repository jamais invoqué).
#   INV-D12-02 — GIT_LEDGER_PATH absent conserve '/app/cra-ledger'.

require 'rails_helper'
require 'tmpdir'

RSpec.describe GitLedgerService, type: :model do
  let(:repo_source) { File.read(Rails.root.join('app/services/git_ledger_repository.rb')) }
  let(:user) { create(:user) }
  let(:cra) do
    create(:cra, :with_creator, creator: user, year: 2026, month: 9,
                                status: 'locked', locked_at: Time.current)
  end

  describe 'LEDGER_PATH resolution (INV-D12-02)' do
    it 'defaults to /app/cra-ledger when GIT_LEDGER_PATH is absent' do
      expect(ENV.fetch('GIT_LEDGER_PATH', nil)).to be_nil
      expect(GitLedgerRepository::LEDGER_PATH).to eq('/app/cra-ledger')
    end

    it 'reads GIT_LEDGER_PATH via ENV.fetch with the contract fallback (D-12)' do
      expect(repo_source)
        .to match(%r{LEDGER_PATH\s*=\s*ENV\.fetch\('GIT_LEDGER_PATH',\s*'/app/cra-ledger'\)})
    end
  end

  describe 'commit_cra_lock! — GIT_LEDGER_REAL states (INV-D12-01)' do
    before do
      # ENV est lu partout (Rails, bundler) : défaut = comportement original,
      # override ciblé sur GIT_LEDGER_REAL uniquement
      allow(ENV).to receive(:[]).and_call_original
    end

    it 'returns the fake commit when GIT_LEDGER_REAL is absent' do
      allow(ENV).to receive(:[]).with('GIT_LEDGER_REAL').and_return(nil)

      result = described_class.commit_cra_lock!(cra)

      expect(result[:commit_hash]).to eq("test-commit-#{cra.id}")
    end

    it 'returns the fake commit for accidental values (1, yes, false, TRUE, on)' do
      %w[1 yes false TRUE on].each do |accidental|
        allow(ENV).to receive(:[]).with('GIT_LEDGER_REAL').and_return(accidental)

        result = described_class.commit_cra_lock!(cra)

        expect(result[:commit_hash]).to eq("test-commit-#{cra.id}")
      end
    end

    it 'commits to the REAL repository when GIT_LEDGER_REAL == "true" (D-12)' do
      allow(ENV).to receive(:[]).with('GIT_LEDGER_REAL').and_return('true')

      Dir.mktmpdir('d12_ledger') do |tmpdir|
        # Overlay sur le singleton (pattern de git_ledger_integration_spec) : la constante
        # originale vit dans la table du module — le remove_const initial est optionnel
        begin
          GitLedgerRepository.singleton_class.send(:remove_const, :LEDGER_PATH)
        rescue NameError
          nil
        end
        GitLedgerRepository.singleton_class.const_set(:LEDGER_PATH, tmpdir)

        begin
          result = described_class.commit_cra_lock!(cra)

          expect(result[:commit_hash]).to match(/\A[0-9a-f]{40}\z/)
          expect(result[:commit_hash]).not_to start_with('test-commit-')
          expect(GitLedgerRepository.initialized?).to be(true)
          expect(GitLedgerRepository.commit_exists_for_cra?(cra.id)).to be(true)
        ensure
          # Le répertoire (ledger inclus) est nettoyé par Dir.mktmpdir lui-même —
          # on ne restaure que l'overlay de constante.
          GitLedgerRepository.singleton_class.send(:remove_const, :LEDGER_PATH)
          GitLedgerRepository.singleton_class.const_set(:LEDGER_PATH,
                                                        ENV.fetch('GIT_LEDGER_PATH', '/app/cra-ledger'))
        end
      end
    end
  end
end
