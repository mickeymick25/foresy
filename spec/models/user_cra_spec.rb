# frozen_string_literal: true

require 'rails_helper'

# RSpec tests for UserCra model
#
# Tests cover:
# - Associations (belongs_to :user, :cra)
# - Validations (presence, role inclusion)
# - Scopes (creators, for_cra, for_user, by_role)
# - Business methods (creator?, cra_creator)
# - Database constraints (partial unique index, CHECK role)
#
# @see app/models/user_cra.rb
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md
#
RSpec.describe UserCra, type: :model do
  # Factories
  let(:user) { create(:user) }
  let(:cra) { create(:cra, created_by_user_id: user.id) }

  describe 'Associations' do
    it { is_expected.to belong_to(:user).required }
    it { is_expected.to belong_to(:cra).required }
  end

  describe 'Validations' do
    describe 'user_id' do
      it 'validates presence' do
        user_cra = build(:user_cra, user_id: nil)
        expect(user_cra).not_to be_valid
        expect(user_cra.errors[:user_id]).to include("can't be blank")
      end
    end

    describe 'cra_id' do
      it 'validates presence' do
        user_cra = build(:user_cra, cra_id: nil)
        expect(user_cra).not_to be_valid
        expect(user_cra.errors[:cra_id]).to include("can't be blank")
      end
    end

    describe 'role' do
      it 'validates presence' do
        user_cra = build(:user_cra, role: nil)
        expect(user_cra).not_to be_valid
        expect(user_cra.errors[:role]).to include("can't be blank")
      end

      it 'validates inclusion in ROLES' do
        expect { create(:user_cra, role: 'invalid') }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'allows creator role' do
        user_cra = build(:user_cra, role: 'creator')
        expect(user_cra).to be_valid
      end

      it 'allows contributor role' do
        user_cra = build(:user_cra, role: 'contributor')
        expect(user_cra).to be_valid
      end

      it 'allows reviewer role' do
        user_cra = build(:user_cra, role: 'reviewer')
        expect(user_cra).to be_valid
      end
    end
  end

  describe 'Scopes' do
    before do
      @creator = create(:user)
      @contributor = create(:user)
      @cra = create(:cra, created_by_user_id: @creator.id)

      create(:user_cra, user: @creator, cra: @cra, role: 'creator')
      create(:user_cra, user: @contributor, cra: @cra, role: 'contributor')
    end

    describe '.creators' do
      it 'returns only creator roles' do
        expect(UserCra.creators.count).to eq(1)
        expect(UserCra.creators.first.role).to eq('creator')
      end
    end

    describe '.for_cra' do
      it 'filters by cra' do
        result = UserCra.for_cra(@cra.id)
        expect(result.count).to eq(2)
      end

      it 'returns empty for non-existent cra' do
        result = UserCra.for_cra(SecureRandom.uuid)
        expect(result).to be_empty
      end
    end

    describe '.for_user' do
      it 'filters by user' do
        result = UserCra.for_user(@creator.id)
        expect(result.count).to eq(1)
        expect(result.first.user_id).to eq(@creator.id)
      end
    end

    describe '.by_role' do
      it 'filters by specific role' do
        result = UserCra.by_role('creator')
        expect(result.count).to eq(1)
        expect(result.first.role).to eq('creator')
      end
    end
  end

  describe 'Business Methods' do
    let(:user) { create(:user) }
    let(:cra) { create(:cra, created_by_user_id: user.id) }

    describe '#creator?' do
      it 'returns true for creator role' do
        user_cra = create(:user_cra, user: user, cra: cra, role: 'creator')
        expect(user_cra.creator?).to be true
      end

      it 'returns false for contributor role' do
        user_cra = create(:user_cra, user: user, cra: cra, role: 'contributor')
        expect(user_cra.creator?).to be false
      end

      it 'returns false for reviewer role' do
        user_cra = create(:user_cra, user: user, cra: cra, role: 'reviewer')
        expect(user_cra.creator?).to be false
      end
    end

    describe '.cra_creator' do
      it 'returns the creator for a specific cra' do
        create(:user_cra, user: user, cra: cra, role: 'creator')
        creator = UserCra.cra_creator(cra.id)
        expect(creator).to be_present
        expect(creator.role).to eq('creator')
      end

      it 'returns nil for cra without creator' do
        cra_no_creator = create(:cra, created_by_user_id: user.id)
        creator = UserCra.cra_creator(cra_no_creator.id)
        expect(creator).to be_nil
      end
    end
  end

  describe 'Database Constraints' do
    let(:user) { create(:user) }
    let(:cra) { create(:cra, created_by_user_id: user.id) }

    describe 'Partial Unique Index' do
      context 'when role = creator' do
        it 'prevents multiple creators for the same cra' do
          create(:user_cra, user: user, cra: cra, role: 'creator')
          expect {
            create(:user_cra, user_id: user.id + 1, cra: cra, role: 'creator')
          }.to raise_error(ActiveRecord::RecordNotUnique)
        end

        it 'allows one creator per cra' do
          expect {
            create(:user_cra, user: user, cra: cra, role: 'creator')
          }.not_to raise_error
        end
      end

      context 'when role != creator' do
        it 'allows multiple contributors for the same cra' do
          user2 = create(:user)
          create(:user_cra, user: user, cra: cra, role: 'contributor')
          expect {
            create(:user_cra, user: user2, cra: cra, role: 'contributor')
          }.not_to raise_error
        end

        it 'allows same user with different roles' do
          create(:user_cra, user: user, cra: cra, role: 'creator')
          expect {
            create(:user_cra, user: user, cra: cra, role: 'contributor')
          }.not_to raise_error
        end
      end
    end

    describe 'CHECK Constraint on role' do
      it 'rejects invalid role values at database level' do
        expect {
          UserCra.connection.execute(
            "INSERT INTO user_cras (user_id, cra_id, role, created_at) VALUES (#{user.id}, '#{cra.id}', 'invalid_role', NOW())"
          )
        }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end

  describe 'CASCADE Delete' do
    let(:user) { create(:user) }
    let(:cra) { create(:cra, created_by_user_id: user.id) }

    it 'is deleted when cra is HARD deleted' do
      user_cra = create(:user_cra, user: user, cra: cra, role: 'creator')
      cra_id = cra.id

      # Hard delete the cra
      cra.destroy!

      # user_cra should be deleted via CASCADE
      expect(UserCra.where(cra_id: cra_id)).not_to exist
    end

    it 'is deleted when user is deleted' do
      user_cra = create(:user_cra, user: user, cra: cra, role: 'creator')
      user_id = user.id

      # Delete the user
      user.destroy!

      # user_cra should be deleted via CASCADE
      expect(UserCra.where(user_id: user_id)).not_to exist
    end
  end

  describe 'Soft Delete Behavior' do
    let(:user) { create(:user) }
    let(:cra) { create(:cra, created_by_user_id: user.id) }

    context 'when cra is soft-deleted' do
      it 'still exists (trigger blocks manual deletion)' do
        user_cra = create(:user_cra, user: user, cra: cra, role: 'creator')

        # Soft delete the cra
        cra.update(deleted_at: Time.current)

        # user_cra should still exist (cra not hard-deleted)
        expect(UserCra.where(id: user_cra.id)).to exist
      end
    end
  end

  describe 'Feature Flag Integration' do
    it 'is accessible via FeatureFlags module' do
      expect(defined?(FeatureFlags)).to be_present
    end
  end
end
