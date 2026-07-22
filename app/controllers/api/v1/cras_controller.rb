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
    #
    # Error Handling (Phase 1.9):
    # - All error responses follow standardized format: { code, message, details }
    # - Uses StandardizedError concern methods
    class CrasController < Api::V1::BaseController
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
        result = CraServices::Create.call(
          cra_params: cra_params,
          current_user: current_user
        )

        if result.success?
          render json: Api::V1::Cras::ResponseFormatter.single(result.data[:cra]), status: :created
        else
          error_invalid_payload(result.error)
        end
      end

      # GET /api/v1/cras
      # Lists CRAs accessible to the current user with pagination
      def index
        result = CraServices::List.call(
          current_user: current_user,
          page: params[:page],
          per_page: params[:per_page]&.to_i || 20,
          filters: extract_filters
        )

        if result.success?
          render json: Api::V1::Cras::ResponseFormatter.collection(
            result.data[:cras],
            pagination: result.data[:pagination]
          ), status: :ok
        else
          error_invalid_payload(result.error)
        end
      end

      # GET /api/v1/cras/:id
      # Shows a specific CRA with full details
      def show
        render json: Api::V1::Cras::ResponseFormatter.single(@cra, include_entries: true), status: :ok
      end

      # PATCH /api/v1/cras/:id
      # Updates a CRA with business rule validation
      def update
        result = CraServices::Update.call(
          cra: @cra,
          cra_params: cra_params,
          current_user: current_user
        )

        if result.success?
          render json: Api::V1::Cras::ResponseFormatter.single(result.data[:cra], include_entries: true), status: :ok
        else
          render_result_error(result)
        end
      end

      # DELETE /api/v1/cras/:id
      # Archives a CRA (soft delete) with business rules
      def destroy
        result = CraServices::Destroy.call(
          cra: @cra,
          current_user: current_user
        )

        if result.success?
          render json: { message: 'CRA archived successfully' }, status: :ok
        else
          render_result_error(result)
        end
      end

      # POST /api/v1/cras/:id/submit
      # Submits a CRA (draft → submitted) with business rule validation
      def submit
        result = CraServices::Lifecycle.call(
          cra: @cra,
          action: 'submit',
          current_user: current_user
        )

        if result.success?
          render json: Api::V1::Cras::ResponseFormatter.single(result.data[:cra], include_entries: true), status: :ok
        else
          render_result_error(result)
        end
      end

      # POST /api/v1/cras/:id/lock
      # Locks a CRA (submitted → locked) with Git versioning
      def lock
        result = CraServices::Lifecycle.call(
          cra: @cra,
          action: 'lock',
          current_user: current_user
        )

        if result.success?
          render json: Api::V1::Cras::ResponseFormatter.single(result.data[:cra], include_entries: true), status: :ok
        else
          render_result_error(result)
        end
      end

      # GET /api/v1/cras/:id/export
      # Exports CRA as CSV (PDF planned for future)
      def export
        result = CraServices::Export.call(
          cra: @cra,
          current_user: current_user,
          include_entries: params[:include_entries] != 'false',
          format: params[:export_format] || 'csv'
        )

        if result.success?
          filename = "cra_#{@cra.year}_#{format('%02d', @cra.month)}.csv"
          send_data result.data,
                    filename: filename,
                    type: 'text/csv',
                    disposition: 'attachment'
        else
          render_result_error(result)
        end
      end

      private

      # Dispatch a service result error to the appropriate standardized
      # error method based on the result's HTTP status.
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

      # FC07 Centralized CRA error handler
      # Handles all CraErrors exceptions and returns JSON according to Phase 1.9 standardized format
      # Format: { code, message, details }
      def handle_cra_error(exception)
        Rails.logger.error "[CrasController] CRA Error: #{exception.class.name} - #{exception.message}"

        case exception
        when CraErrors::InvalidPayloadError
          details = {}
          details[:field] = exception.field if exception.respond_to?(:field) && exception.field
          error_invalid_payload(exception.message, details)

        when CraErrors::InvalidTransitionError
          details = { field: 'status' }
          error_conflict(exception.message, details)

        when CraErrors::CraLockedError
          details = { cra_id: @cra&.id, status: @cra&.status }
          error_conflict(exception.message, details)

        when CraErrors::CraSubmittedError
          details = { cra_id: @cra&.id, status: @cra&.status }
          error_conflict(exception.message, details)

        when CraErrors::DuplicateEntryError
          details = {}
          error_conflict(exception.message, details)

        when CraErrors::CraNotFoundError
          details = { cra_id: params[:id] }
          error_not_found(exception.message, details)

        when CraErrors::UnauthorizedError
          details = {}
          error_forbidden(exception.message, details)

        when CraErrors::NoIndependentCompanyError
          details = {}
          error_forbidden(exception.message, details)

        when CraErrors::MissionNotFoundError
          details = {}
          error_not_found(exception.message, details)

        when CraErrors::InternalError
          details = {}
          error_internal(exception.message, details)

        else
          # Fallback for any other CraErrors::BaseError
          details = { exception_class: exception.class.name }
          error_unprocessable_entity(exception.message, details)
        end
      end
    end
  end
end
