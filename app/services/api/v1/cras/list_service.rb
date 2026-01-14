# frozen_string_literal: true

# app/services/api/v1/cras/list_service.rb
# Migration vers ApplicationResult - Étape 2 du plan de migration
# Contrat unique : tous les services retournent ApplicationResult
# Aucune exception métier levée - tout via Result.fail

require_relative '../../../../../lib/application_result'

module Api
  module V1
    module Cras
      # Service for listing CRAs with pagination and filtering
      # Uses ApplicationResult contract for consistent Service → Controller communication
      #
      # CONTRACT:
      # - Returns ApplicationResult exclusively
      # - No business exceptions raised
      # - No HTTP concerns in service
      # - Single source of truth for business rules
      #
      # @example
      #   result = ListService.call(
      #     current_user: user,
      #     page: 1,
      #     per_page: 20,
      #     filters: { status: 'draft' }
      #   )
      #   result.ok? # => true/false
      #   result.data # => { items: [...], meta: {...} }
      #
      class ListService
        def self.call(current_user:, page: nil, per_page: nil, filters: {})
          new(current_user: current_user, page: page, per_page: per_page, filters: filters).call
        end

        def initialize(current_user:, page: nil, per_page: nil, filters: {})
          @current_user = current_user
          @page = page
          @per_page = per_page
          @filters = filters || {}
        end

        def call
          # Input validation
          validation_result = validate_inputs
          return validation_result unless validation_result.nil?

          # Build query
          query_result = build_base_query
          return query_result unless query_result.nil?

          # Apply filters
          filtered_query = apply_filters(query_result)
          return filtered_query if filtered_query.is_a?(ApplicationResult)

          # Fetch CRAs
          fetch_result = fetch_cras(filtered_query)
          return fetch_result unless fetch_result.nil?

          # Success response
          Result.ok(
            data: {
              items: serialize_cras(fetch_result[:cras]),
              meta: fetch_result[:pagination]
            },
            status: :ok
          )
        # No rescue StandardError - let exceptions bubble up for debugging

        private

        attr_reader :current_user, :page, :per_page, :filters

        # === Validation ===

        def validate_inputs
          # Current user validation
          unless current_user.present?
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Current user is required"
            )
          end

          # Filters validation
          filter_validation_result = validate_filters
          return filter_validation_result unless filter_validation_result.nil?

          nil # All validations passed
        end

        def validate_filters
          # Status validation
          if filters[:status].present? && !valid_status?(filters[:status])
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Invalid status filter. Must be: draft, submitted, or locked"
            )
          end

          # Mini-FC-01: month requires year
          if filters[:month].present? && filters[:year].blank?
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Year is required when month is specified"
            )
          end

          # Month validation
          if filters[:month].present? && !valid_month?(filters[:month])
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Invalid month filter. Must be between 1 and 12"
            )
          end

          # Year validation
          if filters[:year].present? && !valid_year?(filters[:year])
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Invalid year filter. Must be 2000 or later"
            )
          end

          # Currency validation
          if filters[:currency].present? && !valid_currency?(filters[:currency])
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Invalid currency filter. Must be a valid ISO 4217 code"
            )
          end

          nil # All filter validations passed
        end

        # === Query Building ===

        def build_base_query
          Cra.accessible_to(current_user)
             .active
             .includes(
               cra_missions: { mission: :mission_companies },
               cra_entries: :cra_entry_missions
             )
             .order(year: :desc, month: :desc)
        end

        def apply_filters(query)
          # Status filter
          if filters[:status].present?
            query = query.where(status: filters[:status])
          end

          # Month filter
          if filters[:month].present?
            query = query.where(month: filters[:month])
          end

          # Year filter
          if filters[:year].present?
            query = query.where(year: filters[:year])
          end

          # Currency filter
          if filters[:currency].present?
            query = query.where(currency: filters[:currency])
          end

          # Description filter
          if filters[:description].present?
            query = query.where('description ILIKE ?', "%#{filters[:description]}%")
          end

          query
        end

        # === Fetch ===

        def fetch_cras(query)
          begin
            page_num = [page&.to_i || 1, 1].max
            per_page_num = (per_page&.to_i || 20).clamp(1, 100)

            pagy = Pagy.new(count: query.count, page: page_num, limit: per_page_num)
            paginated_cras = query.offset(pagy.offset).limit(pagy.limit).to_a

            pagination = {
              total: pagy.count,
              page: pagy.page,
              per_page: pagy.limit,
              pages: pagy.pages,
              prev: pagy.prev,
              next: pagy.next
            }

            { cras: paginated_cras, pagination: pagination }
        end

        # === Validators ===

        def valid_status?(status)
          Cra::VALID_STATUSES.include?(status.to_s)
        end

        def valid_month?(month)
          month.to_i.between?(1, 12)
        end

        def valid_year?(year)
          year.to_i >= 2000
        end

        def valid_currency?(currency)
          currency.to_s.match?(/\A[A-Z]{3}\z/)
        end

        # === Serialization ===

        def serialize_cras(cras)
          {
            data: cras.map { |cra| serialize_cra(cra) }
          }
        end

        def serialize_cra(cra)
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
end
