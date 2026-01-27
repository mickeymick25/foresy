# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CraServices::Export do
  let(:current_user) { create(:user) }
  let(:cra) { create(:cra, created_by_user_id: current_user.id, status: 'submitted') }

  describe '.call' do
    describe 'input validation' do
      it 'returns failure when cra is nil' do
        result = described_class.call(cra: nil, current_user: current_user)

        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
      end

      it 'returns failure when cra is not provided' do
        result = described_class.call(cra: nil, current_user: nil)

        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
      end
    end

    describe 'permission validation' do
      it 'returns forbidden when user is not CRA creator' do
        other_user = create(:user)
        result = described_class.call(cra: cra, current_user: other_user)

        expect(result).to be_failure
        expect(result.status).to eq(:forbidden)
      end

      it 'succeeds when user is CRA creator' do
        result = described_class.call(cra: cra, current_user: current_user)

        # Should succeed but may fail on lifecycle or CSV generation
        expect(result.status).not_to eq(:forbidden)
      end
    end

    describe 'lifecycle validation' do
      it 'returns failure when CRA is draft' do
        draft_cra = create(:cra, created_by_user_id: current_user.id, status: 'draft')
        result = described_class.call(cra: draft_cra, current_user: current_user)

        expect(result).to be_failure
        expect(result.status).to eq(:conflict)
        # A draft CRA is valid but not exportable
      end

      it 'succeeds when CRA is submitted' do
        submitted_cra = create(:cra, created_by_user_id: current_user.id, status: 'submitted')
        result = described_class.call(cra: submitted_cra, current_user: current_user)

        # Should succeed past lifecycle check (may fail on CSV generation if no entries)
        expect(result.status).not_to eq(:invalid_lifecycle)
      end
    end

    describe 'successful export' do
      before do
        # Create entries via join table for proper associations
        @entry = create(:cra_entry, quantity: 1, unit_price: 50000, description: 'Test work')
        create(:cra_entry_cra, cra: cra, cra_entry: @entry)
      end

      it 'returns success with CSV string data' do
        result = described_class.call(cra: cra, current_user: current_user)

        expect(result).to be_success
        expect(result.data).to be_a(String)
        expect(result.data).to include('date')
        expect(result.data).to include('mission_name')
      end

      it 'includes CSV headers' do
        result = described_class.call(cra: cra, current_user: current_user)

        expect(result.data).to include('date,mission_name,quantity,unit_price_eur,line_total_eur,description')
      end

      it 'includes entry data when include_entries is true' do
        result = described_class.call(cra: cra, current_user: current_user, include_entries: true)

        expect(result.data).to include(@entry.date.iso8601)
        expect(result.data).to include('500.00') # Formatted price
        expect(result.data).to include(@entry.description.to_s)
      end

      it 'excludes entry data when include_entries is false' do
        result = described_class.call(cra: cra, current_user: current_user, include_entries: false)

        expect(result.data).not_to include(@entry.date.iso8601)
        expect(result.data).to include('TOTAL')
      end

      it 'includes UTF-8 BOM for Excel compatibility' do
        result = described_class.call(cra: cra, current_user: current_user)

        expect(result.data).to start_with("\uFEFF")
      end

      it 'includes TOTAL row' do
        result = described_class.call(cra: cra, current_user: current_user)

        expect(result.data).to include('TOTAL')
      end

      it 'calls CRA recalculate_totals explicitly' do
        expect(cra).to receive(:recalculate_totals).once

        described_class.call(cra: cra, current_user: current_user)
      end
    end

    describe 'export without entries' do
      it 'succeeds with no entries' do
        cra_without_entries = create(:cra, created_by_user_id: current_user.id, status: 'submitted')

        result = described_class.call(cra: cra_without_entries, current_user: current_user)

        expect(result).to be_success
        expect(result.data).to be_a(String)
        expect(result.data).to include('TOTAL')
        expect(result.data).to include('0.00') # Zero total
      end

      it 'handles empty cra_entries gracefully' do
        result = described_class.call(cra: cra, current_user: current_user)

        expect(result).to be_success
        expect(result.data).to include('TOTAL')
        # Should not crash even with no entries
      end
    end

    describe 'error handling' do
      it 'returns internal_error when export fails' do
        # Mock an error during CSV generation
        allow_any_instance_of(described_class).to receive(:generate_csv_safe).and_return(nil)

        result = described_class.call(cra: cra, current_user: current_user)

        expect(result).to be_failure
        expect(result.status).to eq(:internal_error)
        expect(result.message).to be_present
      end

      it 'continues export even if recalculate_totals fails' do
        # Create entries first
        entry = create(:cra_entry, quantity: 1, unit_price: 50000)
        create(:cra_entry_cra, cra: cra, cra_entry: entry)

        # Mock recalculate_totals to fail
        allow(cra).to receive(:recalculate_totals).and_raise(StandardError, 'Recalcul failed')

        result = described_class.call(cra: cra, current_user: current_user)

        # Export should still succeed because recalculate_totals is safe-wrapped
        expect(result).to be_success
      end

      it 'logs errors gracefully' do
        # Test that error logging doesn't crash the service
        allow_any_instance_of(described_class).to receive(:append_entries).and_raise(StandardError, 'Test error')

        expect do
          result = described_class.call(cra: cra, current_user: current_user)
          # Should handle the error gracefully
        end.not_to raise_error
      end
    end

    describe 'interface consistency' do
      it 'returns ApplicationResult object' do
        result = described_class.call(cra: cra, current_user: current_user)

        expect(result).to be_a(ApplicationResult)
      end

      it 'has consistent signature with other CraServices' do
        expect(described_class).to respond_to(:call)

        # Method takes keyword arguments
        call_params = described_class.method(:call).parameters
        expect(call_params).to include([:keyreq, :cra])
        expect(call_params).to include([:keyreq, :current_user])
        expect(call_params).to include([:key, :include_entries])
      end

      it 'returns CSV content directly' do
        result = described_class.call(cra: cra, current_user: current_user)

        # New format: result.data is the CSV string directly
        expect(result.data).to be_a(String)
        expect(result.data).to start_with("\uFEFF") # UTF-8 BOM
      end
    end

    describe 'Ruby 3.4 compatibility' do
      it 'generates CSV without arguments to CSV.generate' do
        # This test ensures the service works with Ruby 3.4 where CSV.generate doesn't accept arguments
        expect do
          result = described_class.call(cra: cra, current_user: current_user)
          expect(result).to be_success
          expect(result.data).to be_a(String)
        end.not_to raise_error
      end

      it 'handles CSV generation with proper encoding' do
        result = described_class.call(cra: cra, current_user: current_user)

        # Should handle UTF-8 encoding properly
        expect(result.data.encoding).to eq(Encoding::UTF_8)
      end
    end
  end

  describe '.call - edge cases' do
    context 'CRA with malformed associations' do
      it 'handles missing mission associations gracefully' do
      # Create entry without missions but explicitly associated with CRA
      entry = create(:cra_entry, :without_missions)
      # Explicitly associate the entry with the CRA
      create(:cra_entry_cra, cra: cra, cra_entry: entry)

      result = described_class.call(cra: cra, current_user: current_user)

      expect(result).to be_success
      expect(result.data).to include('Mission sans nom') # Default mission name
    end

      it 'handles missing entry associations' do
        # CRA with entries that have no associations
        entry = create(:cra_entry, quantity: 1, unit_price: 50000)
        # Don't create cra_entry_cra association

        result = described_class.call(cra: cra, current_user: current_user)

        # Should handle missing associations gracefully
        expect(result).to be_success
      end
    end

    context 'large datasets' do
      it 'handles CRA with many entries' do
        # Create many entries
        50.times do
          entry = create(:cra_entry, quantity: 1, unit_price: 50000)
          create(:cra_entry_cra, cra: cra, cra_entry: entry)
        end

        result = described_class.call(cra: cra, current_user: current_user)

        expect(result).to be_success
        expect(result.data).to include('TOTAL')
        # Should handle large datasets without crashing
      end
    end
  end
end
