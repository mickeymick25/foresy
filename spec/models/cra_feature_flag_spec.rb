# frozen_string_literal: true

# Cra Feature Flag Spec
#
# Tests dual-path functionality for Cra model based on USE_USER_RELATIONS feature flag.
# Validates that:
# - When flag is OFF (default): uses legacy created_by_user_id column
# - When flag is ON: uses user_cras pivot table
#
# This ensures backward compatibility while enabling relation-driven architecture.

require 'rails_helper'

RSpec.describe Cra do
  describe 'Feature Flag: accessible_to' do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:cra) { create(:cra, created_by_user_id: user.id) }

    context 'when feature flag is OFF (default)' do
      before do
        # Stub FeatureFlags.relation_driven? to return false
        stub_feature_flags(relation_driven: false)
      end

      it 'uses legacy accessible_to implementation' do
        # Cra created by user should be accessible
        expect(Cra.accessible_to(user)).to include(cra)

        # Cra not created by user should not be accessible
        expect(Cra.accessible_to(other_user)).not_to include(cra)
      end
    end

    context 'when feature flag is ON' do
      let(:user_cra) { create(:user_cra, user: user, cra: cra, role: 'creator') }

      before do
        # Stub FeatureFlags.relation_driven? to return true
        stub_feature_flags(relation_driven: true)
      end

      it 'uses relation_accessible_to implementation' do
        # Without user_cra relation, cra should not be accessible
        expect(Cra.accessible_to(user)).not_to include(cra)

        # With user_cra relation, cra should be accessible
        user_cra
        expect(Cra.accessible_to(user)).to include(cra)
      end

      it 'allows access via user_cras role' do
        # Creator role should have access
        user_cra
        expect(Cra.accessible_to(user)).to include(cra)

        # Contributor role should also have access
        create(:user_cra, user: other_user, cra: cra, role: 'contributor')
        expect(Cra.accessible_to(other_user)).to include(cra)
      end
    end
  end

  describe 'Feature Flag: creator' do
    let(:user) { create(:user) }
    let(:cra) { create(:cra, created_by_user_id: user.id) }

    context 'when feature flag is OFF (default)' do
      before do
        stub_feature_flags(relation_driven: false)
      end

      it 'uses legacy_creator implementation' do
        expect(cra.creator).to eq(user)
        expect(cra.creator.id).to eq(cra.created_by_user_id)
      end
    end

    context 'when feature flag is ON' do
      let(:other_user) { create(:user) }

      before do
        stub_feature_flags(relation_driven: true)
      end

      it 'uses relation_creator implementation' do
        # When no user_cra exists, relation_creator should return nil
        expect(cra.creator).to be_nil

        # When user_cra with creator role exists, should return that user
        create(:user_cra, user: user, cra: cra, role: 'creator')
        expect(cra.creator).to eq(user)

        # When different user has creator role
        cra_without_creator = create(:cra, created_by_user_id: user.id)
        create(:user_cra, user: other_user, cra: cra_without_creator, role: 'creator')
        expect(cra_without_creator.creator).to eq(other_user)
      end
    end
  end

  describe 'Feature Flag: modifiable_by?' do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let(:cra) { create(:cra, created_by_user_id: user.id, status: 'draft') }

    context 'when feature flag is OFF (default)' do
      before do
        stub_feature_flags(relation_driven: false)
      end

      it 'uses legacy_modifiable_by? implementation' do
        # Creator can modify
        expect(cra.modifiable_by?(user)).to be true

        # Non-creator cannot modify
        expect(cra.modifiable_by?(other_user)).to be false
      end

      it 'blocks modification when CRA is locked' do
          locked_cra = create(:cra, created_by_user_id: user.id, status: 'locked')
          expect(locked_cra.modifiable_by?(user)).to be false
        end
    end

    context 'when feature flag is ON' do
      before do
        stub_feature_flags(relation_driven: true)
      end

      it 'uses relation_modifiable_by? implementation' do
        # Without user_cra, should not be modifiable
        expect(cra.modifiable_by?(user)).to be false
        expect(cra.modifiable_by?(other_user)).to be false

        # With user_cra creator role, should be modifiable
        create(:user_cra, user: user, cra: cra, role: 'creator')
        expect(cra.modifiable_by?(user)).to be true

        # Contributor role should not be able to modify
        create(:user_cra, user: other_user, cra: cra, role: 'contributor')
        expect(cra.modifiable_by?(other_user)).to be false
      end

      it 'blocks modification when CRA is locked' do
        locked_cra = create(:cra, created_by_user_id: user.id, status: 'locked')
        create(:user_cra, user: user, cra: locked_cra, role: 'creator')
        expect(locked_cra.modifiable_by?(user)).to be false
      end
    end
  end

  # Helper method to stub FeatureFlags
  def stub_feature_flags(relation_driven:)
    allow(FeatureFlags).to receive(:relation_driven?).and_return(relation_driven)
  end
end
