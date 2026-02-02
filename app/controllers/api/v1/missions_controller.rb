# frozen_string_literal: true

module Api
  module V1
    # MissionsController handles CRUD operations for Mission entities
    # Implements FC 06 - Mission Management with Domain-Driven Architecture
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
    class MissionsController < ApplicationController
      before_action :authenticate_access_token!
      before_action :set_mission, only: %i[show update destroy]
      before_action :check_rate_limit!, only: %i[create update]
      before_action :validate_mission_access!, only: %i[show update destroy]

      # POST /api/v1/missions
      # Creates a new mission with business rule validation
      # Requires: JWT authentication, user must have independent company
      # Params: name, description, mission_type, status, start_date, end_date,
      #         daily_rate/fixed_price, currency, client_company_id
      def create
        # Validate user has independent company access
        unless user_has_independent_company_access?
          render json: {
            error: 'Forbidden',
            message: 'User must have an independent company to create missions'
          }, status: :forbidden
          return
        end

        # Build mission with current user as creator
        mission = Mission.new(mission_attributes.merge(created_by_user_id: current_user.id))

        if mission.save
          # Create MissionCompany relationship for independent company
          independent_company = get_user_independent_company
          mission.mission_companies.create!(
            company_id: independent_company.id,
            role: 'independent'
          )

          # Create MissionCompany relationship for client company if provided
          if client_company_id.present?
            mission.mission_companies.create!(
              company_id: client_company_id,
              role: 'client'
            )
          end

          render json: mission_response(mission), status: :created
        else
          render json: {
            error: 'Invalid Payload',
            message: mission.errors.full_messages
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordInvalid => e
        handle_mission_validation_error(e)
      rescue ArgumentError => e
        # Handle invalid enum values that bypass model validation
        render json: {
          error: 'Invalid Payload',
          message: [e.message]
        }, status: :unprocessable_entity
      rescue StandardError
        render json: {
          error: 'Internal Error',
          message: 'An unexpected error occurred'
        }, status: :internal_server_error
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
      rescue StandardError
        render json: {
          error: 'Internal Error',
          message: 'An unexpected error occurred'
        }, status: :internal_server_error
      end

      # GET /api/v1/missions/:id
      # Shows a specific mission if user has access
      def show
        render json: mission_response(@mission, include_companies: true)
      rescue StandardError
        render json: {
          error: 'Internal Error',
          message: 'An unexpected error occurred'
        }, status: :internal_server_error
      end

      # PATCH /api/v1/missions/:id
      # Updates a mission with business rule validation
      # MVP Rule: Only creator can modify
      def update
        # Check if user is creator (MVP rule)
        unless @mission.modifiable_by?(current_user)
          render json: {
            error: 'Forbidden',
            message: 'Only the mission creator can modify this mission'
          }, status: :forbidden
          return
        end

        # Validate status transition if status is being updated
        new_status = mission_params[:status]
        if new_status.present? && @mission.status != new_status && !@mission.can_transition_to?(new_status)
          render json: {
            error: 'Invalid Transition',
            message: "Cannot transition from #{@mission.status} to #{mission_params[:status]}"
          }, status: :unprocessable_entity
          return
        end

        if @mission.update(mission_params)
          render json: mission_response(@mission, include_companies: true)
        else
          render json: {
            error: 'Invalid Payload',
            message: @mission.errors.full_messages
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordInvalid => e
        handle_mission_validation_error(e)
      rescue StandardError
        render json: {
          error: 'Internal Error',
          message: 'An unexpected error occurred'
        }, status: :internal_server_error
      end

      # DELETE /api/v1/missions/:id
      # Archives a mission (soft delete) with business rules
      # Rule: Cannot delete if mission has CRA entries
      def destroy
        # Check if user is creator (MVP rule)
        unless @mission.modifiable_by?(current_user)
          render json: {
            error: 'Forbidden',
            message: 'Only the mission creator can archive this mission'
          }, status: :forbidden
          return
        end

        if @mission.discard
          render json: {
            message: 'Mission archived successfully'
          }, status: :ok
        else
          render json: {
            error: 'Mission In Use',
            message: @mission.errors.full_messages.join(', ')
          }, status: :conflict
        end
      rescue StandardError
        render json: {
          error: 'Internal Error',
          message: 'An unexpected error occurred'
        }, status: :internal_server_error
      end

      private

      def set_mission
        @mission = Mission.find_by(id: params[:id])
        unless @mission
          render json: {
            error: 'Not Found',
            message: 'Mission not found'
          }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: {
          error: 'Not Found',
          message: 'Mission not found'
        }, status: :not_found
      end

      # Validate user has access to the mission
      # FC 06 Rule: User must belong to a company linked to the mission with role independent or client
      def validate_mission_access!
        return unless @mission

        # Check if user can access this mission
        accessible_missions = Mission.accessible_to(current_user)
        unless accessible_missions.exists?(id: @mission.id)
          render json: {
            error: 'Not Found',
            message: 'Mission not accessible'
          }, status: :not_found
        end
      end

      # Check if user has independent company access
      def user_has_independent_company_access?
        current_user.user_companies.joins(:company).where(role: 'independent').any?
      end

      # Get user's independent company
      def get_user_independent_company
        current_user.user_companies.joins(:company).where(role: 'independent').first.company
      end

      # Rate limiting check for create/update endpoints
      def check_rate_limit!
        endpoint = 'missions'
        client_ip = extract_client_ip_for_rate_limiting

        allowed, retry_after = RateLimitService.check_rate_limit(endpoint, client_ip)

        unless allowed
          response.headers['Retry-After'] = retry_after.to_s
          render json: {
            error: 'Rate limit exceeded',
            retry_after: retry_after
          }, status: :too_many_requests
        end
      end

      # Extract client IP for rate limiting
      def extract_client_ip_for_rate_limiting
        forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
        if forwarded_for.present?
          forwarded_for.split(',').first.strip
        else
          request.env['HTTP_X_REAL_IP'] || request.env['REMOTE_ADDR'] || 'unknown'
        end
      end

      # Strong parameters for mission creation/update (excludes client_company_id)
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

      # Mission attributes only (without relation data)
      def mission_attributes
        mission_params.except(:client_company_id)
      end

      # Extract client_company_id from params
      def client_company_id
        params[:client_company_id]
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

      # Handle mission-specific validation errors
      def handle_mission_validation_error(error)
        mission = error.record

        if mission.errors[:status]&.include?('invalid_transition')
          render json: {
            error: 'Invalid Transition',
            message: mission.errors.full_messages
          }, status: :unprocessable_entity
        elsif mission.errors[:daily_rate]&.include?('required') ||
              mission.errors[:fixed_price]&.include?('required')
          render json: {
            error: 'Invalid Payload',
            message: mission.errors.full_messages
          }, status: :unprocessable_entity
        else
          render json: {
            error: 'Invalid Payload',
            message: mission.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
