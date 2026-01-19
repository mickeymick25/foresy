# frozen_string_literal: true

puts "[ListService] FILE LOADED - DEBUGGING AUTOLOADING"

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
          puts "[ListService] SELF.CALL METHOD ENTERED"
          puts "[ListService] About to call new(...)"
          new(cra: cra, current_user: current_user, **options).call
        end

        def initialize(cra:, current_user: nil, **options)
          puts "[ListService] INITIALIZE METHOD ENTERED"
          @cra = cra
          @current_user = current_user
          @page = options[:page]
          @per_page = options[:per_page]

          # Parameter validation moved to call method

          @page = (@page || DEFAULT_PAGE).to_i
          @per_page = (@per_page || DEFAULT_PER_PAGE).to_i
          @include_associations = options.fetch(:include_associations, true)
          @filters = options[:filters] || {}
          @sort_options = options[:sort_options] || {}
        end

        def call
          puts "[ListService] CALL METHOD ENTERED"
          puts "[ListService] Starting call method"
          puts "[ListService] @cra: #{@cra.inspect}"
          puts "[ListService] @page: #{@page}, @per_page: #{@per_page}"
          puts "[ListService] @filters: #{@filters.inspect}"
          puts "[ListService] @current_user: #{current_user.inspect}"

          # Validate and convert pagination parameters first
          if @page.present? && @page.to_s !~ /\A\d+\z/
            return ApplicationResult.bad_request(
              error: :bad_request,
              message: "Invalid page parameter"
            )
          end

          if @per_page.present? && @per_page.to_s !~ /\A\d+\z/
            return ApplicationResult.bad_request(
              error: :bad_request,
              message: "Invalid per_page parameter"
            )
          end

          # Validate pagination bounds
          if @page.present? && @page.to_i < 1
            return ApplicationResult.bad_request(
              error: :bad_request,
              message: "pagination parameters invalid - page must be greater than 0"
            )
          end

          if @per_page.present? && (@per_page.to_i < 1 || @per_page.to_i > 100)
            return ApplicationResult.bad_request(
              error: :bad_request,
              message: "pagination parameters invalid - per page must be between 1 and 100"
            )
          end

          # Input validation
          unless cra.present?
            puts "[ListService] CRA is not present"
            return ApplicationResult.fail(
              error: :validation_error,
              status: :unprocessable_entity,
              message: "CRA is required"
            )
          end

          # Build query
          puts "[ListService] About to build query"
          query_result = build_entry_query
          puts "[ListService] Query built, query_result class: #{query_result.class}"

          # Ensure query_result is always an ApplicationResult
          if query_result.nil?
            puts "[ListService] query_result is nil"
            query_result = ApplicationResult.fail(
              error: :query_build_failed,
              status: :internal_error,
              message: "Query build failed"
            )
          end

          puts "[ListService] Checking query_result: respond_to?(:success?) = #{query_result.respond_to?(:success?)}, success? = #{query_result.respond_to?(:success?) && query_result.success?}"

          # Ensure we always work with an ApplicationResult
          unless query_result.respond_to?(:success?)
            # Build query returned ActiveRecord::Relation, wrap it in success result
            query_result = ApplicationResult.success(data: query_result)
          end

          return query_result unless query_result.success?

          # Get total count
          puts "[ListService] About to get total_count"
          total_count = query_result.data.count
          puts "[ListService] total_count: #{total_count}"

          # Apply pagination
          puts "[ListService] About to apply pagination"
          entries = apply_pagination(query_result.data)
          puts "[ListService] Pagination applied, entries class: #{entries.class}, count: #{entries.count}"

          # Success response - Format matches test expectations with meta structure
          puts "[ListService] About to serialize entries"
          serialized_entries = serialize_entries(entries)
          puts "[ListService] Entries serialized, count: #{serialized_entries.count}"

          puts "[ListService] About to serialize CRA"
          serialized_cra = serialize_cra(cra)
          puts "[ListService] CRA serialized: #{serialized_cra.inspect}"

          puts "[ListService] About to return success response"
          result = ApplicationResult.success(
            data: {
              entries: serialized_entries,
              cra: serialized_cra,
              meta: {
                total_count: total_count,
                pagination: {
                  current_page: @page,
                  per_page: @per_page
                }
              }
            }
          )
          puts "[ListService] Success response created: #{result.inspect}"
          result
        end

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
          return query if filters.blank?

          start_date = parse_date(filters[:start_date])
          end_date = parse_date(filters[:end_date])

          if filters[:start_date].present? && start_date.nil?
            return ApplicationResult.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Invalid start_date format"
            )
          end

          if filters[:end_date].present? && end_date.nil?
            return ApplicationResult.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Invalid end_date format"
            )
          end

          start_date ||= 2.years.ago.to_date
          end_date ||= Date.current

          query.where(date: start_date..end_date)
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
          query
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
            updated_at: entry.updated_at,
            mission_id: entry.missions.first&.id
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
