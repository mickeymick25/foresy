# frozen_string_literal: true

module Api
  module V1
    module CraEntries
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

        def validate_cra_entry_access!(cra_entry)
          return unless cra_entry.present?

          # Check if user is the creator or has access via CRA
          accessible_cra_ids = get_accessible_cra_ids

          # Check if the CRA associated with this entry is accessible
          cra = cra_entry.cra
          unless accessible_cra_ids.include?(cra.id)
            Rails.logger.warn "User #{current_user.id} attempting to access unauthorized CRA entry #{cra_entry.id}"
            raise CraErrors::UnauthorizedError, 'Access denied to this CRA entry'
          end

          Rails.logger.info "User #{current_user.id} accessing CRA entry #{cra_entry.id}"
        end

        def validate_cra_entry_modification_allowed!(cra_entry)
          return unless cra_entry.present?

          cra = cra_entry.cra
          validate_cra_modification_allowed!(cra)

          # Additional checks specific to CRA entries
          unless cra_entry.modifiable?
            Rails.logger.warn "Attempt to modify non-modifiable CRA entry #{cra_entry.id}"
            raise CraErrors::InvalidPayloadError, 'CRA entry cannot be modified'
          end
        end

        def validate_cra_entry_deletion_allowed!(cra_entry)
          return unless cra_entry.present?

          cra = cra_entry.cra
          validate_cra_modification_allowed!(cra)

          # Additional checks specific to CRA entry deletion
          unless cra_entry.deletable?
            Rails.logger.warn "Attempt to delete non-deletable CRA entry #{cra_entry.id}"
            raise CraErrors::InvalidPayloadError, 'CRA entry cannot be deleted'
          end
        end

        def validate_cra_entry_creation_allowed!(cra)
          return unless cra.present?

          validate_cra_modification_allowed!(cra)

          # Check if CRA is in a state that allows entry creation
          unless cra.draft?
            Rails.logger.warn "Attempt to add entries to non-draft CRA #{cra.id} (status: #{cra.status})"
            raise CraErrors::InvalidPayloadError, 'Cannot add entries to submitted or locked CRA'
          end

          Rails.logger.info "Adding entries to draft CRA #{cra.id} - allowed"
        end

        def validate_cra_entry_creation_params!(params)
          required_params = %i[date quantity unit_price]
          missing_params = required_params.select { |param| params[param].blank? }

          if missing_params.any?
            Rails.logger.warn "Missing required CRA entry creation parameters: #{missing_params.join(', ')}"
            raise ActionController::ParameterMissing, missing_params.first.to_s
          end

          # Validate date
          entry_date = parse_date_param(params[:date])
          if entry_date.nil?
            Rails.logger.warn "Invalid CRA entry creation date: #{params[:date]}"
            raise ArgumentError, 'Invalid date format'
          end

          # Validate quantity (must be positive)
          quantity = params[:quantity].to_f
          unless quantity.positive?
            Rails.logger.warn "Invalid CRA entry creation quantity: #{quantity}"
            raise ArgumentError, 'Quantity must be positive'
          end

          if quantity > 365
            Rails.logger.warn "CRA entry creation quantity exceeds 365 days: #{quantity}"
            raise ArgumentError, 'Quantity cannot exceed 365 days'
          end

          # Validate unit_price (must be positive integer)
          unit_price = params[:unit_price].to_i
          unless unit_price.positive?
            Rails.logger.warn "Invalid CRA entry creation unit_price: #{unit_price}"
            raise ArgumentError, 'Unit price must be positive'
          end

          if unit_price > 100_000_000
            Rails.logger.warn "CRA entry creation unit_price exceeds limit: #{unit_price}"
            raise ArgumentError, 'Unit price cannot exceed 100,000,000 EUR'
          end

          # Validate description if present
          if params[:description].present?
            description = params[:description].to_s
            if description.length > 500
              Rails.logger.warn "CRA entry creation description too long: #{description.length} characters"
              raise ArgumentError, 'Description cannot exceed 500 characters'
            end
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

        def validate_cra_entry_duplicate!(cra_entry_params, mission_id, cra)
          return unless cra.present? && mission_id.present?

          entry_date = parse_date_param(cra_entry_params[:date])
          return unless entry_date.present?

          # Check for duplicate entries (same mission, same date)
          duplicate_exists = CraEntry.joins(:cra_entry_cras, :cra_entry_missions)
                                    .where(cra_entry_cras: { cra_id: cra.id })
                                    .where(cra_entry_missions: { mission_id: mission_id })
                                    .where(date: entry_date)
                                    .where(deleted_at: nil)
                                    .exists?

          if duplicate_exists
            Rails.logger.warn "Duplicate CRA entry detected for mission #{mission_id} and date #{entry_date}"
            raise CraErrors::DuplicateEntryError, 'An entry already exists for this mission and date'
          end
        end

        def get_accessible_cra_entry_ids
          # Get CRA entries accessible via user's independent company missions
          CraEntry.joins(:cra_entry_cras)
                  .joins('INNER JOIN cras ON cras.id = cra_entry_cras.cra_id')
                  .joins('INNER JOIN cra_missions ON cra_missions.cra_id = cras.id')
                  .joins('INNER JOIN missions ON missions.id = cra_missions.mission_id')
                  .joins('INNER JOIN mission_companies ON mission_companies.mission_id = missions.id')
                  .joins('INNER JOIN user_companies ON user_companies.company_id = mission_companies.company_id')
                  .where(user_companies: { user_id: current_user.id, role: %w[independent client] })
                  .where('cras.deleted_at' => nil)
                  .where('mission_companies.deleted_at' => nil)
                  .where('user_companies.deleted_at' => nil)
                  .pluck(:id)
                  .uniq
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
