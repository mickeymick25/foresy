# frozen_string_literal: true

module Api
  module V1
    module Cras
      module ParameterExtractor
        extend ActiveSupport::Concern
        include Common::ParameterExtractor

        private

        def extract_cra_params
          {
            month: safe_integer_param(:month, 1..12),
            year: safe_integer_param(:year, 2000..2100),
            currency: params[:currency] || 'EUR',
            status: extract_cra_status_param,
            description: params[:description]&.strip&.presence
          }
        end

        def extract_cra_entry_params
          {
            date: parse_date_param(params[:date]),
            quantity: safe_decimal_param(:quantity),
            unit_price: safe_integer_param(:unit_price, 0),
            description: params[:description]&.strip&.presence
          }
        end

        def extract_cra_status_param
          status = params[:status]
          return nil unless status.present?

          status.to_sym if status.to_sym.in?(%i[draft submitted locked])
        end

        def extract_cra_lifecycle_params
          {
            target_status: extract_target_status_param,
            force: params[:force] == 'true'
          }
        end

        def extract_target_status_param
          target_status = params[:target_status]
          return nil unless target_status.present?

          target_status.to_sym if target_status.to_sym.in?(%i[submitted locked])
        end

        def extract_cra_search_params
          {
            month: safe_integer_param(:month, 1..12),
            year: safe_integer_param(:year, 2000..2100),
            status: extract_cra_status_param,
            currency: params[:currency],
            created_from: parse_date_param(params[:created_from]),
            created_to: parse_date_param(params[:created_to]),
            has_entries: params[:has_entries] == 'true'
          }.compact
        end

        def validate_cra_id_param!
          cra_id = params[:id]
          raise ActionController::ParameterMissing, 'id' if cra_id.blank?

          cra_id
        end

        def validate_cra_entry_id_param!
          entry_id = params[:entry_id]
          raise ActionController::ParameterMissing, 'entry_id' if entry_id.blank?

          entry_id
        end

        def validate_mission_id_param!
          mission_id = params[:mission_id]
          raise ActionController::ParameterMissing, 'mission_id' if mission_id.blank?

          mission_id
        end

        def safe_integer_param(param_name, range = nil)
          value = params[param_name]&.to_i
          return nil if value.nil? || value.zero?

          return nil if range && !value.between?(range.begin, range.end)

          value
        end

        def safe_decimal_param(param_name)
          value = params[param_name]&.to_f
          return nil if value.nil? || value <= 0

          value
        end

        def parse_date_param(date_param)
          return nil if date_param.blank?

          Date.parse(date_param)
        rescue ArgumentError
          nil
        end

        def validate_required_cra_params(required_params)
          missing_params = required_params.select { |param| params[param].blank? }

          if missing_params.any?
            Rails.logger.warn "Missing required CRA parameters: #{missing_params.join(', ')}"
            raise ActionController::ParameterMissing, missing_params.first.to_s
          end
        end

        def validate_cra_date_range!(start_date, end_date)
          raise ArgumentError, 'Both start_date and end_date are required' unless start_date && end_date

          raise ArgumentError, 'start_date must be before or equal to end_date' unless start_date <= end_date
        end

        def extract_sort_params(default_field = :created_at, default_direction = :desc)
          {
            field: params[:sort]&.to_sym || default_field,
            direction: params[:direction]&.to_sym&.in?(%i[asc desc]) ? params[:direction].to_sym : default_direction
          }
        end

        def extract_pagination_params
          {
            page: [params[:page].to_i, 1].max,
            per_page: params[:per_page].to_i.clamp(1, 100)
          }
        end

        def extract_client_identifier
          # Enhanced version for CRA-specific rate limiting
          api_key ||
            request.headers['X-User-ID'] ||
            request.headers['X-Client-Id'] ||
            client_ip ||
            'anonymous'
        end

        def api_key
          request.headers['X-API-Key'] || request.headers['Authorization']&.sub(/^Bearer /, '')
        end

        def client_ip
          request.remote_ip ||
            request.headers['X-Forwarded-For']&.split(',')&.first&.strip ||
            request.headers['X-Real-IP'] ||
            '0.0.0.0'
        end
      end
    end
  end
end
