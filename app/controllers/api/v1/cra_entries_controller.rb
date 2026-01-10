# frozen_string_literal: true

module Api
  module V1
    # CraEntriesController - Platinum Level
    # Clean, modular implementation using concerns and services
    # Implements FC 07 - CRA Management (Compte Rendu d'Activité) with Domain-Driven Architecture
    #
    # Key Features:
    # - JWT authentication required
    # - Role-based access control (must have access to parent CRA)
    # - Free granularity for quantity (0.25, 0.5, 1.0, 2.0 days)
    # - Unit price stored in cents for precise calculations
    # - Soft delete with business rules (cannot delete from locked CRA)
    # - Automatic CRA-Mission linking via CraMissionLinker service
    # - Rate limiting on create/update operations
    # - Modular architecture with concerns and services
    class CraEntriesController < ApplicationController
      include CraEntries::ErrorHandler
      include CraEntries::ResponseFormatter
      include CraEntries::RateLimitable
      include CraEntries::ParameterExtractor

      before_action :authenticate_access_token!
      before_action :set_cra
      before_action :set_cra_entry, only: %i[show update destroy]
      before_action :check_rate_limit!, only: %i[create update destroy]
      before_action :validate_cra_access!, only: %i[create index show update destroy]
      before_action :validate_cra_modifiable!, only: %i[create]
      before_action :validate_entry_modifiable!, only: %i[update destroy]

      # FC07 Error Handling - Centralized rescue_from for all CraErrors
      rescue_from CraErrors::InvalidPayloadError, with: :handle_invalid_payload_error
      rescue_from CraErrors::InvalidTransitionError, with: :handle_invalid_transition_error
      rescue_from CraErrors::CraLockedError, with: :handle_cra_locked_error
      rescue_from CraErrors::CraSubmittedError, with: :handle_cra_submitted_error
      rescue_from CraErrors::DuplicateEntryError, with: :handle_duplicate_entry_error
      rescue_from CraErrors::UnauthorizedError, with: :handle_unauthorized_error
      rescue_from CraErrors::NoIndependentCompanyError, with: :handle_no_independent_company_error
      rescue_from CraErrors::MissionNotFoundError, with: :handle_mission_not_found_error
      rescue_from CraErrors::CraNotFoundError, with: :handle_cra_not_found_error
      rescue_from CraErrors::EntryNotFoundError, with: :handle_entry_not_found_error
      rescue_from CraErrors::InternalError, with: :handle_internal_error

      # POST /api/v1/cras/:cra_id/entries
      # Creates a new CRA entry with comprehensive business rule validation
      def create
        result = CraEntries::CreateService.call(
          cra: @cra,
          entry_params: cra_entry_attributes,
          mission_id: mission_id,
          current_user: current_user
        )

        if result.success?
          format_cra_entry_creation_response(result.entry, @cra)
        else
          handle_service_error(result)
        end
      rescue StandardError => e
        log_api_error(e, { action: 'create', cra_id: @cra&.id, user_id: current_user&.id })
        render_fc07_error('internal_error', 'An unexpected error occurred', :internal_server_error)
      end

      # GET /api/v1/cras/:cra_id/entries
      # Lists CRA entries with optimized queries and pagination
      def index
        result = CraEntries::ListService.call(
          cra: @cra,
          include_associations: true
        )

        if result.success?
          render json: CraEntries::ResponseFormatter.collection(result.value!, @cra), status: :ok
        else
          handle_service_error(result)
        end
      rescue StandardError => e
        log_api_error(e, { action: 'index', cra_id: @cra&.id, user_id: current_user&.id })
        render_fc07_error('internal_error', 'An unexpected error occurred', :internal_server_error)
      end

      # GET /api/v1/cras/:cra_id/entries/:id
      # Shows a specific CRA entry with full details
      def show
        render json: CraEntries::ResponseFormatter.single(@cra_entry, @cra), status: :ok
      rescue StandardError => e
        log_api_error(e, { action: 'show', cra_id: @cra&.id, cra_entry_id: @cra_entry&.id, user_id: current_user&.id })
        render_fc07_error('internal_error', 'An unexpected error occurred', :internal_server_error)
      end

      # PATCH /api/v1/cras/:cra_id/entries/:id
      # Updates a CRA entry with business rule validation
      def update
        result = CraEntries::UpdateService.call(
          entry: @cra_entry,
          entry_params: cra_entry_params,
          mission_id: mission_id,
          current_user: current_user
        )

        if result.success?
          render json: CraEntries::ResponseFormatter.single(result.entry, @cra), status: :ok
        else
          handle_service_error(result)
        end
      rescue StandardError => e
        log_api_error(e,
                      { action: 'update', cra_id: @cra&.id, cra_entry_id: @cra_entry&.id, user_id: current_user&.id })
        render_fc07_error('internal_error', 'An unexpected error occurred', :internal_server_error)
      end

      # DELETE /api/v1/cras/:cra_id/entries/:id
      # Deletes a CRA entry (soft delete) with business rules
      def destroy
        result = CraEntries::DestroyService.call(
          entry: @cra_entry,
          current_user: current_user
        )

        if result.success?
          render json: {
            success: true,
            message: 'CRA entry deleted successfully',
            timestamp: Time.current.iso8601
          }, status: :ok
        else
          handle_service_error(result)
        end
      rescue StandardError => e
        log_api_error(e,
                      { action: 'destroy', cra_id: @cra&.id, cra_entry_id: @cra_entry&.id, user_id: current_user&.id })
        render_fc07_error('internal_error', 'An unexpected error occurred', :internal_server_error)
      end

      private

      def set_cra
        @cra = Cra.find_by(id: params[:cra_id])
        handle_resource_not_found(@cra, 'CRA') unless @cra
      rescue ActiveRecord::RecordNotFound
        handle_resource_not_found(nil, 'CRA')
      end

      def set_cra_entry
        @cra_entry = @cra.cra_entries.find_by(id: params[:id])
        handle_resource_not_found(@cra_entry, 'CRA entry') unless @cra_entry
      rescue ActiveRecord::RecordNotFound
        handle_resource_not_found(nil, 'CRA entry')
      end

      # Validate user has access to the parent CRA
      # FC 07 Rule: User must have access to missions associated with the CRA
      def validate_cra_access!
        return unless @cra

        accessible_cras = Cra.accessible_to(current_user)
        handle_forbidden('CRA not accessible') unless accessible_cras.exists?(id: @cra.id)
      end

      # Validate that CRA can accept new entries
      # Rule: Cannot add entries if CRA is submitted or locked (FC-07)
      def validate_cra_modifiable!
        return unless @cra

        handle_conflict('Cannot add entries to submitted or locked CRAs') unless @cra.draft?
      end

      # Validate that CRA entry can be modified
      # Rule: Entry cannot be modified if parent CRA is submitted or locked (FC-07)
      def validate_entry_modifiable!
        return unless @cra_entry

        handle_conflict('Cannot modify entry from submitted or locked CRA') unless @cra.draft?
      end

      # Extract CRA entry parameters from request
      def cra_entry_attributes
        {
          date: parse_date_param(params[:date]),
          quantity: safe_decimal_param(:quantity),
          unit_price: safe_integer_param(:unit_price, 0),
          description: params[:description]&.strip&.presence
        }.compact
      end

      # Extract mission_id from request
      def mission_id
        params[:mission_id].present? ? params[:mission_id] : nil
      end

      # FC07 Standard Error Rendering
      def render_fc07_error(error_type, message, status)
        render json: {
          error: error_type,
          message: message,
          timestamp: Time.current.iso8601
        }, status: status
      end

      # FC07 CraErrors handlers
      def handle_invalid_payload_error(error)
        Rails.logger.warn "CRA Entry InvalidPayloadError: #{error.message}"
        render json: {
          error: 'invalid_payload',
          message: error.message,
          field: error.field,
          timestamp: Time.current.iso8601
        }, status: :unprocessable_content
      end

      def handle_invalid_transition_error(error)
        Rails.logger.warn "CRA Entry InvalidTransitionError: #{error.message}"
        render_fc07_error('invalid_transition', error.message, :unprocessable_content)
      end

      def handle_cra_locked_error(error)
        Rails.logger.warn "CRA Entry CraLockedError: #{error.message}"
        render_fc07_error('cra_locked', error.message, :conflict)
      end

      def handle_cra_submitted_error(error)
        Rails.logger.warn "CRA Entry CraSubmittedError: #{error.message}"
        render_fc07_error('cra_submitted', error.message, :conflict)
      end

      def handle_duplicate_entry_error(error)
        Rails.logger.warn "CRA Entry DuplicateEntryError: #{error.message}"
        render_fc07_error('duplicate_entry', error.message, :conflict)
      end

      def handle_unauthorized_error(error)
        Rails.logger.warn "CRA Entry UnauthorizedError: #{error.message}"
        render_fc07_error('unauthorized', error.message, :forbidden)
      end

      def handle_no_independent_company_error(error)
        Rails.logger.warn "CRA Entry NoIndependentCompanyError: #{error.message}"
        render_fc07_error('forbidden', error.message, :forbidden)
      end

      def handle_mission_not_found_error(error)
        Rails.logger.warn "CRA Entry MissionNotFoundError: #{error.message}"
        render_fc07_error('mission_not_found', error.message, :not_found)
      end

      def handle_cra_not_found_error(error)
        Rails.logger.warn "CRA Entry CraNotFoundError: #{error.message}"
        render_fc07_error('not_found', error.message, :not_found)
      end

      def handle_entry_not_found_error(error)
        Rails.logger.warn "CRA Entry EntryNotFoundError: #{error.message}"
        render_fc07_error('not_found', error.message, :not_found)
      end

      def handle_internal_error(error)
        Rails.logger.error "CRA Entry InternalError: #{error.message}"
        render_fc07_error('internal_error', error.message, :internal_server_error)
      end

      # Handle service result errors with appropriate HTTP status
      def handle_service_error(result)
        case result.error_type
        when :validation_failed
          render_fc07_error('invalid_payload', result.errors, :unprocessable_content)
        when :business_rule_violation
          render_fc07_error('business_rule_violation', result.errors, :unprocessable_content)
        when :duplicate_entry
          render_fc07_error('duplicate_entry', result.errors, :conflict)
        when :not_found
          render_fc07_error('not_found', result.errors, :not_found)
        when :forbidden
          render_fc07_error('forbidden', result.errors, :forbidden)
        when :conflict
          render_fc07_error('conflict', result.errors, :conflict)
        else
          render_fc07_error('internal_error', 'An unexpected error occurred', :internal_server_error)
        end
      end

      # Legacy methods kept for compatibility with concerns
      def handle_resource_not_found(_resource, resource_name)
        render_fc07_error('not_found', "#{resource_name} not found", :not_found)
      end

      def handle_forbidden(message)
        render_fc07_error('forbidden', message, :forbidden)
      end

      def handle_conflict(message)
        render_fc07_error('conflict', message, :conflict)
      end

      def parse_date_param(date_param)
        return nil if date_param.blank?

        Date.parse(date_param.to_s)
      rescue ArgumentError
        nil
      end

      def safe_decimal_param(param_name, default = nil)
        value = params[param_name]
        return default if value.blank?

        value.to_d
      rescue ArgumentError
        default
      end

      def safe_integer_param(param_name, default = nil)
        value = params[param_name]
        return default if value.blank?

        value.to_i
      rescue ArgumentError
        default
      end
    end
  end
end
