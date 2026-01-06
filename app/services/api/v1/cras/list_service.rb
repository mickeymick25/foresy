# frozen_string_literal: true

module Api
  module V1
    module Cras
      # Service for listing CRAs with pagination and filtering
      # Uses FC07-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = ListService.call(
      #     current_user: user,
      #     page: 1,
      #     per_page: 20,
      #     filters: { status: 'draft' }
      #   )
      #   result.cras # => [Cra, ...]
      #   result.pagination # => { total: 10, page: 1, ... }
      #
      # @raise [CraErrors::InvalidPayloadError] if user not provided or filters invalid
      # @raise [CraErrors::InternalError] if query fails
      #
      class ListService
        Result = Struct.new(:cras, :pagination, keyword_init: true)

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
          Rails.logger.info "[Cras::ListService] Listing CRAs for user #{@current_user&.id}"

          validate_inputs!
          cras, pagination = fetch_cras

          Rails.logger.info "[Cras::ListService] Successfully fetched #{cras.count} CRAs"
          Result.new(cras: cras, pagination: pagination)
        end

        private

        attr_reader :current_user, :page, :per_page, :filters

        # === Validation ===

        def validate_inputs!
          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                     field: :current_user)
          end

          validate_filters! if filters.present?
        end

        def validate_filters!
          if filters[:status].present? && !valid_status?(filters[:status])
            raise CraErrors::InvalidPayloadError.new('Invalid status filter. Must be: draft, submitted, or locked',
                                                     field: :status)
          end

          # Mini-FC-01: month requires year
          if filters[:month].present? && filters[:year].blank?
            raise CraErrors::InvalidPayloadError.new('year is required when month is specified', field: :month)
          end

          if filters[:month].present? && !valid_month?(filters[:month])
            raise CraErrors::InvalidPayloadError.new('Invalid month filter. Must be between 1 and 12', field: :month)
          end

          if filters[:year].present? && !valid_year?(filters[:year])
            raise CraErrors::InvalidPayloadError.new('Invalid year filter. Must be 2000 or later', field: :year)
          end

          if filters[:currency].present? && !valid_currency?(filters[:currency])
            raise CraErrors::InvalidPayloadError.new('Invalid currency filter. Must be a valid ISO 4217 code',
                                                     field: :currency)
          end
        end

        # === Query ===

        def fetch_cras
          query = build_base_query
          query = apply_filters(query)
          pagy, paginated_cras = paginate_query(query)

          pagination = {
            total: pagy.count,
            page: pagy.page,
            per_page: pagy.limit,
            pages: pagy.pages,
            prev: pagy.prev,
            next: pagy.next
          }

          [paginated_cras, pagination]
        rescue StandardError => e
          Rails.logger.error "[Cras::ListService] Query failed: #{e.message}"
          raise CraErrors::InternalError, 'Failed to query CRAs'
        end

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
          query = query.where(status: filters[:status]) if filters[:status].present?
          query = query.where(month: filters[:month]) if filters[:month].present?
          query = query.where(year: filters[:year]) if filters[:year].present?
          query = query.where(currency: filters[:currency]) if filters[:currency].present?

          query = query.where('description ILIKE ?', "%#{filters[:description]}%") if filters[:description].present?

          query
        end

        def paginate_query(query)
          page_num = [page&.to_i || 1, 1].max
          per_page_num = (per_page&.to_i || 20).clamp(1, 100)

          Pagy.new(count: query.count, page: page_num, limit: per_page_num).then do |pagy|
            [pagy, query.offset(pagy.offset).limit(pagy.limit)]
          end
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
      end
    end
  end
end
