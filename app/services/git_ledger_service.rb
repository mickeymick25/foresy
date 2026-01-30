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
  # FC-07 PLATINUM: Use contract-specified path for Render compatibility
  # Contract: "Local path: /app/cra-ledger"
  LEDGER_PATH = '/app/cra-ledger'
  LEDGER_BRANCH = 'main'

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
