# frozen_string_literal: true

require 'rails_helper'

# Service-level tests for CRA total recalculation (FC-07 Phase 3C)
#
# Tests the automatic recalculation of total_days and total_amount
# through the business services layer, not through model callbacks.
#
# This is the correct architectural level for testing:
# - Uses services (CreateService, UpdateService, DestroyService)
# - Tests business workflows, not implementation details
# - Verifies that total recalculation happens as a side effect
# - No direct model manipulation or callback testing
#
# Contract Requirements:
# - total_days = sum of all cra_entry.quantity for the CRA
# - total_amount = sum of all cra_entry.quantity * unit_price for the CRA
# - Recalculation is automatic and triggered by service operations
# - Recalculation only affects CRAs in draft status
# - All operations are transactional
RSpec.describe 'CRA Total Recalculation via Services' do
  let(:user) { create(:user) }
  let(:mission) { create(:mission) }
  let(:cra) { create(:cra, created_by_user_id: user.id, month: 3, year: 2024, status: 'draft') }

  before do
    # Link CRA to mission for valid CraEntry creation
    create(:cra_mission, cra: cra, mission: mission)

    # Configure Company associations for user mission access
    company = create(:company)
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')
  end

  describe 'CraEntries::CreateService' do
    describe 'automatic total recalculation' do
      context 'when creating the first entry for a CRA' do
        it 'calculates and updates CRA totals correctly' do
          # Initial totals should be zero
          expect(cra.total_days).to eq(0)
          expect(cra.total_amount).to eq(0)

          # Create entry through the service
          result = Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: '2024-03-15',
              quantity: 1.5,
              unit_price: 600_00, # 600.00 EUR in cents
              description: 'Development work'
            },
            mission_id: mission.id,
            current_user: user
          )

          # Verify service returned the created entry
          expect(result.entry).to be_present
          expect(result.entry.quantity).to eq(1.5)
          expect(result.entry.unit_price).to eq(600_00)

          # Verify CRA totals were updated
          cra.reload
          expect(cra.total_days).to eq(1.5)
          expect(cra.total_amount).to eq(90_000) # 1.5 * 600.00 EUR = 900.00 EUR = 90,000 cents
        end
      end

      context 'when adding entries to an existing CRA' do
        before do
          # Create first entry through service
          Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: '2024-03-15',
              quantity: 2.0,
              unit_price: 500_00, # 500.00 EUR
              description: 'First day work'
            },
            mission_id: mission.id,
            current_user: user
          )
          cra.reload
        end

        it 'accumulates totals correctly' do
          # Verify initial totals
          expect(cra.total_days).to eq(2.0)
          expect(cra.total_amount).to eq(100_000) # 2.0 * 500.00 = 1000.00 EUR = 100,000 cents

          # Add second entry through service
          Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: '2024-03-16',
              quantity: 0.5,
              unit_price: 800_00, # 800.00 EUR
              description: 'Half day work'
            },
            mission_id: mission.id,
            current_user: user
          )
          cra.reload

          # Verify totals accumulated correctly
          expect(cra.total_days).to eq(2.5) # 2.0 + 0.5
          expect(cra.total_amount).to eq(140_000) # (2.0 * 500) + (0.5 * 800) = 1000 + 400 = 1400.00 EUR = 140,000 cents
        end
      end

      context 'when creating multiple entries in sequence' do
        it 'maintains running totals accurately' do
          entries_data = [
            { date: '2024-03-15', quantity: 1.0, unit_price: 500_00, description: 'Day 1' },
            { date: '2024-03-16', quantity: 1.5, unit_price: 600_00, description: 'Day 2' },
            { date: '2024-03-17', quantity: 0.5, unit_price: 700_00, description: 'Day 3' }
          ]

          total_days = 0
          total_amount = 0

          entries_data.each do |data|
            # Calculate expected totals before creation
            total_days += data[:quantity]
            total_amount += data[:quantity] * data[:unit_price]

            # Create entry through service
            Api::V1::CraEntries::CreateService.call(
              cra: cra,
              entry_params: data,
              mission_id: mission.id,
              current_user: user
            )
            cra.reload

            # Verify running totals are correct
            expect(cra.total_days).to eq(total_days)
            expect(cra.total_amount).to eq(total_amount)
          end
        end
      end

      context 'when creating entry without mission' do
        it 'calculates totals correctly for mission-less entries' do
          Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: '2024-03-15',
              quantity: 2.0,
              unit_price: 500_00,
              description: 'General work'
            },
            mission_id: nil, # No mission
            current_user: user
          )
          cra.reload

          expect(cra.total_days).to eq(2.0)
          expect(cra.total_amount).to eq(100_000)
        end
      end
    end

    describe 'transaction integrity' do
      context 'when entry creation fails' do
        it 'does not update CRA totals if transaction fails' do
          expect(cra.total_days).to eq(0)
          expect(cra.total_amount).to eq(0)

          # Attempt to create invalid entry (negative quantity should fail)
          expect do
            Api::V1::CraEntries::CreateService.call(
              cra: cra,
              entry_params: {
                date: '2024-03-15',
                quantity: -1.0, # Invalid quantity
                unit_price: 500_00,
                description: 'Invalid work'
              },
              mission_id: mission.id,
              current_user: user
            )
          end.to raise_error(CraErrors::InvalidPayloadError)

          # Verify CRA totals remain unchanged
          cra.reload
          expect(cra.total_days).to eq(0)
          expect(cra.total_amount).to eq(0)
        end
      end
    end

    describe 'business rule compliance' do
      context 'when CRA is not in draft status' do
        before do
          cra.update!(status: 'submitted')
        end

        it 'prevents entry creation and total recalculation' do
          expect do
            Api::V1::CraEntries::CreateService.call(
              cra: cra,
              entry_params: {
                date: '2024-03-15',
                quantity: 1.0,
                unit_price: 500_00,
                description: 'Work attempt'
              },
              mission_id: mission.id,
              current_user: user
            )
          end.to raise_error(CraErrors::CraSubmittedError)

          # Verify no totals were calculated
          cra.reload
          expect(cra.total_days).to eq(0)
          expect(cra.total_amount).to eq(0)
        end
      end

      context 'when duplicate entry exists' do
        before do
          # Create initial entry
          Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: '2024-03-15',
              quantity: 1.0,
              unit_price: 500_00,
              description: 'Original work'
            },
            mission_id: mission.id,
            current_user: user
          )
          cra.reload
        end

        it 'prevents duplicate creation and total calculation' do
          expect do
            Api::V1::CraEntries::CreateService.call(
              cra: cra,
              entry_params: {
                date: '2024-03-15', # Same date
                quantity: 2.0,
                unit_price: 600_00,
                description: 'Duplicate work'
              },
              mission_id: mission.id, # Same mission
              current_user: user
            )
          end.to raise_error(CraErrors::DuplicateEntryError)

          # Verify totals remain for original entry only
          cra.reload
          expect(cra.total_days).to eq(1.0)
          expect(cra.total_amount).to eq(50_000)
        end
      end
    end
  end

  describe 'CraEntries::UpdateService' do
    let(:entry) do
      # Create initial entry through service
      result = Api::V1::CraEntries::CreateService.call(
        cra: cra,
        entry_params: {
          date: '2024-03-15',
          quantity: 1.0,
          unit_price: 500_00,
          description: 'Original work'
        },
        mission_id: mission.id,
        current_user: user
      )
      result.entry
    end

    before do
      entry # Force lazy evaluation to create the entry
      cra.reload
      expect(cra.total_days).to eq(1.0)
      expect(cra.total_amount).to eq(50_000)
    end

    describe 'automatic total recalculation on update' do
      context 'when updating quantity' do
        it 'recalculates totals correctly' do
          # Update entry quantity through service
          Api::V1::CraEntries::UpdateService.call(
            entry: entry,
            entry_params: {
              quantity: 2.5,
              description: 'Updated work'
            },
            mission_id: mission.id,
            current_user: user
          )
          cra.reload

          # Verify totals were recalculated
          expect(cra.total_days).to eq(2.5)
          expect(cra.total_amount).to eq(125_000) # 2.5 * 500.00 = 1250.00 EUR = 125,000 cents
        end
      end

      context 'when updating unit price' do
        it 'recalculates totals correctly' do
          # Update entry unit price through service
          Api::V1::CraEntries::UpdateService.call(
            entry: entry,
            entry_params: {
              unit_price: 600_00, # Changed from 500.00 to 600.00
              description: 'Updated rate'
            },
            mission_id: mission.id,
            current_user: user
          )
          cra.reload

          # Verify totals were recalculated
          expect(cra.total_days).to eq(1.0) # Quantity unchanged
          expect(cra.total_amount).to eq(60_000) # 1.0 * 600.00 = 600.00 EUR = 60,000 cents
        end
      end

      context 'when updating both quantity and unit price' do
        it 'recalculates totals with new values' do
          # Update both quantity and unit price through service
          Api::V1::CraEntries::UpdateService.call(
            entry: entry,
            entry_params: {
              quantity: 1.5,
              unit_price: 800_00,
              description: 'Updated work and rate'
            },
            mission_id: mission.id,
            current_user: user
          )
          cra.reload

          # Verify totals were recalculated
          expect(cra.total_days).to eq(1.5)
          expect(cra.total_amount).to eq(120_000) # 1.5 * 800.00 = 1200.00 EUR = 120,000 cents
        end
      end

      context 'when updating multiple entries in sequence' do
        before do
          # Add a second entry
          result = Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: '2024-03-16',
              quantity: 1.0,
              unit_price: 400_00,
              description: 'Second entry'
            },
            mission_id: mission.id,
            current_user: user
          )
          @second_entry = result.entry
          cra.reload
        end

        it 'maintains accurate totals across multiple updates' do
          # Initial totals: entry (1.0 * 500) + second_entry (1.0 * 400) = 500 + 400 = 900.00 EUR
          expect(cra.total_days).to eq(2.0)
          expect(cra.total_amount).to eq(90_000)

          # Update first entry
          Api::V1::CraEntries::UpdateService.call(
            entry: entry,
            entry_params: { quantity: 2.0 },
            mission_id: mission.id,
            current_user: user
          )
          cra.reload

          # New totals: entry (2.0 * 500) + second_entry (1.0 * 400) = 1000 + 400 = 1400.00 EUR
          expect(cra.total_days).to eq(3.0)
          expect(cra.total_amount).to eq(140_000)

          # Update second entry
          Api::V1::CraEntries::UpdateService.call(
            entry: @second_entry,
            entry_params: { unit_price: 600_00 },
            mission_id: mission.id,
            current_user: user
          )
          cra.reload

          # New totals: entry (2.0 * 500) + second_entry (1.0 * 600) = 1000 + 600 = 1600.00 EUR
          expect(cra.total_days).to eq(3.0)
          expect(cra.total_amount).to eq(160_000)
        end
      end
    end

    describe 'transaction integrity' do
      context 'when update fails validation' do
        it 'does not update CRA totals if transaction fails' do
          expect(cra.total_days).to eq(1.0)
          expect(cra.total_amount).to eq(50_000)

          # Attempt invalid update (negative quantity)
          expect do
            Api::V1::CraEntries::UpdateService.call(
              entry: entry,
              entry_params: { quantity: -1.0 },
              mission_id: mission.id,
              current_user: user
            )
          end.to raise_error(CraErrors::InvalidPayloadError)

          # Verify CRA totals remain unchanged
          cra.reload
          expect(cra.total_days).to eq(1.0)
          expect(cra.total_amount).to eq(50_000)
        end
      end
    end

    describe 'business rule compliance' do
      context 'when CRA is not in draft status' do
        before do
          cra.update!(status: 'locked')
        end

        it 'prevents entry update and total recalculation' do
          expect do
            Api::V1::CraEntries::UpdateService.call(
              entry: entry,
              entry_params: { quantity: 2.0 },
              mission_id: mission.id,
              current_user: user
            )
          end.to raise_error(CraErrors::CraLockedError)

          # Verify CRA totals remain unchanged
          cra.reload
          expect(cra.total_days).to eq(1.0)
          expect(cra.total_amount).to eq(50_000)
        end
      end
    end
  end

  describe 'CraEntries::DestroyService' do
    let(:entry) do
      # Create initial entry through service
      result = Api::V1::CraEntries::CreateService.call(
        cra: cra,
        entry_params: {
          date: '2024-03-15',
          quantity: 1.5,
          unit_price: 600_00,
          description: 'Work to be deleted'
        },
        mission_id: mission.id,
        current_user: user
      )
      result.entry
    end

    before do
      entry # Force lazy evaluation to create the entry
      cra.reload
      expect(cra.total_days).to eq(1.5)
      expect(cra.total_amount).to eq(90_000)
    end

    describe 'automatic total recalculation on destroy' do
      context 'when destroying the only entry' do
        it 'sets totals to zero' do
          # Destroy entry through service
          Api::V1::CraEntries::DestroyService.call(
            entry: entry,
            current_user: user
          )
          cra.reload

          # Verify entry is soft deleted
          expect(entry).to be_discarded

          # Verify CRA totals are set to zero
          expect(cra.total_days).to eq(0)
          expect(cra.total_amount).to eq(0)
        end
      end

      context 'when destroying one of multiple entries' do
        before do
          # Add a second entry
          result = Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: '2024-03-16',
              quantity: 1.0,
              unit_price: 400_00,
              description: 'Second entry'
            },
            mission_id: mission.id,
            current_user: user
          )
          @second_entry = result.entry
          cra.reload

          # Initial totals: entry (1.5 * 600) + second_entry (1.0 * 400) = 900 + 400 = 1300.00 EUR
          expect(cra.total_days).to eq(2.5)
          expect(cra.total_amount).to eq(130_000)
        end

        it 'recalculates totals excluding the destroyed entry' do
          # Destroy first entry through service
          Api::V1::CraEntries::DestroyService.call(
            entry: entry,
            current_user: user
          )
          cra.reload

          # Verify totals reflect only remaining entry
          expect(cra.total_days).to eq(1.0) # Only second entry
          expect(cra.total_amount).to eq(40_000) # Only second entry: 1.0 * 400.00 = 400.00 EUR = 40,000 cents
        end
      end

      context 'when destroying entries in sequence' do
        before do
          # Add a second entry
          result = Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: '2024-03-16',
              quantity: 1.0,
              unit_price: 500_00,
              description: 'Entry 2'
            },
            mission_id: mission.id,
            current_user: user
          )
          @second_entry = result.entry

          # Add a third entry
          result = Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: '2024-03-17',
              quantity: 1.0,
              unit_price: 500_00,
              description: 'Entry 3'
            },
            mission_id: mission.id,
            current_user: user
          )
          @third_entry = result.entry
          cra.reload

          # Initial totals: 1.5 + 1.0 + 1.0 = 3.5 days
          # (1.5 * 600) + (1.0 * 500) + (1.0 * 500) = 900 + 500 + 500 = 1900.00 EUR
          expect(cra.total_days).to eq(3.5)
          expect(cra.total_amount).to eq(190_000)
        end

        it 'maintains accurate totals as entries are destroyed' do
          # Destroy first entry (1.5 days @ 600)
          Api::V1::CraEntries::DestroyService.call(entry: entry, current_user: user)
          cra.reload
          expect(cra.total_days).to eq(2.0) # 1.0 + 1.0
          expect(cra.total_amount).to eq(100_000) # (1.0 * 500) + (1.0 * 500) = 1000.00 EUR

          # Destroy second entry (1.0 days @ 500)
          Api::V1::CraEntries::DestroyService.call(entry: @second_entry, current_user: user)
          cra.reload
          expect(cra.total_days).to eq(1.0)
          expect(cra.total_amount).to eq(50_000)
        end
      end
    end

    describe 'transaction integrity' do
      context 'when destroy operation fails' do
        it 'does not update CRA totals if transaction fails' do
          expect(cra.total_days).to eq(1.5)
          expect(cra.total_amount).to eq(90_000)

          # The destroy service should succeed for valid entries, but let's test
          # that if it fails, totals remain unchanged
          allow(entry).to receive(:discard).and_return(false)

          expect do
            Api::V1::CraEntries::DestroyService.call(entry: entry, current_user: user)
          end.to raise_error(CraErrors::InternalError)

          # Verify CRA totals remain unchanged
          cra.reload
          expect(cra.total_days).to eq(1.5)
          expect(cra.total_amount).to eq(90_000)
        end
      end
    end

    describe 'business rule compliance' do
      context 'when CRA is not in draft status' do
        before do
          cra.update!(status: 'submitted')
        end

        it 'prevents entry destruction and total recalculation' do
          expect do
            Api::V1::CraEntries::DestroyService.call(entry: entry, current_user: user)
          end.to raise_error(CraErrors::CraSubmittedError)

          # Verify CRA totals remain unchanged
          cra.reload
          expect(cra.total_days).to eq(1.5)
          expect(cra.total_amount).to eq(90_000)
        end
      end

      context 'when entry is already deleted' do
        before do
          entry.discard
        end

        it 'prevents double deletion and total recalculation' do
          expect do
            Api::V1::CraEntries::DestroyService.call(entry: entry, current_user: user)
          end.to raise_error(CraErrors::EntryNotFoundError)

          # Verify CRA totals remain unchanged
          cra.reload
          expect(cra.total_days).to eq(1.5)
          expect(cra.total_amount).to eq(90_000)
        end
      end
    end
  end

  describe 'Integration scenarios' do
    context 'complete CRA lifecycle with total tracking' do
      it 'tracks totals accurately through all stages' do
        # Stage 1: Create CRA (no entries)
        expect(cra.total_days).to eq(0)
        expect(cra.total_amount).to eq(0)

        # Stage 2: Add first entry
        result1 = Api::V1::CraEntries::CreateService.call(
          cra: cra,
          entry_params: {
            date: '2024-03-15',
            quantity: 2.0,
            unit_price: 500_00,
            description: 'First entry'
          },
          mission_id: mission.id,
          current_user: user
        )
        cra.reload
        expect(cra.total_days).to eq(2.0)
        expect(cra.total_amount).to eq(100_000)

        # Stage 3: Add second entry
        result2 = Api::V1::CraEntries::CreateService.call(
          cra: cra,
          entry_params: {
            date: '2024-03-16',
            quantity: 0.5,
            unit_price: 800_00,
            description: 'Second entry'
          },
          mission_id: mission.id,
          current_user: user
        )
        cra.reload
        expect(cra.total_days).to eq(2.5)
        expect(cra.total_amount).to eq(140_000) # (2.0 * 500) + (0.5 * 800) = 1000 + 400 = 1400.00 EUR

        # Stage 4: Update first entry
        Api::V1::CraEntries::UpdateService.call(
          entry: result1.entry,
          entry_params: {
            quantity: 1.5,
            description: 'Updated first entry'
          },
          mission_id: mission.id,
          current_user: user
        )
        cra.reload
        expect(cra.total_days).to eq(2.0) # 1.5 + 0.5
        expect(cra.total_amount).to eq(115_000) # (1.5 * 500) + (0.5 * 800) = 750 + 400 = 1150.00 EUR

        # Stage 5: Add third entry
        Api::V1::CraEntries::CreateService.call(
          cra: cra,
          entry_params: {
            date: '2024-03-17',
            quantity: 1.5,
            unit_price: 600_00,
            description: 'Third entry'
          },
          mission_id: mission.id,
          current_user: user
        )
        cra.reload
        expect(cra.total_days).to eq(3.5) # 1.5 + 0.5 + 1.5
        # (1.5 * 500) + (0.5 * 800) + (1.5 * 600) = 750 + 400 + 900 = 2050.00 EUR
        expect(cra.total_amount).to eq(205_000)

        # Stage 6: Remove second entry
        Api::V1::CraEntries::DestroyService.call(entry: result2.entry, current_user: user)
        cra.reload
        expect(cra.total_days).to eq(3.0) # 1.5 + 1.5
        expect(cra.total_amount).to eq(165_000) # (1.5 * 500) + (1.5 * 600) = 750 + 900 = 1650.00 EUR
      end
    end

    context 'mixed operations during draft stage' do
      it 'handles mixed create/update/destroy operations correctly' do
        # Create initial entries
        result1 = Api::V1::CraEntries::CreateService.call(
          cra: cra,
          entry_params: { date: '2024-03-15', quantity: 1.0, unit_price: 500_00, description: 'Entry 1' },
          mission_id: mission.id, current_user: user
        )
        result2 = Api::V1::CraEntries::CreateService.call(
          cra: cra,
          entry_params: { date: '2024-03-16', quantity: 2.0, unit_price: 400_00, description: 'Entry 2' },
          mission_id: mission.id, current_user: user
        )

        # Initial totals: (1.0 * 500) + (2.0 * 400) = 500 + 800 = 1300.00 EUR
        cra.reload
        expect(cra.total_days).to eq(3.0)
        expect(cra.total_amount).to eq(130_000)

        # Update first entry
        Api::V1::CraEntries::UpdateService.call(
          entry: result1.entry,
          entry_params: { quantity: 1.5 },
          mission_id: mission.id,
          current_user: user
        )
        cra.reload

        # After update: (1.5 * 500) + (2.0 * 400) = 750 + 800 = 1550.00 EUR
        expect(cra.total_days).to eq(3.5)
        expect(cra.total_amount).to eq(155_000)

        # Add third entry
        Api::V1::CraEntries::CreateService.call(
          cra: cra,
          entry_params: { date: '2024-03-17', quantity: 0.5, unit_price: 600_00, description: 'Entry 3' },
          mission_id: mission.id, current_user: user
        )
        cra.reload

        # After add: (1.5 * 500) + (2.0 * 400) + (0.5 * 600) = 750 + 800 + 300 = 1850.00 EUR
        expect(cra.total_days).to eq(4.0)
        expect(cra.total_amount).to eq(185_000)

        # Remove second entry
        Api::V1::CraEntries::DestroyService.call(entry: result2.entry, current_user: user)
        cra.reload

        # After remove: (1.5 * 500) + (0.5 * 600) = 750 + 300 = 1050.00 EUR
        expect(cra.total_days).to eq(2.0)
        expect(cra.total_amount).to eq(105_000)
      end
    end
  end

  describe 'Precision and edge cases' do
    context 'with fractional quantities' do
      it 'calculates totals with high precision' do
        Api::V1::CraEntries::CreateService.call(
          cra: cra,
          entry_params: {
            date: '2024-03-15',
            quantity: 0.25, # Quarter day
            unit_price: 100_00, # 100.00 EUR
            description: 'Quarter day work'
          },
          mission_id: mission.id,
          current_user: user
        )
        cra.reload

        expect(cra.total_days).to eq(0.25)
        expect(cra.total_amount).to eq(25_00) # 0.25 * 100.00 = 25.00 EUR = 2,500 cents
      end
    end

    context 'with large quantities' do
      it 'handles large quantities without overflow' do
        Api::V1::CraEntries::CreateService.call(
          cra: cra,
          entry_params: {
            date: '2024-03-15',
            quantity: 31.5, # Maximum realistic monthly total
            unit_price: 1_000_00, # 1000.00 EUR per day
            description: 'Intensive month'
          },
          mission_id: mission.id,
          current_user: user
        )
        cra.reload

        expect(cra.total_days).to eq(31.5)
        expect(cra.total_amount).to eq(3_150_000) # 31.5 days × 1_000.00 EUR/day = 31_500.00 EUR = 3_150_000 cents
      end
    end

    context 'with many entries' do
      it 'calculates totals efficiently for many entries' do
        # Create 50 entries with unique dates
        50.times do |i|
          date = Date.new(2024, 3, 1) + i.days
          Api::V1::CraEntries::CreateService.call(
            cra: cra,
            entry_params: {
              date: date.strftime('%Y-%m-%d'),
              quantity: 0.5,
              unit_price: 500_00,
              description: "Entry #{i + 1}"
            },
            mission_id: mission.id,
            current_user: user
          )
        end
        cra.reload

        expect(cra.total_days).to eq(25.0) # 50 * 0.5
        expect(cra.total_amount).to eq(1_250_000) # 50 * 0.5 * 500.00 = 12,500.00 EUR = 1,250,000 cents
      end
    end
  end
end
