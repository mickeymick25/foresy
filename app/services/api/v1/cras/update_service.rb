# frozen_string_literal: true

# app/services/api/v1/cras/update_service.rb
# Migration vers ApplicationResult - Étape 2 du plan de migration
# Contrat unique : tous les services retournent ApplicationResult
# Aucune exception métier levée - tout via Result.fail

require_relative '../../../../../lib/application_result'

module Api
  module V1
    module Cras
      # Service for updating CRAs with comprehensive business rule validation
      # Uses ApplicationResult contract for consistent Service → Controller communication
      #
      # CONTRACT:
      # - Returns ApplicationResult exclusively
      # - No business exceptions raised
      # - No HTTP concerns in service
      # - Single source of truth for business rules
      #
      # @example
      #   result = UpdateService.call(
      #     cra: cra,
      #     cra_params: { description: 'Updated description' },
      #     current_user: user
      #   )
      #   result.ok? # => true/false
      #   result.data # => { item: { ... } }
      #
      class UpdateService
        def self.call(cra:, cra_params:, current_user:)
          new(cra: cra, cra_params: cra_params, current_user: current_user).call
        end

        def initialize(cra:, cra_params:, current_user:)
          @cra = cra
          @cra_params = cra_params
          @current_user = current_user
        end

        def call
          # Input validation
          validation_result = validate_inputs
          return validation_result unless validation_result.nil?

          # Permission validation
          permission_result = validate_permissions
          return permission_result unless permission_result.nil?

          # Perform update
          update_result = perform_update
          return update_result unless update_result.nil?

          # Success response
          Result.ok(
            data: {
              item: serialize_cra(@cra)
            },
            status: :ok
          )
        # No rescue StandardError - let exceptions bubble up for debugging

        private

        attr_reader :cra, :cra_params, :current_user

        # === Validation ===

        def validate_inputs
          # CRA validation
          unless cra.present?
            return Result.fail(
              error: :not_found,
              status: :not_found,
              message: "CRA not found"
            )
          end

          # CRA params validation
          unless cra_params.present?
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "CRA parameters are required"
            )
          end

          # Current user validation
          unless current_user.present?
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Current user is required"
            )
          end

          nil # All validations passed
        end

        # === Permissions ===

        def validate_permissions
          # Ownership validation
          ownership_result = validate_ownership
          return ownership_result unless ownership_result.nil?

          # CRA modifiable validation
          modifiable_result = validate_cra_modifiable
          return modifiable_result unless modifiable_result.nil?

          # Status transition validation (if status is being updated)
          if cra_params[:status].present?
            transition_result = validate_status_transition
            return transition_result unless transition_result.nil?
          end

          nil # All permissions validated
        end

        def validate_ownership
          unless cra.created_by_user_id == current_user.id
            return Result.fail(
              error: :unauthorized,
              status: :unauthorized,
              message: "Only the CRA creator can modify this CRA"
            )
          end
          nil
        end

        def validate_cra_modifiable
          if cra.locked?
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: "Locked CRAs cannot be modified"
            )
          elsif cra.submitted?
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: "Submitted CRAs cannot be modified"
            )
          end
          nil
        end

        def validate_status_transition
          new_status = cra_params[:status].to_s
          return nil if new_status == cra.status

          unless cra.can_transition_to?(new_status)
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Invalid status transition from #{cra.status} to #{new_status}"
            )
          end
          nil
        end

        # === Update ===

        def perform_update
          begin
            ActiveRecord::Base.transaction do
              update_attributes = build_update_attributes

              unless cra.update(update_attributes)
                return handle_update_error
              end

              cra.reload
            end
            nil # Success
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.warn "[Cras::UpdateService] Validation failed: #{e.record.errors.full_messages.join(', ')}"
            handle_record_invalid(e.record)
          end
        end

        def build_update_attributes
          attributes = {}

          # Month validation
          if cra_params[:month].present?
            month = cra_params[:month].to_i
            if month.between?(1, 12)
              attributes[:month] = month
            end
          end

          # Year validation
          if cra_params[:year].present?
            year = cra_params[:year].to_i
            if year >= 2000
              attributes[:year] = year
            end
          end

          # Status validation
          if cra_params[:status].present?
            new_status = cra_params[:status].to_s
            if Cra::VALID_STATUSES.include?(new_status)
              attributes[:status] = new_status
            end
          end

          # Description validation
          if cra_params[:description].present?
            description = cra_params[:description].to_s.strip
            attributes[:description] = description[0..2000]
          end

          # Currency validation
          if cra_params[:currency].present?
            currency = cra_params[:currency].to_s.upcase
            if currency.match?(/\A[A-Z]{3}\z/)
              attributes[:currency] = currency
            end
          end

          attributes
        end

        def handle_update_error
          errors = cra.errors.full_messages

          if cra.errors[:status]&.any? { |msg| msg.include?('invalid_transition') }
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Invalid status transition"
            )
          elsif errors.any? { |msg| msg.include?('already exists') }
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: "A CRA already exists for this period"
            )
          else
            return Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: errors.join(', ')
            )
          end
        end

        def handle_record_invalid(record)
          errors = record.errors.full_messages

          if record.errors[:status]&.any? { |msg| msg.include?('invalid_transition') }
            Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: "Invalid status transition"
            )
          elsif errors.any? { |msg| msg.include?('already exists') }
            Result.fail(
              error: :conflict,
              status: :conflict,
              message: "A CRA already exists for this period"
            )
          else
            Result.fail(
              error: :validation_error,
              status: :validation_error,
              message: errors.join(', ')
            )
          end
        end

        # === Serialization ===

        def serialize_cra(cra)
          {
            id: cra.id,
            month: cra.month,
            year: cra.year,
            description: cra.description,
            currency: cra.currency,
            status: cra.status,
            total_days: cra.total_days,
            total_amount: cra.total_amount,
            created_at: cra.created_at,
            updated_at: cra.updated_at
          }
        end
      end
    end
  end
end
