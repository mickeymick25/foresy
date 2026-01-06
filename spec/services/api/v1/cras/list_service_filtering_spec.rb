# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Naming/VariableNumber

# Mini-FC-01: CRA Filtering Tests
#
# Tests for filtering CRAs by year, month, and status
# Following TDD methodology: these tests define the expected behavior
#
# Rules (from Mini-FC-01):
# - year alone: allowed
# - month alone: ERROR 422 (year required)
# - year + month: allowed
# - status invalid: ERROR 422
# - Combined filters: AND logic
# - Soft-deleted CRAs: never returned
RSpec.describe Api::V1::Cras::ListService, 'filtering' do
  let(:user) { create(:user) }
  let(:company) { create(:company) }
  let(:mission) { create(:mission, created_by_user_id: user.id) }

  before do
    # Setup user company association
    create(:user_company, user: user, company: company, role: 'independent')
    create(:mission_company, mission: mission, company: company, role: 'independent')
  end

  describe 'filtering by year' do
    let!(:cra_2026) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft') }
    let!(:cra_2025) { create(:cra, created_by_user_id: user.id, year: 2025, month: 12, status: 'draft') }
    let!(:cra_2024) { create(:cra, created_by_user_id: user.id, year: 2024, month: 6, status: 'draft') }

    context 'when filtering by year alone' do
      it 'returns only CRAs from specified year' do
        result = described_class.call(
          current_user: user,
          filters: { year: 2026 }
        )

        expect(result.cras).to contain_exactly(cra_2026)
      end

      it 'returns empty array when no CRAs match year' do
        result = described_class.call(
          current_user: user,
          filters: { year: 2020 }
        )

        expect(result.cras).to be_empty
      end
    end
  end

  describe 'filtering by month' do
    let!(:cra_jan) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft') }
    let!(:cra_feb) { create(:cra, created_by_user_id: user.id, year: 2026, month: 2, status: 'draft') }
    let!(:cra_mar) { create(:cra, created_by_user_id: user.id, year: 2026, month: 3, status: 'draft') }

    context 'when filtering by month without year' do
      it 'raises InvalidPayloadError' do
        expect do
          described_class.call(
            current_user: user,
            filters: { month: 2 }
          )
        end.to raise_error(CraErrors::InvalidPayloadError, /year is required when month is specified/)
      end
    end

    context 'when filtering by year and month together' do
      it 'returns CRAs from specified month and year' do
        result = described_class.call(
          current_user: user,
          filters: { year: 2026, month: 2 }
        )

        expect(result.cras).to contain_exactly(cra_feb)
      end
    end
  end

  describe 'filtering by status' do
    let!(:cra_draft) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft') }
    let!(:cra_submitted) { create(:cra, created_by_user_id: user.id, year: 2026, month: 2, status: 'submitted') }
    let!(:cra_locked) { create(:cra, created_by_user_id: user.id, year: 2026, month: 3, status: 'locked') }

    context 'when filtering by valid status' do
      it 'returns only draft CRAs' do
        result = described_class.call(
          current_user: user,
          filters: { status: 'draft' }
        )

        expect(result.cras).to contain_exactly(cra_draft)
      end

      it 'returns only submitted CRAs' do
        result = described_class.call(
          current_user: user,
          filters: { status: 'submitted' }
        )

        expect(result.cras).to contain_exactly(cra_submitted)
      end

      it 'returns only locked CRAs' do
        result = described_class.call(
          current_user: user,
          filters: { status: 'locked' }
        )

        expect(result.cras).to contain_exactly(cra_locked)
      end
    end

    context 'when filtering by invalid status' do
      it 'raises InvalidPayloadError for unknown status' do
        expect do
          described_class.call(
            current_user: user,
            filters: { status: 'invalid_status' }
          )
        end.to raise_error(CraErrors::InvalidPayloadError, /Invalid status/)
      end

      it 'raises InvalidPayloadError for empty status' do
        # Empty string should be treated as no filter, not invalid
        result = described_class.call(
          current_user: user,
          filters: { status: '' }
        )

        expect(result.cras.count).to eq(3)
      end
    end
  end

  describe 'combined filters (AND logic)' do
    let!(:cra_2026_jan_draft) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft') }
    let!(:cra_2026_jan_locked) { create(:cra, created_by_user_id: user.id, year: 2026, month: 2, status: 'locked') }
    let!(:cra_2025_jan_draft) { create(:cra, created_by_user_id: user.id, year: 2025, month: 1, status: 'draft') }
    let!(:cra_2026_feb_draft) { create(:cra, created_by_user_id: user.id, year: 2026, month: 3, status: 'draft') }

    it 'applies AND logic to year and status' do
      result = described_class.call(
        current_user: user,
        filters: { year: 2026, status: 'draft' }
      )

      expect(result.cras).to contain_exactly(cra_2026_jan_draft, cra_2026_feb_draft)
    end

    it 'applies AND logic to year, month, and status' do
      result = described_class.call(
        current_user: user,
        filters: { year: 2026, month: 1, status: 'draft' }
      )

      expect(result.cras).to contain_exactly(cra_2026_jan_draft)
    end

    it 'returns empty when no CRAs match all filters' do
      result = described_class.call(
        current_user: user,
        filters: { year: 2026, month: 1, status: 'submitted' }
      )

      expect(result.cras).to be_empty
    end
  end

  describe 'soft-deleted CRAs' do
    let!(:active_cra) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft') }
    let!(:deleted_cra) do
      cra = create(:cra, created_by_user_id: user.id, year: 2026, month: 2, status: 'draft')
      cra.update!(deleted_at: Time.current)
      cra
    end

    it 'never returns soft-deleted CRAs' do
      result = described_class.call(
        current_user: user,
        filters: { year: 2026 }
      )

      expect(result.cras).to contain_exactly(active_cra)
      expect(result.cras).not_to include(deleted_cra)
    end
  end

  describe 'no filters' do
    let!(:cra1) { create(:cra, created_by_user_id: user.id, year: 2026, month: 1, status: 'draft') }
    let!(:cra2) { create(:cra, created_by_user_id: user.id, year: 2025, month: 12, status: 'locked') }

    it 'returns all accessible CRAs when no filters provided' do
      result = described_class.call(
        current_user: user,
        filters: {}
      )

      expect(result.cras).to contain_exactly(cra1, cra2)
    end

    it 'returns all accessible CRAs when filters is nil' do
      result = described_class.call(
        current_user: user,
        filters: nil
      )

      expect(result.cras).to contain_exactly(cra1, cra2)
    end
  end

  describe 'pagination with filters' do
    before do
      # Create 30 CRAs for 2026, different months
      (1..12).each do |month|
        create(:cra, created_by_user_id: user.id, year: 2026, month: month, status: 'draft')
      end
    end

    it 'paginates filtered results correctly' do
      result = described_class.call(
        current_user: user,
        page: 1,
        per_page: 5,
        filters: { year: 2026 }
      )

      expect(result.cras.count).to eq(5)
      expect(result.pagination[:total]).to eq(12)
      expect(result.pagination[:pages]).to eq(3)
    end
  end
end
# rubocop:enable Naming/VariableNumber
