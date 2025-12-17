# frozen_string_literal: true

require 'rails_helper'
require 'active_support/testing/time_helpers'

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
end

RSpec.describe Session, type: :model do
  let(:user) { create(:user) }
  subject { build(:session, user: user) }

  describe 'associations' do
    it { should belong_to(:user) }
  end
end

RSpec.describe Session, type: :model do
  describe 'validations' do
    it 'valide l\'unicité du token scoped à user_id' do
      user = create(:user)
      create(:session, user: user, token: 'unique_token')
      session2 = build(:session, user: user, token: 'unique_token')
      expect(session2).not_to be_valid
      expect(session2.errors[:token]).to include('has already been taken')
    end

    it { should validate_presence_of(:expires_at) }
  end
end

RSpec.describe Session, type: :model do
  describe 'scopes' do
    describe '.active' do
      let!(:active_session) { create(:session) }
      let!(:expired_session) { create(:session, :expired) }

      it 'returns only active sessions' do
        expect(described_class.active).to include(active_session)
        expect(described_class.active).not_to include(expired_session)
      end
    end

    describe '.expired' do
      let!(:active_session) { create(:session) }
      let!(:expired_session) { create(:session, :expired) }

      it 'returns only expired sessions' do
        expect(described_class.expired).to include(expired_session)
        expect(described_class.expired).not_to include(active_session)
      end
    end
  end
end

RSpec.describe Session, type: :model do
  describe '#active?' do
    let(:session) { create(:session) }

    context 'when session is active' do
      it 'returns true' do
        expect(session.active?).to be true
      end
    end

    context 'when session is expired' do
      let(:expired_session) { create(:session, :expired) }

      it 'returns false' do
        expect(expired_session.active?).to be false
      end
    end
  end
end

RSpec.describe Session, type: :model do
  describe '#refresh!' do
    let(:session) { create(:session) }

    it 'updates last_activity_at' do
      travel_to 2.hours.ago do
        session.update!(last_activity_at: Time.current)
      end
      old_activity_time = session.last_activity_at
      travel 1.hour
      session.refresh!
      session.reload
      expect(session.last_activity_at).to be > old_activity_time
    end
  end
end
