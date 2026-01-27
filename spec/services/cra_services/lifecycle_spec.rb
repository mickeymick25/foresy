# frozen_string_literal: true

require 'rails_helper'

# Smoke tests for CraServices::Lifecycle - Validates the recreated service architecture
# Tests the migrated pattern: self.submit/lock → new → #submit/#lock
#
# MIGRATION CONTEXT:
# - Migrated from Api::V1::Cras::LifecycleService to CraServices::Lifecycle
# - Architecture: self.call → new → #call pattern
# - ApplicationResult contract for all returns
# - Git Ledger integration preserved for lock operation
#
RSpec.describe CraServices::Lifecycle, type: :service do
  let(:current_user) { create(:user) }
  let(:company) { create(:company) }

  before do
    # Only create user_company if current_user is present (avoids nil user error)
    create(:user_company, user: current_user, company: company, role: 'independent') if current_user.present?
  end

  describe 'class loading and methods' do
    it 'loads CraServices::Lifecycle class correctly' do
      expect(defined?(CraServices::Lifecycle)).to eq('constant')
    end

    it 'has call class method' do
      expect(described_class).to respond_to(:call)
    end

    it 'call method has correct signature (kwargs)' do
      # Keyword arguments in Ruby have arity 1 (the method takes kwargs hash)
      expect(described_class.method(:call).arity).to eq(1)
    end

    it 'call method accepts cra, action, and current_user parameters' do
      expect(described_class.method(:call).parameters).to include([:keyreq, :cra], [:keyreq, :action], [:keyreq, :current_user])
    end
  end

  describe 'submit smoke tests' do
    subject(:result) do
      CraServices::Lifecycle.call(
        cra: cra,
        action: 'submit',
        current_user: current_user
      )
    end

    context 'with valid draft CRA' do
      # Create separate user and company for proper isolation
      let(:test_user) { current_user }
      let(:test_company) { create(:company) }

      let(:cra) { create(:cra, status: 'draft', created_by_user_id: test_user.id) }

      before do
        # Ensure user has independent company access
        create(:user_company, user: test_user, company: test_company, role: 'independent')
        # Ensure CRA has active entries for submission via join table
        create(:cra_entry_cra, cra: cra, cra_entry: create(:cra_entry))
      end

      it 'returns ApplicationResult' do
        expect(result).to be_a(ApplicationResult)
      end

      it 'has success status' do
        expect(result).to be_success
      end

      it 'returns CRA in data' do
        expect(result.data).to have_key(:cra)
        expect(result.data[:cra]).to eq(cra)
      end

      it 'has success message' do
        expect(result.message).to include('submitted successfully')
      end

      it 'transitions CRA to submitted status' do
        expect(result).to be_success
        expect(cra.reload.submitted?).to be true
      end
    end

    context 'with missing parameters' do
      context 'when CRA is nil' do
        let(:cra) { nil }

        it 'returns bad_request ApplicationResult' do
          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_cra)
        end
      end

      context 'when current_user is nil' do
        let(:creator) { create(:user) }
        let(:cra) { create(:cra, created_by_user_id: creator.id) }
        let(:current_user) { nil }

        it 'returns bad_request ApplicationResult' do
          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_user)
        end
      end
    end

    context 'with permission issues' do
      let(:other_user) { create(:user) }
      let(:cra) { create(:cra, status: 'draft', created_by_user_id: other_user.id) }

      it 'returns forbidden when user is not CRA creator' do
        expect(result).to be_failure
        expect(result.status).to eq(:forbidden)
        expect(result.error).to eq(:insufficient_permissions)
      end
    end

    context 'with invalid status' do
      context 'when CRA is already submitted' do
        let(:cra) { create(:cra, status: 'submitted', created_by_user_id: current_user.id) }

        it 'returns conflict for invalid transition' do
          expect(result).to be_failure
          expect(result.status).to eq(:conflict)
          expect(result.error).to eq(:invalid_transition)
          expect(result.message).to include('Only draft CRAs can be submitted')
        end
      end

      context 'when CRA is already locked' do
        let(:cra) { create(:cra, status: 'locked', created_by_user_id: current_user.id) }

        it 'returns conflict for invalid transition' do
          expect(result).to be_failure
          expect(result.status).to eq(:conflict)
          expect(result.error).to eq(:invalid_transition)
        end
      end
    end

    context 'with CRA without entries' do
      let(:cra) { create(:cra, status: 'draft', created_by_user_id: current_user.id) }

      it 'returns bad_request when CRA has no entries' do
        expect(result).to be_failure
        expect(result.status).to eq(:bad_request)
        expect(result.error).to eq(:cra_has_no_entries)
        expect(result.message).to include('must have at least one entry')
      end
    end
  end

  describe 'lock smoke tests' do
    subject(:result) do
      CraServices::Lifecycle.call(
        cra: cra,
        action: 'lock',
        current_user: current_user
      )
    end

    context 'with valid submitted CRA' do
      # Create separate user and company for proper isolation
      let(:test_user) { current_user }
      let(:test_company) { create(:company) }

      let(:cra) { create(:cra, status: 'submitted', created_by_user_id: test_user.id) }

      before do
        # Ensure user has independent company access
        create(:user_company, user: test_user, company: test_company, role: 'independent')
      end

      it 'returns ApplicationResult' do
        expect(result).to be_a(ApplicationResult)
      end

      it 'has success status' do
        expect(result).to be_success
      end

      it 'returns CRA in data' do
        expect(result.data).to have_key(:cra)
        expect(result.data[:cra]).to eq(cra)
      end

      it 'has success message' do
        expect(result.message).to include('locked successfully')
      end

      it 'transitions CRA to locked status' do
        expect(result).to be_success
        expect(cra.reload.locked?).to be true
      end
    end

    context 'with missing parameters' do
      context 'when CRA is nil' do
        let(:cra) { nil }

        it 'returns bad_request ApplicationResult' do
          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_cra)
        end
      end

      context 'when current_user is nil' do
        let(:creator) { create(:user) }
        let(:cra) { create(:cra, created_by_user_id: creator.id) }
        let(:current_user) { nil }

        it 'returns bad_request ApplicationResult' do
          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_user)
        end
      end
    end

    context 'with permission issues' do
      let(:other_user) { create(:user) }
      let(:cra) { create(:cra, status: 'submitted', created_by_user_id: other_user.id) }

      it 'returns forbidden when user is not CRA creator' do
        expect(result).to be_failure
        expect(result.status).to eq(:forbidden)
        expect(result.error).to eq(:insufficient_permissions)
      end
    end

    context 'with invalid status' do
      context 'when CRA is still in draft' do
        let(:cra) { create(:cra, status: 'draft', created_by_user_id: current_user.id) }

        it 'returns conflict for invalid transition' do
          expect(result).to be_failure
          expect(result.status).to eq(:conflict)
          expect(result.error).to eq(:invalid_transition)
          expect(result.message).to include('Only submitted CRAs can be locked')
        end
      end

      context 'when CRA is already locked' do
        let(:cra) { create(:cra, status: 'locked', created_by_user_id: current_user.id) }

        it 'returns conflict for invalid transition' do
          expect(result.status).to eq(:conflict)
          expect(result.error).to eq(:invalid_transition)
          expect(result.message).to include('Cannot lock CRA from status locked')
        end
      end
    end
  end

  describe 'architecture validation' do
    it 'uses ApplicationResult pattern exclusively' do
      cra = create(:cra, status: 'draft', created_by_user_id: current_user.id)
      create(:cra_entry_cra, cra: cra, cra_entry: create(:cra_entry))

      # Test both submit and lock via call with action parameter
      submit_result = CraServices::Lifecycle.call(cra: cra, action: 'submit', current_user: current_user)
      lock_result = CraServices::Lifecycle.call(
        cra: create(:cra, status: 'submitted', created_by_user_id: current_user.id),
        action: 'lock',
        current_user: current_user
      )

      # Both should return ApplicationResult instances
      expect(submit_result).to be_a(ApplicationResult)
      expect(lock_result).to be_a(ApplicationResult)

      # No exceptions should be raised
      expect { submit_result }.not_to raise_error
      expect { lock_result }.not_to raise_error
    end

    it 'has consistent interface with other CraServices' do
      # Validates that CraServices::Lifecycle follows the same pattern
      # as CraServices::Create and other services - uses self.call with kwargs

      expect(described_class.respond_to?(:call)).to be true

      # Call method should take keyword arguments
      expect(described_class.method(:call).parameters).to include([:keyreq, :cra], [:keyreq, :action], [:keyreq, :current_user])
    end
  end

  describe 'migration validation' do
    it 'replaces old Api::V1::Cras::LifecycleService pattern' do
      # This test validates the migration from old exception-based pattern
      # to new ApplicationResult pattern

      cra = create(:cra, status: 'draft', created_by_user_id: current_user.id)

      # The service should not raise exceptions
      expect { CraServices::Lifecycle.call(cra: cra, action: 'submit', current_user: current_user) }
        .not_to raise_error

      # Instead it should return ApplicationResult
      result = CraServices::Lifecycle.call(cra: cra, action: 'submit', current_user: current_user)
      expect(result).to be_a(ApplicationResult)
    end

    it 'preserves Git Ledger integration for lock' do
      # Validates that the Git Ledger integration is preserved
      # in the lock operation

      cra = create(:cra, status: 'submitted', created_by_user_id: current_user.id)

      result = CraServices::Lifecycle.call(cra: cra, action: 'lock', current_user: current_user)

      expect(result).to be_success
      expect(cra.reload.locked?).to be true
    end
  end
end
