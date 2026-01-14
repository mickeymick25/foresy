# frozen_string_literal: true

module Api
  module V1
    module Missions
      # Service for listing missions with filtering, sorting and pagination
      # Uses FC06-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = ListService.call(current_user: user, page: 1, per_page: 20)
      #   result.missions # => [Mission, ...]
      #   result.total_count # => 100
      #
      # @raise [CraErrors::MissionNotFoundError] if mission not provided
      # @raise [CraErrors::InternalError] if query fails
      #
      class ListService
        DEFAULT_PAGE = 1
        DEFAULT_PER_PAGE = 20

        # Enhanced Result struct with Platinum level error handling
        Result = Struct.new(:missions, :total_count, :pagination, :errors, :error_type, keyword_init: true) do
          def success?
            error_type.nil?
          end

          def value?
            success? ? missions : nil
          end

          def value!
            raise "Cannot call value! on failed result" unless success?
            missions
          end

          # Factory methods for different scenarios
          def self.success(missions, total_count, pagination = {})
            new(missions: missions, total_count: total_count, pagination: pagination, errors: nil, error_type: nil)
          end

          def self.failure(errors, error_type)
            new(missions: [], total_count: 0, pagination: {}, errors: errors, error_type: error_type)
          end
        end

        # Options hash for optional parameters to reduce parameter count
        # @option options [Integer] :page (1) Page number
        # @option options [Integer] :per_page (20) Items per page
        # @option options [Boolean] :include_associations (true) Eager load associations
        # @option options [Hash] :filters ({}) Filter criteria
        # @option options [Hash] :sort_options ({}) Sort criteria
        def self.call(current_user:, **options)
          new(current_user: current_user, **options).call
        end

        def initialize(current_user:, **options)
          @current_user = current_user
          @page = (options[:page] || DEFAULT_PAGE).to_i
          @per_page = (options[:per_page] || DEFAULT_PER_PAGE).to_i
          @include_associations = options.fetch(:include_associations, true)
          @filters = options[:filters] || {}
          @sort_options = options[:sort_options] || {}
        end

        def call
          Rails.logger.info "[Missions::ListService] Listing missions for user #{@current_user&.id}"

          validate_inputs!

          base_query = build_mission_query
          total_count = base_query.count
          missions = apply_pagination(base_query)

          # Calculate pagination information
          pagination = calculate_pagination(total_count)

          Rails.logger.info "[Missions::ListService] Retrieved #{missions.size} missions (total: #{total_count})"
          Result.success(missions, total_count, pagination)
        rescue CraErrors::MissionNotFoundError => e
          Rails.logger.warn "[Missions::ListService] Mission not found: #{e.message}"
          Result.failure([e.message], :not_found)
        rescue CraErrors::InternalError => e
          Rails.logger.warn "[Missions::ListService] Query building failed: #{e.message}"
          Result.failure([e.message], :internal_error)
        rescue StandardError => e
          Rails.logger.error "[Missions::ListService] Unexpected error: #{e.message}"
          Rails.logger.error "[Missions::ListService] Backtrace: #{e.backtrace.first(5).join("\n")}" if e.respond_to?(:backtrace)
          Result.failure([e.message], :internal_error)
        end

        private

        attr_reader :current_user, :page, :per_page, :include_associations, :filters, :sort_options

        # === Validation ===

        def validate_inputs!
          raise CraErrors::InvalidPayloadError, 'Current user is required' unless current_user.present?
        end

        # === Query Building ===

        def build_mission_query
          base_query = Mission.accessible_to(current_user).active
          base_query = apply_eager_loading(base_query)
          base_query = apply_filters(base_query)
          apply_sorting(base_query)
        rescue StandardError => e
          Rails.logger.error "[Missions::ListService] Query building failed: #{e.message}"
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
            mission_companies: :company
          )
        end

        def apply_filters(query)
          return query if filters.blank?

          query = apply_status_filters(query)
          query = apply_mission_type_filters(query)
          query = apply_date_filters(query)
          query = apply_financial_filters(query)
          query = apply_company_filters(query)
          query = apply_name_filters(query)
          query
        end

        def apply_status_filters(query)
          return query unless filters[:status].present?

          status = filters[:status].to_s
          return query unless Mission::VALID_STATUSES.include?(status)

          query.where(status: status)
        end

        def apply_mission_type_filters(query)
          return query unless filters[:mission_type].present?

          mission_type = filters[:mission_type].to_s
          return query unless %w[time_based fixed_price].include?(mission_type)

          query.where(mission_type: mission_type)
        end

        def apply_date_filters(query)
          # Date range filters
          if filters[:start_date_from].present? || filters[:start_date_to].present?
            start_date_from = parse_date(filters[:start_date_from]) || Date.new(2000, 1, 1)
            start_date_to = parse_date(filters[:start_date_to]) || Date.current
            query = query.where(start_date: start_date_from..start_date_to)
          end

          if filters[:end_date_from].present? || filters[:end_date_to].present?
            end_date_from = parse_date(filters[:end_date_from]) || Date.new(2000, 1, 1)
            end_date_to = parse_date(filters[:end_date_to]) || Date.current
            query = query.where(end_date: end_date_from..end_date_to)
          end

          # Specific date filters
          if filters[:start_date].present?
            start_date = parse_date(filters[:start_date])
            query = query.where(start_date: start_date) if start_date.present?
          end

          if filters[:end_date].present?
            end_date = parse_date(filters[:end_date])
            query = query.where(end_date: end_date) if end_date.present?
          end

          query
        end

        def apply_financial_filters(query)
          # Daily rate range
          if filters[:min_daily_rate].present?
            min_daily_rate = filters[:min_daily_rate].to_i
            query = query.where('daily_rate >= ?', min_daily_rate)
          end

          if filters[:max_daily_rate].present?
            max_daily_rate = filters[:max_daily_rate].to_i
            query = query.where('daily_rate <= ?', max_daily_rate)
          end

          # Fixed price range
          if filters[:min_fixed_price].present?
            min_fixed_price = filters[:min_fixed_price].to_i
            query = query.where('fixed_price >= ?', min_fixed_price)
          end

          if filters[:max_fixed_price].present?
            max_fixed_price = filters[:max_fixed_price].to_i
            query = query.where('fixed_price <= ?', max_fixed_price)
          end

          query
        end

        def apply_company_filters(query)
          return query unless filters[:company_id].present?

          company_id = filters[:company_id].to_i
          query.joins(:mission_companies).where(
            mission_companies: { company_id: company_id }
          )
        end

        def apply_name_filters(query)
          return query unless filters[:name].present?

          name_filter = filters[:name].to_s
          query.where('name ILIKE ?', "%#{name_filter}%")
        end

        def apply_sorting(query)
          sort_field = validated_sort_field
          sort_direction = validated_sort_direction

          query.order(sort_field => sort_direction.to_sym)
        rescue StandardError => e
          Rails.logger.warn "[Missions::ListService] Sorting failed: #{e.message}, using default sorting"
          query.order(created_at: :desc)
        end

        # === Helpers ===

        def validated_sort_field
          sort_field = sort_options[:field]&.to_s || 'created_at'
          valid_sort_fields = %w[name mission_type status start_date end_date daily_rate fixed_price created_at updated_at]

          valid_sort_fields.include?(sort_field) ? sort_field : 'created_at'
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

        # Calculate pagination information based on total count and current page
        # @param total_count [Integer] Total number of items
        # @return [Hash] Pagination information
        def calculate_pagination(total_count)
          total_pages = (total_count.to_f / per_page).ceil

          {
            page: page,
            per_page: per_page,
            total: total_count,
            pages: total_pages,
            next: page < total_pages,
            prev: page > 1
          }
        end
      end
    end
  end
end
