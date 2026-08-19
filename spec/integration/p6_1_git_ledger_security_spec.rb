# frozen_string_literal: true

# 🔴 P6.1 — Sécurisation de GitLedgerRepository contre les injections shell
#
# This spec characterizes the fix for audit point P6.1: migration of shell
# backticks and system() calls to Open3.capture3 with explicit exit status
# handling, removing the 2>/dev/null suppression pattern.
#
# Invariants:
#   - No backticks (`) remain in app/services/git_ledger_repository.rb body.
#   - Open3 is required and used.
#   - A malicious CRA ID like `; rm -rf /` is passed as a single argument
#     (not interpreted by a shell).

require 'rails_helper'

RSpec.describe 'P6.1 — GitLedgerRepository shell injection security' do
  let(:source_path) { Rails.root.join('app/services/git_ledger_repository.rb') }
  let(:source_content) { File.read(source_path) }

  describe 'static analysis of git_ledger_repository.rb' do
    it 'requires open3' do
      expect(source_content).to match(/require\s+['"]open3['"]/)
    end

    it 'uses Open3.capture3 or Open3.capture2e' do
      expect(source_content).to match(/Open3\.capture(3|2e)/)
    end

    it 'does not use backticks after the require lines' do
      lines = source_content.lines
      # Find the last `require` line; backticks in the body after it are forbidden
      last_require_idx = lines.rindex { |l| l.match?(/\Arequire\s/) } || 0
      body_lines = lines[(last_require_idx + 1)..] || []
      offending = body_lines.select { |l| l.include?('`') }
      expect(offending).to be_empty,
                           "Backticks found in GitLedgerRepository body:\n#{offending.join}"
    end

    it 'does not use system() with shell redirection suppression' do
      expect(source_content).not_to match(%r{2>/dev/null})
      expect(source_content).not_to match(/out:\s*File::NULL/)
    end

    it 'does not use Shellwords as primary defense (Open3 args are separate)' do
      # Shellwords is no longer required because Open3 passes args as an array,
      # bypassing the shell entirely.
      expect(source_content).not_to match(/require\s+['"]shellwords['"]/)
    end
  end

  describe 'behavioral safety with a malicious CRA ID' do
    let(:malicious_id) { '; rm -rf /' }

    before do
      # Stub Open3.capture3 so the spec does not require a real ledger path.
      # Capture the arguments to verify they are passed as an array.
      allow(Open3).to receive(:capture3) do |*_args, **_opts|
        # Return empty stdout, no stderr, failed status (no matching commit)
        status_double = double('Process::Status', success?: false, exitstatus: 1)
        ['', '', status_double]
      end
    end

    it 'commit_exists_for_cra? does not execute the malicious command' do
      GitLedgerRepository.commit_exists_for_cra?(malicious_id)

      expect(Open3).to have_received(:capture3) do |*args, **_opts|
        # First argument must be the literal 'git' executable, not a shell string
        expect(args.first).to eq('git')
        # No argument may be the bare destructive command tokens
        expect(args).not_to include('rm')
        expect(args).not_to include('-rf')
        # The malicious id must be embedded inside a single --grep argument,
        # not split into separate shell tokens
        grep_arg = args[args.index('--grep') + 1]
        expect(grep_arg).to be_a(String)
        expect(grep_arg).to include(malicious_id)
      end
    end

    it 'commit_exists_for_cra? returns false (no shell error raised)' do
      result = GitLedgerRepository.commit_exists_for_cra?(malicious_id)
      expect(result).to be_falsey
    end

    it 'find_commit_info returns nil (no shell error raised)' do
      result = GitLedgerRepository.find_commit_info(malicious_id)
      expect(result).to be_nil
    end

    it 'does not invoke Kernel#system or backtick execution' do
      allow(Kernel).to receive(:system).and_call_original
      allow(GitLedgerRepository).to receive(:`).and_call_original

      GitLedgerRepository.commit_exists_for_cra?(malicious_id)

      expect(Kernel).not_to have_received(:system).with(any_args)
      expect(GitLedgerRepository).not_to have_received(:`)
    end
  end
end
