# frozen_string_literal: true

require 'rails_helper'

# Mission Create Service - DDD/RDD Compliant Tests
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
# 4. Relation-Driven Feature Flag Tests
#
# @example
#   result = MissionServices::Create.call(
#     mission_params: { name: 'Project X', mission_type: 'time_based', start_date: '2025-01-01' },
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { mission: {...} }
#
RSpec.describe MissionServices::Create do
  let(:current_user) { create(:user) }
  let(:valid_mission_params) do
    {
      name: 'Test Mission',
      mission_type: 'time_based',
      start_date: '2025-01-01',
      end_date: '2025-12-31',
      daily_rate: 500,
      currency: 'EUR',
      description: 'Test Mission Description'
    }
  end

  describe '.call' do
    describe 'basic input validation' do
      context 'when mission_params is missing' do
        it 'returns bad_request' do
          result = described_class.call(mission_params: nil, current_user: current_user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_parameters)
          expect(result.message).to include('Mission parameters are required')
        end
      end

      context 'when current_user is missing' do
        it 'returns bad_request' do
          result = described_class.call(mission_params: valid_mission_params, current_user: nil)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_parameters)
          expect(result.message).to include('Current user is required')
        end
      end
    end

    describe 'DDD permission tests (Active - DDD/RDD Compliant)' do
      context 'when user has no independent company' do
        let(:user_without_company) { create(:user) }

        before do
          user_without_company.user_companies.destroy_all
        end

        it 'returns forbidden when user has no independent company' do
          result = described_class.call(mission_params: valid_mission_params, current_user: user_without_company)

          expect(result).to be_failure
          expect(result.status).to eq(:forbidden)
          expect(result.error).to eq(:insufficient_permissions)
          expect(result.message).to include('User does not have permission to create missions')
        end
      end

      context 'when user has company but insufficient permissions' do
        let(:company) { create(:company) }
        let(:user_with_company) { create(:user) }

        before do
          create(:user_company, user: user_with_company, company: company, role: 'client')
        end

        it 'returns forbidden when user has no independent role' do
          result = described_class.call(mission_params: valid_mission_params, current_user: user_with_company)

          expect(result).to be_failure
          expect(result.status).to eq(:forbidden)
          expect(result.error).to eq(:insufficient_permissions)
        end
      end
    end

    describe 'DDD input validation tests (Active - DDD/RDD Compliant)' do
      let(:user) { create(:user) }
      let(:independent_company) { create(:company) }

      before do
        create(:user_company, user: user, company: independent_company, role: 'independent')
      end

      describe 'name validation' do
        it 'returns bad_request when name is missing' do
          params = valid_mission_params.except(:name)
          result = described_class.call(mission_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_name)
        end
      end

      describe 'mission_type validation' do
        it 'returns bad_request when mission_type is missing' do
          params = valid_mission_params.except(:mission_type)
          result = described_class.call(mission_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_mission_type)
        end

        it 'returns bad_request when mission_type is invalid' do
          params = valid_mission_params.merge(mission_type: 'invalid_type')
          result = described_class.call(mission_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:invalid_mission_type)
        end
      end

      describe 'start_date validation' do
        it 'returns bad_request when start_date is missing' do
          params = valid_mission_params.except(:start_date)
          result = described_class.call(mission_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_start_date)
        end
      end

      describe 'financial validation for time_based missions' do
        it 'returns bad_request when daily_rate is missing for time_based' do
          params = valid_mission_params.except(:daily_rate)
          result = described_class.call(mission_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_daily_rate)
        end

        it 'returns bad_request when fixed_price is provided for time_based' do
          params = valid_mission_params.merge(fixed_price: 10000)
          result = described_class.call(mission_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:invalid_financial_field)
        end
      end

      describe 'financial validation for fixed_price missions' do
        it 'returns bad_request when fixed_price is missing for fixed_price' do
          params = valid_mission_params.merge(mission_type: 'fixed_price').except(:fixed_price)
          result = described_class.call(mission_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:missing_fixed_price)
        end

        it 'returns bad_request when daily_rate is provided for fixed_price' do
          params = valid_mission_params.merge(mission_type: 'fixed_price', fixed_price: 10000, daily_rate: 500)
          result = described_class.call(mission_params: params, current_user: user)

          expect(result).to be_failure
          expect(result.status).to eq(:bad_request)
          expect(result.error).to eq(:invalid_financial_field)
        end
      end
    end

    describe 'DDD creation tests (Simple - DDD/RDD Compliant)' do
      let(:user) { create(:user) }
      let(:independent_company) { create(:company) }

      before do
        create(:user_company, user: user, company: independent_company, role: 'independent')
      end

      it 'creates a mission successfully when user has independent permissions' do
        result = described_class.call(
          mission_params: valid_mission_params,
          current_user: user
        )

        expect(result.success?).to be true
        expect(result.data).to be_present
        expect(result.data[:mission]).to be_a(Mission)

        mission = result.data[:mission]
        expect(mission.name).to eq('Test Mission')
        expect(mission.mission_type).to eq('time_based')
      end

      it 'returns ApplicationResult.success on successful creation' do
        result = described_class.call(
          mission_params: valid_mission_params,
          current_user: user
        )

        expect(result).to be_a(ApplicationResult)
        expect(result.success?).to be true
        expect(result.failure?).to be false
        expect(result.error).to be_nil
      end

      it 'creates mission with correct user association' do
        result = described_class.call(
          mission_params: valid_mission_params,
          current_user: user
        )

        mission = result.data[:mission]
        expect(mission.created_by_user_id).to eq(user.id)
      end
    end

    describe 'relation-driven feature flag (DDD/RDD Compliant)' do
      let(:user) { create(:user) }
      let(:independent_company) { create(:company) }

      before do
        create(:user_company, user: user, company: independent_company, role: 'independent')
      end

      context 'when feature flag USE_USER_RELATIONS is ON' do
        before do
          allow(FeatureFlags).to receive(:relation_driven?).and_return(true)
        end

        it 'creates a UserMission record with creator role when flag is ON' do
          result = described_class.call(
            mission_params: valid_mission_params,
            current_user: user
          )

          expect(result.success?).to be true

          mission = result.data[:mission]
          expect(mission.user_missions).to be_present
          expect(mission.user_missions.creators).to be_present
          expect(mission.user_missions.creators.first.user_id).to eq(user.id)
          expect(mission.user_missions.creators.first.role).to eq('creator')
        end

        it 'still populates created_by_user_id for legacy compatibility' do
          result = described_class.call(
            mission_params: valid_mission_params,
            current_user: user
          )

          expect(result.success?).to be true

          mission = result.data[:mission]
          expect(mission.created_by_user_id).to eq(user.id)
        end

        it 'creates only one creator UserMission per mission' do
          result = described_class.call(
            mission_params: valid_mission_params,
            current_user: user
          )

          expect(result.success?).to be true

          mission = result.data[:mission]
          expect(mission.user_missions.creators.count).to eq(1)
        end

        it 'associates the correct user through UserMission' do
          result = described_class.call(
            mission_params: valid_mission_params,
            current_user: user
          )

          expect(result.success?).to be true

          mission = result.data[:mission]
          expect(mission.users).to include(user)
        end
      end

      context 'when feature flag USE_USER_RELATIONS is OFF (legacy mode)' do
        before do
          allow(FeatureFlags).to receive(:relation_driven?).and_return(false)
        end

        it 'does NOT create UserMission record when flag is OFF (legacy mode)' do
          result = described_class.call(
            mission_params: valid_mission_params,
            current_user: user
          )

          expect(result.success?).to be true

          mission = result.data[:mission]
          expect(mission.user_missions.count).to eq(0)
        end

        it 'still populates created_by_user_id in legacy mode' do
          result = described_class.call(
            mission_params: valid_mission_params,
            current_user: user
          )

          expect(result.success?).to be true

          mission = result.data[:mission]
          expect(mission.created_by_user_id).to eq(user.id)
        end
      end
    end

    describe 'interface validation' do
      it 'has call class method' do
        expect(described_class).to respond_to(:call)
      end

      it 'call method accepts keyword arguments' do
        call_params = described_class.method(:call).parameters
        expect(call_params).to include(%i[keyreq mission_params])
        expect(call_params).to include(%i[keyreq current_user])
      end

      it 'returns ApplicationResult for invalid input' do
        result = described_class.call(mission_params: nil, current_user: nil)
        expect(result).to be_a(ApplicationResult)
      end

      it 'returns ApplicationResult for valid input' do
        result = described_class.call(mission_params: valid_mission_params, current_user: current_user)
        expect(result).to be_a(ApplicationResult)
      end
    end
  end
end
