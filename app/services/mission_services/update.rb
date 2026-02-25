# frozen_string_literal: true

# Mission Update Service - Services Layer Architecture
# Handles mission updates including status transitions and attribute modifications
# Uses ApplicationResult contract for consistent Service → Controller communication
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
#
# @example
#   result = MissionServices::Update.call(
#     mission: mission,
#     mission_params: { name: 'New Name', status: 'won' },
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { mission: {...} }
#
class MissionServices
  class Update
    def self.call(mission:, mission_params:, current_user:)
      new(mission: mission, mission_params: mission_params, current_user: current_user).call
    end

    def initialize(mission:, mission_params:, current_user:)
      @mission = mission
      @mission_params = mission_params
      @current_user = current_user
    end

    def call
      # Permission check: only creator can modify
      permission_result = check_permissions
      return permission_result if permission_result.failure?

      # Validate params
      validation_result = validate_params
      return validation_result if validation_result.failure?

      # Handle status transition if needed
      if status_change_needed?
        transition_result = handle_status_transition
        return transition_result if transition_result.failure?
      end

      # Handle other attribute updates
      if attribute_updates_needed?
        update_result = update_attributes
        return update_result if update_result.failure?
      end

      # Success - return updated mission
      ApplicationResult.success(
        data: { mission: @mission },
        message: 'Mission updated successfully'
      )
    rescue StandardError => e
      Rails.logger.error "MissionServices::Update error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :internal_error,
        message: 'An unexpected error occurred while updating the mission'
      )
    end

    private

    attr_reader :mission, :mission_params, :current_user

    # === Permissions ===

    def check_permissions
      unless mission.modifiable_by?(current_user)
        return ApplicationResult.forbidden(
          error: :forbidden,
          message: 'Only the mission creator can modify this mission'
        )
      end

      ApplicationResult.success(data: {})
    end

    # === Validation ===

    def validate_params
      return ApplicationResult.success(data: {}) if mission_params.blank?

      # Validate mission_type if provided
      if mission_params[:mission_type].present?
        mission_type = mission_params[:mission_type].to_s
        unless Mission::VALID_MISSION_TYPES.include?(mission_type)
          return ApplicationResult.bad_request(
            error: :invalid_mission_type,
            message: "Mission type must be one of: #{Mission::VALID_MISSION_TYPES.join(', ')}"
          )
        end
      end

      # Validate status if provided
      if mission_params[:status].present?
        status = mission_params[:status].to_s
        unless Mission::VALID_STATUSES.include?(status)
          return ApplicationResult.bad_request(
            error: :invalid_status,
            message: "Status must be one of: #{Mission::VALID_STATUSES.join(', ')}"
          )
        end
      end

      # Validate dates if provided
      if mission_params[:start_date].present? || mission_params[:end_date].present?
        date_result = validate_dates
        return date_result if date_result.failure?
      end

      # Validate financial fields based on type
      if mission_params[:mission_type].present? || mission_params[:daily_rate].present? || mission_params[:fixed_price].present?
        financial_result = validate_financial_fields
        return financial_result if financial_result.failure?
      end

      ApplicationResult.success(data: {})
    end

    def validate_dates
      start_date = parse_date(mission_params[:start_date]) || mission.start_date
      end_date = parse_date(mission_params[:end_date]) if mission_params[:end_date].present?

      if end_date.present? && start_date.present? && end_date < start_date
        return ApplicationResult.bad_request(
          error: :invalid_date_range,
          message: 'End date must be greater than or equal to start date'
        )
      end

      ApplicationResult.success(data: {})
    end

    def validate_financial_fields
      mission_type = mission_params[:mission_type]&.to_s || mission.mission_type.to_s
      daily_rate = mission_params[:daily_rate]
      fixed_price = mission_params[:fixed_price]

      case mission_type
      when 'time_based'
        if daily_rate.nil? && mission_params.key?(:daily_rate)
          return ApplicationResult.bad_request(
            error: :missing_daily_rate,
            message: 'Daily rate is required for time-based missions'
          )
        end
        if fixed_price.present?
          return ApplicationResult.bad_request(
            error: :invalid_financial_field,
            message: 'Fixed price cannot be set for time-based missions'
          )
        end
      when 'fixed_price'
        if fixed_price.nil? && mission_params.key?(:fixed_price)
          return ApplicationResult.bad_request(
            error: :missing_fixed_price,
            message: 'Fixed price is required for fixed-price missions'
          )
        end
        if daily_rate.present?
          return ApplicationResult.bad_request(
            error: :invalid_financial_field,
            message: 'Daily rate cannot be set for fixed-price missions'
          )
        end
      end

      ApplicationResult.success(data: {})
    end

    def parse_date(date)
      return date if date.is_a?(Date)
      return Date.parse(date) if date.is_a?(String)

      nil
    end

    # === Status Transition ===

    def status_change_needed?
      new_status = mission_params[:status]
      new_status.present? && new_status.to_s != mission.status.to_s
    end

    def handle_status_transition
      new_status = mission_params[:status].to_s

      unless mission.can_transition_to?(new_status)
        return ApplicationResult.unprocessable_entity(
          error: :invalid_transition,
          message: "Cannot transition from #{mission.status} to #{new_status}"
        )
      end

      begin
        mission.update!(status: new_status)
        ApplicationResult.success(data: { mission: mission })
      rescue ActiveRecord::RecordInvalid => e
        ApplicationResult.unprocessable_entity(
          error: :validation_failed,
          message: e.record.errors.full_messages.join(', ')
        )
      end
    end

    # === Attribute Updates ===

    def attribute_updates_needed?
      # Get non-status updates
      updates = mission_params.except(:status).to_h
      updates.any? { |_k, v| v.present? }
    end

    def update_attributes
      updates = mission_params.except(:status).to_h

      # Parse dates if they're strings
      updates[:start_date] = parse_date(updates[:start_date]) if updates[:start_date].present?
      updates[:end_date] = parse_date(updates[:end_date]) if updates[:end_date].present?

      begin
        mission.update!(updates)
        ApplicationResult.success(data: { mission: mission })
      rescue ActiveRecord::RecordInvalid => e
        ApplicationResult.unprocessable_entity(
          error: :validation_failed,
          message: e.record.errors.full_messages.join(', ')
        )
      rescue ArgumentError => e
        ApplicationResult.bad_request(
          error: :invalid_parameter,
          message: e.message
        )
      end
    end
  end
end
