# frozen_string_literal: true

module Api
  module V1
    # MissionsController handles CRUD operations for Mission entities
    # Implements FC 06 - Mission Management with Domain-Driven Architecture
    #
    # Architecture:
    # - Controller is thin - delegates to MissionServices
    # - Uses ApplicationResult for consistent service → controller communication
    # - ErrorRenderable for standardized error responses
    #
    # API Endpoints:
    # - POST /api/v1/missions           # Create mission
    # - GET /api/v1/missions            # List missions
    # - GET /api/v1/missions/:id       # Show mission
    # - PATCH /api/v1/missions/:id     # Update mission
    # - DELETE /api/v1/missions/:id    # Archive mission
    class MissionsController < ApplicationController
      include ErrorRenderable

      before_action :authenticate_access_token!
      before_action :set_mission, only: %i[show update destroy]
      before_action :check_rate_limit!, only: %i[create update]
      before_action :validate_mission_access!, only: %i[show update destroy]

      # POST /api/v1/missions
      # Creates a new mission via MissionServices::Create
      def create
        result = MissionServices::Create.call(
          mission_params: mission_params.to_h,
          current_user: current_user
        )

        render_result(result)
      end

      # GET /api/v1/missions
      # Lists missions accessible to the current user
      def index
        missions = Mission.accessible_to(current_user).active.includes(
          mission_companies: :company
        )

        render json: {
          data: missions.map { |mission| mission_response(mission, include_companies: true) },
          meta: { total: missions.count }
        }
      end

      # GET /api/v1/missions/:id
      # Shows a specific mission if user has access
      def show
        render json: mission_response(@mission, include_companies: true)
      end

      # PATCH /api/v1/missions/:id
      # Updates a mission via MissionServices::Update
      def update
        result = MissionServices::Update.call(
          mission: @mission,
          mission_params: mission_params.to_h,
          current_user: current_user
        )

        render_result(result)
      end

      # DELETE /api/v1/missions/:id
      # Archives a mission via MissionServices::Delete
      def destroy
        result = MissionServices::Delete.call(
          mission: @mission,
          current_user: current_user
        )

        render_result(result)
      end

      private

      def set_mission
        @mission = Mission.find_by(id: params[:id])

        return render_not_found('Mission not found') unless @mission
      rescue ActiveRecord::RecordNotFound
        render_not_found('Mission not found')
      end

      # Validate user has access to the mission
      def validate_mission_access!
        return unless @mission

        accessible_missions = Mission.accessible_to(current_user)
        return if accessible_missions.exists?(id: @mission.id)

        render_not_found('Mission not accessible')
      end

      # Rate limiting check for create/update endpoints
      def check_rate_limit!
        endpoint = 'missions'
        client_ip = extract_client_ip_for_rate_limiting

        allowed, retry_after = RateLimitService.check_rate_limit(endpoint, client_ip)

        return if allowed

        response.headers['Retry-After'] = retry_after.to_s
        render json: {
          error: { code: 'rate_limit_exceeded', message: 'Rate limit exceeded', retry_after: retry_after }
        }, status: :too_many_requests
      end

      # Extract client IP for rate limiting
      def extract_client_ip_for_rate_limiting
        forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
        forwarded_for.present? ? forwarded_for.split(',').first.strip : request.env['HTTP_X_REAL_IP'] || request.env['REMOTE_ADDR'] || 'unknown'
      end

      # Strong parameters for mission creation/update
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
