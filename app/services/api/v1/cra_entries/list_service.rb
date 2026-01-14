# frozen_string_literal: true

# app/services/api/v1/cra_entries/list_service.rb
# Migration vers ApplicationResult - Étape 2 du plan de migration
# Contrat unique : tous les services retournent ApplicationResult
# Aucune exception métier levée - tout via Result.fail

require_relative '../../../../../lib/application_result'

module Api
  module V1
    module CraEntries
      # Service for listing CRA entries with filtering, sorting and pagination
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
      #     cra: cra,
      #     page: 1,
      #     per_page: 20
      #   )
      #   result.ok? # => true/false
      #   result.data # => { items: [...], cra: {...} }
      #
      class ListService
        DEFAULT_PAGE = 1
        DEFAULT_PER_PAGE = 20

        def self.call(cra:, current_user: nil, **options)
          new(cra: cra, current_user: current_user, **options).call
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
          # Input validation
          unless cra.present?
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "CRA is required"
            )
          end

          # Build query
          query_result = build_entry_query
          return query_result unless query_result.nil?

          # Get total count
          total_count = query_result.count

          # Apply pagination
          entries = apply_pagination(query_result)

          # Success response
          Result.ok(
            data: {
              items: serialize_entries(entries),
              cra: serialize_cra(cra),
              meta: {
                total_count: total_count,
                page: @page,
                per_page: @per_page
              }
            },
            status: :ok
          )
        # No rescue StandardError - let exceptions bubble up for debugging

        private

        attr_reader :cra, :current_user, :page, :per_page, :include_associations, :filters, :sort_options

        # === Query Building ===

        def build_entry_query
          base_query = cra.cra_entries.active
          base_query = apply_eager_loading(base_query)
          base_query = apply_filters(base_query)
          apply_sorting(base_query)
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
            # Eliminate SQL injection risk by avoiding variable interpolation
            if validated_sort_direction == 'asc'
              query.order(Arel.sql('(quantity * unit_price) ASC'))
            else
              query.order(Arel.sql('(quantity * unit_price) DESC'))
            end
          else
            query.order(sort_field => sort_direction.to_sym)
          end
        # No rescue StandardError - let exceptions bubble up for debugging
        end

        # === Validation Helpers ===

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

        # === Serialization ===

        def serialize_entries(entries)
          entries.map { |entry| serialize_entry(entry) }
        end

        def serialize_entry(entry)
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

        def serialize_cra(cra)
          {
            id: cra.id,
            total_days: cra.total_days,
            total_amount: cra.total_amount,
            currency: cra.currency,
            status: cra.status
          }
        end
      end
    end
  end
end
