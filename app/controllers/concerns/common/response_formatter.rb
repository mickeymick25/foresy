# frozen_string_literal: true

module Common
  module ResponseFormatter
    extend ActiveSupport::Concern

    included do
      helper_method :format_response, :format_error_response
    end

    private

    def set_json_content_type
      response.headers['Content-Type'] = 'application/json; charset=utf-8'
    end

    def format_response(data, status = :ok, meta = nil)
      set_json_content_type

      response_data = {
        data: data
      }

      response_data[:meta] = meta if meta.present?

      render json: response_data, status: status
    end

    def format_error_response(error, status = :bad_request, details = nil)
      set_json_content_type

      error_data = {
        error: error,
        message: extract_error_message(error)
      }

      error_data[:details] = details if details.present?

      render json: error_data, status: status
    end

    def extract_error_message(error)
      case error
      when String
        error
      when Symbol
        I18n.t("errors.#{error}")
      when Hash
        error[:message] || error.to_s
      else
        error.to_s
      end
    end

    def success_response(message = nil, data = nil, meta = nil)
      response_data = {
        success: true,
        message: message
      }

      response_data[:data] = data if data.present?
      response_data[:meta] = meta if meta.present?

      format_response(response_data, :ok)
    end

    def error_response(message, status = :bad_request, error_code = nil)
      error_data = {
        success: false,
        error: error_code || 'error',
        message: message
      }

      format_response(error_data, status)
    end

    def not_found_response(resource = 'Resource')
      error_response("#{resource} not found", :not_found, 'not_found')
    end

    def unauthorized_response(message = 'Unauthorized')
      error_response(message, :unauthorized, 'unauthorized')
    end

    def forbidden_response(message = 'Forbidden')
      error_response(message, :forbidden, 'forbidden')
    end

    def validation_error_response(errors)
      format_error_response('validation_error', :unprocessable_content, errors)
    end

    def conflict_response(message = 'Conflict')
      error_response(message, :conflict, 'conflict')
    end

    def internal_error_response(message = 'Internal server error')
      error_response(message, :internal_server_error, 'internal_error')
    end

    # Pagination helpers
    def paginated_response(collection, serializer = nil)
      pagy, records = pagy(collection, items: extract_pagination_params[:per_page])

      data = if serializer
               ActiveModel::Serializer::CollectionSerializer.new(
                 records,
                 serializer: serializer
               ).as_json
             else
               records.as_json
             end

      meta = {
        total: pagy.count,
        page: pagy.page,
        per_page: pagy.per,
        pages: pagy.pages
      }

      format_response(data, :ok, meta)
    end

    def extract_pagination_params
      {
        page: [params[:page].to_i, 1].max,
        per_page: params[:per_page].to_i.clamp(1, 100)
      }
    end

    # CRA-specific formatters
    def format_cra(cra)
      {
        id: cra.id,
        month: cra.month,
        year: cra.year,
        status: cra.status,
        description: cra.description,
        total_days: cra.total_days,
        total_amount: cra.total_amount,
        currency: cra.currency,
        created_at: cra.created_at.iso8601,
        updated_at: cra.updated_at.iso8601,
        locked_at: cra.locked_at&.iso8601
      }
    end

    def format_cra_entry(entry)
      {
        id: entry.id,
        date: entry.date.iso8601,
        quantity: entry.quantity,
        unit_price: entry.unit_price,
        line_total: entry.line_total,
        description: entry.description,
        created_at: entry.created_at.iso8601,
        updated_at: entry.updated_at.iso8601
      }
    end

    def format_mission(mission)
      {
        id: mission.id,
        name: mission.name,
        description: mission.description,
        mission_type: mission.mission_type,
        status: mission.status,
        start_date: mission.start_date&.iso8601,
        daily_rate: mission.daily_rate,
        currency: mission.currency,
        created_at: mission.created_at.iso8601,
        updated_at: mission.updated_at.iso8601
      }
    end

    def format_company(company)
      {
        id: company.id,
        name: company.name,
        legal_form: company.legal_form,
        siren: company.siren,
        siret: company.siret,
        created_at: company.created_at.iso8601,
        updated_at: company.updated_at.iso8601
      }
    end

    def format_user(user)
      {
        id: user.id,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        created_at: user.created_at.iso8601,
        updated_at: user.updated_at.iso8601
      }
    end

    # Collection formatters
    def format_collection(collection, formatter_method)
      collection.map { |item| send(formatter_method, item) }
    end

    # Standard JSON API response format
    def json_api_response(data, status = :ok, meta = nil)
      set_json_content_type

      response_data = {
        data: data
      }

      response_data[:meta] = meta if meta.present?
      response_data[:jsonapi] = { version: '1.0' }

      render json: response_data, status: status
    end

    def json_api_error(error, status = :bad_request, meta = nil)
      set_json_content_type

      error_data = {
        errors: [{
          status: Rack::Utils.status_code(status).to_s,
          title: extract_error_message(error),
          detail: meta
        }.compact],
        jsonapi: { version: '1.0' }
      }

      render json: error_data, status: status
    end
  end
end
