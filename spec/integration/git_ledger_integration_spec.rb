# frozen_string_literal: true

# Test d'intégration GitLedgerRepository — environnement isolé (tmpdir)
# Prévient les régressions sur le cycle complet : init → commit → verify → cleanup
# et valide la sécurité (injection shell, .gitignore bypass avec git add -f)

require 'rails_helper'
require 'tmpdir'
require 'ostruct'

RSpec.describe GitLedgerRepository, type: :model do
  let(:tmpdir) { Dir.mktmpdir('foresy_ledger_test') }

  before do
    # Isoler LEDGER_PATH dans un tmpdir
    begin
      GitLedgerRepository.singleton_class.send(:remove_const, :LEDGER_PATH)
    rescue StandardError
      nil
    end
    GitLedgerRepository.singleton_class.const_set(:LEDGER_PATH, tmpdir)
  end

  after do
    GitLedgerRepository.cleanup!(force: true)
    FileUtils.rm_rf(tmpdir)
  end

  let(:test_cra) do
    OpenStruct.new( # rubocop:disable Style/OpenStructUse
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
    ) # rubocop:enable Style/OpenStructUse
  end

  let(:test_payload) do
    {
      'cra_id' => test_cra.id,
      'month' => test_cra.month,
      'year' => test_cra.year,
      'status' => test_cra.status,
      'total_days' => test_cra.total_days,
      'total_amount' => test_cra.total_amount,
      'currency' => test_cra.currency,
      'locked_at' => test_cra.locked_at.iso8601
    }
  end

  describe 'cycle complet init → commit → verify → cleanup' do
    before { GitLedgerRepository.ensure_initialized! }

    it 'initializes the repository' do
      expect(GitLedgerRepository.initialized?).to be(true)
      expect(GitLedgerRepository.valid?).to be(true)
    end

    it 'creates a commit for a locked CRA' do
      result = GitLedgerRepository.create_commit(test_cra, test_payload)

      expect(result[:commit_hash]).to be_present
      expect(result[:commit_hash]).to match(/\A[0-9a-f]{40}\z/)
      expect(result[:message]).to include('CRA locked')
      expect(result[:message]).to include('test-cra-001')
      expect(result[:timestamp]).to be_present
    end

    it 'verifies the commit exists after creation' do
      GitLedgerRepository.create_commit(test_cra, test_payload)

      expect(GitLedgerRepository.commit_exists_for_cra?('test-cra-001')).to be(true)
    end

    it 'finds commit info after creation' do
      GitLedgerRepository.create_commit(test_cra, test_payload)

      info = GitLedgerRepository.find_commit_info('test-cra-001')
      expect(info).not_to be_nil
      expect(info[:commit_hash]).to be_present
      expect(info[:message]).to include('test-cra-001')
      expect(info[:timestamp]).to be_present
    end

    it 'increments commit count after creation' do
      initial_info = GitLedgerRepository.info
      GitLedgerRepository.create_commit(test_cra, test_payload)
      final_info = GitLedgerRepository.info

      expect(final_info[:commit_count]).to be(initial_info[:commit_count] + 1)
    end

    it 'deletes the payload file after commit' do
      GitLedgerRepository.create_commit(test_cra, test_payload)

      payload_file = File.join(GitLedgerRepository::LEDGER_PATH, 'cra_test-cra-001_8_2026.json')
      expect(File.exist?(payload_file)).to be(false)
    end
  end

  describe 'error cases' do
    before { GitLedgerRepository.ensure_initialized! }

    it 'returns false for non-existent CRA ID' do
      expect(GitLedgerRepository.commit_exists_for_cra?('nonexistent')).to be(false)
    end

    it 'returns nil for non-existent CRA commit info' do
      expect(GitLedgerRepository.find_commit_info('nonexistent')).to be_nil
    end

    it 'handles malicious ID safely (no shell injection)' do
      expect(GitLedgerRepository.commit_exists_for_cra?('; rm -rf /')).to be(false)
      # Verify the system is still intact
      expect(GitLedgerRepository.valid?).to be(true)
    end

    it 'handles malicious ID with backticks safely' do
      expect(GitLedgerRepository.commit_exists_for_cra?('`whoami`')).to be(false)
      expect(GitLedgerRepository.valid?).to be(true)
    end
  end

  describe 'info' do
    it 'returns exists: false when directory does not exist' do
      FileUtils.rm_rf(tmpdir)
      info = GitLedgerRepository.info
      expect(info[:exists]).to be(false)
    end

    it 'returns repository info when initialized' do
      GitLedgerRepository.ensure_initialized!
      info = GitLedgerRepository.info

      expect(info[:exists]).to be(true)
      expect(info[:path]).to eq(tmpdir)
      expect(info[:branch]).to eq('main')
      expect(info[:commit_count]).to be >= 1
      expect(info[:last_commit]).to be_present
    end
  end

  describe 'cleanup' do
    it 'removes the ledger directory' do
      GitLedgerRepository.ensure_initialized!
      expect(GitLedgerRepository.exists?).to be(true)

      GitLedgerRepository.cleanup!(force: true)
      expect(GitLedgerRepository.exists?).to be(false)
    end
  end
end
