# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mission, type: :model do
  let(:user) { create(:user) }

  # ==== VALID TRANSITIONS ====

  context 'lead -> pending' do
    let(:mission) { create(:mission, :with_creator, creator: user, status: 'lead') }

    it 'creates mission with correct status' do
      mission = create(:mission, :with_creator, creator: user, status: 'lead')
      expect(mission.status).to eq('lead')
    end

    it 'allows lead -> pending' do
      puts '=== DEBUG: Valid transition lead -> pending ==='
      puts "Before transition: status=#{mission.status}, user_id=#{mission.created_by_user_id}"

      expect(mission.created_by_user_id).to eq(user.id)

      expect { mission.transition_to!('pending') }.not_to raise_error

      puts "After transition: status=#{mission.status}"
      expect(mission.status).to eq('pending')
    end
  end

  context 'pending -> won' do
    let(:mission) { create(:mission, :with_creator, creator: user, status: 'pending') }

    it 'allows pending -> won' do
      puts '=== DEBUG: Valid transition pending -> won ==='
      puts "Before transition: status=#{mission.status}, user_id=#{mission.created_by_user_id}"

      expect(mission.created_by_user_id).to eq(user.id)

      expect { mission.transition_to!('won') }.not_to raise_error

      puts "After transition: status=#{mission.status}"
      expect(mission.status).to eq('won')
    end
  end

  context 'won -> in_progress' do
    let(:mission) { create(:mission, :with_creator, creator: user, status: 'won') }

    it 'allows won -> in_progress' do
      puts '=== DEBUG: Valid transition won -> in_progress ==='
      puts "Before transition: status=#{mission.status}, user_id=#{mission.created_by_user_id}"

      expect(mission.created_by_user_id).to eq(user.id)

      expect { mission.transition_to!('in_progress') }.not_to raise_error

      puts "After transition: status=#{mission.status}"
      expect(mission.status).to eq('in_progress')
    end
  end

  context 'in_progress -> completed' do
    let(:mission) { create(:mission, :with_creator, creator: user, status: 'in_progress') }

    it 'allows in_progress -> completed' do
      puts '=== DEBUG: Valid transition in_progress -> completed ==='
      puts "Before transition: status=#{mission.status}, user_id=#{mission.created_by_user_id}"

      expect(mission.created_by_user_id).to eq(user.id)

      expect { mission.transition_to!('completed') }.not_to raise_error

      puts "After transition: status=#{mission.status}"
      expect(mission.status).to eq('completed')
    end
  end

  # ==== INVALID TRANSITIONS ====

  context 'completed -> in_progress (invalid)' do
    let(:mission) { create(:mission, :with_creator, creator: user, status: 'completed') }

    it 'rejects completed -> in_progress' do
      puts '=== DEBUG: Invalid transition completed -> in_progress ==='
      puts "Before transition: status=#{mission.status}, user_id=#{mission.created_by_user_id}"

      expect(mission.created_by_user_id).to eq(user.id)

      result = mission.transition_to('in_progress')

      puts "Transition result: #{result}"
      puts "Mission errors: #{mission.errors.full_messages.inspect}"
      puts "After attempted transition: status=#{mission.status}"

      expect(result).to eq(false)
      expect(mission.status).to eq('completed')
      expect(mission.errors[:status]).to include('cannot transition from completed to in_progress')
    end
  end

  context 'won -> lead (invalid)' do
    let(:mission) { create(:mission, :with_creator, creator: user, status: 'won') }

    it 'rejects won -> lead' do
      puts '=== DEBUG: Invalid transition won -> lead ==='
      puts "Before transition: status=#{mission.status}, user_id=#{mission.created_by_user_id}"

      expect(mission.created_by_user_id).to eq(user.id)

      result = mission.transition_to('lead')

      puts "Transition result: #{result}"
      puts "Mission errors: #{mission.errors.full_messages.inspect}"
      puts "After attempted transition: status=#{mission.status}"

      expect(result).to eq(false)
      expect(mission.status).to eq('won')
      expect(mission.errors[:status]).to include('cannot transition from won to lead')
    end
  end
end
