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

  # W3-D2 — Caractérisation des chemins non couverts (tracker p6_wave3 §W3-D2)
  # Les délégations, le chemin already-committed, les gardes validate_cra!, le
  # fail-closed de history_rewritten? et le chaînage d erreur sont le contrat réel
  # d'un composant de sécurité (immutabilité légale) — pas de chasse au pourcentage :
  # log_stderr et quelques branches rescue défensives restent documentés si non naturels.
  describe 'chemins non couverts (W3-D2)' do
    let(:cra) do
      create(:cra, :with_creator, creator: user, year: 2026, month: 9,
                                  status: 'locked', locked_at: Time.current)
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GIT_LEDGER_REAL').and_return('true')
    end

    def with_ledger_tmpdir
      Dir.mktmpdir('w3_ledger') do |tmpdir|
        sc = GitLedgerRepository.singleton_class
        sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
        sc.const_set(:LEDGER_PATH, tmpdir)
        yield tmpdir
      ensure
        sc = GitLedgerRepository.singleton_class
        sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
        sc.const_set(:LEDGER_PATH, ENV.fetch('GIT_LEDGER_PATH', '/app/cra-ledger'))
      end
    end

    describe 'validate_cra! — gardes REAL (ArgumentError → GitLedgerError)' do
      it 'refuse un CRA non verrouillé' do
        unlocked = create(:cra, :with_creator, creator: user, year: 2026, month: 9, status: 'draft')

        expect { described_class.commit_cra_lock!(unlocked) }
          .to raise_error(described_class::GitLedgerError,
                          'Git Ledger commit failed: CRA must be locked')
      end

      it 'refuse un CRA non persisté' do
        unpersisted = build(:cra, status: 'locked')

        expect { described_class.commit_cra_lock!(unpersisted) }
          .to raise_error(described_class::GitLedgerError,
                          'Git Ledger commit failed: CRA must be persisted')
      end
    end

    describe 'double lock — handle_existing_commit (idempotence légale)' do
      it 'retourne l info existante sans créer de nouveau commit' do
        with_ledger_tmpdir do
          cra
          first = described_class.commit_cra_lock!(cra)
          expect(first[:commit_hash]).to match(/\A[0-9a-f]{40}\z/)

          count_after_first = GitLedgerRepository.info[:commit_count]
          allow(Rails.logger).to receive(:warn)

          second = described_class.commit_cra_lock!(cra)

          expect(second[:commit_hash]).to eq(first[:commit_hash])
          expect(second[:message]).to match(/CRA locked — cra:#{cra.id}/)
          expect(second[:timestamp]).to be_present
          expect(GitLedgerRepository.info[:commit_count]).to eq(count_after_first) # delta 0
          expect(Rails.logger).to have_received(:warn)
            .with("[GitLedgerService] CRA #{cra.id} already committed")
        end
      end
    end

    describe 'get_existing_commit_info' do
      it 'retourne nil quand le repository est absent' do
        expect(described_class.get_existing_commit_info(cra)).to be_nil
      end

      it 'retourne nil quand le repo est initialisé mais sans commit pour ce CRA' do
        with_ledger_tmpdir do
          GitLedgerRepository.ensure_initialized!
          expect(described_class.get_existing_commit_info(cra)).to be_nil
        end
      end
    end

    describe 'échec initialisation → chaîne GitLedgerError' do
      it 'wrappe l échec de git init en GitLedgerError' do
        Dir.mktmpdir do |dir|
          blocked = File.join(dir, 'blocked')
          FileUtils.touch(blocked) # chemin existant en tant que FICHIER → mkdir_p échoue

          sc = GitLedgerRepository.singleton_class
          sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
          sc.const_set(:LEDGER_PATH, blocked)

          begin
            expect { described_class.commit_cra_lock!(cra) }
              .to raise_error(
                described_class::GitLedgerError,
                /Git Ledger commit failed: Failed to initialize Git Ledger:/
              )
          ensure
            sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
            sc.const_set(:LEDGER_PATH, ENV.fetch('GIT_LEDGER_PATH', '/app/cra-ledger'))
          end
        end
      end
    end

    describe 'délégations repository' do
      it 'repository_info retourne le contrat complet sur un repo initialisé (fetch_info)' do
        with_ledger_tmpdir do |tmpdir|
          GitLedgerRepository.ensure_initialized!

          info = described_class.repository_info

          expect(info).to include(exists: true, path: tmpdir, branch: 'main', initialized: true)
          expect(info[:commit_count]).to be >= 1
          expect(info[:last_commit]).to be_present
        end
      end

      it 'info retourne {exists: false} quand le chemin est absent' do
        Dir.mktmpdir do |dir|
          absent = File.join(dir, 'absent')
          sc = GitLedgerRepository.singleton_class
          sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
          sc.const_set(:LEDGER_PATH, absent)

          begin
            expect(described_class.repository_info).to eq(exists: false)
          ensure
            sc.send(:remove_const, :LEDGER_PATH) if sc.const_defined?(:LEDGER_PATH)
            sc.const_set(:LEDGER_PATH, ENV.fetch('GIT_LEDGER_PATH', '/app/cra-ledger'))
          end
        end
      end

      it 'valid? confirme un repo initialisé (git rev-parse)' do
        with_ledger_tmpdir do
          GitLedgerRepository.ensure_initialized!
          expect(described_class.valid?).to be(true)
        end
      end

      it 'ensure_ledger_repository! initialise sans lever' do
        with_ledger_tmpdir do
          expect { described_class.ensure_ledger_repository! }.not_to raise_error
          expect(GitLedgerRepository.initialized?).to be(true)
        end
      end

      it 'cleanup_repository! supprime le répertoire (puis exists? false)' do
        with_ledger_tmpdir do |tmpdir|
          GitLedgerRepository.ensure_initialized!
          described_class.cleanup_repository!(force: true)

          expect(GitLedgerRepository.exists?).to be(false)
          FileUtils.mkdir_p(tmpdir) # Dir.mktmpdir nettoie lui-même le répertoire à la sortie
        end
      end
    end

    describe 'history_rewritten? — fail-closed (garde anti-rewrite)' do
      it 'lève Git history rewrite detected quand le check open3 lève (fail-closed sur exception)' do
        with_ledger_tmpdir do
          cra
          GitLedgerRepository.ensure_initialized!
          allow(Open3).to receive(:capture3).and_call_original
          allow(Open3).to receive(:capture3)
            .with('git', 'config', 'receive.denyNonFastForwards', anything)
            .and_raise(StandardError, 'open3 down')

          expect { described_class.commit_cra_lock!(cra) }
            .to raise_error(described_class::GitLedgerError, /Git history rewrite detected/)
        end
      end
    end
  end
end
