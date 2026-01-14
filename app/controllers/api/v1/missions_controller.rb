# frozen_string_literal: true

module Api
  module V1
    # MissionsController - Platinum Level
    # Implements FC 06 - Mission Management with Domain-Driven Architecture
    #
    # Key Features:
    # - JWT authentication required
    # - Role-based access control (independent company required)
    # - Mission lifecycle management (draft → lead → active → completed)
    # - Financial validation (time_based vs fixed_price)
    # - Soft delete with business rules
    # - Rate limiting on create/update operations
    # - Modular architecture with concerns and services
    class MissionsController < ApplicationController
      include Pagy::Backend
      include Api::V1::Missions::ErrorHandler
      include Api::V1::Missions::RateLimitable
      include Api::V1::Missions::ParameterExtractor
      include Api::V1::Missions::AccessValidation
      include Common::ResponseFormatter

      before_action :authenticate_access_token!
      before_action :set_mission, only: %i[show update destroy]
      before_action :validate_mission_access!, only: %i[show update destroy]
      before_action :check_rate_limit!, only: %i[create update destroy]

      # FC06 Error Handling - Centralized rescue_from for all MissionErrors
      rescue_from MissionErrors::BaseError, with: :handle_mission_error
      rescue_from MissionErrors::InvalidPayloadError, with: :handle_mission_error
      rescue_from MissionErrors::InvalidTransitionError, with: :handle_mission_error
      rescue_from MissionErrors::MissionLockedError, with: :handle_mission_error
      rescue_from MissionErrors::MissionInUseError, with: :handle_mission_error
      rescue_from MissionErrors::DuplicateEntryError, with: :handle_mission_error
      rescue_from MissionErrors::MissionNotFoundError, with: :handle_mission_error
      rescue_from MissionErrors::UnauthorizedError, with: :handle_mission_error
      rescue_from MissionErrors::NoIndependentCompanyError, with: :handle_mission_error
      rescue_from MissionErrors::InternalError, with: :handle_mission_error

      # POST /api/v1/missions
      # Creates a new mission using CreateService
      def create
        result = Api::V1::Missions::CreateService.call(
          mission_params: mission_params,
          current_user: current_user,
          client_company_id: client_company_id
        )

        render json: Api::V1::Missions::ResponseFormatter.single(result.mission), status: :created
      end

      # GET /api/v1/missions
      # Lists missions using ListService
      def index
        result = Api::V1::Missions::ListService.call(
          current_user: current_user,
          page: params[:page],
          per_page: params[:per_page]&.to_i || 20,
          filters: extract_filters
        )

        render json: Api::V1::Missions::ResponseFormatter.collection(
          result.missions,
          pagination: result.pagination
        ), status: :ok
      end

      # GET /api/v1/missions/:id
      # Shows a specific mission
      def show
        render json: Api::V1::Missions::ResponseFormatter.single(@mission, include_companies: true), status: :ok
      end

      # PATCH /api/v1/missions/:id
      # Updates a mission using UpdateService
      def update
        result = Api::V1::Missions::UpdateService.call(
          mission: @mission,
          mission_params: mission_params,
          current_user: current_user
        )

        render json: Api::V1::Missions::ResponseFormatter.single(result.mission, include_companies: true), status: :ok
      end

      # DELETE /api/v1/missions/:id
      # Destroys a mission using DestroyService
      def destroy
        result = Api::V1::Missions::DestroyService.call(
          mission: @mission,
          current_user: current_user
        )

        if result.success?
          render json: {
            success: true,
            message: 'Mission archived successfully',
            timestamp: Time.current.iso8601
          }, status: :ok
        else
          render json: Api::V1::Missions::ResponseFormatter.error(
            result.errors, result.error_type
          ), status: :unprocessable_entity
        end
      end

      private

      def set_mission
        @mission = Mission.find_by(id: params[:id])
        raise MissionErrors::MissionNotFoundError, "Mission with ID #{params[:id]} not found" unless @mission
      end

      # Validate user has access to the mission
      # FC 06 Rule: User must have access to missions via their companies
      def validate_mission_access!
        return unless @mission

        accessible_missions = Mission.accessible_to(current_user)
        raise MissionErrors::UnauthorizedError, 'Mission not accessible' unless accessible_missions.exists?(id: @mission.id)
      end

      # Extract and validate filters for listing
      def extract_filters
        {
          status: params[:status],
          mission_type: params[:mission_type],
          start_date: params[:start_date],
          end_date: params[:end_date],
          company_id: params[:company_id],
          name: params[:name]
        }.compact
      end

      # Strong parameters for mission creation/update
      def mission_params
        params.permit(:name, :description, :mission_type, :status, :start_date, :end_date,
                     :daily_rate, :fixed_price, :currency)
      end

      # Extract client_company_id from parameters
      def client_company_id
        params[:client_company_id] || params.dig(:mission_params, :client_company_id)
      end

      # FC06 Centralized mission error handler
      # Handles all MissionErrors exceptions and returns JSON according to FC06 specifications
      def handle_mission_error(exception)
        Rails.logger.error "[MissionsController] Mission Error: #{exception.class.name} - #{exception.message}"

        case exception
        when MissionErrors::InvalidPayloadError
          render json: {
            error: 'invalid_payload',
            message: exception.message,
            field: exception.respond_to?(:field) ? exception.field : nil,
            timestamp: Time.current.iso8601
          }.compact, status: :unprocessable_content
        when MissionErrors::InvalidTransitionError
          render json: {
            error: 'invalid_transition',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :unprocessable_content
        when MissionErrors::MissionLockedError
          render json: {
            error: 'mission_locked',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :conflict
        when MissionErrors::MissionInUseError
          render json: {
            error: 'mission_in_use',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :conflict
        when MissionErrors::DuplicateEntryError
          render json: {
            error: 'duplicate_entry',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :conflict
        when MissionErrors::MissionNotFoundError
          render json: {
            error: 'not_found',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :not_found
        when MissionErrors::UnauthorizedError
          render json: {
            error: 'unauthorized',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :forbidden
        when MissionErrors::NoIndependentCompanyError
          render json: {
            error: 'forbidden',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :forbidden
        when MissionErrors::InternalError
          render json: {
            error: 'internal_error',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :internal_server_error
        else
          # Fallback for any other MissionErrors::BaseError
          render json: {
            error: 'mission_error',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :unprocessable_content
        end
      end
    end
  end
end
