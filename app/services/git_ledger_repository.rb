# frozen_string_literal: true

require 'open3'

# GitLedgerRepository
#
# Helper module for Git repository operations used by GitLedgerService.
# Handles low-level Git operations for CRA immutability ledger.
#
# Security: all Git invocations go through Open3.capture3 with argument arrays
# (no shell interpolation), so CRA IDs cannot perform shell injection. stderr
# is logged instead of being silenced, and exit status is checked explicitly.
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

      _stdout, _stderr, status = Open3.capture3('git', 'rev-parse', '--git-dir', chdir: LEDGER_PATH)
      status.success?
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
      stdout, _stderr, status = Open3.capture3(
        'git', 'log', '--grep', "CRA locked.*#{cra_id}", '--oneline', chdir: LEDGER_PATH
      )
      return false unless status.success?

      stdout.present?
    end

    def find_commit_info(cra_id)
      stdout, _stderr, status = Open3.capture3(
        'git', 'log', '--grep', "CRA locked.*#{cra_id}",
        '--pretty=format:%H|%s|%ad', '--date=iso', chdir: LEDGER_PATH
      )
      return nil unless status.success?

      parse_commit_result(stdout)
    end

    def create_commit(cra, payload)
      configure_identity
      filename = write_payload(cra, payload)
      perform_commit(cra, filename)
    end

    private

    def initialize_repository
      FileUtils.mkdir_p(LEDGER_PATH)
      _stdout, stderr, status = Open3.capture3('git', 'init', chdir: LEDGER_PATH)
      raise "git init failed: #{stderr.strip}" unless status.success?

      configure_identity
      create_gitignore
      Rails.logger.info '[GitLedgerRepository] Initialized'
    rescue StandardError => e
      raise "Failed to initialize Git Ledger: #{e.message}"
    end

    def configure_identity
      run_git('config', 'user.name', 'foresy-ledger')
      run_git('config', 'user.email', 'ledger@foresy.internal')
      run_git('branch', '-M', LEDGER_BRANCH)
      run_git('config', 'receive.denyNonFastForwards', 'true')
    end

    def create_gitignore
      content = "# CRA Ledger\ncra_*.json\n.DS_Store\n*.log\n"
      File.write(File.join(LEDGER_PATH, '.gitignore'), content)
      run_git('add', '.gitignore')
      run_git('commit', '-m', 'Initial commit')
    end

    def write_payload(cra, payload)
      filename = "cra_#{cra.id}_#{cra.month}_#{cra.year}.json"
      File.write(File.join(LEDGER_PATH, filename), JSON.pretty_generate(payload))
      run_git('add', filename)
      filename
    end

    def perform_commit(cra, filename)
      raise 'Git history rewrite detected' if history_rewritten?

      message = "CRA locked — cra:#{cra.id} — #{cra.month}/#{cra.year}"
      run_git('commit', '-m', message)

      commit_hash = capture_git('rev-parse', 'HEAD').strip
      timestamp = capture_git('log', '-1', '--pretty=format:%ad', '--date=iso').strip

      File.delete(File.join(LEDGER_PATH, filename))
      { commit_hash: commit_hash, message: message, timestamp: timestamp }
    end

    def history_rewritten?
      stdout, _stderr, status = Open3.capture3(
        'git', 'config', 'receive.denyNonFastForwards', chdir: LEDGER_PATH
      )
      return true unless status.success?

      stdout.strip != 'true'
    rescue StandardError
      true
    end

    def fetch_info
      {
        exists: true,
        path: LEDGER_PATH,
        branch: LEDGER_BRANCH,
        commit_count: capture_git('rev-list', '--count', 'HEAD').strip.to_i,
        last_commit: capture_git('log', '-1', '--pretty=format:%h|%s|%ad', '--date=iso'),
        initialized: true
      }
    end

    def parse_commit_result(result)
      return nil if result.blank?

      commit_hash, message, timestamp = result.split('|')
      { commit_hash: commit_hash, message: message, timestamp: timestamp }
    end

    # Run a git command, logging stderr and returning the exit status success.
    def run_git(*args)
      _stdout, stderr, status = Open3.capture3('git', *args, chdir: LEDGER_PATH)
      log_stderr(args.first, stderr) unless status.success?
      status.success?
    end

    # Run a git command and return its stdout (empty on failure).
    def capture_git(*args)
      stdout, stderr, status = Open3.capture3('git', *args, chdir: LEDGER_PATH)
      log_stderr(args.first, stderr) unless status.success?
      stdout
    end

    def log_stderr(command, stderr)
      return if stderr.nil? || stderr.strip.empty?

      Rails.logger.warn "[GitLedgerRepository] git #{command} stderr: #{stderr.strip}"
    end
  end
end
