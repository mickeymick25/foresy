# frozen_string_literal: true

require 'shellwords'

# GitLedgerRepository
#
# Helper module for Git repository operations used by GitLedgerService.
# Handles low-level Git operations for CRA immutability ledger.
module GitLedgerRepository
  LEDGER_PATH = '/app/cra-ledger'
  LEDGER_BRANCH = 'main'

  class << self
    def exists?
      File.exist?(LEDGER_PATH)
    end

    def initialized?
      exists? && File.exist?(File.join(LEDGER_PATH, '.git'))
    end

    def valid?
      return false unless initialized?

      Dir.chdir(LEDGER_PATH) do
        system('git', 'rev-parse', '--git-dir', out: File::NULL, err: File::NULL)
      end
    rescue StandardError
      false
    end

    def ensure_initialized!
      return if initialized?

      initialize_repository
    end

    def cleanup!(force: false)
      return if Rails.env.production? && !force
      return unless exists?

      FileUtils.rm_rf(LEDGER_PATH)
      Rails.logger.info '[GitLedgerRepository] Cleaned up repository'
    end

    def info
      return { exists: false } unless exists?

      fetch_info
    rescue StandardError
      { exists: false, error: 'Failed to read repository info' }
    end

    def commit_exists_for_cra?(cra_id)
      sanitized_id = Shellwords.escape(cra_id.to_s)
      Dir.chdir(LEDGER_PATH) do
        `git log --grep="CRA locked.*#{sanitized_id}" --oneline 2>/dev/null`.present?
      end
    end

    def find_commit_info(cra_id)
      sanitized_id = Shellwords.escape(cra_id.to_s)
      Dir.chdir(LEDGER_PATH) do
        result = `git log --grep="CRA locked.*#{sanitized_id}" --pretty=format:"%H|%s|%ad" --date=iso 2>/dev/null`
        parse_commit_result(result)
      end
    end

    def create_commit(cra, payload)
      Dir.chdir(LEDGER_PATH) do
        configure_identity
        filename = write_payload(cra, payload)
        perform_commit(cra, filename)
      end
    end

    private

    def initialize_repository
      FileUtils.mkdir_p(LEDGER_PATH)
      Dir.chdir(LEDGER_PATH) do
        system('git', 'init', out: File::NULL, err: File::NULL)
        configure_identity
        create_gitignore
      end
      Rails.logger.info '[GitLedgerRepository] Initialized'
    rescue StandardError => e
      raise "Failed to initialize Git Ledger: #{e.message}"
    end

    def configure_identity
      system('git', 'config', 'user.name', 'foresy-ledger', out: File::NULL, err: File::NULL)
      system('git', 'config', 'user.email', 'ledger@foresy.internal', out: File::NULL, err: File::NULL)
      system('git', 'branch', '-M', LEDGER_BRANCH, out: File::NULL, err: File::NULL)
      system('git', 'config', 'receive.denyNonFastForwards', 'true', out: File::NULL, err: File::NULL)
    end

    def create_gitignore
      content = "# CRA Ledger\ncra_*.json\n.DS_Store\n*.log\n"
      File.write('.gitignore', content)
      system('git', 'add', '.gitignore', out: File::NULL, err: File::NULL)
      system('git', 'commit', '-m', 'Initial commit', out: File::NULL, err: File::NULL)
    end

    def write_payload(cra, payload)
      filename = "cra_#{cra.id}_#{cra.month}_#{cra.year}.json"
      File.write(filename, JSON.pretty_generate(payload))
      system('git', 'add', filename, out: File::NULL, err: File::NULL)
      filename
    end

    def perform_commit(cra, filename)
      raise 'Git history rewrite detected' if history_rewritten?

      message = "CRA locked — cra:#{cra.id} — #{cra.month}/#{cra.year}"
      system('git', 'commit', '-m', message, out: File::NULL, err: File::NULL)

      commit_info = {
        commit_hash: `git rev-parse HEAD`.strip,
        message: message,
        timestamp: `git log -1 --pretty=format:"%ad" --date=iso`.strip
      }

      File.delete(filename)
      commit_info
    end

    def history_rewritten?
      result = `git config receive.denyNonFastForwards`.strip
      result != 'true'
    rescue StandardError
      true
    end

    def fetch_info
      Dir.chdir(LEDGER_PATH) do
        {
          exists: true,
          path: LEDGER_PATH,
          branch: LEDGER_BRANCH,
          commit_count: `git rev-list --count HEAD 2>/dev/null`.strip.to_i,
          last_commit: `git log -1 --pretty=format:"%h|%s|%ad" --date=iso 2>/dev/null`,
          initialized: true
        }
      end
    end

    def parse_commit_result(result)
      return nil if result.blank?

      commit_hash, message, timestamp = result.split('|')
      { commit_hash: commit_hash, message: message, timestamp: timestamp }
    end
  end
end
