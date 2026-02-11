# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CraEntry, type: :model do
  describe 'lifecycle invariants' do
    let(:user) { create(:user) }
    let(:mission) { create(:mission) }

    context 'when CRA is draft' do
      let(:cra) { create(:cra, status: :draft, user: user) }

      it 'allows creation of entry via service' do
        # DDD: Use service for creation
        result = CraEntryServices::Create.call(
          cra: cra,
          attributes: {
            date: Date.today,
            quantity: 1.0,
            unit_price: 50_000,
            description: 'Test entry',
            mission_id: mission.id
          },
          current_user: user
        )

        expect(result.success?).to be true
      end

      it 'allows update of entry via service' do
        entry = create(:cra_entry, cra: cra, mission: mission)

        # DDD: Use service for update
        result = CraEntryServices::Update.call(
          cra_entry: entry,
          attributes: { quantity: 2.0 },
          current_user: user
        )

        expect(result.success?).to be true
        expect(entry.reload.quantity).to eq(2.0)
      end

      it 'requires service for deletion - discarding raises error' do
        entry = create(:cra_entry, cra: cra, mission: mission)

        # DDD: discard requires explicit lifecycle validation via service
        expect do
          entry.discard
        end.to raise_error(RuntimeError, /CraEntry#discard requires explicit lifecycle validation via service/)
      end
    end

    context 'when CRA is submitted' do
      let(:cra) { create(:cra, status: :submitted, user: user) }

      it 'forbids creation of entry via service' do
        # DDD: Use service for creation - should fail for submitted CRA
        result = CraEntryServices::Create.call(
          cra: cra,
          attributes: {
            date: Date.today,
            quantity: 1.0,
            unit_price: 50_000,
            description: 'Test entry',
            mission_id: mission.id
          },
          current_user: user
        )

        expect(result.success?).to be false
        expect(result.error).to eq(:invalid_cra_state)
      end
    end

    context 'when CRA is locked' do
      let(:cra) { create(:cra, status: :locked, user: user) }
      let(:entry) { create(:cra_entry, cra: cra, mission: mission) }

      it 'forbids update of entry via service' do
        # DDD: Use service for update - should fail for locked CRA
        result = CraEntryServices::Update.call(
          cra_entry: entry,
          attributes: { quantity: 2.0 },
          current_user: user
        )

        expect(result.success?).to be false
        expect(result.error).to eq(:invalid_transition)
      end

      it 'forbids deletion of entry via service' do
        # DDD: Use service for destroy - should fail for locked CRA
        result = CraEntryServices::Destroy.call(
          cra_entry: entry,
          current_user: user
        )

        expect(result.success?).to be false
        expect(result.error).to eq(:invalid_transition)
      end
    end
  end
end
