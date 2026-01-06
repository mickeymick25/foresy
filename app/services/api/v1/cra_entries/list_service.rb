# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      # Service for listing CRA entries with filtering, sorting and pagination
      # Uses FC07-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = ListService.call(cra: cra, page: 1, per_page: 20)
      #   result.entries # => [CraEntry, ...]
      #   result.total_count # => 100
      #
      # @raise [CraErrors::CraNotFoundError] if CRA not provided
      # @raise [CraErrors::InternalError] if query fails
      #
      class ListService
        DEFAULT_PAGE = 1
        DEFAULT_PER_PAGE = 20

        Result = Struct.new(:items, :total_count, keyword_init: true)

        # Options hash for optional parameters to reduce parameter count
        # @option options [Integer] :page (1) Page number
        # @option options [Integer] :per_page (20) Items per page
        # @option options [Boolean] :include_associations (true) Eager load associations
        # @option options [Hash] :filters ({}) Filter criteria
        # @option options [Hash] :sort_options ({}) Sort criteria
        def self.call(cra:, current_user: nil, **)
          new(cra: cra, current_user: current_user, **).call
        end

        def initialize(cra:, current_user: nil, **options)
          @cra = cra
          @current_user = current_user
          @page = (options[:page] || DEFAULT_PAGE).to_i
          @per_page = (options[:per_page] || DEFAULT_PER_PAGE).to_i
          @include_associations = options.fetch(:include_associations, true)
          @filters = options[:filters] || {}
          @sort_options = options[:sort_options] || {}
        end

        def call
          Rails.logger.info "[CraEntries::ListService] Listing entries for CRA #{@cra&.id}"

          validate_inputs!

          base_query = build_entry_query
          total_count = base_query.count
          entries = apply_pagination(base_query)

          Rails.logger.info "[CraEntries::ListService] Retrieved #{entries.size} entries (total: #{total_count})"
          Result.new(items: entries, total_count: total_count)
        end

        private

        attr_reader :cra, :current_user, :page, :per_page, :include_associations, :filters, :sort_options

        # === Validation ===

        def validate_inputs!
          raise CraErrors::CraNotFoundError, 'CRA is required' unless cra.present?
        end

        # === Query Building ===

        def build_entry_query
          base_query = cra.cra_entries.active
          base_query = apply_eager_loading(base_query)
          base_query = apply_filters(base_query)
          apply_sorting(base_query)
        rescue StandardError => e
          Rails.logger.error "[CraEntries::ListService] Query building failed: #{e.message}"
          raise CraErrors::InternalError, 'Failed to build query'
        end

        # === Pagination ===

        def apply_pagination(query)
          offset = (page - 1) * per_page
          query.limit(per_page).offset(offset)
        end

        def apply_eager_loading(query)
          return query unless include_associations

          query.includes(
            :cra_entry_missions,
            :cra_entry_cras,
            { cra_entry_missions: :mission },
            { cra_entry_cras: :cra }
          )
        end

        def apply_filters(query)
          return query if filters.blank?

          query = apply_date_filters(query)
          query = apply_mission_filter(query)
          query = apply_quantity_filters(query)
          query = apply_unit_price_filters(query)
          query = apply_description_filter(query)
          apply_line_total_filters(query)
        end

        def apply_date_filters(query)
          # Date range
          if filters[:start_date].present? || filters[:end_date].present?
            start_date = parse_date(filters[:start_date]) || 2.years.ago.to_date
            end_date = parse_date(filters[:end_date]) || Date.current
            query = query.where(date: start_date..end_date)
          end

          # Specific date
          if filters[:date].present?
            date = parse_date(filters[:date])
            query = query.where(date: date) if date.present?
          end

          query
        end

        def apply_mission_filter(query)
          return query unless filters[:mission_id].present?

          query.joins(:cra_entry_missions).where(
            cra_entry_missions: { mission_id: filters[:mission_id] }
          )
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

        def apply_description_filter(query)
          return query unless filters[:description].present?

          query.where('description ILIKE ?', "%#{filters[:description]}%")
        end

        def apply_line_total_filters(query)
          if filters[:min_line_total].present?
            min_line_total = filters[:min_line_total].to_i
            query = query.where('(quantity * unit_price) >= ?', min_line_total)
          end

          if filters[:max_line_total].present?
            max_line_total = filters[:max_line_total].to_i
            query = query.where('(quantity * unit_price) <= ?', max_line_total)
          end

          query
        end

        def apply_sorting(query)
          sort_field = validated_sort_field
          sort_direction = validated_sort_direction

          if sort_field == 'line_total'
            query.order(Arel.sql("(quantity * unit_price) #{sort_direction}"))
          else
            query.order(sort_field => sort_direction.to_sym)
          end
        rescue StandardError => e
          Rails.logger.warn "[CraEntries::ListService] Sorting failed: #{e.message}, using default sorting"
          query.order(date: :desc)
        end

        # === Helpers ===

        def validated_sort_field
          sort_field = sort_options[:field]&.to_s || 'date'
          valid_sort_fields = %w[date quantity unit_price description created_at updated_at line_total]

          valid_sort_fields.include?(sort_field) ? sort_field : 'date'
        end

        def validated_sort_direction
          sort_direction = sort_options[:direction]&.to_s&.downcase || 'desc'

          %w[asc desc].include?(sort_direction) ? sort_direction : 'desc'
        end

        def parse_date(date_param)
          return nil if date_param.blank?

          Date.parse(date_param.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
