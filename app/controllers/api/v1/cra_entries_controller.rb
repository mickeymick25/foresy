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
        result = CraEntryServices::Create.call(
          cra: @cra,
          attributes: cra_entry_attributes,
          current_user: current_user
        )

        if result.success?
          render json: Api::V1::CraEntries::ResponseFormatter.single(result.data[:cra_entry], @cra), status: :created
        else
          handle_service_error(result)
        end
      rescue StandardError => e
        Rails.logger.error "[CREATE] EXCEPTION: #{e.class}: #{e.message}"
        Rails.logger.error "[CREATE] BACKTRACE: #{e.backtrace.first(3).join("\n")}"
        log_api_error(e, { action: 'create', cra_id: @cra&.id, user_id: current_user&.id })
        render json: { error: 'internal_error', message: e.message }, status: :internal_server_error
      end

      # GET /api/v1/cras/:cra_id/entries
      # Lists CRA entries with optimized queries and pagination
      def index
        result = CraEntryServices::List.call(
          cra: @cra,
          current_user: current_user
        )

        if result.success?
          render json: Api::V1::CraEntries::ResponseFormatter.collection(result.data[:cra_entries], @cra), status: :ok
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
        render json: Api::V1::CraEntries::ResponseFormatter.single(@cra_entry, @cra), status: :ok
      rescue StandardError => e
        log_api_error(e, { action: 'show', cra_id: @cra&.id, cra_entry_id: @cra_entry&.id, user_id: current_user&.id })
        render_fc07_error('internal_error', 'An unexpected error occurred', :internal_server_error)
      end

      # PATCH /api/v1/cras/:cra_id/entries/:id
      # Updates a CRA entry with business rule validation
      def update
        result = CraEntryServices::Update.call(
          cra_entry: @cra_entry,
          attributes: cra_entry_attributes,
          current_user: current_user
        )

        if result.success?
          render json: Api::V1::CraEntries::ResponseFormatter.single(result.data[:cra_entry], @cra), status: :ok
        else
          handle_service_error(result)
        end
      rescue StandardError => e
        Rails.logger.error "[UPDATE] EXCEPTION: #{e.class}: #{e.message}"
        Rails.logger.error "[UPDATE] BACKTRACE: #{e.backtrace.first(3).join("\n")}"
        log_api_error(e,
                      { action: 'update', cra_id: @cra&.id, cra_entry_id: @cra_entry&.id, user_id: current_user&.id })
        render json: { error: 'internal_error', message: e.message }, status: :internal_server_error
      end

      # DELETE /api/v1/cras/:cra_id/entries/:id
      # Deletes a CRA entry (soft delete) with business rules
      def destroy
        result = CraEntryServices::Destroy.call(
          cra_entry: @cra_entry,
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
        attributes = {
          date: parse_date_param(params[:date]),
          quantity: safe_decimal_param(:quantity),
          description: params[:description]&.strip&.presence
        }

        # Only include unit_price if explicitly provided (allows partial updates)
        if params[:unit_price].present?
          attributes[:unit_price] = safe_integer_param(:unit_price, 0)
        end

        attributes.compact
      end

      # Extract mission_id from request
      def mission_id
        params[:mission_id].present? ? params[:mission_id].to_i : nil
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
        }, status: :unprocessable_entity
      end

      def handle_invalid_transition_error(error)
        Rails.logger.warn "CRA Entry InvalidTransitionError: #{error.message}"
        render_fc07_error('invalid_transition', error.message, :unprocessable_entity)
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
        case result.error
        # Existing handlers
        when :validation_failed
          render_fc07_error('invalid_payload', result.message, :unprocessable_entity)
        when :business_rule_violation
          render_fc07_error('business_rule_violation', result.message, :unprocessable_entity)
        when :duplicate_entry
          render_fc07_error('duplicate_entry', result.message, :conflict)
        when :not_found
          render_fc07_error('not_found', result.message, :not_found)
        when :forbidden, :insufficient_permissions
          render_fc07_error('forbidden', result.message, :forbidden)
        when :conflict, :invalid_cra_state
          render_fc07_error('conflict', result.message, :conflict)
        # Input validation errors (400 Bad Request)
        # Validation errors - 422 Unprocessable Entity
        when :missing_cra, :missing_attributes, :missing_user, :missing_cra_entry
          render_fc07_error('invalid_payload', result.message, :unprocessable_entity)
        when :invalid_date, :future_date_not_allowed
          render_fc07_error('invalid_payload', result.message, :unprocessable_entity)
        when :invalid_quantity
          render_fc07_error('invalid_payload', result.message, :unprocessable_entity)
        when :invalid_unit_price
          render_fc07_error('invalid_payload', result.message, :unprocessable_entity)
        when :description_too_long
          render_fc07_error('invalid_payload', result.message, :unprocessable_entity)
        # Relation errors (422 Unprocessable Entity)
        when :relation_creation_failed
          render_fc07_error('relation_error', result.message, :unprocessable_entity)
        # Server errors (500)
        when :create_failed, :update_failed, :destroy_failed
          render_fc07_error('internal_error', result.message, :internal_server_error)
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
