# frozen_string_literal: true

module Api
  module V1
    # CrasController - Platinum Level
    # Implements FC 07 - CRA Management (Compte Rendu d'Activité) with Domain-Driven Architecture
    #
    # Key Features:
    # - JWT authentication required
    # - Role-based access control (independent company required)
    # - CRA lifecycle management (draft → submitted → locked)
    # - Financial calculations (total_days, total_amount) server-side only
    # - Soft delete with business rules
    # - Rate limiting on create/update operations
    # - Git Ledger versioning for locked CRAs
    # - Modular architecture with concerns and services
    class CrasController < ApplicationController
      include Pagy::Backend
      include Api::V1::Cras::ErrorHandler
      include Api::V1::Cras::RateLimitable
      include Api::V1::Cras::ParameterExtractor
      include Api::V1::Cras::AccessValidation
      include Common::ResponseFormatter

      before_action :authenticate_access_token!
      before_action :set_cra, only: %i[show update destroy submit lock export]
      before_action :validate_cra_access!, only: %i[show update destroy submit lock export]
      before_action :check_rate_limit!, only: %i[create update submit lock]

      # FC07 Error Handling - Centralized rescue_from for all CraErrors
      rescue_from CraErrors::BaseError, with: :handle_cra_error
      rescue_from CraErrors::InvalidPayloadError, with: :handle_cra_error
      rescue_from CraErrors::InvalidTransitionError, with: :handle_cra_error
      rescue_from CraErrors::CraLockedError, with: :handle_cra_error
      rescue_from CraErrors::CraSubmittedError, with: :handle_cra_error
      rescue_from CraErrors::DuplicateEntryError, with: :handle_cra_error
      rescue_from CraErrors::CraNotFoundError, with: :handle_cra_error
      rescue_from CraErrors::UnauthorizedError, with: :handle_cra_error
      rescue_from CraErrors::NoIndependentCompanyError, with: :handle_cra_error
      rescue_from CraErrors::MissionNotFoundError, with: :handle_cra_error
      rescue_from CraErrors::InternalError, with: :handle_cra_error

      # POST /api/v1/cras
      # Creates a new CRA with comprehensive business rule validation
      def create
        result = Api::V1::Cras::CreateService.call(
          cra_params: cra_params,
          current_user: current_user
        )

        render json: Api::V1::Cras::ResponseFormatter.single(result.cra), status: :created
      end

      # GET /api/v1/cras
      # Lists CRAs accessible to the current user with pagination
      def index
        result = Api::V1::Cras::ListService.call(
          current_user: current_user,
          page: params[:page],
          per_page: params[:per_page]&.to_i || 20,
          filters: extract_filters
        )

        render json: Api::V1::Cras::ResponseFormatter.collection(
          result.cras,
          pagination: result.pagination
        ), status: :ok
      end

      # GET /api/v1/cras/:id
      # Shows a specific CRA with full details
      def show
        render json: Api::V1::Cras::ResponseFormatter.single(@cra, include_entries: true), status: :ok
      end

      # PATCH /api/v1/cras/:id
      # Updates a CRA with business rule validation
      def update
        result = Api::V1::Cras::UpdateService.call(
          cra: @cra,
          cra_params: cra_params,
          current_user: current_user
        )

        render json: Api::V1::Cras::ResponseFormatter.single(result.cra, include_entries: true), status: :ok
      end

      # DELETE /api/v1/cras/:id
      # Archives a CRA (soft delete) with business rules
      def destroy
        Api::V1::Cras::DestroyService.call(
          cra: @cra,
          current_user: current_user
        )

        render json: {
          success: true,
          message: 'CRA archived successfully',
          timestamp: Time.current.iso8601
        }, status: :ok
      end

      # POST /api/v1/cras/:id/submit
      # Submits a CRA (draft → submitted) with business rule validation
      def submit
        result = Api::V1::Cras::LifecycleService.submit!(
          cra: @cra,
          current_user: current_user
        )

        render json: Api::V1::Cras::ResponseFormatter.single(result.cra, include_entries: true), status: :ok
      end

      # POST /api/v1/cras/:id/lock
      # Locks a CRA (submitted → locked) with Git versioning
      def lock
        result = Api::V1::Cras::LifecycleService.lock!(
          cra: @cra,
          current_user: current_user
        )

        render json: Api::V1::Cras::ResponseFormatter.single(result.cra, include_entries: true), status: :ok
      end

      # GET /api/v1/cras/:id/export
      # Exports CRA as CSV (PDF planned for future)
      def export
        result = Api::V1::Cras::ExportService.new(
          cra: @cra,
          format: params[:export_format] || 'csv',
          options: export_options
        ).call

        send_data result[:data],
                  filename: result[:filename],
                  type: result[:content_type],
                  disposition: 'attachment'
      end

      private

      def set_cra
        @cra = Cra.find_by(id: params[:id])
        raise CraErrors::CraNotFoundError, "CRA with ID #{params[:id]} not found" unless @cra
      end

      # Validate user has access to the CRA
      # FC 07 Rule: User must have access to missions associated with the CRA
      def validate_cra_access!
        return unless @cra

        accessible_cras = Cra.accessible_to(current_user)
        raise CraErrors::UnauthorizedError, 'CRA not accessible' unless accessible_cras.exists?(id: @cra.id)
      end

      # Extract and validate filters for listing
      def extract_filters
        {
          status: params[:status],
          month: params[:month]&.to_i,
          year: params[:year]&.to_i,
          company_id: params[:company_id]
        }.compact
      end

      # Strong parameters for CRA creation/update
      def cra_params
        params.permit(:month, :year, :currency, :description, :status)
      end

      # Options for export
      def export_options
        {
          include_entries: params[:include_entries] != 'false'
        }
      end

      # FC07 Centralized CRA error handler
      # Handles all CraErrors exceptions and returns JSON according to FC07 specifications
      def handle_cra_error(exception)
        Rails.logger.error "[CrasController] CRA Error: #{exception.class.name} - #{exception.message}"

        case exception
        when CraErrors::InvalidPayloadError
          render json: {
            error: 'invalid_payload',
            message: exception.message,
            field: exception.respond_to?(:field) ? exception.field : nil,
            timestamp: Time.current.iso8601
          }.compact, status: :unprocessable_content
        when CraErrors::InvalidTransitionError
          render json: {
            error: 'invalid_transition',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :unprocessable_content
        when CraErrors::CraLockedError
          render json: {
            error: 'cra_locked',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :conflict
        when CraErrors::CraSubmittedError
          render json: {
            error: 'cra_submitted',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :unprocessable_content
        when CraErrors::DuplicateEntryError
          render json: {
            error: 'duplicate_entry',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :conflict
        when CraErrors::CraNotFoundError
          render json: {
            error: 'not_found',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :not_found
        when CraErrors::UnauthorizedError
          render json: {
            error: 'unauthorized',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :forbidden
        when CraErrors::NoIndependentCompanyError
          render json: {
            error: 'forbidden',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :forbidden
        when CraErrors::MissionNotFoundError
          render json: {
            error: 'not_found',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :not_found
        when CraErrors::InternalError
          render json: {
            error: 'internal_error',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :internal_server_error
        else
          # Fallback for any other CraErrors::BaseError
          render json: {
            error: 'cra_error',
            message: exception.message,
            timestamp: Time.current.iso8601
          }, status: :unprocessable_content
        end
      end
    end
  end
end
