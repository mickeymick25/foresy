# frozen_string_literal: true

require 'rails_helper'

# RSpec tests for UserMission model
#
# Tests cover:
# - Associations (belongs_to :user, :mission)
# - Validations (presence, role inclusion)
# - Scopes (creators, for_mission, for_user, by_role)
# - Business methods (creator?, mission_creator)
# - Database constraints (partial unique index, CHECK role)
#
# @see app/models/user_mission.rb
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md
#
RSpec.describe UserMission, type: :model do
  # Factories
  let(:user) { create(:user) }
  let(:mission) { create(:mission, created_by_user_id: user.id) }

  describe 'Associations' do
    it { is_expected.to belong_to(:user).required }
    it { is_expected.to belong_to(:mission).required }
  end

  describe 'Validations' do
    describe 'user_id' do
      it 'validates presence' do
        user_mission = build(:user_mission, user_id: nil)
        expect(user_mission).not_to be_valid
        expect(user_mission.errors[:user_id]).to include("can't be blank")
      end
    end

    describe 'mission_id' do
      it 'validates presence' do
        user_mission = build(:user_mission, mission_id: nil)
        expect(user_mission).not_to be_valid
        expect(user_mission.errors[:mission_id]).to include("can't be blank")
      end
    end

    describe 'role' do
      it 'validates presence' do
        user_mission = build(:user_mission, role: nil)
        expect(user_mission).not_to be_valid
        expect(user_mission.errors[:role]).to include("can't be blank")
      end

      it 'validates inclusion in ROLES' do
        expect { create(:user_mission, role: 'invalid') }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'allows creator role' do
        user_mission = build(:user_mission, role: 'creator')
        expect(user_mission).to be_valid
      end

      it 'allows contributor role' do
        user_mission = build(:user_mission, role: 'contributor')
        expect(user_mission).to be_valid
      end

      it 'allows reviewer role' do
        user_mission = build(:user_mission, role: 'reviewer')
        expect(user_mission).to be_valid
      end
    end
  end

  describe 'Scopes' do
    before do
      @creator = create(:user)
      @contributor = create(:user)
      @mission = create(:mission, created_by_user_id: @creator.id)

      create(:user_mission, user: @creator, mission: @mission, role: 'creator')
      create(:user_mission, user: @contributor, mission: @mission, role: 'contributor')
    end

    describe '.creators' do
      it 'returns only creator roles' do
        expect(UserMission.creators.count).to eq(1)
        expect(UserMission.creators.first.role).to eq('creator')
      end
    end

    describe '.for_mission' do
      it 'filters by mission' do
        result = UserMission.for_mission(@mission.id)
        expect(result.count).to eq(2)
      end

      it 'returns empty for non-existent mission' do
        result = UserMission.for_mission(SecureRandom.uuid)
        expect(result).to be_empty
      end
    end

    describe '.for_user' do
      it 'filters by user' do
        result = UserMission.for_user(@creator.id)
        expect(result.count).to eq(1)
        expect(result.first.user_id).to eq(@creator.id)
      end
    end

    describe '.by_role' do
      it 'filters by specific role' do
        result = UserMission.by_role('creator')
        expect(result.count).to eq(1)
        expect(result.first.role).to eq('creator')
      end
    end
  end

  describe 'Business Methods' do
    let(:user) { create(:user) }
    let(:mission) { create(:mission, created_by_user_id: user.id) }

    describe '#creator?' do
      it 'returns true for creator role' do
        user_mission = create(:user_mission, user: user, mission: mission, role: 'creator')
        expect(user_mission.creator?).to be true
      end

      it 'returns false for contributor role' do
        user_mission = create(:user_mission, user: user, mission: mission, role: 'contributor')
        expect(user_mission.creator?).to be false
      end

      it 'returns false for reviewer role' do
        user_mission = create(:user_mission, user: user, mission: mission, role: 'reviewer')
        expect(user_mission.creator?).to be false
      end
    end

    describe '.mission_creator' do
      it 'returns the creator for a specific mission' do
        create(:user_mission, user: user, mission: mission, role: 'creator')
        creator = UserMission.mission_creator(mission.id)
        expect(creator).to be_present
        expect(creator.role).to eq('creator')
      end

      it 'returns nil for mission without creator' do
        mission_no_creator = create(:mission, created_by_user_id: user.id)
        creator = UserMission.mission_creator(mission_no_creator.id)
        expect(creator).to be_nil
      end
    end
  end

  describe 'Database Constraints' do
    let(:user) { create(:user) }
    let(:mission) { create(:mission, :with_creator, creator: user) }

    describe 'Partial Unique Index' do
      context 'when role = creator' do
        it 'prevents multiple creators for the same mission' do
          user2 = create(:user)
          expect do
            create(:user_mission, user: user2, mission: mission, role: 'creator')
          end.to raise_error(ActiveRecord::RecordNotUnique)
        end

        it 'allows one creator per mission' do
          # Factory already created creator user_mission
          expect(mission.user_missions.creators.count).to eq(1)
        end
      end

      context 'when role != creator' do
        it 'allows multiple contributors for the same mission' do
          user2 = create(:user)
          expect do
            create(:user_mission, user: user, mission: mission, role: 'contributor')
            create(:user_mission, user: user2, mission: mission, role: 'contributor')
          end.not_to raise_error
        end

        it 'allows same user with different roles' do
          # Factory already created creator user_mission
          expect do
            create(:user_mission, user: user, mission: mission, role: 'contributor')
          end.not_to raise_error
        end
      end
    end

    describe 'CHECK Constraint on role' do
      it 'rejects invalid role values at database level' do
        expect do
          sql = 'INSERT INTO user_missions (user_id, mission_id, role, created_at) '
          sql += "VALUES (#{user.id}, '#{mission.id}', 'invalid_role', NOW())"
          UserMission.connection.execute(sql)
        end.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end

  describe 'CASCADE Delete' do
    let(:user) { create(:user) }
    let(:mission) { create(:mission, created_by_user_id: user.id) }

    it 'is deleted when mission is HARD deleted' do
      create(:user_mission, user: user, mission: mission, role: 'creator')
      mission_id = mission.id

      # Hard delete the mission
      mission.destroy!

      # user_mission should be deleted via CASCADE
      expect(UserMission.where(mission_id: mission_id)).not_to exist
    end

    it 'is deleted when user is deleted' do
      create(:user_mission, user: user, mission: mission, role: 'creator')
      user_id = user.id

      # Delete the user
      user.destroy!

      # user_mission should be deleted via CASCADE
      expect(UserMission.where(user_id: user_id)).not_to exist
    end
  end

  describe 'Soft Delete Behavior' do
    let(:user) { create(:user) }
    let(:mission) { create(:mission, created_by_user_id: user.id) }

    context 'when mission is soft-deleted' do
      it 'still exists (trigger blocks manual deletion)' do
        user_mission = create(:user_mission, user: user, mission: mission, role: 'creator')

        # Soft delete the mission
        mission.update(deleted_at: Time.current)

        # user_mission should still exist (mission not hard-deleted)
        expect(UserMission.where(id: user_mission.id)).to exist
      end
    end
  end
end
