# frozen_string_literal: true

require 'rails_helper'

# Tests for CraEntryServices::Create - Validates the extracted service architecture
# Tests the migrated pattern: CraEntryServices::Create.call with ApplicationResult contract
#
# MIGRATION CONTEXT:
# - Extracted from CraEntry model callbacks and business logic
# - Architecture: self.call → new → #call pattern
# - ApplicationResult contract for all returns
# - Explicit CRA recalculation (no hidden callbacks)
#
RSpec.describe CraEntryServices::Create, type: :service do
  let(:current_user) { create(:user) }
  let(:company) { create(:company) }
  let(:cra) { create(:cra, status: 'draft', created_by_user_id: current_user.id) }

  let(:valid_attributes) do
    {
      date: Date.new(2024, 12, 15),
      quantity: 8.0,
      unit_price: 75_000,
      description: 'Development work'
    }
  end

  before do
    create(:user_company, user: current_user, company: company, role: 'independent')
    cra
  end

  describe 'class loading and methods' do
    it 'loads CraEntryServices::Create class correctly' do
      expect(defined?(CraEntryServices::Create)).to eq('constant')
    end

    it 'has call class method' do
      expect(described_class).to respond_to(:call)
    end

    it 'call method has correct signature' do
      # Service has `_ = nil` as first param, so arity is -2
      expect(described_class.method(:call).arity).to eq(-2)
    end
  end

  describe 'successful creation' do
    subject(:result) do
      CraEntryServices::Create.call(
        cra: cra,
        attributes: valid_attributes,
        current_user: current_user
      )
    end

    it 'returns ApplicationResult' do
      expect(result).to be_a(ApplicationResult)
    end

    it 'has success status' do
      expect(result).to be_success
    end

    it 'returns CRA entry in data' do
      expect(result.data).to have_key(:cra_entry)
      expect(result.data[:cra_entry]).to be_a(Hash)
    end

    it 'has success message' do
      expect(result.message).to include('created successfully')
    end

    it 'creates CRA entry with correct attributes' do
      cra_entry = result.data[:cra_entry]
      expect(cra_entry[:date]).to eq(Date.new(2024, 12, 15))
      expect(cra_entry[:quantity]).to eq(8.0)
      expect(cra_entry[:unit_price]).to eq(75_000)
      expect(cra_entry[:description]).to eq('Development work')
    end

    it 'creates CRA entry in database' do
      expect { result }.to change(CraEntry, :count).by(1)
    end

    it 'associates CRA entry with CRA' do
      result
      created_entry = CraEntry.last
      expect(created_entry.cras).to include(cra)
    end

    it 'recalculates CRA totals' do
      expect(cra).to receive(:recalculate_totals).once
      result
    end
  end

  describe 'input validation errors' do
    context 'when CRA is nil' do
      subject(:result) do
        CraEntryServices::Create.call(
          cra: nil,
          attributes: valid_attributes,
          current_user: current_user
        )
      end

      it 'returns bad_request ApplicationResult' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:missing_cra)
      end
    end

    context 'when attributes are nil' do
      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: nil,
          current_user: current_user
        )
      end

      it 'returns bad_request ApplicationResult' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:missing_attributes)
      end
    end

    context 'when current_user is nil' do
      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: valid_attributes,
          current_user: nil
        )
      end

      it 'returns bad_request ApplicationResult' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:missing_user)
      end
    end
  end

  describe 'permission validation errors' do
    let(:other_user) { create(:user) }

    subject(:result) do
      CraEntryServices::Create.call(
        cra: cra,
        attributes: valid_attributes,
        current_user: other_user
      )
    end

    it 'returns forbidden when user is not CRA creator' do
      expect(result).to be_failure
      expect(result.status).to eq(:forbidden)
      expect(result.error).to eq(:insufficient_permissions)
    end
  end

  describe 'CRA lifecycle validation errors' do
    context 'when CRA is submitted' do
      let(:cra) { create(:cra, status: 'submitted', created_by_user_id: current_user.id) }

      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: valid_attributes,
          current_user: current_user
        )
      end

      it 'returns conflict for invalid CRA state' do
        expect(result).to be_failure
        expect(result.status).to eq(:conflict)
        expect(result.error).to eq(:invalid_cra_state)
        expect(result.message).to include('Cannot create entries in submitted or locked CRAs')
      end
    end

    context 'when CRA is locked' do
      let(:cra) { create(:cra, status: 'locked', created_by_user_id: current_user.id) }

      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: valid_attributes,
          current_user: current_user
        )
      end

      it 'returns conflict for invalid CRA state' do
        expect(result).to be_failure
        expect(result.status).to eq(:conflict)
        expect(result.error).to eq(:invalid_cra_state)
      end
    end
  end

  describe 'business rule validation errors' do
    context 'when date is missing' do
      let(:attributes_without_date) { valid_attributes.except(:date) }

      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: attributes_without_date,
          current_user: current_user
        )
      end

      it 'returns bad_request for invalid date' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:invalid_date)
      end
    end

    context 'when date is in the future' do
      let(:future_attributes) { valid_attributes.merge(date: Date.current + 1.day) }

      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: future_attributes,
          current_user: current_user
        )
      end

      it 'returns bad_request for future date' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:future_date_not_allowed)
      end
    end

    context 'when quantity is zero' do
      let(:zero_quantity_attributes) { valid_attributes.merge(quantity: 0) }

      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: zero_quantity_attributes,
          current_user: current_user
        )
      end

      it 'returns bad_request for invalid quantity' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:invalid_quantity)
      end
    end

    context 'when quantity is negative' do
      let(:negative_quantity_attributes) { valid_attributes.merge(quantity: -1) }

      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: negative_quantity_attributes,
          current_user: current_user
        )
      end

      it 'returns bad_request for invalid quantity' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:invalid_quantity)
      end
    end

    context 'when unit_price is zero' do
      let(:zero_price_attributes) { valid_attributes.merge(unit_price: 0) }

      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: zero_price_attributes,
          current_user: current_user
        )
      end

      it 'returns bad_request for invalid unit_price' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:invalid_unit_price)
      end
    end

    context 'when description is too long' do
      let(:long_description) { 'a' * 501 }
      let(:long_description_attributes) { valid_attributes.merge(description: long_description) }

      subject(:result) do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: long_description_attributes,
          current_user: current_user
        )
      end

      it 'returns bad_request for description too long' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:description_too_long)
      end
    end
  end

  describe 'duplicate entry validation' do
    let(:mission) { create(:mission) }
    let(:attributes_with_mission) { valid_attributes.merge(mission_id: mission.id) }

    before do
      # Create existing CRA entry for same CRA, mission, and date
      create(:cra_entry,
             date: Date.new(2024, 12, 15),
             quantity: 4.0,
             unit_price: 50_000,
             cra_entry_cras: [create(:cra_entry_cra, cra: cra)],
             cra_entry_missions: [create(:cra_entry_mission, mission: mission)])
    end

    subject(:result) do
      CraEntryServices::Create.call(
        cra: cra,
        attributes: attributes_with_mission,
        current_user: current_user
      )
    end

    it 'returns conflict for duplicate entry' do
      expect(result).to be_failure
      expect(result.status).to eq(:conflict)
      expect(result.error).to eq(:duplicate_entry)
      expect(result.message).to include('already exists for this mission and date')
    end
  end

  describe 'mission association' do
    let(:mission) { create(:mission) }
    let(:attributes_with_mission) { valid_attributes.merge(mission_id: mission.id) }

    subject(:result) do
      CraEntryServices::Create.call(
        cra: cra,
        attributes: attributes_with_mission,
        current_user: current_user
      )
    end

    it 'associates CRA entry with mission' do
      result
      created_entry = CraEntry.last
      expect(created_entry.missions).to include(mission)
    end
  end

  describe 'optional description' do
    let(:attributes_without_description) { valid_attributes.except(:description) }

    subject(:result) do
      CraEntryServices::Create.call(
        cra: cra,
        attributes: attributes_without_description,
        current_user: current_user
      )
    end

    it 'creates CRA entry without description' do
      expect(result).to be_success
      cra_entry = result.data[:cra_entry]
      expect(cra_entry[:description]).to be_nil
    end
  end

  describe 'optional mission' do
    subject(:result) do
      CraEntryServices::Create.call(
        cra: cra,
        attributes: valid_attributes,
        current_user: current_user
      )
    end

    it 'creates CRA entry without mission association' do
      expect(result).to be_success
      created_entry = CraEntry.last
      expect(created_entry.missions).to be_empty
    end
  end

  describe 'architecture validation' do
    it 'uses ApplicationResult pattern exclusively' do
      # Test both success and failure cases
      success_result = CraEntryServices::Create.call(
        cra: cra,
        attributes: valid_attributes,
        current_user: current_user
      )

      failure_result = CraEntryServices::Create.call(
        cra: nil,
        attributes: valid_attributes,
        current_user: current_user
      )

      # Both should return ApplicationResult instances
      expect(success_result).to be_a(ApplicationResult)
      expect(failure_result).to be_a(ApplicationResult)

      # No exceptions should be raised
      expect { success_result }.not_to raise_error
      expect { failure_result }.not_to raise_error
    end

    it 'has consistent interface with other services' do
      # Validates that CraEntryServices::Create follows the same pattern
      # as CraServices and other services

      expect(described_class.respond_to?(:call)).to be true

      # Method should take keyword arguments
      expect(described_class.method(:call).parameters).to include(%i[keyreq cra], %i[keyreq attributes],
                                                                  %i[keyreq current_user])
    end
  end

  describe 'transaction safety' do
    it 'creates entry atomically' do
      # This test verifies that if any part of the creation fails,
      # no partial data is left in the database

      expect do
        CraEntryServices::Create.call(
          cra: cra,
          attributes: valid_attributes.merge(date: 'invalid'),
          current_user: current_user
        )
      end.not_to change(CraEntry, :count)
    end
  end

  describe 'CRA recalculation integration' do
    it 'calls CRA recalculation after successful creation' do
      expect(cra).to receive(:recalculate_totals).once

      CraEntryServices::Create.call(
        cra: cra,
        attributes: valid_attributes,
        current_user: current_user
      )
    end

    it 'does not recalculate CRA on validation failure' do
      expect(cra).not_to receive(:recalculate_totals)

      CraEntryServices::Create.call(
        cra: cra,
        attributes: valid_attributes.merge(date: 'invalid'),
        current_user: current_user
      )
    end
  end
end
