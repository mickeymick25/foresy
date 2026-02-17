# frozen_string_literal: true

# Mission Feature Flag Spec
#
# Tests dual-path functionality for Mission model based on USE_USER_RELATIONS feature flag.
# Validates that:
# - When flag is OFF (default): uses legacy created_by_user_id column
# - When flag is ON: uses user_missions pivot table
#
# This ensures backward compatibility while enabling relation-driven architecture.

require 'rails_helper'

RSpec.describe Mission do
  describe 'Feature Flag: accessible_to' do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:mission) { create(:mission, created_by_user_id: user.id) }

    context 'when feature flag is OFF (default)' do
      let(:company) { create(:company) }
      let(:user_company) { create(:user_company, user: user, company: company, role: 'independent') }
      let(:mission_company) { create(:mission_company, mission: mission, company: company, role: 'independent') }

      before do
        # Stub FeatureFlags.relation_driven? to return false
        allow(FeatureFlags).to receive(:relation_driven?).and_return(false)
        # Set up company associations so legacy path works
        user_company
        mission_company
      end

      it 'uses legacy_accessible_to implementation' do
        # Mission accessible to user via company
        expect(Mission.accessible_to(user)).to include(mission)

        # Mission not accessible to other_user (no company association)
        expect(Mission.accessible_to(other_user)).not_to include(mission)
      end
    end

    context 'when feature flag is ON' do
      let(:user_mission) { create(:user_mission, user: user, mission: mission, role: 'creator') }

      before do
        # Stub FeatureFlags.relation_driven? to return true
        allow(FeatureFlags).to receive(:relation_driven?).and_return(true)
      end

      it 'uses relation_accessible_to implementation' do
        # Without user_mission relation, mission should not be accessible
        expect(Mission.accessible_to(user)).not_to include(mission)

        # With user_mission relation, mission should be accessible
        user_mission
        expect(Mission.accessible_to(user)).to include(mission)
      end

      it 'allows access via any user_missions role' do
        # Creator role should have access
        user_mission
        expect(Mission.accessible_to(user)).to include(mission)

        # Contributor role should also have access
        create(:user_mission, user: other_user, mission: mission, role: 'contributor')
        expect(Mission.accessible_to(other_user)).to include(mission)
      end
    end
  end

  describe 'Feature Flag: creator' do
    let(:user) { create(:user) }
    let(:mission) { create(:mission, created_by_user_id: user.id) }

    context 'when feature flag is OFF (default)' do
      before do
        allow(FeatureFlags).to receive(:relation_driven?).and_return(false)
      end

      it 'uses legacy_creator implementation' do
        expect(mission.creator).to eq(user)
        expect(mission.creator.id).to eq(mission.created_by_user_id)
      end
    end

    context 'when feature flag is ON' do
      let(:other_user) { create(:user) }

      before do
        allow(FeatureFlags).to receive(:relation_driven?).and_return(true)
      end

      it 'uses relation_creator implementation' do
        # When no user_mission exists, relation_creator should return nil
        expect(mission.creator).to be_nil

        # When user_mission with creator role exists, should return that user
        create(:user_mission, user: user, mission: mission, role: 'creator')
        expect(mission.creator).to eq(user)

        # When different user has creator role
        mission_without_creator = create(:mission, created_by_user_id: user.id)
        create(:user_mission, user: other_user, mission: mission_without_creator, role: 'creator')
        expect(mission_without_creator.creator).to eq(other_user)
      end
    end
  end

  describe 'Feature Flag: modifiable_by?' do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:mission) { create(:mission, created_by_user_id: user.id, status: 'lead') }

    context 'when feature flag is OFF (default)' do
      before do
        allow(FeatureFlags).to receive(:relation_driven?).and_return(false)
      end

      it 'uses legacy_modifiable_by? implementation' do
        # Creator can modify
        expect(mission.modifiable_by?(user)).to be true

        # Non-creator cannot modify
        expect(mission.modifiable_by?(other_user)).to be false
      end

      it 'allows modification in lead status' do
        expect(mission.modifiable_by?(user)).to be true
      end

      it 'allows modification in pending status' do
        pending_mission = create(:mission, created_by_user_id: user.id, status: 'pending')
        expect(pending_mission.modifiable_by?(user)).to be true
      end
    end

    context 'when feature flag is ON' do
      before do
        allow(FeatureFlags).to receive(:relation_driven?).and_return(true)
      end

      it 'uses relation_modifiable_by? implementation' do
        # Without user_mission, should not be modifiable
        expect(mission.modifiable_by?(user)).to be false
        expect(mission.modifiable_by?(other_user)).to be false

        # With user_mission creator role, should be modifiable
        create(:user_mission, user: user, mission: mission, role: 'creator')
        expect(mission.modifiable_by?(user)).to be true

        # Contributor role should not be able to modify
        create(:user_mission, user: other_user, mission: mission, role: 'contributor')
        expect(mission.modifiable_by?(other_user)).to be false
      end

      it 'blocks modification in completed status' do
        completed_mission = create(:mission, created_by_user_id: user.id, status: 'completed')
        create(:user_mission, user: user, mission: completed_mission, role: 'creator')
        expect(completed_mission.modifiable_by?(user)).to be false
      end
    end
  end
end
