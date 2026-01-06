# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Missions', type: :request do
  # Test data setup
  let(:user) { create(:user) }
  let(:user_token) { AuthenticationService.login(user, '127.0.0.1', 'Test Agent')[:token] }
  let(:Authorization) { "Bearer #{user_token}" }

  # Test companies and relationships
  let(:independent_company) { create(:company) }
  let(:client_company) { create(:company) }
  let(:user_independent_company) do
    create(:user_company, user: user, company: independent_company, role: 'independent')
  end
  let(:user_client_company) { create(:user_company, user: user, company: client_company, role: 'client') }

  # Create missions for testing
  let(:mission) { create(:mission, user: user) }
  let(:mission_with_companies) do
    mission = create(:mission, user: user)
    create(:mission_company, mission: mission, company: independent_company, role: 'independent')
    create(:mission_company, mission: mission, company: client_company, role: 'client')
    mission
  end

  describe 'POST /api/v1/missions' do
    path '/api/v1/missions' do
      post 'Creates a new mission' do
        tags 'Missions'
        consumes 'application/json'
        produces 'application/json'

        parameter name: :mission_params, in: :body, required: true, schema: {
          type: :object,
          properties: {
            name: { type: :string },
            description: { type: :string },
            mission_type: { type: :string, enum: %w[time_based fixed_price] },
            status: { type: :string, enum: %w[lead pending won in_progress completed] },
            start_date: { type: :string, format: :date },
            end_date: { type: :string, format: :date, nullable: true },
            daily_rate: { type: :integer },
            fixed_price: { type: :integer },
            currency: { type: :string },
            client_company_id: { type: :string, format: :uuid, nullable: true }
          },
          required: %w[name mission_type status start_date currency]
        }

        response '201', 'Mission created successfully' do
          before do
            user_independent_company
          end

          let(:mission_params) do
            {
              name: 'Test Mission',
              description: 'Test mission description',
              mission_type: 'time_based',
              status: 'lead',
              start_date: Date.current.to_s,
              daily_rate: 60_000,
              currency: 'EUR'
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['id']).to be_present
            expect(data['name']).to eq('Test Mission')
            expect(data['mission_type']).to eq('time_based')
            expect(data['status']).to eq('lead')
            expect(data['daily_rate']).to eq(60_000)
            expect(data['currency']).to eq('EUR')
          end
        end

        response '201', 'Mission created with client company' do
          before do
            user_independent_company
          end

          let(:mission_params) do
            {
              name: 'Test Mission with Client',
              mission_type: 'fixed_price',
              status: 'won',
              start_date: Date.current.to_s,
              fixed_price: 500_000,
              currency: 'EUR',
              client_company_id: client_company.id
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['id']).to be_present
            expect(data['name']).to eq('Test Mission with Client')
            expect(data['mission_type']).to eq('fixed_price')
            expect(data['fixed_price']).to eq(500_000)
          end
        end

        response '401', 'Unauthorized - No token' do
          let(:Authorization) { '' }

          let(:mission_params) do
            {
              name: 'Test Mission',
              mission_type: 'time_based',
              status: 'lead',
              start_date: Date.current.to_s,
              currency: 'EUR'
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Missing token')
            expect(response.status).to eq(401)
          end
        end

        response '403', 'Forbidden - No independent company access' do
          let(:mission_params) do
            {
              name: 'Test Mission',
              mission_type: 'time_based',
              status: 'lead',
              start_date: Date.current.to_s,
              currency: 'EUR'
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Forbidden')
            expect(data['message']).to include('independent company')
            expect(response.status).to eq(403)
          end
        end

        response '422', 'Validation failed - Invalid mission type' do
          before do
            user_independent_company
          end

          let(:mission_params) do
            {
              name: 'Test Mission',
              mission_type: 'invalid_type',
              status: 'lead',
              start_date: Date.current.to_s,
              currency: 'EUR'
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Invalid Payload')
            expect(data['message'].to_s.downcase).to include('mission_type')
            expect(response.status).to eq(422)
          end
        end

        response '422', 'Validation failed - Time-based mission without daily_rate' do
          before do
            user_independent_company
          end

          let(:mission_params) do
            {
              name: 'Test Mission',
              mission_type: 'time_based',
              status: 'lead',
              start_date: Date.current.to_s,
              currency: 'EUR'
              # daily_rate missing
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Invalid Payload')
            expect(data['message'].to_s.downcase).to include('daily rate')
            expect(response.status).to eq(422)
          end
        end

        response '422', 'Validation failed - Fixed-price mission without fixed_price' do
          before do
            user_independent_company
          end

          let(:mission_params) do
            {
              name: 'Test Mission',
              mission_type: 'fixed_price',
              status: 'lead',
              start_date: Date.current.to_s,
              currency: 'EUR'
              # fixed_price missing
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Invalid Payload')
            expect(data['message'].to_s.downcase).to include('fixed price')
            expect(response.status).to eq(422)
          end
        end
      end
    end
  end

  describe 'GET /api/v1/missions' do
    path '/api/v1/missions' do
      get 'Lists missions accessible to user' do
        tags 'Missions'
        consumes 'application/json'
        produces 'application/json'

        response '200', 'Returns list of missions' do
          before do
            user_independent_company
            mission_with_companies
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['data']).to be_an(Array)
            expect(data['data'].length).to eq(1)
            expect(data['meta']['total']).to eq(1)
            expect(data['data'][0]['id']).to eq(mission_with_companies.id)
          end
        end

        response '200', 'Returns empty list when no missions' do
          before do
            user_independent_company
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['data']).to be_an(Array)
            expect(data['data']).to be_empty
            expect(data['meta']['total']).to eq(0)
          end
        end

        response '401', 'Unauthorized' do
          let(:Authorization) { '' }

          run_test! do |response|
            expect(response.status).to eq(401)
          end
        end
      end
    end
  end

  describe 'GET /api/v1/missions/:id' do
    path '/api/v1/missions/{id}' do
      get 'Shows a specific mission' do
        tags 'Missions'
        consumes 'application/json'
        produces 'application/json'

        parameter name: :id, in: :path, type: :string, format: :uuid

        response '200', 'Mission found and accessible' do
          before do
            user_independent_company
            mission_with_companies
          end

          let(:id) { mission_with_companies.id }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['id']).to eq(mission_with_companies.id)
            expect(data['name']).to be_present
            expect(data['companies']).to be_an(Array)
            expect(data['companies'].length).to eq(2)
          end
        end

        response '401', 'Unauthorized' do
          let(:Authorization) { '' }
          let(:id) { mission.id }

          run_test! do |response|
            expect(response.status).to eq(401)
          end
        end

        response '404', 'Mission not found or not accessible' do
          before do
            user_independent_company
          end

          let(:id) { SecureRandom.uuid }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Not Found')
            expect(data['message']).to include('Mission not found')
            expect(response.status).to eq(404)
          end
        end
      end
    end
  end

  describe 'PATCH /api/v1/missions/:id' do
    path '/api/v1/missions/{id}' do
      patch 'Updates a mission' do
        tags 'Missions'
        consumes 'application/json'
        produces 'application/json'

        parameter name: :id, in: :path, type: :string, format: :uuid
        parameter name: :mission_params, in: :body, required: true, schema: {
          type: :object,
          properties: {
            name: { type: :string },
            description: { type: :string },
            status: { type: :string, enum: %w[lead pending won in_progress completed] },
            end_date: { type: :string, format: :date }
          }
        }

        response '200', 'Mission updated successfully' do
          before do
            user_independent_company
            mission_with_companies
          end

          let(:id) { mission_with_companies.id }
          let(:mission_params) do
            {
              name: 'Updated Mission Name',
              description: 'Updated description',
              status: 'pending'
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['name']).to eq('Updated Mission Name')
            expect(data['description']).to eq('Updated description')
            expect(data['status']).to eq('pending')
          end
        end

        response '401', 'Unauthorized' do
          let(:Authorization) { '' }
          let(:id) { mission.id }
          let(:mission_params) { { name: 'Updated Mission' } }

          run_test! do |response|
            expect(response.status).to eq(401)
          end
        end

        response '403', 'Forbidden - User is not the creator' do
          before do
            user_independent_company
            other_user = create(:user)
            other_mission = create(:mission, user: other_user)
            create(:mission_company, mission: other_mission, company: independent_company, role: 'independent')
          end

          let(:id) do
            Mission.joins(:mission_companies).where(mission_companies: { company_id: independent_company.id }).first.id
          end
          let(:mission_params) { { name: 'Updated Mission' } }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Forbidden')
            expect(data['message']).to include('creator')
            expect(response.status).to eq(403)
          end
        end

        response '422', 'Invalid status transition' do
          before do
            user_independent_company
            mission_with_companies
          end

          let(:id) { mission_with_companies.id }
          let(:mission_params) { { status: 'completed' } }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Invalid Transition')
            expect(data['message']).to include('Cannot transition')
            expect(response.status).to eq(422)
          end
        end

        response '404', 'Mission not accessible' do
          before do
            user_independent_company
          end

          let(:id) { SecureRandom.uuid }
          let(:mission_params) { { name: 'Updated Mission' } }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Not Found')
            expect(response.status).to eq(404)
          end
        end
      end
    end
  end

  describe 'DELETE /api/v1/missions/:id' do
    path '/api/v1/missions/{id}' do
      delete 'Archives a mission' do
        tags 'Missions'
        consumes 'application/json'
        produces 'application/json'

        parameter name: :id, in: :path, type: :string, format: :uuid

        response '200', 'Mission archived successfully' do
          before do
            user_independent_company
            mission_with_companies
          end

          let(:id) { mission_with_companies.id }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['message']).to include('archived')
            expect(response.status).to eq(200)

            # Verify mission is soft deleted
            mission_with_companies.reload
            expect(mission_with_companies.deleted_at).to be_present
          end
        end

        response '401', 'Unauthorized' do
          let(:Authorization) { '' }
          let(:id) { mission.id }

          run_test! do |response|
            expect(response.status).to eq(401)
          end
        end

        response '403', 'Forbidden - User is not the creator' do
          before do
            user_independent_company
            other_user = create(:user)
            other_mission = create(:mission, user: other_user)
            create(:mission_company, mission: other_mission, company: independent_company, role: 'independent')
          end

          let(:id) do
            Mission.joins(:mission_companies).where(mission_companies: { company_id: independent_company.id }).first.id
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Forbidden')
            expect(data['message']).to include('creator')
            expect(response.status).to eq(403)
          end
        end

        response '409', 'Mission in use (has CRA entries)' do
          before do
            user_independent_company
            mission_with_companies
            # Mock that mission has CRA entries
            allow_any_instance_of(Mission).to receive(:cra_entries?).and_return(true)
          end

          let(:id) { mission_with_companies.id }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Mission In Use')
            expect(data['message'].downcase).to include('mission')
            expect(response.status).to eq(409)
          end
        end

        response '404', 'Mission not accessible' do
          before do
            user_independent_company
          end

          let(:id) { SecureRandom.uuid }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Not Found')
            expect(response.status).to eq(404)
          end
        end
      end
    end
  end

  describe 'Rate Limiting' do
    path '/api/v1/missions' do
      post 'Creates a new mission' do
        tags 'Missions'
        consumes 'application/json'
        produces 'application/json'

        parameter name: :mission_params, in: :body, required: true, schema: {
          type: :object,
          properties: {
            name: { type: :string },
            mission_type: { type: :string },
            status: { type: :string },
            start_date: { type: :string },
            currency: { type: :string }
          }
        }

        response '429', 'Rate limit exceeded' do
          before do
            user_independent_company
            # Simulate rate limit exceeded
            allow(RateLimitService).to receive(:check_rate_limit)
              .and_return([false, 60])
          end

          let(:mission_params) do
            {
              name: 'Test Mission',
              mission_type: 'time_based',
              status: 'lead',
              start_date: Date.current.to_s,
              currency: 'EUR'
            }
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['error']).to eq('Rate limit exceeded')
            expect(data['retry_after']).to eq(60)
            expect(response.headers['Retry-After']).to eq('60')
            expect(response.status).to eq(429)
          end
        end
      end
    end
  end

  describe 'Lifecycle Transitions' do
    let(:user_with_company) do
      user_independent_company
      user
    end

    context 'Valid status transitions' do
      it 'allows lead -> pending' do
        mission = create(:mission, user: user_with_company, status: 'lead')
        create(:mission_company, mission: mission, company: independent_company, role: 'independent')

        patch "/api/v1/missions/#{mission.id}",
              params: { status: 'pending' }.to_json,
              headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{user_token}" }

        expect(response.status).to eq(200)
        mission.reload
        expect(mission.status).to eq('pending')
      end

      it 'allows pending -> won' do
        mission = create(:mission, user: user_with_company, status: 'pending')
        create(:mission_company, mission: mission, company: independent_company, role: 'independent')

        patch "/api/v1/missions/#{mission.id}",
              params: { status: 'won' }.to_json,
              headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{user_token}" }

        expect(response.status).to eq(200)
        mission.reload
        expect(mission.status).to eq('won')
      end

      it 'allows won -> in_progress' do
        mission = create(:mission, user: user_with_company, status: 'won')
        create(:mission_company, mission: mission, company: independent_company, role: 'independent')

        patch "/api/v1/missions/#{mission.id}",
              params: { status: 'in_progress' }.to_json,
              headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{user_token}" }

        expect(response.status).to eq(200)
        mission.reload
        expect(mission.status).to eq('in_progress')
      end

      it 'allows in_progress -> completed' do
        mission = create(:mission, user: user_with_company, status: 'in_progress')
        create(:mission_company, mission: mission, company: independent_company, role: 'independent')

        patch "/api/v1/missions/#{mission.id}",
              params: { status: 'completed' }.to_json,
              headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{user_token}" }

        expect(response.status).to eq(200)
        mission.reload
        expect(mission.status).to eq('completed')
      end
    end

    context 'Invalid status transitions' do
      it 'rejects completed -> in_progress' do
        mission = create(:mission, user: user_with_company, status: 'completed')
        create(:mission_company, mission: mission, company: independent_company, role: 'independent')

        patch "/api/v1/missions/#{mission.id}",
              params: { status: 'in_progress' }.to_json,
              headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{user_token}" }

        expect(response.status).to eq(422)
        data = JSON.parse(response.body)
        expect(data['error']).to eq('Invalid Transition')
      end

      it 'rejects won -> lead' do
        mission = create(:mission, user: user_with_company, status: 'won')
        create(:mission_company, mission: mission, company: independent_company, role: 'independent')

        patch "/api/v1/missions/#{mission.id}",
              params: { status: 'lead' }.to_json,
              headers: { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{user_token}" }

        expect(response.status).to eq(422)
        data = JSON.parse(response.body)
        expect(data['error']).to eq('Invalid Transition')
      end
    end
  end
end
