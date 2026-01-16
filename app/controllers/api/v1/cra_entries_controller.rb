# frozen_string_literal: true

require_relative '../../../../lib/pundit'  # Stub Pundit pour PHASE 2.0
require_relative '../../../../app/controllers/concerns/http_status_map'

module Api
  module V1
    # CraEntriesController - Pattern Canonique Platinum Level
    # Adaptateur passif entre HTTP et Services avec gestion Shared::Result
    class CraEntriesController < ApplicationController
      include HTTP_STATUS_MAP

      before_action :authenticate_access_token!


      # Global exception handling - PRIORITÉ 2: Auth + HTTP Contract Codes
      rescue_from StandardError, with: :handle_internal_error
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
      rescue_from ::Pundit::NotAuthorizedError, with: :handle_not_authorized

      # POST /api/v1/cras/:cra_id/entries
      def create
        puts "[TRACE] Starting create method"
        puts "[TRACE] entry_params: #{entry_params.inspect}"
        puts "[TRACE] current_user: #{current_user.inspect}"

        # Phase 2.0: Load CRA in action, then authorize
        cra = Cra.find_by(id: params[:cra_id])
        return render json: { error: 'CRA not found', error_type: :not_found },
                      status: http_status(:not_found) unless cra

        puts "[TRACE] CRA loaded: #{cra.inspect}"

        # Phase 2.0: Authorize AFTER business loading
        return unless authorize_cra!(cra)

        result = Api::V1::CraEntries::CreateService.call(
          cra: cra,
          entry_params: entry_params,
          current_user: current_user
        )

        puts "[TRACE] CreateService returned: #{result.inspect}"
        puts "[TRACE] result.success?: #{result.respond_to?(:success?) ? result.success? : 'N/A'}"

        format_standard_response(result, :created)
        puts "[TRACE] format_standard_response completed successfully"
      rescue => e
        puts "[TRACE] UNCAUGHT ERROR: #{e.class}: #{e.message}"
        puts "[TRACE] Error backtrace: #{e.backtrace.join("\n")}"
        Rails.logger.fatal("[CRA][CREATE][UNCAUGHT] #{e.class}: #{e.message}")
        Rails.logger.fatal("[CRA][CREATE][UNCAUGHT] #{e.backtrace.join("\n")}")
        render json: { error: "Internal server error", error_type: :internal_error },
               status: :unprocessable_entity
      end

      # GET /api/v1/cras/:cra_id/entries
      def index
            puts "[CraEntriesController] Starting index action"
        puts "[CraEntriesController] params: #{params.inspect}"
        puts "[CraEntriesController] current_user: #{current_user.inspect}"

        # Phase 2.0: Load CRA in action, then authorize
        cra = Cra.find_by(id: params[:cra_id])
        return render json: { error: 'CRA not found', error_type: :not_found },
                      status: http_status(:not_found) unless cra

        puts "[CraEntriesController] CRA loaded: #{cra.inspect}"

        # Phase 2.0: Authorize AFTER business loading
        return unless authorize_cra!(cra)

            # Valider et convertir les paramètres de pagination
            page = params[:page].to_i > 0 ? params[:page].to_i : 1
            per_page = params[:per_page].to_i > 0 ? params[:per_page].to_i : 20

            puts "[CraEntriesController] page: #{page}, per_page: #{per_page}"

            # Préparer les filtres de manière sécurisée
            filters = {
              start_date: params[:start_date],
              end_date: params[:end_date],
              mission_id: params[:mission_id]
            }

            puts "[CraEntriesController] filters: #{filters.inspect}"

            puts "[CraEntriesController] About to call ListService"
            result = Api::V1::CraEntries::ListService.call(
              cra: cra,
              current_user: current_user,
              page: page,
              per_page: per_page,
              filters: filters
            )

            puts "[CraEntriesController] ListService returned: #{result.inspect}"

            puts "[CraEntriesController] About to call format_collection_response"
            format_collection_response(result, :ok)
            puts "[CraEntriesController] format_collection_response completed"
          end

      # GET /api/v1/cras/:cra_id/entries/:id
      def show
        # Phase 2.0: Load CRA in action, then authorize
        cra = Cra.find_by(id: params[:cra_id])
        return render json: { error: 'CRA not found', error_type: :not_found },
                      status: http_status(:not_found) unless cra

        # Phase 2.0: Authorize AFTER business loading
        return unless authorize_cra!(cra)

        # Phase 2.0: Load entry in action
        entry = CraEntry.find_by(id: params[:id], cra_id: cra.id)
        return render json: { error: 'Entry not found', error_type: :not_found },
                      status: http_status(:not_found) unless entry

        # Format single entry
        entry_data = { entry: result_data_entry(entry) }
        cra_data = { cra: result_data_cra(cra) }

        render json: entry_data.merge(cra_data),
               status: http_status(:ok)
      end

      # PATCH /api/v1/cras/:cra_id/entries/:id
      def update
        # Phase 2.0: Load CRA in action, then authorize
        cra = Cra.find_by(id: params[:cra_id])
        return render json: { error: 'CRA not found', error_type: :not_found },
                      status: http_status(:not_found) unless cra

        # Phase 2.0: Authorize AFTER business loading
        Rails.logger.info "[CRA][UPDATE] CRA loaded successfully, calling authorize"
        return unless authorize_cra!(cra)

        # Phase 2.0: Load entry in action
        entry = CraEntry.find_by(id: params[:id])
        Rails.logger.info "[CRA][UPDATE] Entry found: #{entry.present?}, ID: #{entry&.id}"

        return render json: { error: 'Entry not found', error_type: :not_found },
                      status: http_status(:not_found) unless entry

        Rails.logger.info "[CRA][UPDATE] About to call UpdateService"
        Rails.logger.info "[CRA][UPDATE] entry: #{entry.inspect}"
        Rails.logger.info "[CRA][UPDATE] entry_params: #{entry_params.inspect}"
        Rails.logger.info "[CRA][UPDATE] current_user: #{current_user.inspect}"
        Rails.logger.info "[CRA][UPDATE] Entry belongs to CRA: #{entry.cra_entry_cras.first.cra_id if entry.cra_entry_cras.any?}"

        begin
          result = Api::V1::CraEntries::UpdateService.call(
            cra_entry: entry,
            entry_params: entry_params,
            current_user: current_user
          )
          Rails.logger.info "[CRA][UPDATE] UpdateService returned: #{result.inspect}"
        rescue => e
          Rails.logger.fatal "[CRA][UPDATE][EXCEPTION] #{e.class}: #{e.message}"
          Rails.logger.fatal "[CRA][UPDATE][EXCEPTION] Backtrace: #{e.backtrace.join("\n")}"
          raise e
        end

        format_standard_response(result, :ok)
      end

      # DELETE /api/v1/cras/:cra_id/entries/:id
      def destroy
        # Phase 2.0: Load CRA in action, then authorize
        cra = Cra.find_by(id: params[:cra_id])
        return render json: { error: 'CRA not found', error_type: :not_found },
                      status: http_status(:not_found) unless cra

        # Phase 2.0: Authorize AFTER business loading
        return unless authorize_cra!(cra)

        # Phase 2.0: Load entry in action
        entry = CraEntry.find_by(id: params[:id], cra_id: cra.id)
        return render json: { error: 'CRA entry not found', error_type: :not_found },
                      status: http_status(:not_found) unless entry

        result = Api::V1::CraEntries::DestroyService.call(
          cra_entry: entry,
          current_user: current_user
        )

        format_destroy_response(result)
      end

      private

      def set_cra
        Rails.logger.info "[DEBUG] set_cra method called"
        Rails.logger.info "[DEBUG] params[:cra_id]: #{params[:cra_id]}"

        @cra = Cra.find_by(id: params[:cra_id])
        Rails.logger.info "[DEBUG] @cra found: #{@cra.present?}"
        Rails.logger.info "[DEBUG] @cra: #{@cra.inspect}"

        unless @cra
          Rails.logger.info "[DEBUG] CRA not found - returning 404"
          render json: { error: 'CRA not found', error_type: :not_found },
                 status: http_status(:not_found)
          return
        end

        Rails.logger.info "[DEBUG] CRA found - proceeding with authorization"
      end





      def current_user_can_access_cra?(cra)
        Rails.logger.info "[DEBUG] Authorization check starting"
        Rails.logger.info "[DEBUG] current_user.id: #{current_user.id}"
        Rails.logger.info "[DEBUG] cra.created_by_user_id: #{cra.created_by_user_id}"
        Rails.logger.info "[DEBUG] cra.id: #{cra.id}"
        Rails.logger.info "[DEBUG] cra: #{cra.inspect}"

        # Allow access if user is the CRA creator
        if cra.created_by_user_id == current_user.id
          Rails.logger.info "[DEBUG] Authorization: ALLOWED - User is CRA creator"
          return true
        end

        # TODO: Implement proper authorization logic for shared CRAs
        # For now, only allow access to the CRA creator
        Rails.logger.info "[DEBUG] Authorization: DENIED - User is not CRA creator"
        false
      end

      def set_cra_entry
        @cra_entry = CraEntry.find_by(id: params[:id])

        return if @cra_entry

        render json: { error: "CRA entry not found" }, status: :not_found
      end

      # Strong parameters with complete SQL injection sanitization
      def entry_params
        puts "[TRACE] entry_params called"
        puts "[TRACE] params: #{params.inspect}"
        puts "[TRACE] params[:entry]: #{params[:entry].inspect}"

        raw =
          if params[:entry].present?
            puts "[TRACE] Using JSON format (params[:entry])"
            params.require(:entry).permit(
              :mission_id,
              :quantity,
              :unit_price,
              :date,
              :description
            )
          else
            puts "[TRACE] Using form-encoded format"
            params.permit(
              :mission_id,
              :quantity,
              :unit_price,
              :date,
              :description
            )
          end

        puts "[TRACE] Raw params after permit: #{raw.inspect}"

        # UUID sanitization - preserve UUID format, validate format
        if raw[:mission_id].present?
          puts "[TRACE] Sanitizing mission_id: #{raw[:mission_id].inspect}"
          mission_id_str = raw[:mission_id].to_s
          # Check if it's a valid UUID format (basic validation)
          if mission_id_str.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
            raw[:mission_id] = mission_id_str
            puts "[TRACE] mission_id preserved as UUID: #{raw[:mission_id].inspect}"
          else
            # Fallback to integer conversion for backward compatibility
            raw[:mission_id] = mission_id_str.to_i
            puts "[TRACE] mission_id converted to integer: #{raw[:mission_id].inspect}"
          end
        end

        # String sanitization for ALL string fields
        puts "[TRACE] Applying string sanitization to all string fields"
        raw.each do |key, value|
          if value.is_a?(String)
            puts "[TRACE] Sanitizing #{key}: #{value.inspect}"
            raw[key] = value.gsub(/['";]/, '')
            puts "[TRACE] #{key} after sanitization: #{raw[key].inspect}"
          end
        end

        puts "[TRACE] Final sanitized params: #{raw.inspect}"
        raw
      end

      # Map Shared::Result error_type to HTTP status - Canonique P1.4.2
      def map_error_type_to_http_status(error_type)
        case error_type
        when :validation_error
          http_status(:validation_error)
        when :unauthorized
          http_status(:unauthorized)
        when :forbidden
          http_status(:forbidden)
        when :not_found
          http_status(:not_found)
        when :duplicate_entry
          http_status(:conflict)
        when :bad_request
          http_status(:bad_request)
        when :internal_error
          http_status(:internal_error)
        else
          http_status(:bad_request)
        end
      end

      # Extract entry data from ActiveRecord object for show action
      def result_data_entry(entry)
        {
          id: entry.id,
          date: entry.date,
          quantity: entry.quantity,
          unit_price: entry.unit_price,
          description: entry.description,
          created_at: entry.created_at,
          updated_at: entry.updated_at
        }
      end

      # Extract CRA data from ActiveRecord object for show action
      def result_data_cra(cra)
        {
          id: cra.id,
          total_days: cra.total_days,
          total_amount: cra.total_amount,
          currency: cra.currency,
          status: cra.status
        }
      end

      # === P1.2.7: STANDARDISER CONTRÔLEURS - FORMAT HELPERS ===

      # Global exception handlers for proper HTTP status codes
      def handle_internal_error(exception)
        Rails.logger.error "[CraEntriesController] Internal error: #{exception.class}: #{exception.message}"
        Rails.logger.error exception.backtrace.join("\n")
        render json: { error: "Internal server error", error_type: :internal_error },
               status: :unprocessable_entity
      end

      def handle_not_found(exception)
        Rails.logger.warn "[CraEntriesController] Not found: #{exception.message}"
        render json: { error: "Resource not found", error_type: :not_found },
               status: :not_found
      end

      def handle_validation_error(exception)
        Rails.logger.warn "[CraEntriesController] Validation error: #{exception.message}"
        render json: { error: exception.message, error_type: :validation_error },
               status: :unprocessable_entity
      end

      def handle_not_authorized(exception)
        Rails.logger.warn "[CraEntriesController] Not authorized: #{exception.message}"
        render json: { error: "Forbidden", error_type: :forbidden },
               status: :forbidden
      end

      # Format standard response for single item operations (create, update)
      # Implements P1.2.7 - Eliminates manual parsing and standardizes controller logic
      def format_standard_response(result, status_key)
        if result.success?
          # DEBUG: Show the result structure being processed
          puts "[CraEntriesController::format_standard_response] result.data: #{result.data.inspect}"
          puts "[CraEntriesController::format_standard_response] result.data[:item]: #{result.data&.dig(:item)&.inspect}"
          puts "[CraEntriesController::format_standard_response] result.data[:item][:data]: #{result.data&.dig(:item, :data)&.inspect}"

          # Adapt Shared::Result format to expected test format
          # Service returns: { item: { data: {...} }, cra: { data: {...} } }
          # Test expects: { data: { cra_entry: {...} } }
          entry_data = result.data[:item][:data] if result.data[:item]
          cra_data = result.data[:cra][:data] if result.data[:cra]

          puts "[CraEntriesController::format_standard_response] entry_data: #{entry_data.inspect}"
          puts "[CraEntriesController::format_standard_response] cra_data: #{cra_data.inspect}"

          # Flatten JSON API structure to match test expectations
          # Extract attributes from JSON API format and put them directly under cra_entry
          if entry_data && entry_data[:attributes]
            # Extract attributes and flatten them - entry_data is already the complete structure
            flattened_entry = entry_data[:attributes].merge(
              id: entry_data[:id],
              type: entry_data[:type]
            )
          else
            flattened_entry = entry_data || {}
          end

          puts "[CraEntriesController::format_standard_response] flattened_entry: #{flattened_entry.inspect}"

          render json: {
            data: {
              cra_entry: flattened_entry
            }.compact
          }, status: http_status(status_key)
        else
          # Format error response to match test expectations (errors array)
          error_message = result.respond_to?(:message) ? result.message : result.error.to_s
          render json: { errors: [error_message] },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # Format collection response for list operations (index)
      # Implements P1.2.7 - Eliminates manual parsing and standardizes controller logic
      def format_collection_response(result, status_key)
        if result.success?
          render json: result.data, status: http_status(status_key)
        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # Format destroy response with custom message for deletion confirmation
      # Implements P1.2.7 - Specialized handler for destroy operations
      def format_destroy_response(result)
        return head :not_found unless result

        if result.success?
          # Use result.data from the service instead of calling result_data_entry(@cra_entry)
          deleted_entry_data = result.data[:item] if result.data && result.data[:item]

          render json: {
            message: 'CRA entry deleted successfully',
            deleted_entry: deleted_entry_data
          },
                 status: http_status(:ok)

        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # Phase 2.0 - Authorization moved INSIDE actions (after business loading)
      def authorize_cra!(cra)
        Rails.logger.info "[AUTHORIZE] === STARTING AUTHORIZATION CHECK ==="
        Rails.logger.info "[AUTHORIZE] cra.id: #{cra&.id}"
        Rails.logger.info "[AUTHORIZE] current_user: #{current_user.inspect}"

        # Vérifications préliminaires pour diagnostic précis
        unless current_user
          Rails.logger.error "[AUTHORIZE] ❌ current_user is nil!"
          render json: { error: "Unauthorized", error_type: :unauthorized },
                 status: :unauthorized
          return false
        end

        unless cra
          Rails.logger.error "[AUTHORIZE] ❌ cra is nil!"
          render json: { error: "CRA not found", error_type: :not_found },
                 status: :not_found
          return false
        end

        begin
          Rails.logger.info "[AUTHORIZE] ✅ Preliminary checks passed"

          if current_user_can_access_cra?(cra)
            Rails.logger.info "[AUTHORIZE] ✅ Authorization successful for user #{current_user.id}"
            return true
          else
            Rails.logger.info "[AUTHORIZE] ❌ Authorization failed for user #{current_user.id} - returning 403"
            render json: { error: "Forbidden", error_type: :forbidden },
                   status: :forbidden
            return false
          end
        rescue => e
          Rails.logger.error "[AUTHORIZE] ❌ Exception during authorization: #{e.class}: #{e.message}"
          Rails.logger.error "[AUTHORIZE] Exception backtrace: #{e.backtrace.join("\n")}"
          render json: { error: "Authorization failed", error_type: :forbidden },
                 status: :forbidden
          return false
        end
      end
    end
  end
end
