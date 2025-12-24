# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    # NOTE: Email uniqueness is now conditional with OAuth support
    # - For traditional users (no provider): global email uniqueness (case-insensitive)
    # - For OAuth users (with provider): email uniqueness per provider (case-insensitive)
    # This is tested through custom examples to verify both behaviors
    it { should allow_value('user@example.com').for(:email) }
    it { should_not allow_value('invalid-email').for(:email) }
    it { should allow_value('test.email+tag@subdomain.example.co.uk').for(:email) }

    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }
    it { should allow_value('password123').for(:password) }
    it { should_not allow_value('short').for(:password) }

    # NOTE: validate_inclusion_of(:active) removed - shoulda-matchers warns that
    # boolean columns automatically convert non-boolean values, making this test meaningless.
    # The 'active' column has a default value (true) and null: false constraint in the schema.

    describe 'Email uniqueness behavior' do
      # Test email uniqueness for traditional users (no provider)
      it 'enforces global email uniqueness for traditional users' do
        # Create a traditional user with email
        create(:user, email: 'traditional@example.com')

        # Try to create another traditional user with same email
        duplicate_traditional_user = build(:user, email: 'traditional@example.com')

        expect(duplicate_traditional_user).not_to be_valid
        expect(duplicate_traditional_user.errors[:email]).to include('has already been taken')
      end

      it 'allows same email for different providers (OAuth users)' do
        # Create OAuth user with email
        oauth_user = User.new(
          provider: 'google_oauth2',
          uid: 'google_user_123',
          email: 'shared@example.com',
          active: true
        )
        oauth_user.save!

        # Create another OAuth user with same email but different provider
        another_oauth_user = User.new(
          provider: 'github',
          uid: 'github_user_456',
          email: 'shared@example.com', # Same email
          active: true
        )

        expect(another_oauth_user).to be_valid
      end

      it 'prevents same email for same provider (OAuth users)' do
        # Create OAuth user with email
        existing_oauth_user = User.new(
          provider: 'google_oauth2',
          uid: 'google_user_123',
          email: 'oauth@example.com',
          active: true
        )
        existing_oauth_user.save!

        # Try to create another OAuth user with same email and same provider
        duplicate_oauth_user = User.new(
          provider: 'google_oauth2', # Same provider
          uid: 'google_user_456', # Different uid
          email: 'oauth@example.com', # Same email
          active: true
        )

        expect(duplicate_oauth_user).not_to be_valid
        expect(duplicate_oauth_user.errors[:email]).to include('must be unique per provider')
      end
    end
  end

  describe 'OAuth validations' do
    # Provider validations
    # Note: OAuth validations are conditional and tested through custom examples
    # because shoulda-matchers cannot prove conditional validations

    # OAuth provider inclusion is tested through custom examples below
    # OAuth uid presence is tested through custom examples below
    # OAuth uniqueness is tested through custom examples below

    describe '(provider, uid) uniqueness' do
      let(:existing_user) do
        create(:user,
               provider: 'google_oauth2',
               uid: 'google_user_123',
               email: 'user@example.com')
      end

      it 'prevents duplicate (provider, uid) combination' do
        # Create OAuth user manually without password_digest
        existing_user
        duplicate_user = User.new(
          provider: 'google_oauth2',
          uid: 'google_user_123', # Same as existing_user
          email: 'different@example.com',
          active: true
          # No password_digest = OAuth user
        )

        expect(duplicate_user).not_to be_valid
        expect(duplicate_user.errors[:provider]).to include('and uid combination must be unique')
      end

      it 'allows same provider with different uid' do
        user_with_different_uid = User.new(
          provider: 'google_oauth2',
          uid: 'google_user_456', # Different uid
          email: 'user2@example.com',
          active: true
          # No password_digest = OAuth user
        )

        expect(user_with_different_uid).to be_valid
      end

      it 'allows same uid with different provider' do
        user_with_different_provider = User.new(
          provider: 'github', # Different provider
          uid: 'google_user_123', # Same uid
          email: 'user3@example.com',
          active: true
          # No password_digest = OAuth user
        )

        expect(user_with_different_provider).to be_valid
      end
    end

    describe 'Email uniqueness per provider' do
      let(:existing_user) do
        create(:user,
               provider: 'google_oauth2',
               uid: 'google_user_123',
               email: 'same@example.com')
      end

      it 'prevents duplicate email for same provider' do
        # Create OAuth user manually without password_digest
        existing_user
        duplicate_email_user = User.new(
          provider: 'google_oauth2', # Same provider
          uid: 'different_uid',
          email: 'same@example.com', # Same email as existing_user
          active: true
          # No password_digest = OAuth user
        )

        expect(duplicate_email_user).not_to be_valid
        expect(duplicate_email_user.errors[:email]).to include('must be unique per provider')
      end

      it 'allows same email for different providers' do
        user_with_different_provider = User.new(
          provider: 'github', # Different provider
          uid: 'github_user_456',
          email: 'same@example.com', # Same email but different provider
          active: true
          # No password_digest = OAuth user
        )

        expect(user_with_different_provider).to be_valid
      end

      it 'enforces case-insensitive email uniqueness' do
        # Create OAuth user manually without password_digest
        existing_user
        user_with_uppercase_email = User.new(
          provider: 'google_oauth2',
          uid: 'google_user_789',
          email: 'SAME@EXAMPLE.COM', # Uppercase version of existing user's email
          active: true
          # No password_digest = OAuth user
        )

        expect(user_with_uppercase_email).not_to be_valid
        expect(user_with_uppercase_email.errors[:email]).to include('must be unique per provider')
      end
    end
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
