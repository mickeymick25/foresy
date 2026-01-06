# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CraEntry, type: :model do
  describe 'business uniqueness invariant' do
    let(:cra) { create(:cra, status: :draft) }
    let(:mission) { create(:mission) }
    let(:date) { Date.current }

    context 'when entry is unique' do
      it 'allows creation' do
        expect do
          create(:cra_entry, cra: cra, mission: mission, date: date)
        end.to change(CraEntry, :count).by(1)
      end
    end

    context 'when duplicate entry exists' do
      before do
        create(:cra_entry, cra: cra, mission: mission, date: date)
      end

      it 'forbids duplicate (cra, mission, date)' do
        expect do
          create(:cra_entry, cra: cra, mission: mission, date: date)
        end.to raise_error(CraErrors::DuplicateEntryError)
      end
    end

    context 'when updating existing entry' do
      it 'does not self-collide' do
        entry = create(:cra_entry, cra: cra, mission: mission, date: date)

        expect do
          entry.update!(quantity: entry.quantity + 1)
        end.not_to raise_error
      end
    end
  end
end
