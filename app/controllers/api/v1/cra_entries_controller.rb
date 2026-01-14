# frozen_string_literal: true

require_relative '../../../../app/controllers/concerns/http_status_map'

module Api
  module V1
    # CraEntriesController - Pattern Canonique Platinum Level
    # Adaptateur passif entre HTTP et Services avec gestion Shared::Result
    class CraEntriesController < ApplicationController
      include HTTP_STATUS_MAP

      before_action :authenticate_access_token!
      before_action :authorize_cra_access!, only: %i[create index show update]
      before_action :set_cra, only: %i[create index show update]
      before_action :set_cra_entry, only: %i[show update destroy]

      # POST /api/v1/cras/:cra_id/entries
      def create
        result = Api::V1::CraEntries::CreateService.call(
          cra: @cra,
          entry_params: entry_params,
          current_user: current_user
        )

        Rails.logger.error("[CRA][CREATE] Result inspect: #{result.inspect}") if result.nil?
        Rails.logger.error("[CRA][CREATE] Result class: #{result.class}") if result.present?
        Rails.logger.error("[CRA][CREATE] Result success?: #{result.respond_to?(:success?) ? result.success? : 'N/A'}")
        Rails.logger.error("[CRA][CREATE] Result data: #{result.respond_to?(:data) ? result.data.inspect : 'N/A'}")

        format_standard_response(result, :created)
      rescue => e
        Rails.logger.fatal("[CRA][CREATE][UNCAUGHT] #{e.class}: #{e.message}")
        Rails.logger.fatal("[CRA][CREATE][UNCAUGHT] #{e.backtrace.join("\n")}")
        raise
      end

      # GET /api/v1/cras/:cra_id/entries
      def index
        result = Api::V1::CraEntries::ListService.call(
          cra: @cra,
          current_user: current_user,
          page: params[:page],
          per_page: params[:per_page]&.to_i || 20
        )

        format_collection_response(result, :ok)
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
        result = Api::V1::CraEntries::DestroyService.call(
          cra_entry: @cra_entry,
          current_user: current_user
        )

        format_destroy_response(result)
      end

      private

      def set_cra
        @cra = Cra.find_by(id: params[:cra_id])
        render json: { error: 'CRA not found', error_type: :not_found },
               status: HTTP_STATUS_MAP[:not_found] unless @cra
      end

      # Authorization guard - DEBUG VERSION: Always returns 403 to test if method is called
      def authorize_cra_access!
        Rails.logger.info("[DEBUG] authorize_cra_access! CALLED for CRA ID: #{params[:cra_id]}")
        Rails.logger.info("[DEBUG] Current user ID: #{current_user.id}")

        # ALWAYS return 403 for debugging - ignore all other logic
        Rails.logger.info("[DEBUG] ALWAYS returning 403 for debugging")
        render json: { error: "DEBUG: Always forbidden" }, status: :forbidden
      end

      def set_cra_entry
        return unless @cra

        puts "[CraEntriesController] Looking for CRA Entry with ID: #{params[:id]}"
        puts "[CraEntriesController] CRA ID: #{@cra.id}"
        puts "[CraEntriesController] Available CRA Entries count: #{@cra.cra_entries.count}"

        # Try direct association access instead of find_by
        # Try direct query instead of through association
        @cra_entry = CraEntry.joins(:cra_entry_cras)
                            .where(cra_entry_cras: { cra_id: @cra.id })
                            .where(id: params[:id])
                            .first

        puts "[CraEntriesController] Found CRA Entry: #{@cra_entry.inspect}"

        unless @cra_entry
          puts "[CraEntriesController] CRA Entry not found - Available IDs: #{@cra.cra_entries.pluck(:id).inspect}"
        end
      end

      # Strong parameters
      def entry_params
        params.permit(:date, :quantity, :unit_price, :description, :mission_id)
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
        if result.success?
          render json: {
            message: 'CRA entry deleted successfully',
            deleted_entry: result_data_entry(@cra_entry)
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
