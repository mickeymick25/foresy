# frozen_string_literal: true

module Api
  module V1
    module Missions
      # Parameter extraction concern for mission-related operations
      # Provides centralized parameter extraction and validation functionality
      module ParameterExtractor
        extend ActiveSupport::Concern

        private

        # Extract mission creation parameters with validation
        # @param params [ActionController::Parameters] Raw parameters
        # @return [Hash] Validated mission creation parameters
        # @raise [ActionController::ParameterMissing] if required parameters are missing
        #
        # @example
        #   mission_params = extract_mission_creation_params(params)
        def extract_mission_creation_params(params)
          required_params = [:name, :mission_type, :status]
          missing_params = required_params.select { |param| params[param].blank? }

          if missing_params.any?
            raise ActionController::ParameterMissing, "Missing required parameters: #{missing_params.join(', ')}"
          end

          {
            name: sanitize_string(params[:name]),
            description: sanitize_string(params[:description]),
            mission_type: validate_mission_type(params[:mission_type]),
            status: validate_mission_status(params[:status]),
            start_date: parse_date(params[:start_date]),
            end_date: parse_date(params[:end_date]),
            daily_rate: parse_integer(params[:daily_rate]),
            fixed_price: parse_integer(params[:fixed_price]),
            currency: validate_currency(params[:currency]),
            client_company_id: parse_integer(params[:client_company_id])
          }.compact
        end

        # Extract mission update parameters with validation
        # @param params [ActionController::Parameters] Raw parameters
        # @return [Hash] Validated mission update parameters
        # @raise [ActionController::ParameterMissing] if required parameters are missing
        #
        # @example
        #   mission_params = extract_mission_update_params(params)
        def extract_mission_update_params(params)
          # For updates, parameters are optional unless specified
          update_params = {}

          update_params[:name] = sanitize_string(params[:name]) if params[:name].present?
          update_params[:description] = sanitize_string(params[:description]) if params[:description].present?
          update_params[:mission_type] = validate_mission_type(params[:mission_type]) if params[:mission_type].present?
          update_params[:status] = validate_mission_status(params[:status]) if params[:status].present?
          update_params[:start_date] = parse_date(params[:start_date]) if params[:start_date].present?
          update_params[:end_date] = parse_date(params[:end_date]) if params[:end_date].present?
          update_params[:daily_rate] = parse_integer(params[:daily_rate]) if params[:daily_rate].present?
          update_params[:fixed_price] = parse_integer(params[:fixed_price]) if params[:fixed_price].present?
          update_params[:currency] = validate_currency(params[:currency]) if params[:currency].present?

          update_params
        end

        # Extract listing parameters with validation and defaults
        # @param params [ActionController::Parameters] Raw parameters
        # @return [Hash] Validated listing parameters
        #
        # @example
        #   list_params = extract_mission_list_params(params)
        def extract_mission_list_params(params)
          {
            page: parse_page(params[:page]),
            per_page: parse_per_page(params[:per_page]),
            status: validate_mission_status(params[:status]) if params[:status].present?,
            mission_type: validate_mission_type(params[:mission_type]) if params[:mission_type].present?,
            start_date_from: parse_date(params[:start_date_from]) if params[:start_date_from].present?,
            start_date_to: parse_date(params[:start_date_to]) if params[:start_date_to].present?,
            end_date_from: parse_date(params[:end_date_from]) if params[:end_date_from].present?,
            end_date_to: parse_date(params[:end_date_to]) if params[:end_date_to].present?,
            min_daily_rate: parse_integer(params[:min_daily_rate]) if params[:min_daily_rate].present?,
            max_daily_rate: parse_integer(params[:max_daily_rate]) if params[:max_daily_rate].present?,
            min_fixed_price: parse_integer(params[:min_fixed_price]) if params[:min_fixed_price].present?,
            max_fixed_price: parse_integer(params[:max_fixed_price]) if params[:max_fixed_price].present?,
            company_id: parse_integer(params[:company_id]) if params[:company_id].present?,
            name: sanitize_search_string(params[:name]) if params[:name].present?
          }.compact
        end

        # Extract export parameters with validation
        # @param params [ActionController::Parameters] Raw parameters
        # @return [Hash] Validated export parameters
        #
        # @example
        #   export_params = extract_mission_export_params(params)
        def extract_mission_export_params(params)
          {
            format: validate_export_format(params[:format] || 'csv'),
            include_associations: parse_boolean(params[:include_associations], default: true),
            filters: extract_mission_list_params(params)
          }
        end

        # Extract sorting parameters with validation
        # @param params [ActionController::Parameters] Raw parameters
        # @return [Hash] Validated sorting parameters
        #
        # @example
        #   sort_options = extract_mission_sort_options(params)
        def extract_mission_sort_options(params)
          {
            field: validate_sort_field(params[:sort_by] || params[:field] || 'created_at'),
            direction: validate_sort_direction(params[:direction] || params[:order] || 'desc')
          }
        end

        # Extract pagination parameters with validation and defaults
        # @param params [ActionController::Parameters] Raw parameters
        # @return [Hash] Validated pagination parameters
        #
        # @example
        #   pagination = extract_pagination_params(params)
        def extract_pagination_params(params)
          {
            page: parse_page(params[:page]),
            per_page: parse_per_page(params[:per_page]),
            offset: parse_offset(params[:offset])
          }
        end

        # Extract mission ID from parameters
        # @param params [ActionController::Parameters] Raw parameters
        # @return [Integer] Validated mission ID
        # @raise [ActionController::ParameterMissing] if mission_id is missing
        #
        # @example
        #   mission_id = extract_mission_id(params)
        def extract_mission_id(params)
          mission_id = params[:id] || params[:mission_id]

          unless mission_id.present?
            raise ActionController::ParameterMissing, 'Missing required parameter: id'
          end

          parsed_id = parse_integer(mission_id)

          unless parsed_id.present? && parsed_id.positive?
            raise ActionController::ParameterMissing, 'Invalid mission ID format'
          end

          parsed_id
        end

        # Extract client company ID from parameters (optional)
        # @param params [ActionController::Parameters] Raw parameters
        # @return [Integer, nil] Validated client company ID or nil
        #
        # @example
        #   client_company_id = extract_client_company_id(params)
        def extract_client_company_id(params)
          return nil if params[:client_company_id].blank?

          client_company_id = parse_integer(params[:client_company_id])

          return nil unless client_company_id.present? && client_company_id.positive?

          client_company_id
        end

        # Sanitize and validate mission name
        # @param name [String] Mission name
        # @return [String] Sanitized mission name
        # @raise [ArgumentError] if name is invalid
        def validate_mission_name(name)
          sanitized_name = sanitize_string(name)

          if sanitized_name.length < 3
            raise ArgumentError, 'Mission name must be at least 3 characters long'
          end

          if sanitized_name.length > 200
            raise ArgumentError, 'Mission name cannot exceed 200 characters'
          end

          sanitized_name
        end

        # Validate mission type
        # @param mission_type [String] Mission type
        # @return [String] Validated mission type
        # @raise [ArgumentError] if mission type is invalid
        def validate_mission_type(mission_type)
          valid_types = %w[time_based fixed_price]

          unless valid_types.include?(mission_type.to_s)
            raise ArgumentError, "Mission type must be one of: #{valid_types.join(', ')}"
          end

          mission_type.to_s
        end

        # Validate mission status
        # @param status [String] Mission status
        # @return [String] Validated mission status
        # @raise [ArgumentError] if status is invalid
        def validate_mission_status(status)
          valid_statuses = %w[draft lead active completed cancelled]

          unless valid_statuses.include?(status.to_s)
            raise ArgumentError, "Mission status must be one of: #{valid_statuses.join(', ')}"
          end

          status.to_s
        end

        # Validate currency code
        # @param currency [String] Currency code
        # @return [String] Validated currency code
        # @raise [ArgumentError] if currency is invalid
        def validate_currency(currency)
          default_currency = 'EUR'
          return default_currency if currency.blank?

          currency_code = currency.to_s.upcase

          unless currency_code.match?(/\A[A-Z]{3}\z/)
            raise ArgumentError, 'Currency must be a valid ISO 4217 code (e.g., EUR, USD, GBP)'
          end

          currency_code
        end

        # Validate export format
        # @param format [String] Export format
        # @return [String] Validated export format
        # @raise [ArgumentError] if format is invalid
        def validate_export_format(format)
          valid_formats = %w[csv json xlsx]

          unless valid_formats.include?(format.to_s)
            raise ArgumentError, "Export format must be one of: #{valid_formats.join(', ')}"
          end

          format.to_s
        end

        # Validate sort field
        # @param field [String] Sort field
        # @return [String] Validated sort field
        # @raise [ArgumentError] if field is invalid
        def validate_sort_field(field)
          valid_fields = %w[name mission_type status start_date end_date daily_rate fixed_price created_at updated_at]

          unless valid_fields.include?(field.to_s)
            raise ArgumentError, "Sort field must be one of: #{valid_fields.join(', ')}"
          end

          field.to_s
        end

        # Validate sort direction
        # @param direction [String] Sort direction
        # @return [String] Validated sort direction
        # @raise [ArgumentError] if direction is invalid
        def validate_sort_direction(direction)
          valid_directions = %w[asc desc]

          unless valid_directions.include?(direction.to_s.downcase)
            raise ArgumentError, "Sort direction must be one of: #{valid_directions.join(', ')}"
          end

          direction.to_s.downcase
        end

        # Sanitize string input
        # @param str [String] Input string
        # @return [String] Sanitized string
        def sanitize_string(str)
          return nil if str.blank?

          str.to_s.strip
        end

        # Sanitize search string (allows wildcards)
        # @param str [String] Search string
        # @return [String] Sanitized search string
        def sanitize_search_string(str)
          return nil if str.blank?

          # Allow alphanumeric, spaces, and basic punctuation for search
          str.to_s.strip.gsub(/[^a-zA-Z0-9\s\-_@.]/, '')
        end

        # Parse and validate date
        # @param date_param [String] Date string
        # @return [Date, nil] Parsed date or nil if invalid
        def parse_date(date_param)
          return nil if date_param.blank?

          Date.parse(date_param.to_s)
        rescue ArgumentError
          nil
        end

        # Parse and validate integer
        # @param int_param [String, Integer] Integer parameter
        # @return [Integer, nil] Parsed integer or nil if invalid
        def parse_integer(int_param)
          return nil if int_param.blank?

          int_param.to_i
        rescue ArgumentError
          nil
        end

        # Parse and validate page number
        # @param page_param [String, Integer] Page parameter
        # @return [Integer] Validated page number
        def parse_page(page_param)
          page = parse_integer(page_param) || 1
          page > 0 ? page : 1
        end

        # Parse and validate per_page
        # @param per_page_param [String, Integer] Per page parameter
        # @return [Integer] Validated per page value
        def parse_per_page(per_page_param)
          per_page = parse_integer(per_page_param) || 20

          # Cap per_page at reasonable maximum
          [per_page, 100].min
        end

        # Parse offset parameter
        # @param offset_param [String, Integer] Offset parameter
        # @return [Integer, nil] Parsed offset or nil if invalid
        def parse_offset(offset_param)
          offset = parse_integer(offset_param)
          offset && offset >= 0 ? offset : nil
        end

        # Parse boolean parameter
        # @param bool_param [String, Boolean] Boolean parameter
        # @param default [Boolean] Default value if nil
        # @return [Boolean] Parsed boolean
        def parse_boolean(bool_param, default: false)
          return default if bool_param.nil?

          case bool_param.to_s.downcase
          when 'true', '1', 'yes', 'on'
            true
          when 'false', '0', 'no', 'off'
            false
          else
            default
          end
        end
      end
    end
  end
end
