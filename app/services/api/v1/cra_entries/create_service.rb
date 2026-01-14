# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      # Service for creating CRA entries with comprehensive business rule validation
      # Uses Shared::Result contract for consistent Service → Controller communication
      #
      # CONTRACT:
      # - Returns Shared::Result::ResultObject exclusively
      # - No business exceptions raised
      # - No HTTP concerns in service
      # - Single source of truth for business rules
      #
      # @example
      #   result = CreateService.call(
      #     cra: cra,
      #     entry_params: { date: '2025-01-15', quantity: 1, unit_price: 50000, mission_id: 'uuid' },
      #     current_user: user
      #   )
      #   result.success? # => true/false
      #   result.data # => { item: { ... }, cra: { ... } }
      #
      class CreateService
        Result = Api::V1::CraEntries::Shared::Result

        def self.call(cra:, entry_params:, current_user:)
          new(cra: cra, entry_params: entry_params, current_user: current_user).call
        end

        def initialize(cra:, entry_params:, current_user:)
          @cra = cra
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

          # Build entry
          @entry = build_entry
          return @entry if @entry.is_a?(Shared::ResultObject)

          # Validate entry
          entry_validation = validate_entry
          return entry_validation if entry_validation

          # Check for duplicates
          duplicate_result = check_duplicate
          return duplicate_result if duplicate_result

          # Save entry with associations
          save_result = save_entry_with_associations
          return save_result if save_result

          # Recalculate CRA totals
          recalculate_cra_totals

          # Success response
          Result.success_entry(@entry, @cra.reload)
        rescue StandardError => e
          Rails.logger.error "[CraEntries::CreateService] Unexpected error: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.first(10).join("\n")
          Result.failure(["An unexpected error occurred: #{e.message}"], :internal_error)
        end

        private

        attr_reader :cra, :entry_params, :current_user

        # === Input Validation ===

        def validate_inputs
          unless cra.present?
            return Result.failure(["CRA not found"], :not_found)
          end

          unless entry_params.present?
            return Result.failure(["Entry parameters are required"], :bad_request)
          end

          unless current_user.present?
            return Result.failure(["Current user is required"], :bad_request)
          end

          # Required fields validation
          missing_fields = []
          missing_fields << 'date' unless entry_params[:date].present?
          missing_fields << 'quantity' unless entry_params[:quantity].present?
          missing_fields << 'unit_price' unless entry_params[:unit_price].present?
          missing_fields << 'mission_id' unless entry_params[:mission_id].present?

          if missing_fields.any?
            return Result.failure(["Missing required fields: #{missing_fields.join(', ')}"], :validation_error)
          end

          nil
        end

        def validate_permissions
          unless cra.created_by_user_id == current_user.id
            return Result.failure(["Only the CRA creator can add entries to this CRA"], :unauthorized)
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

        # === Build Entry ===

        def build_entry
          CraEntry.new(
            date: parse_date(entry_params[:date]),
            quantity: entry_params[:quantity].to_d,
            unit_price: entry_params[:unit_price].to_i,
            description: entry_params[:description]
          )
        end

        def parse_date(date_value)
          return date_value if date_value.is_a?(Date)
          Date.parse(date_value.to_s)
        rescue ArgumentError
          nil
        end

        def validate_entry
          unless @entry.valid?
            return Result.failure(@entry.errors.full_messages, :validation_error)
          end

          # Additional business validations
          if @entry.quantity.negative?
            return Result.failure(["Quantity cannot be negative"], :validation_error)
          end

          if @entry.unit_price.negative?
            return Result.failure(["Unit price cannot be negative"], :validation_error)
          end

          if @entry.date.nil?
            return Result.failure(["Date is invalid"], :validation_error)
          end

          if @entry.date > Date.current
            return Result.failure(["Date cannot be in the future"], :validation_error)
          end

          nil
        end

        # === Duplicate Check ===

        def check_duplicate
          # Check if an entry already exists for this CRA, mission, and date
          existing = CraEntry
            .joins(:cra_entry_cras, :cra_entry_missions)
            .where(cra_entry_cras: { cra_id: cra.id })
            .where(cra_entry_missions: { mission_id: mission_id })
            .where(date: @entry.date)
            .exists?

          if existing
            return Result.failure(
              ["An entry already exists for this mission and date in this CRA"],
              :conflict
            )
          end

          nil
        end

        # === Save Entry ===

        def save_entry_with_associations
          ActiveRecord::Base.transaction do
            unless @entry.save
              raise ActiveRecord::Rollback
              return Result.failure(@entry.errors.full_messages, :validation_error)
            end

            # Create CRA-Entry association
            CraEntryCra.create!(
              cra_id: cra.id,
              cra_entry_id: @entry.id
            )

            # Create Entry-Mission association
            CraEntryMission.create!(
              cra_entry_id: @entry.id,
              mission_id: mission_id
            )

            # Create CRA-Mission association if not exists
            unless CraMission.exists?(cra_id: cra.id, mission_id: mission_id)
              CraMission.create!(
                cra_id: cra.id,
                mission_id: mission_id
              )
            end
          end

          nil
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[CraEntries::CreateService] Association creation failed: #{e.message}"
          Result.failure([e.record.errors.full_messages.join(', ')], :validation_error)
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

        def mission_id
          @mission_id ||= entry_params[:mission_id]
        end
      end
    end
  end
end
