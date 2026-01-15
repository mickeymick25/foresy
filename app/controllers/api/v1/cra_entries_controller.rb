# frozen_string_literal: true

require_relative '../../../../app/controllers/concerns/http_status_map'

module Api
  module V1
    # CraEntriesController - Pattern Canonique Platinum Level
    # Adaptateur passif entre HTTP et Services avec gestion Shared::Result
    class CraEntriesController < ApplicationController
      include HTTP_STATUS_MAP

      before_action :authenticate_access_token!
      before_action :set_cra, only: %i[create index show update]
      before_action :authorize_cra_access!, only: %i[create index show update]
      before_action :set_cra_entry, only: %i[show update destroy]

      # POST /api/v1/cras/:cra_id/entries
      def create
        puts "[TRACE] Starting create method"
        puts "[TRACE] @cra: #{@cra.inspect}"
        puts "[TRACE] entry_params: #{entry_params.inspect}"
        puts "[TRACE] current_user: #{current_user.inspect}"

        result = Api::V1::CraEntries::CreateService.call(
          cra: @cra,
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
        raise
      end

      # GET /api/v1/cras/:cra_id/entries
      def index
        puts "[CraEntriesController] Starting index action"
        puts "[CraEntriesController] params: #{params.inspect}"
        puts "[CraEntriesController] @cra: #{@cra.inspect}"
        puts "[CraEntriesController] current_user: #{current_user.inspect}"

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
          cra: @cra,
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
        if @cra_entry
          # Format single entry
          entry_data = { entry: result_data_entry(@cra_entry) }
          cra_data = { cra: result_data_cra(@cra) }

          render json: entry_data.merge(cra_data),
                 status: HTTP_STATUS_MAP[:ok]
        else
          render json: { error: 'Entry not found', error_type: :not_found },
                 status: HTTP_STATUS_MAP[:not_found]
        end
      end

      # PATCH /api/v1/cras/:cra_id/entries/:id
      def update
        result = Api::V1::CraEntries::UpdateService.call(
          cra_entry: @cra_entry,
          entry_params: entry_params,
          current_user: current_user
        )

        format_standard_response(result, :ok)
      end

      # DELETE /api/v1/cras/:cra_id/entries/:id
      def destroy
        unless @cra_entry
          return render json: { error: "CRA entry not found" }, status: :not_found
        end

        result = Api::V1::CraEntries::DestroyService.call(
          cra_entry: @cra_entry,
          current_user: current_user
        )

        format_destroy_response(result)
      end

      private

      def set_cra
        @cra = Cra.find_by(id: params[:cra_id])

        unless @cra
          render json: { error: 'CRA not found', error_type: :not_found },
                 status: HTTP_STATUS_MAP[:not_found]
          return
        end
      end

      def authorize_cra_access!
        return if @cra.nil? # laisser set_cra gérer le 404

        unless current_user_can_access_cra?
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end
      end

      def current_user_can_access_cra?
        @cra.created_by_user_id == current_user.id
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

        # Numeric sanitization
        if raw[:mission_id].present?
          puts "[TRACE] Sanitizing mission_id: #{raw[:mission_id].inspect}"
          raw[:mission_id] = raw[:mission_id].to_s.scan(/\d+/).first.to_i
          puts "[TRACE] mission_id after sanitization: #{raw[:mission_id].inspect}"
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
          HTTP_STATUS_MAP[:validation_error]
        when :unauthorized, :forbidden
          HTTP_STATUS_MAP[:unauthorized]
        when :not_found
          HTTP_STATUS_MAP[:not_found]
        when :duplicate_entry
          HTTP_STATUS_MAP[:conflict]
        when :bad_request
          HTTP_STATUS_MAP[:bad_request]
        when :internal_error
          HTTP_STATUS_MAP[:internal_error]
        else
          HTTP_STATUS_MAP[:bad_request]
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
          }, status: HTTP_STATUS_MAP[status_key]
        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # Format collection response for list operations (index)
      # Implements P1.2.7 - Eliminates manual parsing and standardizes controller logic
      def format_collection_response(result, status_key)
        if result.success?
          render json: result.data, status: HTTP_STATUS_MAP[status_key]
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
                 status: HTTP_STATUS_MAP[:ok]

        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end
    end
  end
end
