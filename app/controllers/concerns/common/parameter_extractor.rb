# frozen_string_literal: true

module Common
  module ParameterExtractor
    extend ActiveSupport::Concern

    private

    def extract_pagination_params
      {
        page: [params[:page].to_i, 1].max,
        per_page: params[:per_page].to_i.clamp(1, 100)
      }
    end

    def extract_sort_params(default_field = :id, default_direction = :desc)
      {
        field: params[:sort]&.to_sym || default_field,
        direction: params[:direction]&.to_sym&.in?(%i[asc desc]) ? params[:direction].to_sym : default_direction
      }
    end

    def extract_date_range_params
      start_date = parse_date_param(params[:start_date]) if params[:start_date].present?
      end_date = parse_date_param(params[:end_date]) if params[:end_date].present?

      {
        start_date: start_date,
        end_date: end_date,
        range_valid?: start_date.present? && end_date.present? && start_date <= end_date
      }
    end

    def parse_date_param(date_param)
      return nil if date_param.blank?

      Date.parse(date_param)
    rescue ArgumentError
      nil
    end

    def extract_search_params
      params[:search]&.strip&.presence
    end

    def extract_filter_params(allowed_filters = [])
      filters = {}

      allowed_filters.each do |filter|
        filters[filter] = params[filter] if params[filter].present?
      end

      filters
    end

    def extract_client_identifier
      # Extract client identifier for rate limiting
      request.headers['X-API-Key'] ||
        request.headers['X-Client-Id'] ||
        request.remote_ip ||
        'unknown'
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

    def extract_authentication_info
      {
        token: extract_bearer_token,
        api_key: api_key,
        client_identifier: extract_client_identifier,
        ip_address: client_ip
      }
    end

    def extract_bearer_token
      authorization_header = request.headers['Authorization']
      return nil unless authorization_header.present?

      if authorization_header.match(/^Bearer (.+)/)
        ::Regexp.last_match(1)
      else
        authorization_header
      end
    end

    def extract_cra_specific_params
      {
        month: safe_integer_param(:month, 1..12),
        year: safe_integer_param(:year, 2000..2100),
        currency: params[:currency] || 'EUR',
        status: extract_status_param
      }
    end

    def extract_cra_entry_specific_params
      {
        date: parse_date_param(params[:date]),
        quantity: safe_decimal_param(:quantity),
        unit_price: safe_integer_param(:unit_price, 0),
        description: params[:description]&.strip&.presence
      }
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

    def extract_status_param
      status = params[:status]
      return nil unless status.present?

      status.to_sym if status.to_sym.in?(%i[draft submitted locked])
    end

    def validate_required_params(required_params)
      missing_params = required_params.select { |param| params[param].blank? }

      raise ActionController::ParameterMissing, missing_params.first.to_s if missing_params.any?
    end

    def validate_date_range!(start_date, end_date)
      raise ArgumentError, 'Both start_date and end_date are required' unless start_date && end_date

      raise ArgumentError, 'start_date must be before or equal to end_date' unless start_date <= end_date
    end
  end
end
