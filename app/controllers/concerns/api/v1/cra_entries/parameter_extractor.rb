# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      module ParameterExtractor
        extend ActiveSupport::Concern
        include Common::ParameterExtractor

        private

        def extract_cra_entry_params
          {
            date: parse_date_param(params[:date]),
            quantity: safe_decimal_param(:quantity),
            unit_price: safe_integer_param(:unit_price, 0),
            description: params[:description]&.strip&.presence
          }
        end

        def extract_cra_entry_search_params
          {
            cra_id: params[:cra_id],
            mission_id: params[:mission_id],
            date_from: parse_date_param(params[:date_from]),
            date_to: parse_date_param(params[:date_to]),
            quantity_min: safe_decimal_param(:quantity_min),
            quantity_max: safe_decimal_param(:quantity_max),
            unit_price_min: safe_integer_param(:unit_price_min, 0),
            unit_price_max: safe_integer_param(:unit_price_max, 0),
            has_description: params[:has_description] == 'true'
          }.compact
        end

        def validate_cra_entry_id_param!
          entry_id = params[:id] || params[:entry_id]
          raise ActionController::ParameterMissing, 'entry_id' if entry_id.blank?

          entry_id
        end

        def validate_cra_id_param!
          cra_id = params[:cra_id]
          raise ActionController::ParameterMissing, 'cra_id' if cra_id.blank?

          cra_id
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

        def validate_required_cra_entry_params(required_params)
          missing_params = required_params.select { |param| params[param].blank? }

          if missing_params.any?
            Rails.logger.warn "Missing required CRA entry parameters: #{missing_params.join(', ')}"
            raise ActionController::ParameterMissing, missing_params.first.to_s
          end
        end

        def validate_cra_entry_date!(date)
          raise ArgumentError, 'Invalid date format' if date.nil?

          raise ArgumentError, 'Entry date cannot be in the future' if date > Date.current

          raise ArgumentError, 'Entry date too far in the past' if date < 10.years.ago.to_date
        end

        def validate_cra_entry_quantity!(quantity)
          raise ArgumentError, 'Quantity must be positive' if quantity.nil? || quantity <= 0

          Rails.logger.warn "Large CRA entry quantity: #{quantity} (possible error)" if quantity > 24
        end

        def validate_cra_entry_unit_price!(unit_price)
          raise ArgumentError, 'Unit price must be non-negative' if unit_price.nil? || unit_price.negative?

          Rails.logger.warn "High CRA entry unit price: #{unit_price} cents" if unit_price > 100_000 # 1000€ in cents
        end

        def extract_sort_params(default_field = :date, default_direction = :desc)
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
          # Enhanced version for CRA entry-specific rate limiting
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

        def validate_date_range!(start_date, end_date)
          raise ArgumentError, 'Both start_date and end_date are required' unless start_date && end_date

          raise ArgumentError, 'start_date must be before or equal to end_date' unless start_date <= end_date

          # Validate reasonable date range (max 1 year)
          raise ArgumentError, 'Date range cannot exceed 1 year' if (end_date - start_date) > 365
        end

        def validate_quantity_range!(min_quantity, max_quantity)
          return unless min_quantity && max_quantity

          raise ArgumentError, 'min_quantity cannot be greater than max_quantity' if min_quantity > max_quantity

          if min_quantity > 24 || max_quantity > 24
            Rails.logger.warn "Large quantity range: #{min_quantity}-#{max_quantity}"
          end
        end

        def validate_unit_price_range!(min_price, max_price)
          return unless min_price && max_price

          raise ArgumentError, 'min_unit_price cannot be greater than max_unit_price' if min_price > max_price

          if min_price > 100_000 || max_price > 100_000
            Rails.logger.warn "High unit price range: #{min_price}-#{max_price} cents"
          end
        end
      end
    end
  end
end
