# frozen_string_literal: true

# GitLedgerService
#
# Service responsable du versioning Git des CRA verrouillés.
# Implements FC 07 - CRA Management avec Git Ledger pour l'immutabilité légale.
#
# Usage:
#   GitLedgerService.commit_cra_lock!(cra)
#
# Dependencies:
#   - GitLedgerRepository (git_ledger_repository.rb)
#   - GitLedgerPayload (git_ledger_payload.rb)
class GitLedgerService
  # INV-D12-03 (#28) — chemin contractuel par défaut (valeur fallback de
  # GitLedgerRepository::LEDGER_PATH, L16 — fichier non modifié, épinglé par
  # INV-D12-02). La garde en tête de branche réelle compare ledger_path à cette
  # valeur (via GitLedgerRepository.ledger_path — le lookup eigenclass voit les
  # stub_const/overlays, contrairement à un accès externe GitLedgerRepository::LEDGER_PATH).
  DEFAULT_LEDGER_PATH = '/app/cra-ledger'
  # FC-07 PLATINUM: Use contract-specified path for Render compatibility
  # Contract: "Local path: /app/cra-ledger" — résolu par GitLedgerRepository
  # (D-12 : configurable via GIT_LEDGER_PATH, fallback /app/cra-ledger — INV-D12-02)

  # GitLedgerError
  #
  # Exception spécifique au GitLedgerService pour gérer les erreurs
  # liées au versioning Git des CRA verrouillés.
  #
  # Used in:
  #   - GitLedgerService.commit_cra_lock!
  #   - Cra#lock! (rescue)
  #
  class GitLedgerError < StandardError
    # No additional functionality needed - inherits from StandardError
  end

  class << self
    def commit_cra_lock!(cra)
      # D-12 / INV-D12-01 — fake uniquement en test ET sans activation explicite.
      # Trois états de GIT_LEDGER_REAL : absent → fake, != "true" (1/yes/false/TRUE/on) →
      # fake, == "true" → vrai repository Git. Aucune valeur accidentelle n'active le réel.
      return fake_commit(cra) if Rails.env.test? && ENV['GIT_LEDGER_REAL'] != 'true'

      # BACKLOG #28 (O-1bis) — INV-D12-03 : fail-fast EN PREMIER (avant validate_cra!
      # et tout appel Git) : en test, GIT_LEDGER_REAL=true n'est PAS une autorisation
      # d'écrire le ledger contractuel par défaut — la cible doit être un overlay
      # (GIT_LEDGER_PATH résolu au boot — serveur E2E CI — ou stub_const runtime).
      # Le message sera wrapé par la porte contractuelle (« Git Ledger commit failed: … »).
      if Rails.env.test? && ENV['GIT_LEDGER_REAL'] == 'true' &&
         GitLedgerRepository.ledger_path == DEFAULT_LEDGER_PATH
        raise GitLedgerError,
              'Real ledger without overlay — GIT_LEDGER_REAL=true requires an override ' \
              '(GIT_LEDGER_PATH at boot, or const_set) (INV-D12-03)'
      end

      validate_cra!(cra)
      GitLedgerRepository.ensure_initialized!

      return handle_existing_commit(cra) if cra_already_committed?(cra)

      execute_commit(cra)
    rescue StandardError => e
      Rails.logger.error "[GitLedgerService] Failed to commit CRA #{cra.id}: #{e.message}"
      raise GitLedgerService::GitLedgerError, "Git Ledger commit failed: #{e.message}"
    end

    def cra_already_committed?(cra)
      return false unless GitLedgerRepository.exists?

      GitLedgerRepository.commit_exists_for_cra?(cra.id)
    end

    def get_existing_commit_info(cra)
      return nil unless GitLedgerRepository.exists?

      GitLedgerRepository.find_commit_info(cra.id)
    end

    def ensure_ledger_repository!
      GitLedgerRepository.ensure_initialized!
    end

    def cleanup_repository!(force: false)
      GitLedgerRepository.cleanup!(force: force)
    end

    def repository_info
      GitLedgerRepository.info
    end

    def valid?
      GitLedgerRepository.valid?
    end

    private

    def validate_cra!(cra)
      raise ArgumentError, 'CRA must be locked' unless cra.locked?
      raise ArgumentError, 'CRA must be persisted' unless cra.persisted?
    end

    def fake_commit(cra)
      {
        cra_id: cra.id,
        commit_hash: "test-commit-#{cra.id}",
        committed_at: Time.current
      }
    end
    private :fake_commit

    def handle_existing_commit(cra)
      Rails.logger.warn "[GitLedgerService] CRA #{cra.id} already committed"
      get_existing_commit_info(cra)
    end

    def execute_commit(cra)
      payload = GitLedgerPayload.build(cra)
      commit_info = nil

      ActiveRecord::Base.transaction do
        commit_info = GitLedgerRepository.create_commit(cra, payload)
        log_success(cra, commit_info)
      end

      commit_info
    end

    def log_success(cra, commit_info)
      Rails.logger.info "[GitLedgerService] Committed CRA #{cra.id}"
      Rails.logger.info "[GitLedgerService] #{commit_info[:commit_hash]}"
    end
  end
end
