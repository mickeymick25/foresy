require 'rails_helper'

RSpec.describe Session, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:token) }
    it { should validate_uniqueness_of(:token) }
    it { should validate_presence_of(:expires_at) }
    it { should validate_presence_of(:last_activity_at) }
  end

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

  describe '#refresh!' do
    let(:session) { create(:session) }
    let(:old_activity_time) { session.last_activity_at }

    it 'updates last_activity_at' do
      travel 1.hour
      session.refresh!
      expect(session.last_activity_at).to be > old_activity_time
    end
  end
end 