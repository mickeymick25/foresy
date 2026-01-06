# frozen_string_literal: true

module Api
  module V1
    module Cras
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

        def validate_cra_access!(cra)
          return unless cra.present?

          # Check if user is the creator
          if cra.created_by_user_id == current_user.id
            Rails.logger.info "User #{current_user.id} accessing own CRA #{cra.id}"
            return
          end

          # Check access via missions (FC06 rules)
          accessible_cra_ids = get_accessible_cra_ids

          unless accessible_cra_ids.include?(cra.id)
            Rails.logger.warn "User #{current_user.id} attempting to access unauthorized CRA #{cra.id}"
            raise CraErrors::UnauthorizedError, 'Access denied to this CRA'
          end
        end

        def validate_cra_modification_allowed!(cra)
          return unless cra.present?

          case cra.status
          when 'submitted'
            Rails.logger.warn "Attempt to modify submitted CRA #{cra.id}"
            raise CraErrors::CraSubmittedError, 'Cannot modify submitted CRA'
          when 'locked'
            Rails.logger.warn "Attempt to modify locked CRA #{cra.id}"
            raise CraErrors::CraLockedError, 'Cannot modify locked CRA'
          when 'draft'
            Rails.logger.info "Modifying draft CRA #{cra.id} - allowed"
          else
            Rails.logger.warn "Unknown CRA status #{cra.status} for CRA #{cra.id}"
            raise ArgumentError, "Invalid CRA status: #{cra.status}"
          end
        end

        def validate_cra_lifecycle_transition!(cra, target_status)
          return unless cra.present?

          valid_transitions = {
            'draft' => ['submitted'],
            'submitted' => ['locked']
          }

          unless valid_transitions[cra.status]&.include?(target_status)
            Rails.logger.warn "Invalid transition from #{cra.status} to #{target_status} for CRA #{cra.id}"
            raise CraErrors::InvalidTransitionError,
                  "Invalid transition from #{cra.status} to #{target_status}"
          end
        end

        def validate_mission_access!(mission)
          return unless mission.present?

          # Validate mission access using FC06 rules
          accessible_mission_ids = get_accessible_mission_ids

          unless accessible_mission_ids.include?(mission.id)
            Rails.logger.warn "User #{current_user.id} attempting to access unauthorized mission #{mission.id}"
            raise CraErrors::MissionNotFoundError, 'Mission not accessible'
          end
        end

        def validate_cra_creation_params!(params)
          required_params = %i[month year currency]
          missing_params = required_params.select { |param| params[param].blank? }

          if missing_params.any?
            Rails.logger.warn "Missing required CRA creation parameters: #{missing_params.join(', ')}"
            raise ActionController::ParameterMissing, missing_params.first.to_s
          end

          # Validate month range
          month = params[:month].to_i
          unless month.between?(1, 12)
            Rails.logger.warn "Invalid CRA month: #{month}"
            raise ArgumentError, 'Month must be between 1 and 12'
          end

          # Validate year range
          year = params[:year].to_i
          current_year = Time.current.year
          unless year.between?(current_year - 10, current_year + 1)
            Rails.logger.warn "Invalid CRA year: #{year}"
            raise ArgumentError, "Year must be between #{current_year - 10} and #{current_year + 1}"
          end

          # Validate currency
          valid_currencies = %w[EUR USD GBP]
          unless valid_currencies.include?(params[:currency])
            Rails.logger.warn "Invalid CRA currency: #{params[:currency]}"
            raise ArgumentError, "Currency must be one of: #{valid_currencies.join(', ')}"
          end
        end

        def validate_cra_entry_params!(params)
          required_params = %i[date quantity unit_price]
          missing_params = required_params.select { |param| params[param].blank? }

          if missing_params.any?
            Rails.logger.warn "Missing required CRA entry parameters: #{missing_params.join(', ')}"
            raise ActionController::ParameterMissing, missing_params.first.to_s
          end

          # Validate date
          entry_date = parse_date_param(params[:date])
          if entry_date.nil?
            Rails.logger.warn "Invalid CRA entry date: #{params[:date]}"
            raise ArgumentError, 'Invalid date format'
          end

          # Validate quantity (must be positive)
          quantity = params[:quantity].to_f
          unless quantity.positive?
            Rails.logger.warn "Invalid CRA entry quantity: #{quantity}"
            raise ArgumentError, 'Quantity must be positive'
          end

          # Validate unit_price (must be non-negative integer)
          unit_price = params[:unit_price].to_i
          unless unit_price >= 0
            Rails.logger.warn "Invalid CRA entry unit_price: #{unit_price}"
            raise ArgumentError, 'Unit price must be non-negative'
          end
        end

        def get_accessible_cra_ids
          # Get CRAs accessible via user's independent company missions
          Cra.joins(:cra_missions)
             .joins('INNER JOIN missions ON missions.id = cra_missions.mission_id')
             .joins('INNER JOIN mission_companies ON mission_companies.mission_id = missions.id')
             .joins('INNER JOIN user_companies ON user_companies.company_id = mission_companies.company_id')
             .where(user_companies: { user_id: current_user.id, role: %w[independent client] })
             .where(deleted_at: nil)
             .pluck(:id)
             .uniq
        end

        def get_accessible_mission_ids
          # Get missions accessible via user's company roles
          Mission.joins(:mission_companies)
                 .joins('INNER JOIN user_companies ON user_companies.company_id = mission_companies.company_id')
                 .where(user_companies: { user_id: current_user.id, role: %w[independent client] })
                 .where(deleted_at: nil)
                 .pluck(:id)
                 .uniq
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
