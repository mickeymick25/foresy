# frozen_string_literal: true

# app/application/services/cra_entries/list.rb
# Adapted to use Domain::CraEntry::CraEntry for business validations
# New Application layer structure - Step 6 of migration plan
# Single responsibility: List CRA entries with pagination and filtering
# Returns ApplicationResult exclusively - no business exceptions raised

module Services
  module CraEntries
    # Service for listing CRA entries with pagination and filtering
    # Uses ApplicationResult contract for consistent Service → Controller communication
    #
    # CONTRACT:
    # - Returns ApplicationResult exclusively
    # - No business exceptions raised
    # - No HTTP concerns in service
    # - Single source of truth for business rules
    #
    # @example
    #   result = List.call(
    #     current_user: user,
    #     page: 1,
    #     per_page: 20,
    #     filters: { status: 'draft' }
    #   )
    #   result.ok? # => true/false
    #   result.data # => { items: [...], meta: {...} }
    #
    class List
      DEFAULT_PAGE = 1
      DEFAULT_PER_PAGE = 20

      def self.call(cra:, current_user: nil, page: nil, per_page: nil, filters: {})
        new(cra: cra, current_user: current_user, page: page, per_page: per_page, filters: filters).call
      end

      def initialize(cra:, current_user: nil, page: nil, per_page: nil, filters: {})
        @cra = cra
        @current_user = current_user
        @page = (page || DEFAULT_PAGE).to_i
        @per_page = (per_page || DEFAULT_PER_PAGE).to_i
        @filters = filters || {}
      end

      def call
        # Input validation
        validation_result = validate_inputs
        return validation_result unless validation_result.nil?

        # Business validation using Domain object
        domain_validation_result = validate_business_rules
        return domain_validation_result unless domain_validation_result.nil?

        # Build query
        query_result = build_base_query
        return query_result unless query_result.nil?

        # Apply filters
        filtered_query = apply_filters(query_result)
        return filtered_query if filtered_query.is_a?(ApplicationResult)

        # Apply sorting
        sorted_query = apply_sorting(filtered_query)

        # Fetch entries
        fetch_result = fetch_entries(sorted_query)
        return fetch_result unless fetch_result.nil?

        # Success response
        ApplicationResult.success(
          data: {
            items: {
              data: serialize_entries(fetch_result[:entries]),
              meta: fetch_result[:pagination]
            }
          }
        )
      rescue StandardError => e
        ApplicationResult.fail(
          error: :internal_error,
          status: :internal_server_error,
          message: "Failed to fetch CRA entries: #{e.message}"
        )
      end

      private

      attr_reader :cra, :current_user, :page, :per_page, :filters

      # === Validation ===

      def validate_inputs
        # CRA validation
        unless cra.present?
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: 'Not Found'
          )
        end

        # Current user validation
        if current_user.present? && cra.created_by_user_id != current_user.id
          return ApplicationResult.fail(
            error: :forbidden,
            status: :forbidden,
            message: 'Forbidden'
          )
        end

        # Pagination validation
        if @page < 1
          return ApplicationResult.fail(
            error: :bad_request,
            status: :bad_request,
            message: 'Page must be greater than 0'
          )
        end

        if @per_page < 1 || @per_page > 100
          return ApplicationResult.fail(
            error: :bad_request,
            status: :bad_request,
            message: 'Per page must be between 1 and 100'
          )
        end

        nil # All input validations passed
      end

      def validate_business_rules
        # Validate filters using Domain::CraEntry::CraEntry

        # Date range validation
        date_result = validate_date_range
        return date_result unless date_result.nil?

        # Quantity range validation
        quantity_result = validate_quantity_range
        return quantity_result unless quantity_result.nil?

        # Unit price range validation
        unit_price_result = validate_unit_price_range
        return unit_price_result unless unit_price_result.nil?

        # Description length validation
        description_result = validate_description_length
        return description_result unless description_result.nil?

        nil # All business rule validations passed
      end

      def validate_date_range
        if filters[:start_date].present? || filters[:end_date].present?
          start_date = parse_date(filters[:start_date])
          end_date = parse_date(filters[:end_date])

          if start_date.present? && end_date.present? && start_date > end_date
            return ApplicationResult.fail(
              error: :bad_request,
              status: :bad_request,
              message: 'Start date cannot be after end date'
            )
          end
        end

        nil
      end

      def validate_quantity_range
        # Min quantity validation
        if filters[:min_quantity].present?
          min_quantity = filters[:min_quantity].to_d
          if min_quantity.negative? || min_quantity > ::Domain::CraEntry::CraEntry::MAX_QUANTITY
            return ApplicationResult.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Minimum quantity must be between 0 and #{::Domain::CraEntry::CraEntry::MAX_QUANTITY}"
            )
          end
        end

        # Max quantity validation
        if filters[:max_quantity].present?
          max_quantity = filters[:max_quantity].to_d
          if max_quantity.negative? || max_quantity > ::Domain::CraEntry::CraEntry::MAX_QUANTITY
            return ApplicationResult.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Maximum quantity must be between 0 and #{::Domain::CraEntry::CraEntry::MAX_QUANTITY}"
            )
          end
        end

        nil
      end

      def validate_unit_price_range
        # Min unit price validation
        if filters[:min_unit_price].present?
          min_unit_price = filters[:min_unit_price].to_i
          if min_unit_price.negative? || min_unit_price > ::Domain::CraEntry::CraEntry::MAX_UNIT_PRICE
            return ApplicationResult.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Minimum unit price must be between 0 and #{::Domain::CraEntry::CraEntry::MAX_UNIT_PRICE} cents"
            )
          end
        end

        # Max unit price validation
        if filters[:max_unit_price].present?
          max_unit_price = filters[:max_unit_price].to_i
          if max_unit_price.negative? || max_unit_price > ::Domain::CraEntry::CraEntry::MAX_UNIT_PRICE
            return ApplicationResult.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Maximum unit price must be between 0 and #{::Domain::CraEntry::CraEntry::MAX_UNIT_PRICE} cents"
            )
          end
        end

        nil
      end

      def validate_description_length
        if filters[:description].present? && filters[:description].length > ::Domain::CraEntry::CraEntry::MAX_DESCRIPTION_LENGTH
          return ApplicationResult.fail(
            error: :bad_request,
            status: :bad_request,
            message: 'Description filter cannot exceed ' \
                     "#{::Domain::CraEntry::CraEntry::MAX_DESCRIPTION_LENGTH} characters"
          )
        end

        nil
      end

      # === Query Building ===

      def build_base_query
        CraEntry.joins(:cra_entry_cras)
                .where(cra_entry_cras: { cra_id: cra.id })
                .where(deleted_at: nil)
                .includes(:cra_entry_missions, :cra_entry_cras)
      end

      def apply_filters(query)
        return query if filters.blank?

        # Apply date filters
        query = apply_date_filters(query)

        # Apply quantity filters
        query = apply_quantity_filters(query)

        # Apply unit price filters
        query = apply_unit_price_filters(query)

        # Apply mission filter
        query = apply_mission_filter(query)

        # Apply description filter
        apply_description_filter(query)
      end

      def apply_date_filters(query)
        if filters[:start_date].present?
          start_date = parse_date(filters[:start_date])
          query = query.where('date >= ?', start_date) if start_date.present?
        end

        if filters[:end_date].present?
          end_date = parse_date(filters[:end_date])
          query = query.where('date <= ?', end_date) if end_date.present?
        end

        query
      end

      def apply_quantity_filters(query)
        if filters[:min_quantity].present?
          min_quantity = filters[:min_quantity].to_d
          query = query.where('quantity >= ?', min_quantity)
        end

        if filters[:max_quantity].present?
          max_quantity = filters[:max_quantity].to_d
          query = query.where('quantity <= ?', max_quantity)
        end

        query
      end

      def apply_unit_price_filters(query)
        if filters[:min_unit_price].present?
          min_unit_price = filters[:min_unit_price].to_i
          query = query.where('unit_price >= ?', min_unit_price)
        end

        if filters[:max_unit_price].present?
          max_unit_price = filters[:max_unit_price].to_i
          query = query.where('unit_price <= ?', max_unit_price)
        end

        query
      end

      def apply_mission_filter(query)
        if filters[:mission_id].present?
          query = query.joins(:cra_entry_missions)
                       .where(cra_entry_missions: { mission_id: filters[:mission_id] })
        end

        query
      end

      def apply_description_filter(query)
        if filters[:description].present?
          description_filter = filters[:description].to_s
          query = query.where('description ILIKE ?', "%#{description_filter}%")
        end

        query
      end

      def apply_sorting(query)
        # Default sorting by date desc, then by created_at desc
        sort_field = filters[:sort_field] || 'date'
        sort_direction = filters[:sort_direction] || 'desc'

        # Validate sort field
        valid_sort_fields = %w[date quantity unit_price description created_at updated_at line_total]
        sort_field = 'date' unless valid_sort_fields.include?(sort_field)

        # Validate sort direction
        sort_direction = 'desc' unless %w[asc desc].include?(sort_direction)

        query.order(sort_field => sort_direction, created_at: :desc)
      end

      # === Fetch ===

      def fetch_entries(query)
        pagy = Pagy.new(count: query.count, page: @page, limit: @per_page)
        paginated_entries = query.offset(pagy.offset).limit(@per_page).to_a

        pagination = {
          total: pagy.count,
          page: pagy.page,
          per_page: pagy.limit,
          pages: pagy.pages,
          prev: pagy.prev,
          next: pagy.next
        }

        { entries: paginated_entries, cra: cra, pagination: pagination }
      rescue StandardError => e
        ApplicationResult.fail(
          error: :internal_error,
          status: :internal_server_error,
          message: "Failed to fetch entries: #{e.message}"
        )
      end

      # === Utilities ===

      def parse_date(date_param)
        return nil if date_param.blank?

        Date.parse(date_param.to_s)
      rescue ArgumentError
        nil
      end

      # === Serialization ===

      def serialize_entries(entries)
        {
          data: entries.map { |entry| serialize_entry(entry) }
        }
      end

      def serialize_entry(entry)
        mission = entry.cra_entry_missions.first&.mission

        {
          id: entry.id,
          date: entry.date,
          quantity: entry.quantity.to_f,
          unit_price: entry.unit_price.to_i,
          description: entry.description,
          mission_id: mission&.id,
          mission_name: mission&.name,
          line_total: (entry.quantity.to_f * entry.unit_price.to_f / 100.0).round(2),
          created_at: entry.created_at,
          updated_at: entry.updated_at
        }
      end

      def serialize_cra(cra)
        {
          id: cra.id,
          month: cra.month,
          year: cra.year,
          description: cra.description,
          status: cra.status,
          total_days: cra.total_days,
          total_amount: cra.total_amount
        }
      end
    end
  end
end
