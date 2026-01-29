# frozen_string_literal: true

module GitLedgerService
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
end
