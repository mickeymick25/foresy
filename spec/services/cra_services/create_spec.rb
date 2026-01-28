# frozen_string_literal: true

require 'rails_helper'

# CRA Create Service - DDD/RDD Compliant Tests
# Tests following Domain-Driven Design and Responsibility-Driven Design patterns
# Focus on isolated domain logic with clear responsibility boundaries
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
#
# Test Categories:
# 1. Input Validation - Basic parameter validation
# 2. Permission Validation - Domain rules for user authorization
# 3. Business Logic Validation - Domain-specific rules
#
# @example
#   result = CraServices::Create.call(
#     cra_params: { month: 1, year: 2025, currency: 'EUR' },
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { cra: {...} }
#
RSpec.describe CraServices::Create do
  let(:current_user) { create(:user) }
  let(:valid_cra_params) do
    {
      month: 1,
      year: 2025,
      currency: 'EUR',
      description: 'Test CRA'
    }
  end

  describe '.call' do
    describe 'basic input validation' do
      context 'when cra_params is missing' do
        it 'returns bad_request' do
          result = described_class.call(cra_params: nil, current_user: current_user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_parameters)
          expect(result.message).to include('CRA parameters are required')
        end
      end

      context 'when current_user is missing' do
        it 'returns bad_request' do
          result = described_class.call(cra_params: valid_cra_params, current_user: nil)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_parameters)
          expect(result.message).to include('Current user is required')
        end
      end

      context 'when both are missing' do
        it 'returns bad_request for cra_params first' do
          result = described_class.call(cra_params: nil, current_user: nil)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_parameters)
        end
      end
    end

    describe 'DDD permission tests (Active - DDD/RDD Compliant)' do
      # Tests following DDD/RDD methodology - domain logic isolated and tested independently

      context 'when user has no independent company' do
        let(:user_without_company) { create(:user) }

        before do
          # Ensure user has independent company permissions (DDD isolation)
          user_without_company.user_companies.destroy_all
        end

        it 'returns forbidden when user has no independent company' do
          # DDD/RDD compliant test - isolated domain rule
          result = described_class.call(cra_params: valid_cra_params, current_user: user_without_company)

          # ApplicationResult pattern validation
          expect(result).to be_failure
          expect(result.status).to eq(:forbidden)
          expect(result.error).to eq(:insufficient_permissions)

          # Domain rule validation
          expect(result.message).to include('User does not have permission to create CRAs')
        end

        it 'verifies ApplicationResult structure for permission failure' do
          # Additional test for comprehensive DDD/RDD validation
          result = described_class.call(cra_params: valid_cra_params, current_user: user_without_company)

          # Complete ApplicationResult contract validation
          expect(result).to be_a(ApplicationResult)
          expect(result.success?).to be false
          expect(result.failure?).to be true
          expect(result.data).to be_nil
        end
      end

      context 'when user has company but insufficient permissions' do
        let(:company) { create(:company) }
        let(:user_with_company) { create(:user) }

        before do
          # Associate user with company but WITHOUT independent role (insufficient permissions)
          create(:user_company, user: user_with_company, company: company, role: 'client')
          # NOTE: User has company but not with 'independent' role, so permissions will fail
        end

        it 'returns forbidden when user has no companies with permission' do
          # Service checks user_has_independent_company_access? - user has 'client' role, not 'independent'
          result = described_class.call(cra_params: valid_cra_params, current_user: user_with_company)

          # ApplicationResult pattern validation
          expect(result).to be_failure
          expect(result.status).to eq(:forbidden)
          expect(result.error).to eq(:insufficient_permissions)

          # Domain rule validation
          expect(result.message).to include('User does not have permission to create CRAs')
        end

        it 'verifies ApplicationResult structure for permission failure with company' do
          # Additional test for comprehensive DDD/RDD validation
          result = described_class.call(cra_params: valid_cra_params, current_user: user_with_company)

          # Complete ApplicationResult contract validation
          expect(result).to be_a(ApplicationResult)
          expect(result.success?).to be false
          expect(result.failure?).to be true
          expect(result.data).to be_nil
        end
      end
    end

    describe 'DDD input validation tests (Active - DDD/RDD Compliant)' do
      # Tests following DDD/RDD methodology - domain validation rules isolated and tested independently
      # Uses real service error codes and validation logic

      let(:user) { create(:user) }
      let(:independent_company) { create(:company) }

      before do
        # Ensure user has independent company permissions for validation testing
        create(:user_company, user: user, company: independent_company, role: 'independent')
      end

      describe 'month validation' do
        it 'returns bad_request when month is 0' do
          params = valid_cra_params.merge(month: 0)
          result = described_class.call(cra_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:invalid_month)
          expect(result.message).to include('Month must be between 1 and 12')
        end

        it 'returns bad_request when month > 12' do
          params = valid_cra_params.merge(month: 13)
          result = described_class.call(cra_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:invalid_month)
        end

        it 'returns bad_request when month is missing' do
          params = valid_cra_params.except(:month)
          result = described_class.call(cra_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_month)
        end
      end

      describe 'year validation' do
        it 'returns bad_request when year is before 2000' do
          params = valid_cra_params.merge(year: 1999)
          result = described_class.call(cra_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:invalid_year)
          expect(result.message).to include('Year must be 2000 or later')
        end

        it 'returns bad_request when year is too far in future' do
          params = valid_cra_params.merge(year: Date.current.year + 10)
          result = described_class.call(cra_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:year_too_far_future)
          expect(result.message).to include('cannot be more than 5 years in the future')
        end

        it 'returns bad_request when year is missing' do
          params = valid_cra_params.except(:year)
          result = described_class.call(cra_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_year)
        end
      end

      describe 'description validation' do
        it 'validates description length' do
          long_description = 'a' * 2001
          params = valid_cra_params.merge(description: long_description)
          result = described_class.call(cra_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:description_too_long)
          expect(result.message).to include('Description cannot exceed 2000 characters')
        end

        it 'accepts description within limit' do
          params = valid_cra_params.merge(description: 'a' * 2000)
          result = described_class.call(cra_params: params, current_user: user)

          # Should not fail description validation (may fail for other reasons like permissions)
          expect(result.error).not_to eq(:description_too_long)
        end
      end

      describe 'currency validation' do
        it 'returns bad_request when currency is invalid' do
          params = valid_cra_params.merge(currency: 'INVALID')
          result = described_class.call(cra_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:invalid_currency)
          expect(result.message).to include('Currency must be a valid ISO 4217 code')
        end

        it 'accepts valid currency codes' do
          %w[USD EUR GBP JPY CHF CAD AUD].each do |currency|
            params = valid_cra_params.merge(currency: currency)
            result = described_class.call(cra_params: params, current_user: user)
            # Should not fail currency validation (may fail for other reasons like permissions)
            expect(result.error).not_to eq(:invalid_currency)
          end
        end
      end
    end

    describe 'DDD creation tests (Simple - DDD/RDD Compliant)' do
      # Simple creation tests using exact same approach as working permission tests
      # Focus on basic successful creation scenarios

      # Use same setup as permission tests that work
      let(:user) { create(:user) }
      let(:independent_company) { create(:company) }

      before do
        # Ensure user has independent company permissions (same as permission tests)
        create(:user_company, user: user, company: independent_company, role: 'independent')
      end

      it 'creates a CRA successfully when user has independent permissions' do
        # Simple test: user with independent company should be able to create CRA
        result = described_class.call(
          cra_params: valid_cra_params,
          current_user: user
        )

        # Should succeed with proper permissions
        expect(result.success?).to be true
        expect(result.data).to be_present
        expect(result.data[:cra]).to be_a(Cra)

        cra = result.data[:cra]
        expect(cra.month).to eq(1)
        expect(cra.year).to eq(2025)
        expect(cra.currency).to eq('EUR')
      end

      it 'returns ApplicationResult.success on successful creation' do
        result = described_class.call(
          cra_params: valid_cra_params,
          current_user: user
        )

        # Verify ApplicationResult contract
        expect(result).to be_a(ApplicationResult)
        expect(result.success?).to be true
        expect(result.failure?).to be false
        expect(result.error).to be_nil
      end

      it 'creates CRA with correct user association' do
        result = described_class.call(
          cra_params: valid_cra_params,
          current_user: user
        )

        cra = result.data[:cra]
        expect(cra.created_by_user_id).to eq(user.id)
      end
    end

    describe 'interface validation' do
      it 'has call class method' do
        expect(described_class).to respond_to(:call)
      end

      it 'call method accepts keyword arguments' do
        call_params = described_class.method(:call).parameters
        expect(call_params).to include(%i[keyreq cra_params])
        expect(call_params).to include(%i[keyreq current_user])
      end

      it 'returns ApplicationResult for invalid input' do
        result = described_class.call(cra_params: nil, current_user: nil)
        expect(result).to be_a(ApplicationResult)
      end

      it 'returns ApplicationResult for valid input' do
        result = described_class.call(cra_params: valid_cra_params, current_user: current_user)
        expect(result).to be_a(ApplicationResult)
      end
    end
  end
end
