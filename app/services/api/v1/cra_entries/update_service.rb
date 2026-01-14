# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      # Service for updating CRA entries with comprehensive business rule validation
      # Uses Shared::Result contract for consistent Service → Controller communication
      #
      # CONTRACT:
      # - Returns Shared::Result::ResultObject exclusively
      # - No business exceptions raised
      # - No HTTP concerns in service
      # - Single source of truth for business rules
      #
      # @example
      #   result = UpdateService.call(
      #     cra_entry: entry,
      #     entry_params: { quantity: 2, unit_price: 60000 },
      #     current_user: user
      #   )
      #   result.success? # => true/false
      #   result.data # => { item: { ... }, cra: { ... } }
      #
      class UpdateService
        Result = Api::V1::CraEntries::Shared::Result

        def self.call(cra_entry:, entry_params:, current_user:)
          new(cra_entry: cra_entry, entry_params: entry_params, current_user: current_user).call
        end

        def initialize(cra_entry:, entry_params:, current_user:)
          @cra_entry = cra_entry
          @entry_params = entry_params
          @current_user = current_user
        end

        def call
          # Input validation
          validation_result = validate_inputs
          return validation_result if validation_result

          # Permission validation
          permission_result = validate_permissions
          return permission_result if permission_result

          # CRA lifecycle validation
          lifecycle_result = check_cra_modifiable
          return lifecycle_result if lifecycle_result

          # Validate entry params
          params_validation_result = validate_entry_params
          return params_validation_result if params_validation_result

          # Duplicate check
          duplicate_result = check_duplicate
          return duplicate_result if duplicate_result

          # Perform update
          update_result = perform_update
          return update_result if update_result

          # Recalculate CRA totals
          recalculate_cra_totals

          # Success response
          Result.success_entry(@cra_entry, cra.reload)
        rescue StandardError => e
          Rails.logger.error "[CraEntries::UpdateService] Unexpected error: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.first(10).join("\n")
          Result.failure(["An unexpected error occurred: #{e.message}"], :internal_error)
        end

        private

        attr_reader :cra_entry, :entry_params, :current_user

        # === Input Validation ===

        def validate_inputs
          unless cra_entry.present?
            return Result.failure(["CRA entry not found"], :not_found)
          end

          unless entry_params.present?
            return Result.failure(["Entry parameters are required"], :bad_request)
          end

          unless current_user.present?
            return Result.failure(["Current user is required"], :bad_request)
          end

          # At least one field should be provided for update
          updatable_fields = [:date, :quantity, :unit_price, :description, :mission_id]
          has_updates = updatable_fields.any? { |field| entry_params[field].present? }
          unless has_updates
            return Result.failure(["At least one field must be provided for update"], :validation_error)
          end

          nil
        end

        def validate_permissions
          # Check CRA ownership
          unless cra.created_by_user_id == current_user.id
            return Result.failure(["Only the CRA creator can modify entries"], :unauthorized)
          end

          nil
        end

        def check_cra_modifiable
          if cra.locked?
            return Result.failure(["Locked CRAs cannot be modified"], :conflict)
          end

          if cra.submitted?
            return Result.failure(["Submitted CRAs cannot be modified"], :conflict)
          end

          nil
        end

        def validate_entry_params
          # Date validation
          if entry_params[:date].present?
            parsed_date = parse_date(entry_params[:date])
            unless parsed_date
              return Result.failure(["Date must be in a valid format"], :validation_error)
            end

            if parsed_date > Date.current
              return Result.failure(["Date cannot be in the future"], :validation_error)
            end
          end

          # Quantity validation
          if entry_params[:quantity].present?
            quantity = entry_params[:quantity].to_d
            if quantity.negative?
              return Result.failure(["Quantity cannot be negative"], :validation_error)
            end
            if quantity > 1000
              return Result.failure(["Quantity cannot exceed 1000"], :validation_error)
            end
          end

          # Unit price validation
          if entry_params[:unit_price].present?
            unit_price = entry_params[:unit_price].to_i
            if unit_price.negative?
              return Result.failure(["Unit price cannot be negative"], :validation_error)
            end
            if unit_price > 1_000_000_000
              return Result.failure(["Unit price cannot exceed 1 billion cents"], :validation_error)
            end
          end

          # Description validation
          if entry_params[:description].present?
            description = entry_params[:description].to_s
            if description.length > 1000
              return Result.failure(["Description cannot exceed 1000 characters"], :validation_error)
            end
          end

          # Mission validation (if provided)
          if entry_params[:mission_id].present?
            mission = Mission.find_by(id: entry_params[:mission_id])
            unless mission
              return Result.failure(["Mission not found"], :not_found)
            end

            # Check if mission is accessible to user
            accessible_missions = Mission.accessible_to(current_user)
            unless accessible_missions.exists?(id: mission.id)
              return Result.failure(["Mission not accessible"], :unauthorized)
            end
          end

          nil
        end

        # === Duplicate Check ===

        def check_duplicate
          return nil unless mission_id_changed? || date_changed?

          new_date = entry_params[:date].present? ? parse_date(entry_params[:date]) : cra_entry.date
          new_mission_id = mission_id || current_mission_id

          if duplicate_entry_exists?(new_mission_id, new_date)
            return Result.failure(
              ["An entry already exists for this mission and date in this CRA"],
              :conflict
            )
          end

          nil
        end

        def duplicate_entry_exists?(check_mission_id, date)
          return false unless check_mission_id && date

          CraEntry
            .joins(:cra_entry_cras, :cra_entry_missions)
            .where(cra_entry_cras: { cra_id: cra.id })
            .where(cra_entry_missions: { mission_id: check_mission_id })
            .where(date: date)
            .where(deleted_at: nil)
            .where.not(id: cra_entry.id)
            .exists?
        end

        # === Update Operation ===

        def perform_update
          ActiveRecord::Base.transaction do
            # Update entry attributes
            update_attributes

            # Update mission association if needed
            update_mission_association if mission_id_changed?

            # Save entry
            unless @cra_entry.save
              return Result.failure(@cra_entry.errors.full_messages, :validation_error)
            end

            @cra_entry.reload
          end

          nil
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[CraEntries::UpdateService] Update failed: #{e.message}"
          Result.failure([e.record.errors.full_messages.join(', ')], :validation_error)
        end

        def update_attributes
          # Update date
          if entry_params[:date].present?
            parsed_date = parse_date(entry_params[:date])
            @cra_entry.date = parsed_date if parsed_date
          end

          # Update quantity
          if entry_params[:quantity].present?
            @cra_entry.quantity = entry_params[:quantity].to_d
          end

          # Update unit_price
          if entry_params[:unit_price].present?
            @cra_entry.unit_price = entry_params[:unit_price].to_i
          end

          # Update description
          if entry_params[:description].present?
            @cra_entry.description = entry_params[:description].to_s
          end
        end

        def update_mission_association
          # Remove old association
          cra_entry.cra_entry_missions.destroy_all if current_mission_id.present?

          # Create new association
          if mission_id.present?
            CraEntryMission.create!(
              cra_entry_id: cra_entry.id,
              mission_id: mission_id
            )

            # Link CRA to mission if not already linked
            unless CraMission.exists?(cra_id: cra.id, mission_id: mission_id)
              CraMission.create!(
                cra_id: cra.id,
                mission_id: mission_id
              )
            end
          end
        end

        # === Recalculate Totals ===

        def recalculate_cra_totals
          entries = CraEntry.joins(:cra_entry_cras).where(cra_entry_cras: { cra_id: cra.id })

          total_days = entries.sum(:quantity)
          total_amount = entries.sum('quantity * unit_price')

          cra.update_columns(
            total_days: total_days,
            total_amount: total_amount.to_i,
            updated_at: Time.current
          )
        end

        # === Helpers ===

        def cra
          @cra ||= Cra.find_by!(id: cra_entry.cra_entry_cras.first.cra_id)
        end

        def current_mission_id
          @current_mission_id ||= cra_entry.cra_entry_missions.first&.mission_id
        end

        def mission_id_changed?
          entry_params[:mission_id].present? && entry_params[:mission_id] != current_mission_id
        end

        def date_changed?
          return false unless entry_params[:date].present?

          parse_date(entry_params[:date]) != cra_entry.date
        end

        def mission_id
          @mission_id ||= entry_params[:mission_id]
        end

        def parse_date(date_value)
          return date_value if date_value.is_a?(Date)
          Date.parse(date_value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
