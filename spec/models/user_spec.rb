# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should allow_value('user@example.com').for(:email) }
    it { should_not allow_value('invalid-email').for(:email) }
    it { should allow_value('test.email+tag@subdomain.example.co.uk').for(:email) }

    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }
    it { should allow_value('password123').for(:password) }
    it { should_not allow_value('short').for(:password) }

    it { should validate_inclusion_of(:active).in_array([true, false]) }
  end

  describe 'associations' do
    it { should have_many(:sessions).dependent(:destroy) }
  end

  describe 'scopes' do
    describe '.active' do
      let(:active_user) { create(:user, active: true) }
      let(:inactive_user) { create(:user, active: false) }

      it 'returns only active users' do
        expect(described_class.active).to include(active_user)
        expect(described_class.active).not_to include(inactive_user)
      end
    end
  end

  describe 'callbacks' do
    describe '#downcase_email' do
      let(:user) { build(:user, email: "TEST_#{rand(100_000)}@EXAMPLE.COM") }

      it 'downcases the email before save' do
        user.save!
        expect(user.email).to eq(user.email.downcase)
      end

      it 'handles empty email by validating presence' do
        user = build(:user, email: '')
        expect { user.save! }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe '#set_default_active' do
      it 'sets active to true by default for new records' do
        user = build(:user, email: 'new@example.com')
        expect(user.active).to be true
      end

      it 'does not override explicit active value' do
        user = build(:user, active: false)
        expect(user.active).to be false
      end
    end
  end

  describe 'instance methods' do
    describe '#active?' do
      let(:active_user) { build(:user, active: true) }
      let(:inactive_user) { build(:user, active: false) }

      it 'returns true for active user' do
        expect(active_user.active?).to be true
      end

      it 'returns false for inactive user' do
        expect(inactive_user.active?).to be false
      end
    end

    describe '#active_sessions' do
      let(:user) { create(:user) }
      let(:active_session) { create(:session, user: user) }
      let(:expired_session) { create(:session, :expired, user: user) }

      it 'returns only active sessions' do
        expect(user.active_sessions).to include(active_session)
        expect(user.active_sessions).not_to include(expired_session)
      end

      it 'returns empty array when no active sessions' do
        expired_session
        expect(user.active_sessions).to be_empty
      end
    end

    describe '#create_session' do
      let(:user) { create(:user) }

      it 'creates a new session with metadata' do
        expect do
          user.create_session(ip_address: '192.168.1.1', user_agent: 'Test Browser')
        end.to change(user.sessions, :count).by(1)

        session = user.sessions.last
        expect(session.ip_address).to eq('192.168.1.1')
        expect(session.user_agent).to eq('Test Browser')
        expect(session.expires_at).to be > Time.current
      end

      it 'creates session without metadata' do
        expect do
          user.create_session
        end.to change(user.sessions, :count).by(1)
      end
    end

    describe '#invalidate_all_sessions!' do
      let(:user) { create(:user) }
      let(:session1) { create(:session, user: user) }
      let(:session2) { create(:session, user: user) }

      it 'expires all active sessions' do
        expect(session1.active?).to be true
        expect(session2.active?).to be true

        user.invalidate_all_sessions!

        session1.reload
        session2.reload
        expect(session1.expired?).to be true
        expect(session2.expired?).to be true
      end

      it 'does not affect already expired sessions' do
        expired_session = create(:session, :expired, user: user)

        user.invalidate_all_sessions!

        expect(expired_session.expired?).to be true
      end
    end
  end
end
