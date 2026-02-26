# frozen_string_literal: true

require 'rails_helper'

# MissionServices::Delete Specs
# Tests for the Delete service following the same pattern as Create
#
# Test Coverage:
# - Success: archive mission
# - Permission: non-creator cannot delete
# - Business rules: mission_in_use (has CRA entries), already archived
RSpec.describe MissionServices::Delete do
  let(:current_user) { create(:user) }
  let(:other_user) { create(:user) }

  # Helper to create creator UserMission association
  def create_creator_mission!(mission, user)
    create(:user_mission, mission: mission, user: user, role: 'creator')
  end

  describe '.call' do
    subject(:call) do
      described_class.call(
        mission: mission,
        current_user: current_user
      )
    end

    # ============================================
    # SUCCESS CASES
    # ============================================

    describe 'when user is the creator (success cases)' do
      let(:mission) { create(:mission) }

      before do
        create_creator_mission!(mission, current_user)
      end

      it 'returns success' do
        expect(call.success?).to be true
      end

      it 'soft deletes the mission (sets deleted_at)' do
        expect(call.data[:mission].deleted_at).to be_present
      end

      it 'returns appropriate success message' do
        expect(call.message).to include('archived')
      end

      it 'returns the archived mission' do
        expect(call.data[:mission]).to eq(mission)
      end
    end

    # ============================================
    # PERMISSION DENIED CASES
    # ============================================

    describe 'when user is NOT the creator (permission denied)' do
      let(:mission) { create(:mission, created_by_user_id: other_user.id) }

      it 'returns forbidden' do
        expect(call.success?).to be false
        expect(call.status).to eq(:forbidden)
        expect(call.error).to eq(:forbidden)
      end

      it 'returns appropriate error message' do
        expect(call.message).to include('creator')
      end

      it 'does not delete the mission' do
        call
        expect(mission.deleted_at).to be_nil
      end
    end

    # ============================================
    # BUSINESS RULE: MISSION IN USE
    # ============================================

    describe 'when mission has CRA entries (mission_in_use)' do
      let(:mission) { create(:mission) }
      let(:cra) { create(:cra, user: current_user) }

      before do
        # Create creator association first
        create_creator_mission!(mission, current_user)
        # Create CRA entry linked to this mission
        cra_entry = create(:cra_entry, cra: cra)
        create(:cra_entry_mission, cra_entry: cra_entry, mission: mission)
      end

      it 'returns conflict' do
        expect(call.success?).to be false
        expect(call.status).to eq(:conflict)
        expect(call.error).to eq(:mission_in_use)
      end

      it 'returns appropriate error message' do
        expect(call.message).to include('CRA')
      end

      it 'does not delete the mission' do
        call
        expect(mission.deleted_at).to be_nil
      end
    end

    # ============================================
    # BUSINESS RULE: ALREADY ARCHIVED
    # ============================================

    describe 'when mission is already archived' do
      let(:mission) { create(:mission, deleted_at: 1.day.ago) }

      before do
        create_creator_mission!(mission, current_user)
      end

      it 'returns not_found' do
        expect(call.success?).to be false
        expect(call.status).to eq(:not_found)
        expect(call.error).to eq(:mission_not_found)
      end

      it 'returns appropriate error message' do
        expect(call.message).to include('archived')
      end
    end

    # ============================================
    # ALLOWED STATUSES FOR DELETION
    # ============================================

    describe 'when mission is completed' do
      let(:mission) { create(:mission, :completed) }

      before do
        create_creator_mission!(mission, current_user)
      end

      # Business rule: completed missions cannot be modified/deleted
      it 'returns forbidden (completed missions cannot be archived)' do
        expect(call.success?).to be false
        expect(call.status).to eq(:forbidden)
      end
    end

    describe 'when mission is in_progress' do
      let(:mission) { create(:mission, :in_progress) }

      before do
        create_creator_mission!(mission, current_user)
      end

      it 'allows archiving in_progress missions' do
        expect(call.success?).to be true
        expect(call.data[:mission].deleted_at).to be_present
      end
    end

    describe 'when mission is lead' do
      let(:mission) { create(:mission, :lead) }

      before do
        create_creator_mission!(mission, current_user)
      end

      it 'allows archiving lead missions' do
        expect(call.success?).to be true
        expect(call.data[:mission].deleted_at).to be_present
      end
    end

    describe 'when mission is pending' do
      let(:mission) { create(:mission, :pending) }

      before do
        create_creator_mission!(mission, current_user)
      end

      it 'allows archiving pending missions' do
        expect(call.success?).to be true
        expect(call.data[:mission].deleted_at).to be_present
      end
    end

    describe 'when mission is won' do
      let(:mission) { create(:mission, :won) }

      before do
        create_creator_mission!(mission, current_user)
      end

      it 'allows archiving won missions' do
        expect(call.success?).to be true
        expect(call.data[:mission].deleted_at).to be_present
      end
    end
  end
end
