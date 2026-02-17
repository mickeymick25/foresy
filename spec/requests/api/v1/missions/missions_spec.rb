# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 Missions', type: :request do
  # ============================================================
  # POST /api/v1/missions
  # ============================================================
  describe 'POST /api/v1/missions' do
    path '/api/v1/missions' do
      post 'Creates a new mission' do
        tags 'Missions'
        consumes 'application/json'
        produces 'application/json'

        parameter name: :Authorization, in: :header, type: :string, required: true
        parameter name: :mission_params, in: :body, required: true, schema: {
          type: :object,
          properties: {
            name: { type: :string },
            mission_type: { type: :string },
            status: { type: :string },
            start_date: { type: :string, format: :date },
            daily_rate: { type: :integer },
            fixed_price: { type: :integer },
            currency: { type: :string },
            client_company_id: { type: :string, format: :uuid, nullable: true }
          }
        }

        response '201', 'Mission created successfully' do
          let(:mission_params) do
            {
              name: 'Test Mission',
              mission_type: 'time_based',
              status: 'lead',
              start_date: Date.current.to_s,
              daily_rate: 60_000,
              currency: 'EUR'
            }
          end

          let(:Authorization) { "Bearer #{@token}" }

          before do
            user = create(:user)
            company = create(:company)
            create(:user_company, user: user, company: company, role: 'independent')
            @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
          end

          run_test!
        end

        response '401', 'Unauthorized - No token' do
          let(:mission_params) do
            {
              name: 'Test Mission',
              mission_type: 'time_based',
              status: 'lead',
              start_date: Date.current.to_s,
              currency: 'EUR'
            }
          end

          let(:Authorization) { '' }

          run_test!
        end
      end
    end
  end

  # ============================================================
  # GET /api/v1/missions
  # ============================================================
  describe 'GET /api/v1/missions' do
    path '/api/v1/missions' do
      get 'Lists missions accessible to user' do
        tags 'Missions'
        produces 'application/json'
        parameter name: :Authorization, in: :header, type: :string, required: true

        response '200', 'Returns list of missions' do
          let(:Authorization) { "Bearer #{@token}" }

          before do
            user = create(:user)
            company = create(:company)
            create(:user_company, user: user, company: company, role: 'independent')

            mission = create(:mission, user: user)
            create(:mission_company, mission: mission, company: company, role: 'independent')

            @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
          end

          run_test!
        end

        response '200', 'Returns empty list' do
          let(:Authorization) { "Bearer #{@token}" }

          before do
            user = create(:user)
            create(:user_company, user: user, company: create(:company), role: 'independent')
            @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
          end

          run_test!
        end
      end
    end
  end

  # ============================================================
  # GET /api/v1/missions/:id
  # ============================================================
  describe 'GET /api/v1/missions/:id' do
    path '/api/v1/missions/{id}' do
      get 'Shows a mission' do
        tags 'Missions'
        produces 'application/json'

        parameter name: :id, in: :path, type: :string
        parameter name: :Authorization, in: :header, type: :string, required: true

        response '200', 'Mission found' do
          let(:id) { @mission.id }
          let(:Authorization) { "Bearer #{@token}" }

          before do
            user = create(:user)
            company = create(:company)
            create(:user_company, user: user, company: company, role: 'independent')

            mission = create(:mission, user: user)
            create(:mission_company, mission: mission, company: company, role: 'independent')

            @mission = mission
            @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
          end

          run_test!
        end
      end
    end
  end

  # ============================================================
  # PATCH /api/v1/missions/:id
  # ============================================================
  describe 'PATCH /api/v1/missions/:id' do
    path '/api/v1/missions/{id}' do
      patch 'Updates a mission' do
        tags 'Missions'
        consumes 'application/json'
        produces 'application/json'

        parameter name: :id, in: :path, type: :string
        parameter name: :Authorization, in: :header, type: :string, required: true
        parameter name: :mission_params, in: :body, required: true

        response '200', 'Mission updated successfully' do
          let(:id) { @mission.id }
          let(:Authorization) { "Bearer #{@token}" }
          let(:mission_params) { { status: 'pending' } }

          before do
            user = create(:user)
            company = create(:company)
            create(:user_company, user: user, company: company, role: 'independent')

            mission = create(:mission, user: user, status: 'lead')
            create(:mission_company, mission: mission, company: company, role: 'independent')

            @mission = mission
            @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
          end

          run_test!
        end

        response '422', 'Invalid status transition' do
          let(:id) { @mission.id }
          let(:Authorization) { "Bearer #{@token}" }
          let(:mission_params) { { status: 'completed' } }

          before do
            user = create(:user)
            company = create(:company)
            create(:user_company, user: user, company: company, role: 'independent')

            mission = create(:mission, user: user, status: 'lead')
            create(:mission_company, mission: mission, company: company, role: 'independent')

            @mission = mission
            @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
          end

          run_test!
        end
      end
    end
  end

  # ============================================================
  # Lifecycle Transitions
  # ============================================================
  describe 'PATCH /api/v1/missions/:id - Lifecycle Transitions' do
    path '/api/v1/missions/{id}' do
      patch 'Transitions mission status' do
        tags 'Missions'
        consumes 'application/json'
        produces 'application/json'

        parameter name: :id, in: :path, type: :string
        parameter name: :Authorization, in: :header, type: :string, required: true
        parameter name: :mission_params, in: :body, required: true

        context 'lead -> pending' do
          response '200', 'allows lead -> pending' do
            let(:id) { @mission.id }
            let(:Authorization) { "Bearer #{@token}" }
            let(:mission_params) { { status: 'pending' } }

            before do
              user = create(:user)
              company = create(:company)
              create(:user_company, user: user, company: company, role: 'independent')

              mission = create(:mission, user: user, status: 'lead')
              create(:mission_company, mission: mission, company: company, role: 'independent')

              @mission = mission
              @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
            end

            run_test!
          end
        end

        context 'pending -> won' do
          response '200', 'allows pending -> won' do
            let(:id) { @mission.id }
            let(:Authorization) { "Bearer #{@token}" }
            let(:mission_params) { { status: 'won' } }

            before do
              user = create(:user)
              company = create(:company)
              create(:user_company, user: user, company: company, role: 'independent')

              mission = create(:mission, user: user, status: 'pending')
              create(:mission_company, mission: mission, company: company, role: 'independent')

              @mission = mission
              @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
            end

            run_test!
          end
        end

        context 'won -> in_progress' do
          response '200', 'allows won -> in_progress' do
            let(:id) { @mission.id }
            let(:Authorization) { "Bearer #{@token}" }
            let(:mission_params) { { status: 'in_progress' } }

            before do
              user = create(:user)
              company = create(:company)
              create(:user_company, user: user, company: company, role: 'independent')

              mission = create(:mission, user: user, status: 'won')
              create(:mission_company, mission: mission, company: company, role: 'independent')

              @mission = mission
              @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
            end

            run_test!
          end
        end

        context 'in_progress -> completed' do
          response '200', 'allows in_progress -> completed' do
            let(:id) { @mission.id }
            let(:Authorization) { "Bearer #{@token}" }
            let(:mission_params) { { status: 'completed' } }

            before do
              user = create(:user)
              company = create(:company)
              create(:user_company, user: user, company: company, role: 'independent')

              mission = create(:mission, user: user, status: 'in_progress')
              create(:mission_company, mission: mission, company: company, role: 'independent')

              @mission = mission
              @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
            end

            run_test!
          end
        end

        context 'completed -> in_progress (invalid)' do
          response '403', 'rejects completed -> in_progress' do
            let(:id) { @mission.id }
            let(:Authorization) { "Bearer #{@token}" }
            let(:mission_params) { { status: 'in_progress' } }

            before do
              user = create(:user)
              company = create(:company)
              create(:user_company, user: user, company: company, role: 'independent')

              mission = create(:mission, user: user, status: 'completed')
              create(:mission_company, mission: mission, company: company, role: 'independent')

              @mission = mission
              @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
            end

            run_test!
          end
        end

        context 'won -> lead (invalid)' do
          response '422', 'rejects won -> lead' do
            let(:id) { @mission.id }
            let(:Authorization) { "Bearer #{@token}" }
            let(:mission_params) { { status: 'lead' } }

            before do
              user = create(:user)
              company = create(:company)
              create(:user_company, user: user, company: company, role: 'independent')

              mission = create(:mission, user: user, status: 'won')
              create(:mission_company, mission: mission, company: company, role: 'independent')

              @mission = mission
              @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
            end

            run_test!
          end
        end
      end
    end
  end

  # ============================================================
  # DELETE /api/v1/missions/:id
  # ============================================================
  describe 'DELETE /api/v1/missions/:id' do
    path '/api/v1/missions/{id}' do
      delete 'Archives a mission' do
        tags 'Missions'
        produces 'application/json'

        parameter name: :id, in: :path, type: :string
        parameter name: :Authorization, in: :header, type: :string, required: true

        response '200', 'Mission archived successfully' do
          let(:id) { @mission.id }
          let(:Authorization) { "Bearer #{@token}" }

          before do
            user = create(:user)
            company = create(:company)
            create(:user_company, user: user, company: company, role: 'independent')

            mission = create(:mission, user: user)
            create(:mission_company, mission: mission, company: company, role: 'independent')

            @mission = mission
            @token = AuthenticationService.login(user, '127.0.0.1', 'rswag')[:token]
          end

          run_test!
        end
      end
    end
  end
end
