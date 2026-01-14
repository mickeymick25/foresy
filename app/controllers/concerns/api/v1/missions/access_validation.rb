# frozen_string_literal: true

module Api
  module V1
    module Missions
      module AccessValidation
        extend ActiveSupport::Concern

        private

        def validate_user_authentication!
          unless current_user.present?
            Rails.logger.warn 'Authentication required but no current_user found'
            unauthorized_response('Authentication required')
          end
        end

        def validate_user_company_role!
          return unless current_user.present?

          user_companies = current_user.user_companies.joins(:company)
          independent_companies = user_companies.where(role: 'independent')

          if independent_companies.empty?
            Rails.logger.warn "User #{current_user.id} has no independent company role"
            raise CraErrors::NoIndependentCompanyError, 'User must have independent company role'
          end

          @independent_company = independent_companies.first.company
        end

        def validate_mission_access!(mission)
          return unless mission.present?

          # Check if user is the creator or has access via missions
          accessible_mission_ids = get_accessible_mission_ids

          unless accessible_mission_ids.include?(mission.id)
            Rails.logger.warn "User #{current_user.id} attempting to access unauthorized mission #{mission.id}"
            raise CraErrors::UnauthorizedError, 'Access denied to this mission'
          end

          Rails.logger.info "User #{current_user.id} accessing mission #{mission.id}"
        end

        def validate_mission_modification_allowed!(mission)
          return unless mission.present?

          # Check if mission is in a state that allows modification
          allowed_statuses = %w[draft lead active]
          return if allowed_statuses.include?(mission.status)

          case mission.status
          when 'completed'
            Rails.logger.warn "Attempt to modify completed mission #{mission.id}"
            raise CraErrors::InvalidPayloadError, 'Cannot modify completed mission'
          when 'cancelled'
            Rails.logger.warn "Attempt to modify cancelled mission #{mission.id}"
            raise CraErrors::InvalidPayloadError, 'Cannot modify cancelled mission'
          else
            Rails.logger.warn "Attempt to modify mission #{mission.id} with unknown status #{mission.status}"
            raise ArgumentError, "Invalid mission status: #{mission.status}"
          end
        end

        def validate_mission_deletion_allowed!(mission)
          return unless mission.present?

          # Additional checks specific to mission deletion
          check_mission_usage! if mission.persisted?
          check_cra_dependencies! if mission.persisted?

          validate_mission_modification_allowed!(mission)

          Rails.logger.info "Deleting mission #{mission.id} - allowed"
        end

        def validate_mission_creation_allowed!(current_user)
          return unless current_user.present?

          validate_user_company_role!
          validate_mission_creation_params!(mission_params)

          Rails.logger.info "Creating mission for user #{current_user.id} - allowed"
        end

        def validate_mission_creation_params!(params)
          required_params = %i[name mission_type status]
          missing_params = required_params.select { |param| params[param].blank? }

          if missing_params.any?
            Rails.logger.warn "Missing required mission creation parameters: #{missing_params.join(', ')}"
            raise ActionController::ParameterMissing, missing_params.first.to_s
          end

          # Validate name
          name = params[:name].to_s.strip
          if name.length < 3
            Rails.logger.warn "Invalid mission name length: #{name.length}"
            raise ArgumentError, 'Mission name must be at least 3 characters long'
          end

          if name.length > 200
            Rails.logger.warn "Mission name too long: #{name.length}"
            raise ArgumentError, 'Mission name cannot exceed 200 characters'
          end

          # Validate mission type
          mission_type = params[:mission_type].to_s
          valid_types = %w[time_based fixed_price]
          unless valid_types.include?(mission_type)
            Rails.logger.warn "Invalid mission type: #{mission_type}"
            raise ArgumentError, "Mission type must be one of: #{valid_types.join(', ')}"
          end

          # Validate status
          status = params[:status].to_s
          valid_statuses = %w[draft lead active completed cancelled]
          unless valid_statuses.include?(status)
            Rails.logger.warn "Invalid mission status: #{status}"
            raise ArgumentError, "Mission status must be one of: #{valid_statuses.join(', ')}"
          end

          # Validate financial fields based on mission type
          if mission_type == 'time_based'
            validate_daily_rate!(params[:daily_rate])
          elsif mission_type == 'fixed_price'
            validate_fixed_price!(params[:fixed_price])
          end

          # Validate dates if provided
          if params[:start_date].present?
            start_date = parse_date_param(params[:start_date])
            if start_date.nil?
              Rails.logger.warn "Invalid mission creation start date: #{params[:start_date]}"
              raise ArgumentError, 'Invalid start date format'
            end
          end

          if params[:end_date].present?
            end_date = parse_date_param(params[:end_date])
            if end_date.nil?
              Rails.logger.warn "Invalid mission creation end date: #{params[:end_date]}"
              raise ArgumentError, 'Invalid end date format'
            end
          end

          # Validate date logic
          if params[:start_date].present? && params[:end_date].present?
            start_date = parse_date_param(params[:start_date])
            end_date = parse_date_param(params[:end_date])
            if start_date > end_date
              Rails.logger.warn "Mission creation dates invalid: start #{start_date} > end #{end_date}"
              raise ArgumentError, 'Start date must be before end date'
            end
          end
        end

        # First validate_mission_access! method is above (lines 27-38)

        def validate_mission_duplicate!(mission_params, client_company_id, current_user)
          return unless mission_params.present? && current_user.present?

          name = mission_params[:name].to_s.strip
          return unless name.present?

          # Check for duplicate mission names for the same creator
          duplicate_exists = Mission.where(
            name: name,
            created_by_user_id: current_user.id,
            deleted_at: nil
          ).exists?

          if duplicate_exists
            Rails.logger.warn "Duplicate mission name detected for user #{current_user.id} and name #{name}"
            raise CraErrors::DuplicateEntryError, 'A mission with this name already exists'
          end
        end

        def get_accessible_mission_ids
          # Get missions accessible via user's independent company missions
          Mission.joins(:mission_companies)
                 .joins('INNER JOIN user_companies ON user_companies.company_id = mission_companies.company_id')
                 .where(user_companies: { user_id: current_user.id, role: %w[independent client] })
                 .where(deleted_at: nil)
                 .pluck(:id)
                 .uniq
        end

        def get_accessible_company_ids
          # Get companies accessible via user's roles
          UserCompany.joins(:company)
                     .where(user_id: current_user.id, role: %w[independent client])
                     .where(deleted_at: nil)
                     .pluck(:company_id)
                     .uniq
        end

        def check_mission_usage!
          # Check if mission is being used in active CRAs
          active_cras_with_mission = CraMission.joins(:cra)
                                            .where(mission_id: mission.id)
                                            .where.not(cras: { status: 'locked' })
                                            .exists?

          if active_cras_with_mission
            Rails.logger.warn "Mission #{mission.id} is linked to active CRAs and cannot be deleted"
            raise CraErrors::MissionInUseError, 'Mission is linked to active CRAs and cannot be deleted'
          end
        end

        def check_cra_dependencies!
          # Check if mission has any CRA entries
          cra_entries_with_mission = CraEntry.joins(:cra_entry_missions)
                                          .where(cra_entry_missions: { mission_id: mission.id })
                                          .where(deleted_at: nil)
                                          .exists?

          if cra_entries_with_mission
            Rails.logger.warn "Mission #{mission.id} has CRA entries and cannot be deleted"
            raise CraErrors::MissionInUseError, 'Mission has CRA entries and cannot be deleted'
          end
        end

        def validate_daily_rate!(daily_rate)
          return if daily_rate.blank?

          daily_rate_value = daily_rate.to_i
          unless daily_rate_value.positive?
            Rails.logger.warn "Invalid mission creation daily rate: #{daily_rate_value}"
            raise ArgumentError, 'Daily rate must be greater than 0'
          end

          if daily_rate_value > 100_000_000
            Rails.logger.warn "Mission creation daily rate exceeds limit: #{daily_rate_value}"
            raise ArgumentError, 'Daily rate cannot exceed 100,000,000'
          end
        end

        def validate_fixed_price!(fixed_price)
          return if fixed_price.blank?

          fixed_price_value = fixed_price.to_i
          unless fixed_price_value.positive?
            Rails.logger.warn "Invalid mission creation fixed price: #{fixed_price_value}"
            raise ArgumentError, 'Fixed price must be greater than 0'
          end

          if fixed_price_value > 1_000_000_000
            Rails.logger.warn "Mission creation fixed price exceeds limit: #{fixed_price_value}"
            raise ArgumentError, 'Fixed price cannot exceed 1,000,000,000'
          end
        end

        def parse_date_param(date_param)
          return nil if date_param.blank?

          Date.parse(date_param)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
