# frozen_string_literal: true

# CRA Create Service - Services Layer Architecture
# Migrated from Api::V1::Cras::CreateService to CraServices namespace
# Uses ApplicationResult contract for consistent Service → Controller communication
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
#
# @example
#   result = CraServices::Create.call(
#     cra_params: { month: 1, year: 2025, currency: 'EUR' },
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { cra: {...} }
#
class CraServices::Create
  def self.call(cra_params:, current_user:)
    new(cra_params: cra_params, current_user: current_user).call
  end

  def initialize(cra_params:, current_user:)
    @cra_params = cra_params
    @current_user = current_user
  end

  def call
    return ApplicationResult.bad_request(
      error: :missing_parameters,
      message: "CRA parameters are required"
    ) unless @cra_params.present?

    return ApplicationResult.bad_request(
      error: :missing_parameters,
      message: "Current user is required"
    ) unless @current_user.present?

      # Parameter validation
      validation_result = validate_cra_params
      return validation_result if validation_result.failure?

      # Permission check
      permission_check = check_user_permissions
      return permission_check if permission_check.failure?

      # Build CRA
      build_result = build_cra
      return build_result if build_result.failure?

      # Save CRA
      save_result = save_cra(build_result.data[:cra])
      return save_result if save_result.failure?

      # Success
      ApplicationResult.success(
        data: { cra: save_result.data[:cra] },
        message: "CRA created successfully"
      )
    rescue StandardError => e
      Rails.logger.error "CraServices::Create error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :internal_error,
        message: "An unexpected error occurred while creating the CRA"
      )
    end

    private

    attr_reader :cra_params, :current_user

    # === Validation ===

    def validate_cra_params
      # Check required parameters
      return ApplicationResult.bad_request(
        error: :missing_month,
        message: "Month is required"
      ) unless cra_params[:month].present?

      return ApplicationResult.bad_request(
        error: :missing_year,
        message: "Year is required"
      ) unless cra_params[:year].present?

      # Validate month
      month = cra_params[:month].to_i
      return ApplicationResult.bad_request(
        error: :invalid_month,
        message: "Month must be between 1 and 12"
      ) unless (1..12).include?(month)

      # Validate year
      year = cra_params[:year].to_i
      return ApplicationResult.bad_request(
        error: :invalid_year,
        message: "Year must be 2000 or later"
      ) if year < 2000

      return ApplicationResult.bad_request(
        error: :year_too_far_future,
        message: "Year cannot be more than 5 years in the future"
      ) if year > (Date.current.year + 5)

      # Validate currency if provided
      if cra_params[:currency].present?
        currency = cra_params[:currency].to_s
        return ApplicationResult.bad_request(
          error: :invalid_currency,
          message: "Currency must be a valid ISO 4217 code"
        ) unless currency.match?(/\A[A-Z]{3}\z/)
      end

      # Validate description if provided
      if cra_params[:description].present?
        description = cra_params[:description].to_s
        return ApplicationResult.bad_request(
          error: :description_too_long,
          message: "Description cannot exceed 2000 characters"
        ) if description.length > 2000
      end

      ApplicationResult.success(data: {})
    end

    # === Permissions ===

    def check_user_permissions
      return ApplicationResult.forbidden(
        error: :insufficient_permissions,
        message: "User does not have permission to create CRAs"
      ) unless user_has_independent_company_access?

      ApplicationResult.success(data: {}) # Permission check passed
    end

    def user_has_independent_company_access?
      return false unless current_user.present?

      current_user.user_companies.joins(:company).where(role: 'independent').exists?
    end

    # === Build ===

    def build_cra
      cra = Cra.new(
        month: cra_params[:month].to_i,
        year: cra_params[:year].to_i,
        description: cra_params[:description].to_s,
        currency: cra_params[:currency]&.to_s || 'EUR',
        status: 'draft',
        created_by_user_id: current_user.id
      )

      unless cra.valid?
        return ApplicationResult.unprocessable_entity(
          error: :validation_failed,
          message: cra.errors.full_messages.join(', ')
        )
      end

      ApplicationResult.success(data: { cra: cra })
    rescue StandardError => e
      ApplicationResult.internal_error(
        error: :build_failed,
        message: "Failed to build CRA: #{e.message}"
      )
    end

    # === Save ===

    def save_cra(cra)
      ActiveRecord::Base.transaction do
        cra.save!
        cra.reload
      rescue ActiveRecord::RecordInvalid => e
        # Handle duplicate CRA error with multiple detection patterns
        base_errors = cra.errors[:base] || []
        duplicate_detected = base_errors.any? do |msg|
          msg.include?('already exists') ||
          msg.include?('A CRA already exists') ||
          msg.include?('duplicate') ||
          msg.include?('has already been taken')
        end

        if duplicate_detected
          return ApplicationResult.conflict(
            error: :cra_already_exists,
            message: "A CRA already exists for this user, month, and year"
          )
        end

        ApplicationResult.unprocessable_entity(
          error: :save_failed,
          message: e.record.errors.full_messages.join(', ')
        )
      rescue ActiveRecord::RecordNotFound => e
        ApplicationResult.not_found(
          error: :cra_not_found,
          message: "CRA not found during save"
        )
      end

      ApplicationResult.success(data: { cra: cra })
    rescue StandardError => e
      Rails.logger.error "[DEBUG] CraServices::Create save_cra StandardError: #{e.class} - #{e.message}"
      Rails.logger.error "[DEBUG] StandardError details: #{e.inspect}"
      ApplicationResult.internal_error(
        error: :save_failed,
        message: "Failed to save CRA: #{e.message}"
      )
    end
end
