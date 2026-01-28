# frozen_string_literal: true

# CRA List Service - Services Layer Architecture
# Migrated from Api::V1::Cras::ListService to CraServices namespace
# Uses ApplicationResult contract for consistent Service → Controller communication
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
#
# @example
#   result = CraServices::List.call(
#     current_user: user,
#     page: 1,
#     per_page: 20,
#     filters: { status: 'draft' }
#   )
#   result.success? # => true/false
#   result.data # => { cras: [...], pagination: {...} }
#
class CraServices::List
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
    unless current_user.present?
      return ApplicationResult.bad_request(
        error: :missing_user,
        message: 'Current user is required'
      )
    end

    # Filter validation
    filter_validation = validate_filters
    return filter_validation if filter_validation.failure?

    # Fetch CRAs
    fetch_result = fetch_cras
    return fetch_result if fetch_result.failure?

    # Success
    cras, pagination = fetch_result.data.values_at(:cras, :pagination)
    ApplicationResult.success(
      data: {
        cras: cras,
        pagination: pagination
      },
      message: 'CRAs listed successfully'
    )
  rescue StandardError => e
    Rails.logger.error "CraServices::List error: #{e.message}" if defined?(Rails)
    ApplicationResult.internal_error(
      error: :internal_error,
      message: 'An unexpected error occurred while listing CRAs'
    )
  end

  private

  attr_reader :current_user, :page, :per_page, :filters

  # === Filter Validation ===

  def validate_filters
    return ApplicationResult.success if filters.empty?

    # Validate status filter
    if filters[:status].present? && !valid_status?(filters[:status])
      return ApplicationResult.bad_request(
        error: :invalid_status_filter,
        message: 'Invalid status filter. Must be: draft, submitted, or locked'
      )
    end

    # Mini-FC-01: month requires year
    if filters[:month].present? && filters[:year].blank?
      return ApplicationResult.bad_request(
        error: :missing_year_for_month,
        message: 'year is required when month is specified'
      )
    end

    # Validate month
    if filters[:month].present? && !valid_month?(filters[:month])
      return ApplicationResult.bad_request(
        error: :invalid_month_filter,
        message: 'Invalid month filter. Must be between 1 and 12'
      )
    end

    # Validate year
    if filters[:year].present? && !valid_year?(filters[:year])
      return ApplicationResult.bad_request(
        error: :invalid_year_filter,
        message: 'Year must be 2000 or later'
      )
    end

    # Validate currency
    if filters[:currency].present? && !valid_currency?(filters[:currency])
      return ApplicationResult.bad_request(
        error: :invalid_currency_filter,
        message: 'Invalid currency filter. Must be a valid ISO 4217 code'
      )
    end

    ApplicationResult.success
  end

  # === Fetch CRAs ===

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

    ApplicationResult.success(
      data: {
        cras: paginated_cras,
        pagination: pagination
      }
    )
  rescue StandardError => e
    Rails.logger.error "[CraServices::List] Query failed: #{e.message}" if defined?(Rails)
    ApplicationResult.internal_error(
      error: :query_failed,
      message: 'Failed to query CRAs'
    )
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

    # Description search with ILIKE for case-insensitive search
    query = query.where('description ILIKE ?', "%#{filters[:description]}%") if filters[:description].present?

    query
  end

  def paginate_query(query)
    page_num = [page&.to_i || 1, 1].max
    per_page_num = (per_page&.to_i || 20).clamp(1, 100)

    pagy = Pagy.new(count: query.count, page: page_num, limit: per_page_num)
    [pagy, query.offset(pagy.offset).limit(pagy.limit)]
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
