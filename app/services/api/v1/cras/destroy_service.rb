# frozen_string_literal: true

# app/services/api/v1/cras/destroy_service.rb
# Migration vers ApplicationResult - Étape 2 du plan de migration
# Contrat unique : tous les services retournent ApplicationResult
# Aucune exception métier levée - tout via Result.fail

require_relative '../../../../../lib/application_result'

module Api
  module V1
    module Cras
      # Service for soft-deleting CRAs with comprehensive business rule validation
      # Uses ApplicationResult contract for consistent Service → Controller communication
      #
      # CONTRACT:
      # - Returns ApplicationResult exclusively
      # - No business exceptions raised
      # - No HTTP concerns in service
      # - Single source of truth for business rules
      #
      # @example
      #   result = DestroyService.call(
      #     cra: cra,
      #     current_user: user
      #   )
      #   result.ok? # => true/false
      #   result.data # => { item: { ... } }
      #
      class DestroyService
        def self.call(cra:, current_user:)
          new(cra: cra, current_user: current_user).call
        end

        def initialize(cra:, current_user:)
          @cra = cra
          @current_user = current_user
        end

        def call
          # Input validation
          validation_result = validate_inputs
          return validation_result unless validation_result.nil?

          # Permission validation
          permission_result = validate_permissions
          return permission_result unless permission_result.nil?

          # Perform soft delete
          delete_result = perform_soft_delete
          return delete_result unless delete_result.nil?

          # Success response
          Result.ok(
            data: {
              item: serialize_cra(@cra)
            },
            status: :ok
          )
        # No rescue StandardError - let exceptions bubble up for debugging

        private

        attr_reader :cra, :current_user

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

          # Current user validation
          unless current_user.present?
            return Result.fail(
              error: :invalid_payload,
              status: :invalid_payload,
              message: "Current user is required"
            )
          end

          nil # All validations passed
        end

        def validate_permissions
          # Not deleted validation
          if cra.discarded?
            return Result.fail(
              error: :not_found,
              status: :not_found,
              message: "CRA is already deleted"
            )
          end

          # Ownership validation
          unless cra.created_by_user_id == current_user.id
            return Result.fail(
              error: :unauthorized,
              status: :unauthorized,
              message: "Only the CRA creator can delete this CRA"
            )
          end

          # CRA modifiable validation
          if cra.locked?
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: "Locked CRAs cannot be deleted"
            )
          elsif cra.submitted?
            return Result.fail(
              error: :conflict,
              status: :conflict,
              message: "Submitted CRAs cannot be deleted"
            )
          end

          # No active entries validation
          if cra.cra_entries.active.any?
            return Result.fail(
              error: :bad_request,
              status: :bad_request,
              message: "Cannot delete CRA with active entries. Please delete all entries first."
            )
          end

          nil # All permissions validated
        end

        # === Delete ===

        def perform_soft_delete
          begin
            ActiveRecord::Base.transaction do
              unless cra.discard
                return Result.fail(
                  error: :internal_error,
                  status: :internal_error,
                  message: "Failed to delete CRA"
                )
              end

              cra.reload
            end
            nil # Success
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "[Cras::DestroyService] Soft delete failed: #{e.message}"
            Result.fail(
              error: :internal_error,
              status: :internal_error,
              message: "Failed to delete CRA"
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
