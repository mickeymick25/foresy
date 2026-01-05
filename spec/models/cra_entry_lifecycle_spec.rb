# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CraEntry, type: :model do
  describe 'lifecycle invariants' do
    let(:user) { create(:user) }
    let(:mission) { build_stubbed(:mission) }

    context 'when CRA is draft' do
      let(:cra) { create(:cra, status: :draft, user: user) }

      it 'allows creation of entry' do
        entry = CraEntry.create!(
          cra: cra,
          mission: mission,
          date: Date.today,
          quantity: 1.0,
          unit_price: 500
        )

        expect(entry).to be_persisted
      end

      it 'allows update of entry' do
        entry = create(:cra_entry, cra: cra, mission: mission)

        expect do
          entry.update!(quantity: 2.0)
        end.not_to raise_error
      end

      it 'allows deletion of entry' do
        entry = create(:cra_entry, cra: cra, mission: mission)

        expect do
          entry.discard
        end.not_to raise_error

        expect(entry.reload).to be_discarded
      end
    end

    context 'when CRA is submitted' do
      let(:cra) { create(:cra, status: :submitted, user: user) }

      it 'forbids creation of entry' do
        expect do
          CraEntry.create!(
            cra: cra,
            mission: mission,
            date: Date.today,
            quantity: 1.0,
            unit_price: 500
          )
        end.to raise_error(CraErrors::CraSubmittedError)
      end
    end

    context 'when CRA is locked' do
      let(:cra) { create(:cra, status: :locked, user: user) }
      let(:entry) { create(:cra_entry, cra: cra, mission: mission) }

      it 'forbids update of entry' do
        expect do
          entry.update!(quantity: 2.0)
        end.to raise_error(CraErrors::CraLockedError)
      end

      it 'forbids deletion of entry' do
        expect do
          entry.destroy
        end.to raise_error(CraErrors::CraLockedError)
      end
    end
  end
end
