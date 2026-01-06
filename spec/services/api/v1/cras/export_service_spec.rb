# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::Cras::ExportService do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let(:mission) { create(:mission, :time_based, created_by_user_id: user.id) }

  before do
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')
  end

  describe '#call' do
    context 'when format is csv' do
      let(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1) }

      before do
        entry1 = create(:cra_entry, date: Date.new(2026, 1, 10), quantity: 1.0, unit_price: 50_000, description: 'Dev work')
        entry2 = create(:cra_entry, date: Date.new(2026, 1, 11), quantity: 0.5, unit_price: 50_000, description: 'Meeting')

        create(:cra_entry_cra, cra: cra, cra_entry: entry1)
        create(:cra_entry_cra, cra: cra, cra_entry: entry2)

        create(:cra_entry_mission, cra_entry: entry1, mission: mission)
        create(:cra_entry_mission, cra_entry: entry2, mission: mission)

        cra.reload
      end

      it 'returns csv content with correct headers' do
        result = described_class.new(cra: cra, format: 'csv').call

        expect(result[:content_type]).to eq('text/csv')
        expect(result[:data]).to include('date,mission_name,quantity,unit_price_eur,line_total_eur,description')
      end

      it 'includes all CRA entries' do
        result = described_class.new(cra: cra, format: 'csv').call

        lines = result[:data].lines
        # Header + 2 entries + TOTAL = 4 lines
        expect(lines.count).to eq(4)
      end

      it 'formats amounts in euros (not cents)' do
        result = described_class.new(cra: cra, format: 'csv').call

        # 50_000 cents = 500.00 EUR
        expect(result[:data]).to include('500.00')
      end

      it 'includes a TOTAL row' do
        result = described_class.new(cra: cra, format: 'csv').call

        expect(result[:data]).to include('TOTAL')
      end

      it 'returns correct filename' do
        result = described_class.new(cra: cra, format: 'csv').call

        expect(result[:filename]).to eq('cra_2026_01.csv')
      end

      it 'includes entry details in correct order' do
        result = described_class.new(cra: cra, format: 'csv').call

        expect(result[:data]).to include('2026-01-10')
        expect(result[:data]).to include(mission.name)
        expect(result[:data]).to include('Dev work')
      end

      it 'calculates line totals correctly' do
        result = described_class.new(cra: cra, format: 'csv').call

        # Entry 1: 1.0 * 500.00 = 500.00
        # Entry 2: 0.5 * 500.00 = 250.00
        expect(result[:data]).to include('500.00')
        expect(result[:data]).to include('250.00')
      end
    end

    context 'when CRA has no entries' do
      let(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 2) }

      it 'returns csv with headers and total only' do
        result = described_class.new(cra: cra, format: 'csv').call

        lines = result[:data].lines
        # Header + TOTAL = 2 lines
        expect(lines.count).to eq(2)
      end

      it 'shows zero total' do
        result = described_class.new(cra: cra, format: 'csv').call

        expect(result[:data]).to include('TOTAL')
        expect(result[:data]).to include('0.00')
      end
    end

    context 'with invalid format' do
      let(:cra) { create(:cra, created_by_user_id: user.id) }

      it 'raises InvalidPayloadError for xml format' do
        expect {
          described_class.new(cra: cra, format: 'xml').call
        }.to raise_error(CraErrors::InvalidPayloadError, /format must be/)
      end

      it 'raises InvalidPayloadError for pdf format (not yet supported)' do
        expect {
          described_class.new(cra: cra, format: 'pdf').call
        }.to raise_error(CraErrors::InvalidPayloadError, /format must be/)
      end

      it 'raises InvalidPayloadError for nil format' do
        expect {
          described_class.new(cra: cra, format: nil).call
        }.to raise_error(CraErrors::InvalidPayloadError, /format must be/)
      end
    end

    context 'with uppercase format' do
      let(:cra) { create(:cra, created_by_user_id: user.id) }

      it 'accepts CSV in any case' do
        result = described_class.new(cra: cra, format: 'CSV').call

        expect(result[:content_type]).to eq('text/csv')
      end
    end

    context 'with include_entries option' do
      let(:cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 3) }

      before do
        entry = create(:cra_entry, date: Date.new(2026, 3, 15), quantity: 1.0, unit_price: 50_000)
        create(:cra_entry_cra, cra: cra, cra_entry: entry)
        create(:cra_entry_mission, cra_entry: entry, mission: mission)
        cra.reload
      end

      context 'when include_entries is true (default)' do
        it 'includes entry rows in CSV' do
          result = described_class.new(cra: cra, format: 'csv').call

          lines = result[:data].lines
          # Header + 1 entry + TOTAL = 3 lines
          expect(lines.count).to eq(3)
        end
      end

      context 'when include_entries is false' do
        it 'excludes entry rows from CSV' do
          result = described_class.new(cra: cra, format: 'csv', options: { include_entries: false }).call

          lines = result[:data].lines
          # Header + TOTAL only = 2 lines
          expect(lines.count).to eq(2)
        end

        it 'still includes headers' do
          result = described_class.new(cra: cra, format: 'csv', options: { include_entries: false }).call

          expect(result[:data]).to include('date,mission_name,quantity,unit_price_eur,line_total_eur,description')
        end

        it 'still includes TOTAL row' do
          result = described_class.new(cra: cra, format: 'csv', options: { include_entries: false }).call

          expect(result[:data]).to include('TOTAL')
        end
      end
    end
  end
end
