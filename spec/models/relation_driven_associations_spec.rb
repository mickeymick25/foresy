
# frozen_string_literal: true

require 'rails_helper'

# RSpec tests for DDD Relation-Driven associations
# Part of DDD Relation-Driven Correction (PLATINUM)
#
# Tests cover:
# - User ↔ Mission via user_missions
# - User ↔ CRA via user_cras
# - Association chains (through tables)
#
# These tests validate that the relation-driven architecture
# correctly connects aggregates through pivot tables.
#
# @see app/models/user.rb
# @see app/models/mission.rb
# @see app/models/cra.rb
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md
#
RSpec.describe 'Relation-Driven Associations', type: :model do
  describe 'User ↔ Mission via user_missions' do
    let(:user) { create(:user) }
    let(:mission) { create(:mission, created_by_user_id: user.id) }
    let(:user_mission) { create(:user_mission, user: user, mission: mission, role: 'creator') }

    describe 'User has_many :missions, through: :user_missions' do
      it 'returns missions through user_missions' do
        user_mission
        expect(user.missions).to include(mission)
      end

      it 'only returns missions where user has a relation' do
        other_mission = create(:mission)
        user_mission
        expect(user.missions).not_to include(other_mission)
      end

      it 'is empty when no mission relations exist' do
        expect(user.missions).to be_empty
      end
    end

    describe 'Mission has_many :users, through: :user_missions' do
      it 'returns users through user_missions' do
        user_mission
        expect(mission.users).to include(user)
      end

      it 'only returns users where mission relation exists' do
        other_user = create(:user)
        user_mission
        expect(mission.users).not_to include(other_user)
      end

      it 'is empty when no user relations exist' do
        expect(mission.users).to be_empty
      end

      context 'with multiple users' do
        let(:user2) { create(:user) }

        before do
          create(:user_mission, user: user, mission: mission, role: 'creator')
          create(:user_mission, user: user2, mission: mission, role: 'contributor')
        end

        it 'returns all associated users' do
          expect(mission.users.count).to eq(2)
          expect(mission.users).to include(user, user2)
        end

        it 'can filter by role' do
          creators = mission.users.joins(:user_missions).where(user_missions: { role: 'creator' })
          expect(creators.count).to eq(1)
          expect(creators.first).to eq(user)
        end
      end
    end

    describe 'User has_many :user_missions' do
      it 'returns user_missions for this user' do
        user_mission
        expect(user.user_missions).to include(user_mission)
      end

      it 'filters by mission' do
        user_mission
        expect(user.user_missions.for_mission(mission.id)).to include(user_mission)
      end
    end

    describe 'Mission has_many :user_missions' do
      it 'returns user_missions for this mission' do
        user_mission
        expect(mission.user_missions).to include(user_mission)
      end

      it 'filters by user' do
        user_mission
        expect(mission.user_missions.for_user(user.id)).to include(user_mission)
      end
    end
  end

  describe 'User ↔ CRA via user_cras' do
    let(:user) { create(:user) }
    let(:cra) { create(:cra, created_by_user_id: user.id) }
    let(:user_cra) { create(:user_cra, user: user, cra: cra, role: 'creator') }

    describe 'User has_many :cras, through: :user_cras' do
      it 'returns cras through user_cras' do
        user_cra
        expect(user.cras).to include(cra)
      end

      it 'only returns cras where user has a relation' do
        other_cra = create(:cra)
        user_cra
        expect(user.cras).not_to include(other_cra)
      end

      it 'is empty when no cra relations exist' do
        expect(user.cras).to be_empty
      end
    end

    describe 'CRA has_many :users, through: :user_cras' do
      it 'returns users through user_cras' do
        user_cra
        expect(cra.users).to include(user)
      end

      it 'only returns users where cra relation exists' do
        other_user = create(:user)
        user_cra
        expect(cra.users).not_to include(other_user)
      end

      it 'is empty when no user relations exist' do
        expect(cra.users).to be_empty
      end
    end

    describe 'User has_many :user_cras' do
      it 'returns user_cras for this user' do
        user_cra
        expect(user.user_cras).to include(user_cra)
      end

      it 'filters by cra' do
        user_cra
        expect(user.user_cras.for_cra(cra.id)).to include(user_cra)
      end
    end

    describe 'CRA has_many :user_cras' do
      it 'returns user_cras for this cra' do
        user_cra
        expect(cra.user_cras).to include(user_cra)
      end

      it 'filters by user' do
        user_cra
        expect(cra.user_cras.for_user(user.id)).to include(user_cra)
      end
    end
  end

  describe 'Cross-model access patterns' do
    let(:user) { create(:user) }
    let(:mission) { create(:mission, created_by_user_id: user.id) }
    let(:cra) { create(:cra, created_by_user_id: user.id) }

    before do
      create(:user_mission, user: user, mission: mission, role: 'creator')
      create(:user_cra, user: user, cra: cra, role: 'creator')
    end

    describe 'User can access all created missions and cras' do
      it 'user.created_missions returns missions' do
        expect(user.created_missions).to include(mission)
      end

      it 'user.created_cras returns cras' do
        expect(user.created_cras).to include(cra)
      end
    end

    describe 'Mission can access creator' do
      it 'mission.relation_creator returns user' do
        creator = mission.relation_creator
        expect(creator).to eq(user)
      end
    end

    describe 'CRA can access creator' do
      it 'cra.relation_creator returns user' do
        creator = cra.relation_creator
        expect(creator).to eq(user)
      end
    end

    describe 'mission.users returns correct users' do
      it 'includes creator' do
        expect(mission.users).to include(user)
      end
    end

    describe 'cra.users returns correct users' do
      it 'includes creator' do
        expect(cra.users).to include(user)
      end
    end
  end

  describe 'Feature Flag Integration' do
    let(:user) { create(:user) }
    let(:mission) { create(:mission, created_by_user_id: user.id) }

    before do
      create(:user_mission, user: user, mission: mission, role: 'creator')
    end

    it 'relation-driven path is accessible when USE_USER_RELATIONS is enabled' do
      # This test validates the feature flag is accessible
      expect(defined?(USE_USER_RELATIONS)).to be_present
    end

    it 'associations work regardless of feature flag state' do
      # Associations should always work, regardless of feature flag
      expect(user.missions).to include(mission)
      expect(mission.users).to include(user)
    end
  end
end
