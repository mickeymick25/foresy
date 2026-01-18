# frozen_string_literal: true

# app/services/api/v1/cra_entries/create_service.rb
# Migration vers ApplicationResult - Étape 2 du plan de migration
# Contrat unique : tous les services retournent ApplicationResult
# Aucune exception métier levée - tout via ApplicationResult.fail

require_relative '../../../../../lib/application_result'

module Api
  module V1
    module CraEntries
      # Service for creating CRA entries with comprehensive business rule validation
      # Uses ApplicationResult contract for consistent Service → Controller communication
      #
      # CONTRACT:
      # - Returns ApplicationResult exclusively
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
        include Api::V1::CraEntries::Shared::ValidationHelpers

        def self.call(cra:, entry_params:, current_user:)
          new(cra: cra, entry_params: entry_params, current_user: current_user).call
        end

        def initialize(cra:, entry_params:, current_user:)
          @cra = cra
          @entry_params = entry_params
          @current_user = current_user
        end

        def call
          # Input validation - CTO SAFE PATCH
          return ApplicationResult.not_found unless cra
          return ApplicationResult.fail(error: :validation_error, status: :validation_error, message: "Entry parameters are required") unless entry_params
          return ApplicationResult.fail(error: :validation_error, status: :validation_error, message: "Current user is required") unless current_user



          # Permission validation
          permission_result = validate_permissions
          return permission_result unless permission_result.nil?

          # CRA lifecycle validation
          lifecycle_result = check_cra_modifiable
          return lifecycle_result unless lifecycle_result.nil?

          # Build entry
          @entry = build_entry
          return ApplicationResult.fail(error: :validation_error, status: :validation_error, message: "Failed to build entry") unless @entry

          # Validate entry
          entry_validation = validate_entry
          return entry_validation unless entry_validation.nil?

          # Mission company validation - Business rule
          mission_company_validation = validate_mission_company
          return mission_company_validation unless mission_company_validation.nil?

          # Check for duplicates
          duplicate_result = check_duplicate
          return duplicate_result unless duplicate_result.nil?

          # Save entry with associations in a single transaction
          save_entry_with_associations_transaction

          # Recalculate CRA totals
          recalculate_cra_totals

          # Success response - CTO SAFE PATCH: ApplicationResult.success
          ApplicationResult.success_entry(
            serialize_entry(@entry),
            serialize_cra(cra.reload)
          )
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "[CraEntries::CreateService] Record validation failed: #{e.message}"
          Rails.logger.error e.backtrace.first(10).join("\n")
          ApplicationResult.fail(
            error: :validation_error,
            status: :unprocessable_entity,
            message: e.record.errors.full_messages.join(', ')
          )
        rescue => e
          Rails.logger.error "[CraEntries::CreateService] Unexpected error: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.first(10).join("\n")
          ApplicationResult.fail(
            error: :internal_error,
            status: :internal_error,
            message: "An unexpected error occurred: #{e.message}"
          )
        end

        private

        attr_reader :cra, :entry_params, :current_user

        # === Input Validation ===

        def validate_inputs
          # CTO SAFE PATCH: Removed basic validations - moved to call method
          # Required fields validation
          missing_fields = []
          missing_fields << 'date' unless entry_params[:date].present?
          missing_fields << 'quantity' unless entry_params[:quantity].present?
          missing_fields << 'unit_price' unless entry_params[:unit_price].present?
          missing_fields << 'mission_id' unless entry_params[:mission_id].present?

          if missing_fields.any?
            return ApplicationResult.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Missing required fields: #{missing_fields.join(', ')}"
            )
          end

          nil
        end

        def validate_permissions
          unless cra.created_by_user_id == current_user.id
            return ApplicationResult.fail(
              error: :unauthorized,
              status: :unauthorized,
              message: "Only the CRA creator can add entries to this CRA"
            )
          end

          nil
        end

        def check_cra_modifiable
          if cra.locked?
            return ApplicationResult.fail(
              error: :conflict,
              status: :conflict,
              message: "Locked CRAs cannot be modified"
            )
          end

          if cra.submitted?
            return ApplicationResult.fail(
              error: :conflict,
              status: :conflict,
              message: "Submitted CRAs cannot be modified"
            )
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
            return ApplicationResult.fail(
              error: :validation_error,
              status: :validation_error,
              message: @entry.errors.full_messages.join(', ')
            )
          end

          # Additional business validations
          if @entry.quantity.negative?
            return ApplicationResult.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Quantity cannot be negative"
            )
          end

          if @entry.unit_price.negative?
            return ApplicationResult.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Unit price cannot be negative"
            )
          end

          if @entry.date.nil?
            return ApplicationResult.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Date is invalid"
            )
          end

          if @entry.date > Date.current
            return ApplicationResult.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Date cannot be in the future"
            )
          end

          nil
        end

        # === Mission Company Validation ===

        def validate_mission_company
          mission = Mission.find_by(id: mission_id)
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: "Mission not found"
          ) unless mission

          user_company_ids = current_user.user_companies.pluck(:company_id)
          mission_company_ids = mission.mission_companies.pluck(:company_id)

          unless (user_company_ids & mission_company_ids).any?
            return ApplicationResult.fail(
              error: :validation_error,
              status: :unprocessable_entity,
              message: "Mission does not belong to user's company"
            )
          end

          nil
        end



        # === Duplicate Check ===

        def check_duplicate
          # TEMPORARY: Always return error to test if this method is called
          Rails.logger.info "[CraEntries::CreateService] TEMPORARY: Always returning duplicate error for testing"
          return ApplicationResult.fail(
            error: :duplicate_entry,
            status: :conflict,
            message: "TEMPORARY: Always duplicate error for testing"
          )
        end

        # === Save Entry ===

        def save_entry_with_associations_transaction
          ActiveRecord::Base.transaction do
            # Create main entry
            @entry.save!

            # Create CRA-Entry association
            CraEntryCra.create!(
              cra_id: cra.id,
              cra_entry_id: @entry.id
            )

            # Create Entry-Mission association (optional - non-blocking for SQL injection protection)
            if mission_id.present? && Mission.exists?(mission_id)
              CraEntryMission.create!(
                cra_entry_id: @entry.id,
                mission_id: mission_id
              )
            end

            # Create CRA-Mission association if not exists
            # Create CRA-Mission association if not exists (optional - non-blocking for SQL injection protection)
            if mission_id.present? && Mission.exists?(mission_id) && !CraMission.exists?(cra_id: cra.id, mission_id: mission_id)
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

          # CTO SAFE PATCH: Non-bang method to avoid 500 errors
          if cra.update(
            total_days: total_days,
            total_amount: total_amount.to_i,
            updated_at: Time.current
          )
            Rails.logger.info "[CraEntries::CreateService] Recalculated totals for CRA #{cra.id}: #{total_days} days, #{total_amount} amount"
          else
            Rails.logger.error "[CraEntries::CreateService] Failed to update CRA totals: #{cra.errors.full_messages.join(', ')}"
            # Don't return error here - totals calculation failure shouldn't break creation
          end
        end

        # === Serialization ===

        def serialize_entry(entry)
          {
            data: {
              id: entry.id,
              type: "cra_entry",
              attributes: {
                date: entry.date,
                quantity: entry.quantity,
                unit_price: entry.unit_price,
                description: entry.description,
                created_at: entry.created_at,
                updated_at: entry.updated_at,
                mission_id: entry.cra_entry_missions.first&.mission_id
              },
              relationships: {}
            }
          }
        end

        def serialize_cra(cra)
          {
            data: {
              id: cra.id,
              type: "cra",
              attributes: {
                month: cra.month,
                year: cra.year,
                status: cra.status,
                description: cra.description,
                total_days: cra.total_days,
                total_amount: cra.total_amount,
                currency: cra.currency,
                created_at: cra.created_at,
                updated_at: cra.updated_at,
                locked_at: cra.locked_at
              },
              relationships: {
                user: {
                  data: {
                    id: cra.created_by_user_id.to_s,
                    type: "user"
                  }
                }
              }
            }
          }
        end

        # === Helpers ===

        def mission_id
          @mission_id ||= begin
            # Handle both Hash and JSON string parameters for L452 test compatibility
            params = entry_params.is_a?(String) ? JSON.parse(entry_params) : entry_params
            params[:mission_id] || params['mission_id']
          rescue JSON::ParserError
            # Fallback to direct access if JSON parsing fails
            entry_params[:mission_id]
          end
        end
      end
    end
  end
end
