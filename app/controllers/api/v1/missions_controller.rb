# frozen_string_literal: true

module Api
  module V1
    # MissionsController handles CRUD operations for Mission entities
    # Implements FC 06 - Mission Management with Domain-Driven Architecture
    #
    # This controller is intentionally THIN: all business logic lives in
    # MissionServices::* (Create / Update / Delete), following the same
    # pattern as CraServices::* and CrasController. Each action dispatches
    # to the corresponding service and renders the ApplicationResult.
    #
    # Features:
    # - JWT authentication required
    # - Role-based access control (independent/client)
    # - Mission lifecycle management (lead → completed)
    # - Financial validation (time_based vs fixed_price)
    # - Soft delete with business rules
    # - Rate limiting on create/update operations
    #
    # API Endpoints:
    # - POST /api/v1/missions           # Create mission
    # - GET /api/v1/missions            # List missions
    # - GET /api/v1/missions/:id        # Show mission
    # - PATCH /api/v1/missions/:id      # Update mission
    # - DELETE /api/v1/missions/:id     # Archive mission
    #
    # Error Handling:
    # - 401 unauthorized: Invalid JWT
    # - 403 forbidden: No company access
    # - 404 not_found: Mission not accessible
    # - 422 invalid_payload: Business validation failed
    # - 422 invalid_transition: Invalid status transition
    # - 409 mission_in_use: Mission linked to CRA
    # - 500 internal_error: Server error
    class MissionsController < Api::V1::BaseController
      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      before_action :authenticate_access_token!
      before_action :set_mission, only: %i[show update destroy]
      before_action :check_rate_limit!, only: %i[create update]
      before_action :validate_mission_access!, only: %i[show update destroy]
      include Common::RateLimitable

      # POST /api/v1/missions
      # Creates a new mission with business rule validation
      # Requires: JWT authentication, user must have independent company
      # Params: name, description, mission_type, status, start_date, end_date,
      #         daily_rate/fixed_price, currency, client_company_id
      def create
        result = MissionServices::Create.call(
          mission_params: mission_params,
          current_user: current_user
        )

        if result.success?
          render json: mission_response(result.data[:mission]), status: :created
        else
          render_result_error(result)
        end
      end

      # GET /api/v1/missions
      # Lists missions accessible to the current user
      # Accessible missions: missions where user's companies have independent or client role
      def index
        missions = Mission.accessible_to(current_user).active.includes(
          mission_companies: :company
        )

        render json: {
          data: missions.map { |mission| mission_response(mission, include_companies: true) },
          meta: {
            total: missions.count
          }
        }
      rescue StandardError => e
        error_internal(e.message)
      end

      # GET /api/v1/missions/:id
      # Shows a specific mission if user has access
      def show
        render json: mission_response(@mission, include_companies: true)
      rescue StandardError => e
        error_internal(e.message)
      end

      # PATCH /api/v1/missions/:id
      # Updates a mission with business rule validation
      # MVP Rule: Only creator can modify (enforced by MissionServices::Update)
      def update
        result = MissionServices::Update.call(
          mission: @mission,
          mission_params: mission_params,
          current_user: current_user
        )

        if result.success?
          render json: mission_response(result.data[:mission], include_companies: true)
        else
          render_result_error(result)
        end
      end

      # DELETE /api/v1/missions/:id
      # Archives a mission (soft delete) with business rules
      # Rule: Cannot delete if mission has CRA entries (enforced by MissionServices::Delete)
      def destroy
        result = MissionServices::Delete.call(
          mission: @mission,
          current_user: current_user
        )

        if result.success?
          render json: { message: 'Mission archived successfully' }, status: :ok
        else
          render_result_error(result)
        end
      end

      private

      # Dispatch a service result error to the appropriate standardized
      # error method based on the result's HTTP status.
      # Mirrors the pattern used by CrasController.
      def render_result_error(result)
        message = result.message || result.error.to_s
        case result.status
        when :conflict
          error_conflict(message)
        when :forbidden
          error_forbidden(message)
        when :not_found
          error_not_found(message)
        when :bad_request
          error_bad_request(message)
        when :internal_server_error, :internal_error
          error_internal(message)
        else
          error_unprocessable_entity(message)
        end
      end

      def record_not_found
        error_not_found('Mission not found')
      end

      def set_mission
        @mission = Mission.find_by(id: params[:id])
        return if @mission

        error_not_found('Mission not found')
      end

      # Validate user has access to the mission
      # FC 06 Rule: User must belong to a company linked to the mission with role independent or client
      def validate_mission_access!
        return unless @mission

        accessible_missions = Mission.accessible_to(current_user)

        return if accessible_missions.exists?(id: @mission.id)

        error_not_found('Mission not accessible')
      end

      # Rate limiting check for create/update endpoints
      def check_rate_limit!
        endpoint = 'missions'
        client_ip = extract_client_ip_for_rate_limiting

        allowed, retry_after = RateLimitService.check_rate_limit(endpoint, client_ip)

        unless allowed
          response.headers['Retry-After'] = retry_after.to_s
          error_too_many_requests('Rate limit exceeded', { retry_after: retry_after })
        end
      end

      # Strong parameters for mission creation/update (excludes client_company_id from Mission attrs;
      # client_company_id is consumed by MissionServices::Create to build the client relation)
      def mission_params
        params.permit(
          :name,
          :description,
          :mission_type,
          :status,
          :start_date,
          :end_date,
          :daily_rate,
          :fixed_price,
          :currency,
          :client_company_id
        )
      end

      # Format mission response according to FC 06
      def mission_response(mission, include_companies: false)
        response = {
          id: mission.id,
          name: mission.name,
          description: mission.description,
          mission_type: mission.mission_type,
          status: mission.status,
          start_date: mission.start_date,
          end_date: mission.end_date,
          currency: mission.currency,
          created_at: mission.created_at,
          updated_at: mission.updated_at
        }

        # Add financial information based on mission type
        if mission.time_based?
          response[:daily_rate] = mission.daily_rate
        elsif mission.fixed_price?
          response[:fixed_price] = mission.fixed_price
        end

        # Include company information if requested
        if include_companies
          response[:companies] = mission.mission_companies.map do |mc|
            {
              id: mc.company_id,
              role: mc.role,
              company: {
                id: mc.company.id,
                name: mc.company.name,
                siret: mc.company.siret
              }
            }
          end
        end

        response
      end
    end
  end
end
