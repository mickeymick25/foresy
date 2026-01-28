# frozen_string_literal: true

# app/application/services/cra_entries/destroy.rb
# Adapted to use Domain::CraEntry::CraEntry for business validations
# New Application layer structure - Phase 1 of Step 6 - CraEntry Services
# Single responsibility: Destroy (soft delete) CRA entries with business rule validation
# Returns ApplicationResult exclusively - no business exceptions raised

module Services
  module CraEntries
    # Service for soft deleting CRA entries with comprehensive business rule validation
    # Uses ApplicationResult contract for consistent Service → Controller communication
    #
    # CONTRACT:
    # - Returns ApplicationResult exclusively
    # - No business exceptions raised
    # - No HTTP concerns in service
    # - Single source of truth for business rules (Domain::CraEntry::CraEntry)
    #
    # @example
    #   result = Destroy.call(
    #     cra_entry: entry,
    #     current_user: user
    #   )
    #   result.ok? # => true/false
    #   result.data # => { item: {...}, cra: {...} }
    #
    class Destroy
      def self.call(cra_entry:, current_user:)
        new(cra_entry: cra_entry, current_user: current_user).call
      end

      def initialize(cra_entry:, current_user:)
        @cra_entry = cra_entry
        @current_user = current_user
      end

      def call
        # Input validation
        validation_result = validate_inputs
        return validation_result unless validation_result.nil?

        # Permission validation
        permission_result = validate_permissions
        return permission_result unless permission_result.nil?

        # Business rule validation using Domain object
        domain_validation_result = validate_business_rules
        return domain_validation_result unless domain_validation_result.nil?

        # Soft delete entry
        delete_result = soft_delete_entry
        return delete_result unless delete_result.nil?

        # Success response
        ApplicationResult.success(
          data: {
            item: serialize_entry(delete_result[:entry]),
            cra: serialize_cra(delete_result[:cra])
          },
          status: :ok
        )
      rescue ActiveRecord::RecordInvalid => e
        ApplicationResult.fail(
          error: :validation_error,
          status: :unprocessable_content,
          message: "Failed to delete entry: #{e.message}"
        )
      rescue StandardError => e
        ApplicationResult.fail(
          error: :internal_error,
          status: :internal_server_error,
          message: "Failed to delete CRA entry: #{e.message}"
        )
      end

      private

      attr_reader :cra_entry, :current_user

      # === Validation ===

      def validate_inputs
        # CRA entry validation
        unless cra_entry.present?
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: 'CRA entry not found'
          )
        end

        unless current_user.present?
          return ApplicationResult.fail(
            error: :bad_request,
            status: :bad_request,
            message: 'Current user is required'
          )
        end

        # Check if entry is already soft-deleted
        if cra_entry.deleted_at.present?
          return ApplicationResult.fail(
            error: :conflict,
            status: :conflict,
            message: 'CRA entry is already deleted'
          )
        end

        nil # All input validations passed
      end

      def validate_permissions
        # Check if user owns the CRA containing this entry
        cra = cra_entry.cra_entry_cras.first&.cra
        unless cra.present?
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: 'CRA not found for this entry'
          )
        end

        unless cra.created_by_user_id == current_user.id
          return ApplicationResult.fail(
            error: :forbidden,
            status: :forbidden,
            message: 'You can only delete entries for your own CRAs'
          )
        end

        nil # Permission validation passed
      end

      def validate_business_rules
        # Validate that CRA can be modified using Domain rules
        cra = cra_entry.cra_entry_cras.first&.cra
        unless cra.present?
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: 'Associated CRA not found'
          )
        end

        # Use Domain::CraEntry::CraEntry to check if CRA is modifiable
        unless ::Domain::CraEntry::CraEntry.cra_modifiable?(cra.status)
          return ApplicationResult.fail(
            error: :conflict,
            status: :conflict,
            message: 'CRA is locked and cannot be modified'
          )
        end

        nil # Business rule validations passed
      end

      # === Soft Delete Operations ===

      def soft_delete_entry
        # Get the associated CRA before soft delete
        cra = cra_entry.cra_entry_cras.first&.cra

        # Soft delete entry in transaction
        CraEntry.transaction do
          # Perform soft delete
          cra_entry.update!(deleted_at: Time.current)
        end

        { entry: cra_entry, cra: cra }
      end

      # === Serialization ===

      def serialize_entry(entry)
        {
          id: entry.id,
          date: entry.date,
          quantity: entry.quantity.to_f,
          unit_price: entry.unit_price.to_i,
          description: entry.description,
          deleted_at: entry.deleted_at,
          created_at: entry.created_at,
          updated_at: entry.updated_at
        }
      end

      def serialize_cra(cra)
        CraSerializer.new(cra).serialize
      end
    end
  end
end
