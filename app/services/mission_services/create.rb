# frozen_string_literal: true

# Mission Create Service - Services Layer Architecture
# Follows the same pattern as CraServices::Create for consistency
# Uses ApplicationResult contract for consistent Service → Controller communication
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
#
# @example
#   result = MissionServices::Create.call(
#     mission_params: { name: 'Project X', mission_type: 'time_based', ... },
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { mission: {...} }
#
class MissionServices
  class Create
    def self.call(mission_params:, current_user:)
      new(mission_params: mission_params, current_user: current_user).call
    end

    def initialize(mission_params:, current_user:)
      @mission_params = mission_params
      @current_user = current_user
    end

    def call
      unless @mission_params.present?
        return ApplicationResult.bad_request(
          error: :missing_parameters,
          message: 'Mission parameters are required'
        )
      end

      unless @current_user.present?
        return ApplicationResult.bad_request(
          error: :missing_parameters,
          message: 'Current user is required'
        )
      end

      # Parameter validation
      validation_result = validate_mission_params
      return validation_result if validation_result.failure?

      # Permission check
      permission_check = check_user_permissions
      return permission_check if permission_check.failure?

      # Build Mission
      build_result = build_mission
      return build_result if build_result.failure?

      # Save Mission
      save_result = save_mission(build_result.data[:mission])
      return save_result if save_result.failure?

      # Success
      ApplicationResult.success(
        data: { mission: save_result.data[:mission] },
        message: 'Mission created successfully'
      )
    rescue StandardError => e
      Rails.logger.error "MissionServices::Create error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :internal_error,
        message: 'An unexpected error occurred while creating the mission'
      )
    end

    private

    attr_reader :mission_params, :current_user

    # === Validation ===

    def validate_mission_params
      # Validate required parameters
      required_result = validate_required_parameters
      return required_result unless required_result.nil?

      # Validate mission type
      type_result = validate_mission_type
      return type_result unless type_result.nil?

      # Validate dates
      date_result = validate_dates
      return date_result unless date_result.nil?

      # Validate financial fields based on type
      financial_result = validate_financial_fields
      return financial_result unless financial_result.nil?

      # Validate optional parameters
      optional_result = validate_optional_parameters
      return optional_result unless optional_result.nil?

      ApplicationResult.success(data: {})
    end

    def validate_required_parameters
      unless mission_params[:name].present?
        return ApplicationResult.bad_request(
          error: :missing_name,
          message: 'Name is required'
        )
      end

      unless mission_params[:mission_type].present?
        return ApplicationResult.bad_request(
          error: :missing_mission_type,
          message: 'Mission type is required'
        )
      end

      unless mission_params[:start_date].present?
        return ApplicationResult.bad_request(
          error: :missing_start_date,
          message: 'Start date is required'
        )
      end

      nil
    end

    def validate_mission_type
      mission_type = mission_params[:mission_type].to_s
      unless Mission::VALID_MISSION_TYPES.include?(mission_type)
        return ApplicationResult.bad_request(
          error: :invalid_mission_type,
          message: "Mission type must be one of: #{Mission::VALID_MISSION_TYPES.join(', ')}"
        )
      end

      nil
    end

    def validate_dates
      start_date = mission_params[:start_date]
      end_date = mission_params[:end_date]

      # Parse dates if they're strings
      start_date = parse_date(start_date)
      unless start_date
        return ApplicationResult.bad_request(
          error: :invalid_start_date,
          message: 'Start date must be a valid date'
        )
      end

      if end_date.present?
        end_date = parse_date(end_date)
        unless end_date
          return ApplicationResult.bad_request(
            error: :invalid_end_date,
            message: 'End date must be a valid date'
          )
        end

        if end_date < start_date
          return ApplicationResult.bad_request(
            error: :invalid_date_range,
            message: 'End date must be greater than or equal to start date'
          )
        end
      end

      nil
    end

    def validate_financial_fields
      mission_type = mission_params[:mission_type].to_s

      case mission_type
      when 'time_based'
        unless mission_params[:daily_rate].present?
          return ApplicationResult.bad_request(
            error: :missing_daily_rate,
            message: 'Daily rate is required for time-based missions'
          )
        end
        if mission_params[:fixed_price].present?
          return ApplicationResult.bad_request(
            error: :invalid_financial_field,
            message: 'Fixed price cannot be set for time-based missions'
          )
        end
      when 'fixed_price'
        unless mission_params[:fixed_price].present?
          return ApplicationResult.bad_request(
            error: :missing_fixed_price,
            message: 'Fixed price is required for fixed-price missions'
          )
        end
        if mission_params[:daily_rate].present?
          return ApplicationResult.bad_request(
            error: :invalid_financial_field,
            message: 'Daily rate cannot be set for fixed-price missions'
          )
        end
      end

      nil
    end

    def validate_optional_parameters
      # Validate currency if provided
      if mission_params[:currency].present?
        currency = mission_params[:currency].to_s
        unless currency.match?(/\A[A-Z]{3}\z/)
          return ApplicationResult.bad_request(
            error: :invalid_currency,
            message: 'Currency must be a valid ISO 4217 code'
          )
        end
      end

      # Validate description if provided
      if mission_params[:description].present?
        description = mission_params[:description].to_s
        if description.length > 2000
          return ApplicationResult.bad_request(
            error: :description_too_long,
            message: 'Description cannot exceed 2000 characters'
          )
        end
      end

      nil
    end

    def parse_date(date)
      case date
      when Date then date
      when String then begin
        Date.parse(date)
      rescue StandardError
        nil
      end
      end
    end

    # === Permissions ===

    def check_user_permissions
      unless user_has_independent_company_access?
        return ApplicationResult.forbidden(
          error: :insufficient_permissions,
          message: 'User does not have permission to create missions'
        )
      end

      ApplicationResult.success(data: {}) # Permission check passed
    end

    def user_has_independent_company_access?
      return false unless current_user.present?

      current_user.user_companies.joins(:company).where(role: 'independent').exists?
    end

    # === Build ===

    def build_mission
      # Build attributes hash with conditional end_date
      mission_attributes = {
        name: mission_params[:name].to_s,
        description: mission_params[:description].to_s,
        mission_type: mission_params[:mission_type],
        status: mission_params[:status] || 'lead',
        start_date: parse_date(mission_params[:start_date]),
        daily_rate: mission_params[:daily_rate],
        fixed_price: mission_params[:fixed_price],
        currency: mission_params[:currency]&.to_s || 'EUR',
        created_by_user_id: current_user.id
      }

      # Add end_date if provided
      mission_attributes[:end_date] = parse_date(mission_params[:end_date]) if mission_params[:end_date].present?

      mission = Mission.new(mission_attributes)

      unless mission.valid?
        return ApplicationResult.unprocessable_entity(
          error: :validation_failed,
          message: mission.errors.full_messages.join(', ')
        )
      end

      ApplicationResult.success(data: { mission: mission })
    rescue StandardError => e
      ApplicationResult.internal_error(
        error: :build_failed,
        message: "Failed to build mission: #{e.message}"
      )
    end

    # === Save ===

    def save_mission(mission)
      ActiveRecord::Base.transaction do
        mission.save!
        mission.reload

        # Relation-driven: create UserMission pivot record when flag is ON
        create_user_mission_relation!(mission, current_user) if FeatureFlags.relation_driven?
      rescue ActiveRecord::RecordInvalid => e
        ApplicationResult.unprocessable_entity(
          error: :save_failed,
          message: e.record.errors.full_messages.join(', ')
        )
      rescue ActiveRecord::RecordNotFound
        ApplicationResult.not_found(
          error: :mission_not_found,
          message: 'Mission not found during save'
        )
      end

      ApplicationResult.success(data: { mission: mission })
    rescue StandardError => e
      Rails.logger.error "[DEBUG] MissionServices::Create save_mission StandardError: #{e.class} - #{e.message}"
      ApplicationResult.internal_error(
        error: :save_failed,
        message: "Failed to save mission: #{e.message}"
      )
    end

    # === Relation-Driven ===

    # Creates UserMission pivot record for relation-driven architecture
    # @param mission [Mission] the created mission
    # @param user [User] the creator user
    # @raise [ActiveRecord::RecordInvalid] if UserMission creation fails
    def create_user_mission_relation!(mission, user)
      user_mission = UserMission.new(
        user_id: user.id,
        mission_id: mission.id,
        role: UserMission::DEFAULT_ROLE # 'creator'
      )

      unless user_mission.valid?
        msg = "MissionServices::Create UserMission validation failed: #{user_mission.errors.full_messages}"
        Rails.logger.error "[DEBUG] #{msg}"
        raise ActiveRecord::RecordInvalid, user_mission
      end

      user_mission.save!
      msg = "[DEBUG] Created UserMission: user_id=#{user.id}, mission_id=#{mission.id}, role=creator"
      Rails.logger.info msg
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[DEBUG] MissionServices::Create failed to create UserMission: #{e.message}"
      raise
    end
  end
end
