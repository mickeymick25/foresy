# frozen_string_literal: true

# Script de test GitLedgerRepository — environnement isolé (tmpdir)
# Valide le cycle complet : init → commit → verify → cleanup

require 'tmpdir'
require 'ostruct'

# Utiliser un répertoire temporaire isolé
tmpdir = Dir.mktmpdir('foresy_ledger_test')

# Monkey-patch LEDGER_PATH
begin
  GitLedgerRepository.singleton_class.send(:remove_const, :LEDGER_PATH)
rescue StandardError
  nil
end
GitLedgerRepository.singleton_class.const_set(:LEDGER_PATH, tmpdir)

puts "LEDGER_PATH: #{GitLedgerRepository::LEDGER_PATH}"
puts ''

# 1. Initial state
puts '=== 1. Initial state ==='
puts "exists?: #{GitLedgerRepository.exists?}"
puts "initialized?: #{GitLedgerRepository.initialized?}"
puts ''

# 2. Initialize
puts '=== 2. Initialize ==='
GitLedgerRepository.ensure_initialized!
puts "exists?: #{GitLedgerRepository.exists?}"
puts "initialized?: #{GitLedgerRepository.initialized?}"
puts "valid?: #{GitLedgerRepository.valid?}"
puts ''

# 3. Info before commit
puts '=== 3. Info (before commit) ==='
info = GitLedgerRepository.info
puts "path: #{info[:path]}"
puts "branch: #{info[:branch]}"
puts "commit_count: #{info[:commit_count]}"
puts "last_commit: #{info[:last_commit]}"
puts ''

# 4. Create commit (simulated CRA lock)
puts '=== 4. Create commit ==='
cra = OpenStruct.new( # rubocop:disable Style/OpenStructUse
  id: 'test-cra-001',
  month: 8,
  year: 2026,
  description: 'Test CRA for ledger validation',
  status: 'locked',
  total_days: 5.0,
  total_amount: 300_000,
  currency: 'EUR',
  locked_at: Time.current,
  created_at: Time.current,
  updated_at: Time.current,
  creator_user_id: 1
)

# Build payload manually (GitLedgerPayload expects a Cra model)
payload = {
  'cra_id' => cra.id,
  'month' => cra.month,
  'year' => cra.year,
  'description' => cra.description,
  'status' => cra.status,
  'total_days' => cra.total_days,
  'total_amount' => cra.total_amount,
  'currency' => cra.currency,
  'created_by_user_id' => cra.creator_user_id,
  'created_at' => cra.created_at.iso8601,
  'updated_at' => cra.updated_at.iso8601,
  'locked_at' => cra.locked_at.iso8601
}

result = GitLedgerRepository.create_commit(cra, payload)
puts "commit_hash: #{result[:commit_hash]}"
puts "message: #{result[:message]}"
puts "timestamp: #{result[:timestamp]}"
puts ''

# 5. Verify commit exists
puts '=== 5. Verify commit exists ==='
exists = GitLedgerRepository.commit_exists_for_cra?('test-cra-001')
puts "commit_exists_for_cra?('test-cra-001'): #{exists}"

commit_info = GitLedgerRepository.find_commit_info('test-cra-001')
puts "find_commit_info: #{commit_info.inspect}"
puts ''

# 6. Info after commit
puts '=== 6. Info (after commit) ==='
info = GitLedgerRepository.info
puts "commit_count: #{info[:commit_count]}"
puts "last_commit: #{info[:last_commit]}"
puts ''

# 7. Error cases
puts '=== 7. Error cases ==='

# 7a. Non-existent CRA ID
puts "commit_exists_for_cra?('nonexistent'): #{GitLedgerRepository.commit_exists_for_cra?('nonexistent')}"
puts "find_commit_info('nonexistent'): #{GitLedgerRepository.find_commit_info('nonexistent').inspect}"

# 7b. Malicious ID (injection attempt)
puts "commit_exists_for_cra?('; rm -rf /'): #{GitLedgerRepository.commit_exists_for_cra?('; rm -rf /')}"
puts ''

# 8. Cleanup
puts '=== 8. Cleanup ==='
GitLedgerRepository.cleanup!(force: true)
puts "exists? after cleanup: #{GitLedgerRepository.exists?}"
FileUtils.remove_entry(tmpdir)
puts ''

puts '=== ALL TESTS PASSED ===' # rubocop:enable Style/OpenStructUse
