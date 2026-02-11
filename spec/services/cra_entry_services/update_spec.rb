# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CraEntryServices::Update do
  let(:current_user) { create(:user) }
  let(:cra) { create(:cra, created_by_user_id: current_user.id) }
  let(:cra_entry) { create(:cra_entry, cra: cra, quantity: 10, unit_price: 100) }

  let(:valid_attributes) do
    {
      quantity: 15,
      unit_price: 120,
      description: 'Updated entry'
    }
  end

  describe '.call' do
    describe 'input validation' do
      it 'returns bad_request when cra_entry is nil' do
        result = described_class.call(cra_entry: nil, attributes: valid_attributes, current_user: current_user)

        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:missing_cra_entry)
        expect(result.message).to include('CRA Entry is required')
      end

      it 'returns bad_request when current_user is nil' do
        result = described_class.call(cra_entry: cra_entry, attributes: valid_attributes, current_user: nil)

        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:missing_user)
        expect(result.message).to include('Current user is required')
      end

      it 'returns internal_error when attributes are nil' do
        # attributes is a required keyword arg - passing nil causes update! to fail
        # This is caught by StandardError rescue and returns :internal_error
        result = described_class.call(cra_entry: cra_entry, attributes: nil, current_user: current_user)

        expect(result).to be_failure
        expect(result.status).to eq(:internal_error)
        expect(result.error).to eq(:update_failed)
      end
    end

    describe 'lifecycle and permission validation' do
      it 'returns forbidden if user is not creator' do
        other_user = create(:user)
        result = described_class.call(cra_entry: cra_entry, attributes: valid_attributes, current_user: other_user)

        expect(result).to be_failure
        expect(result.status).to eq(:forbidden)
        expect(result.error).to eq(:insufficient_permissions)
      end

      it 'returns conflict if CRA is not draft' do
        cra.update!(status: 'submitted')
        result = described_class.call(cra_entry: cra_entry, attributes: valid_attributes, current_user: current_user)

        expect(result).to be_failure
        expect(result.status).to eq(:conflict)
        expect(result.error).to eq(:invalid_transition)
      end
    end

    describe 'successful update' do
      it 'updates attributes and recalculates CRA totals' do
        expect(cra).to receive(:recalculate_totals).once

        result = described_class.call(cra_entry: cra_entry, attributes: valid_attributes, current_user: current_user)

        expect(result).to be_success
        expect(result.data[:cra_entry].quantity).to eq(15)
        expect(result.data[:cra_entry].unit_price).to eq(120)
        expect(result.data[:cra_entry].description).to eq('Updated entry')
      end
    end

    describe 'interface validation' do
      it 'returns an ApplicationResult object' do
        result = described_class.call(cra_entry: cra_entry, attributes: valid_attributes, current_user: current_user)
        expect(result).to be_a(ApplicationResult)
      end
    end
  end
end
