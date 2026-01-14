# frozen_string_literal: true

require_relative '../../../../app/controllers/concerns/http_status_map'

module Api
  module V1
    # CrasController - Pattern Canonique Platinum Level
    # Adaptateur passif entre HTTP et Services avec gestion Shared::Result
    class CrasController < ApplicationController
      include HTTP_STATUS_MAP

      before_action :authenticate_access_token!
      before_action :set_cra, only: %i[show update destroy submit lock export]

      # POST /api/v1/cras
      def create
        result = Api::V1::Cras::CreateService.call(
          cra_params: cra_params,
          current_user: current_user
        )

        if result.success?
          render json: result.data,
                 status: HTTP_STATUS_MAP[:created]
        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # GET /api/v1/cras
      def index
        result = Api::V1::Cras::ListService.call(
          current_user: current_user,
          page: params[:page],
          per_page: params[:per_page]&.to_i || 20,
          filters: extract_filters
        )

        if result.success?
          render json: result.data,
                 status: HTTP_STATUS_MAP[:ok]
        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # GET /api/v1/cras/:id
      def show
        if @cra
          render json: {
            cra: cra_data(@cra)
          },
                 status: HTTP_STATUS_MAP[:ok]
        else
          render json: { error: 'CRA not found', error_type: :not_found },
                 status: HTTP_STATUS_MAP[:not_found]
        end
      end

      # PATCH /api/v1/cras/:id
      def update
        result = Api::V1::Cras::UpdateService.call(
          cra: @cra,
          cra_params: cra_params,
          current_user: current_user
        )

        if result.success?
          render json: result.data,
                 status: HTTP_STATUS_MAP[:ok]
        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # DELETE /api/v1/cras/:id
      def destroy
        result = Api::V1::Cras::DestroyService.call(
          cra: @cra,
          current_user: current_user
        )

        if result.success?
          render json: {
            message: 'CRA archived successfully',
            deleted_cra: cra_data(@cra)
          },
                 status: HTTP_STATUS_MAP[:ok]
        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # POST /api/v1/cras/:id/submit
      def submit
        result = Api::V1::Cras::LifecycleService.submit!(
          cra: @cra,
          current_user: current_user
        )

        if result.success?
          render json: result.data,
                 status: HTTP_STATUS_MAP[:ok]
        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # POST /api/v1/cras/:id/lock
      def lock
        result = Api::V1::Cras::LifecycleService.lock!(
          cra: @cra,
          current_user: current_user
        )

        if result.success?
          render json: result.data,
                 status: HTTP_STATUS_MAP[:ok]
        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      # GET /api/v1/cras/:id/export
      def export
        result = Api::V1::Cras::ExportService.new(
          cra: @cra,
          format: params[:format] || 'csv',
          options: export_options
        ).call

        if result.success?
          send_data result.data[:content],
                    filename: result.data[:filename],
                    type: result.data[:content_type],
                    disposition: 'attachment'
        else
          render json: { error: result.error, error_type: result.error },
                 status: map_error_type_to_http_status(result.error)
        end
      end

      private

      def set_cra
        @cra = Cra.find_by(id: params[:id])
      end

      # Strong parameters
      def cra_params
        params.permit(:month, :year, :currency, :description, :status)
      end

      # Extraction des filtres
      def extract_filters
        {
          status: params[:status],
          month: params[:month]&.to_i,
          year: params[:year]&.to_i,
          company_id: params[:company_id]
        }.compact
      end

      # Options pour l'export
      def export_options
        {
          include_entries: params[:include_entries] != 'false'
        }
      end

      # Map Shared::Result error_type to HTTP status
      def map_error_type_to_http_status(error_type)
        case error_type
        when :invalid_month, :invalid_year, :missing_parameters
          HTTP_STATUS_MAP[:unprocessable_entity]
        when :insufficient_permissions
          HTTP_STATUS_MAP[:forbidden]
        when :cra_already_exists
          HTTP_STATUS_MAP[:conflict]
        when :invalid_currency, :description_too_long
          HTTP_STATUS_MAP[:unprocessable_entity]
        when :internal_error
          HTTP_STATUS_MAP[:internal_error]
        else
          HTTP_STATUS_MAP[:invalid_payload]
        end
      end

      # Extract CRA data for show action
      def cra_data(cra)
        {
          id: cra.id,
          month: cra.month,
          year: cra.year,
          description: cra.description,
          currency: cra.currency,
          status: cra.status,
          total_days: cra.total_days,
          total_amount: cra.total_amount,
          created_at: cra.created_at,
          updated_at: cra.updated_at
        }
      end
    end
  end
end
