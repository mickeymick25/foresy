# frozen_string_literal: true

require 'rails_helper'

# MissionServices::Update Specs
# Tests for the Update service following the same pattern as Create
#
# Test Coverage:
# - Success: update mission attributes, status transition
# - Permission: non-creator cannot update
# - Validation: invalid payload, invalid status transition
RSpec.describe MissionServices::Update do
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
        mission_params: mission_params,
        current_user: current_user
      )
    end

    let(:mission_params) { {} }

    # ============================================
    # SUCCESS CASES
    # ============================================

    describe 'when user is the creator (success cases)' do
      let(:mission) { create(:mission) }

      context 'with valid name update' do
        before do
          create_creator_mission!(mission, current_user)
        end
        let(:mission_params) { { name: 'Updated Mission Name' } }

        it 'returns success' do
          expect(call.success?).to be true
        end

        it 'returns the updated mission' do
          expect(call.data[:mission].name).to eq('Updated Mission Name')
        end
      end

      context 'with valid description update' do
        before do
          create_creator_mission!(mission, current_user)
        end

        let(:mission_params) { { description: 'New description' } }

        it 'updates the description successfully' do
          expect(call.success?).to be true
          expect(call.data[:mission].description).to eq('New description')
        end
      end

      context 'with valid daily_rate update for time_based mission' do
        let(:mission) { create(:mission, :time_based, daily_rate: 500) }

        before do
          create_creator_mission!(mission, current_user)
        end

        let(:mission_params) { { daily_rate: 600 } }

        it 'updates the daily_rate successfully' do
          expect(call.success?).to be true
          expect(call.data[:mission].daily_rate.to_i).to eq(600)
        end
      end

      context 'with valid fixed_price update for fixed_price mission' do
        let(:mission) { create(:mission, :fixed_price, fixed_price: 5000) }

        before do
          create_creator_mission!(mission, current_user)
        end

        let(:mission_params) { { fixed_price: 6000 } }

        it 'updates the fixed_price successfully' do
          expect(call.success?).to be true
          expect(call.data[:mission].fixed_price.to_i).to eq(6000)
        end
      end

      # Status transition tests
      context 'with valid status transition lead -> pending' do
        let(:mission) { create(:mission, :lead) }

        before do
          create_creator_mission!(mission, current_user)
        end

        let(:mission_params) { { status: 'pending' } }

        it 'transitions successfully' do
          expect(call.success?).to be true
          expect(call.data[:mission].status).to eq('pending')
        end
      end

      context 'with valid status transition pending -> won' do
        let(:mission) { create(:mission, :pending) }

        before do
          create_creator_mission!(mission, current_user)
        end

        let(:mission_params) { { status: 'won' } }

        it 'transitions successfully' do
          expect(call.success?).to be true
          expect(call.data[:mission].status).to eq('won')
        end
      end

      context 'with valid status transition won -> in_progress' do
        let(:mission) { create(:mission, :won) }

        before do
          create_creator_mission!(mission, current_user)
        end

        let(:mission_params) { { status: 'in_progress' } }

        it 'transitions successfully' do
          expect(call.success?).to be true
          expect(call.data[:mission].status).to eq('in_progress')
        end
      end

      context 'with valid status transition in_progress -> completed' do
        let(:mission) { create(:mission, :in_progress) }

        before do
          create_creator_mission!(mission, current_user)
        end

        let(:mission_params) { { status: 'completed' } }

        it 'transitions successfully' do
          expect(call.success?).to be true
          expect(call.data[:mission].status).to eq('completed')
        end
      end

      context 'with both status and attributes update' do
        let(:mission) { create(:mission, :pending, name: 'Original') }

        before do
          create_creator_mission!(mission, current_user)
        end

        let(:mission_params) { { status: 'won', name: 'Updated Name' } }

        it 'updates both status and attributes' do
          expect(call.success?).to be true
          expect(call.data[:mission].status).to eq('won')
          expect(call.data[:mission].name).to eq('Updated Name')
        end
      end
    end

    # ============================================
    # PERMISSION DENIED CASES
    # ============================================

    describe 'when user is NOT the creator (permission denied)' do
      let(:mission) { create(:mission, :with_creator, creator: other_user) }
      let(:mission_params) { { name: 'Hacked Name' } }

      it 'returns forbidden' do
        expect(call.success?).to be false
        expect(call.status).to eq(:forbidden)
        expect(call.error).to eq(:forbidden)
      end

      it 'returns appropriate error message' do
        expect(call.message).to include('creator')
      end
    end

    # ============================================
    # INVALID STATUS TRANSITIONS
    # ============================================

    describe 'with invalid status transitions' do
      let(:mission) { create(:mission, :lead) }

      before do
        create_creator_mission!(mission, current_user)
      end

      context 'lead -> won (invalid - must go through pending)' do
        let(:mission_params) { { status: 'won' } }

        it 'returns unprocessable_entity' do
          expect(call.success?).to be false
          expect(call.status).to eq(:unprocessable_entity)
          expect(call.error).to eq(:invalid_transition)
        end

        it 'returns appropriate error message' do
          expect(call.message).to include('Cannot transition')
        end
      end

      context 'lead -> completed (invalid)' do
        let(:mission_params) { { status: 'completed' } }

        it 'returns unprocessable_entity' do
          expect(call.success?).to be false
          expect(call.status).to eq(:unprocessable_entity)
        end
      end

      context 'with invalid status value' do
        let(:mission_params) { { status: 'invalid_status' } }

        it 'returns bad_request' do
          expect(call.success?).to be false
          expect(call.status).to eq(:bad_request)
          expect(call.error).to eq(:invalid_status)
        end
      end
    end

    # ============================================
    # VALIDATION ERROR CASES
    # ============================================

    describe 'with validation errors' do
      let(:mission) { create(:mission, :time_based, daily_rate: 500) }

      before do
        create_creator_mission!(mission, current_user)
      end

      context 'with invalid financial field (fixed_price for time_based)' do
        let(:mission_params) { { fixed_price: 1000 } }

        it 'returns bad_request' do
          expect(call.success?).to be false
          expect(call.status).to eq(:bad_request)
          expect(call.error).to eq(:invalid_financial_field)
        end
      end

      context 'with invalid date range' do
        let(:mission_params) do
          {
            start_date: '2026-01-01',
            end_date: '2025-01-01'
          }
        end

        it 'returns bad_request' do
          expect(call.success?).to be false
          expect(call.status).to eq(:bad_request)
          expect(call.error).to eq(:invalid_date_range)
        end
      end

      context 'with invalid mission_type' do
        let(:mission_params) { { mission_type: 'invalid_type' } }

        it 'returns bad_request' do
          expect(call.success?).to be false
          expect(call.status).to eq(:bad_request)
          expect(call.error).to eq(:invalid_mission_type)
        end
      end
    end

    # ============================================
    # COMPLETED MISSION (cannot be modified)
    # ============================================

    describe 'when mission is already completed' do
      let(:mission) { create(:mission, :completed) }

      before do
        create_creator_mission!(mission, current_user)
      end

      let(:mission_params) { { name: 'New Name' } }

      it 'returns forbidden (completed missions cannot be modified)' do
        expect(call.success?).to be false
        expect(call.status).to eq(:forbidden)
      end
    end
  end
end
