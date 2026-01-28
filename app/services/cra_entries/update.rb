# frozen_string_literal: true

# app/application/services/cra_entries/update.rb
# Adapted to use Domain::CraEntry::CraEntry for business validations
# New Application layer structure - Phase 1 of Step 6 - CraEntry Services
# Single responsibility: Update CRA entry with business validations
# Returns ApplicationResult exclusively - no business exceptions raised

module Services
  module CraEntries
    # Service for updating CRA entries with business validations
    # Uses ApplicationResult contract for consistent Service → Controller communication
    #
    # CONTRACT:
    # - Returns ApplicationResult exclusively
    # - No business exceptions raised
    # - No HTTP concerns in service
    # - Single source of truth for business rules (Domain::CraEntry::CraEntry)
    #
    # @example
    #   result = Update.call(
    #     cra_entry: entry,
    #     entry_params: { date: '2024-12-15', quantity: 8.0, unit_price: 75000, description: 'Updated work' },
    #     current_user: user
    #   )
    #   result.ok? # => true/false
    #   result.data # => { item: {...}, cra: {...} }
    #
    class Update
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
        return validation_result unless validation_result.nil?

        # Business validation using Domain object
        domain_validation_result = validate_business_rules
        return domain_validation_result unless domain_validation_result.nil?

        # Permission validation
        permission_result = validate_permissions
        return permission_result unless permission_result.nil?

        # Duplicate validation (for updates)
        duplicate_result = validate_duplicate
        return duplicate_result unless duplicate_result.nil?

        # Update entry with associations
        update_result = update_entry_with_associations
        return update_result unless update_result.nil?

        # Success response
        ApplicationResult.success(
          data: {
            item: serialize_entry(update_result[:entry]),
            cra: serialize_cra(update_result[:cra])
          },
          status: :ok
        )
      rescue StandardError => e
        ApplicationResult.fail(
          error: :internal_error,
          status: :internal_server_error,
          message: "Failed to update CRA entry: #{e.message}"
        )
      end

      private

      attr_reader :cra_entry, :entry_params, :current_user

      # === Validation ===

      def validate_inputs
        # Required parameters validation
        unless cra_entry.present?
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: 'CRA entry not found'
          )
        end

        unless entry_params.present?
          return ApplicationResult.fail(
            error: :bad_request,
            status: :bad_request,
            message: 'Entry parameters are required'
          )
        end

        unless current_user.present?
          return ApplicationResult.fail(
            error: :bad_request,
            status: :bad_request,
            message: 'Current user is required'
          )
        end

        # Check if entry is not soft-deleted
        if cra_entry.deleted_at.present?
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: 'Cannot update deleted entry'
          )
        end

        nil # All input validations passed
      end

      def validate_business_rules
        # Validate entry parameters using Domain::CraEntry::CraEntry
        # Create temporary domain object for validation
        temp_entry = ::Domain::CraEntry::CraEntry.new(
          date: entry_params[:date] || cra_entry.date,
          quantity: entry_params[:quantity] || cra_entry.quantity,
          unit_price: entry_params[:unit_price] || cra_entry.unit_price,
          description: entry_params[:description] || cra_entry.description
        )

        unless temp_entry.valid_date?
          return ApplicationResult.fail(
            error: :validation_error,
            status: :unprocessable_content,
            message: 'Invalid date format'
          )
        end

        unless temp_entry.valid_quantity?
          return ApplicationResult.fail(
            error: :validation_error,
            status: :unprocessable_content,
            message: "Quantity must be between 0 and #{::Domain::CraEntry::CraEntry::MAX_QUANTITY} days"
          )
        end

        unless temp_entry.valid_unit_price?
          return ApplicationResult.fail(
            error: :validation_error,
            status: :unprocessable_content,
            message: "Unit price must be between 0 and #{::Domain::CraEntry::CraEntry::MAX_UNIT_PRICE} cents"
          )
        end

        unless temp_entry.valid_description?
          return ApplicationResult.fail(
            error: :validation_error,
            status: :unprocessable_content,
            message: "Description cannot exceed #{::Domain::CraEntry::CraEntry::MAX_DESCRIPTION_LENGTH} characters"
          )
        end

        nil # All business rule validations passed
      end

      def validate_permissions
        # Permission validation
        unless cra_entry.created_by_user_id == current_user.id
          return ApplicationResult.fail(
            error: :forbidden,
            status: :forbidden,
            message: 'You can only update entries you created'
          )
        end

        # Check CRA status using domain rules
        cra = cra_entry.cra_entry_cras.first&.cra
        unless cra.present?
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: 'Associated CRA not found'
          )
        end

        unless ::Domain::CraEntry::CraEntry.cra_modifiable?(cra.status)
          return ApplicationResult.fail(
            error: :conflict,
            status: :conflict,
            message: 'CRA is locked and cannot be modified'
          )
        end

        nil # Permission validation passed
      end

      def validate_duplicate
        # Check for duplicate entry (excluding current entry)
        mission_id = extract_mission_id
        date = entry_params[:date] || cra_entry.date

        if mission_id.present?
          existing_entry = CraEntry.joins(:cra_entry_cras, :cra_entry_missions)
                                   .where(cra_entry_cras: { cra_id: cra_entry.cra_entry_cras.first.cra.id })
                                   .where(cra_entry_missions: { mission_id: mission_id })
                                   .where(date: date)
                                   .where(deleted_at: nil)
                                   .where.not(id: cra_entry.id)
                                   .first

          if existing_entry.present?
            return ApplicationResult.fail(
              error: :conflict,
              status: :conflict,
              message: 'An entry already exists for this mission and date'
            )
          end
        end

        nil # No duplicate found
      end

      # === Entry Update ===

      def update_entry_with_associations
        # Extract mission_id from parameters
        mission_id = extract_mission_id

        # Find and validate mission if provided
        mission_validation = find_and_validate_mission(mission_id)
        return mission_validation unless mission_validation.success?

        mission = mission_validation.data[:mission]

        # Get the associated CRA
        cra = cra_entry.cra_entry_cras.first&.cra
        unless cra.present?
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: 'Associated CRA not found'
          )
        end

        # Update entry with associations in transaction
        begin
          ActiveRecord::Base.transaction do
            # Update entry
            cra_entry.update!(
              date: entry_params[:date] || cra_entry.date,
              quantity: entry_params[:quantity] || cra_entry.quantity,
              unit_price: entry_params[:unit_price] || cra_entry.unit_price,
              description: entry_params[:description] || cra_entry.description
            )

            # Update mission association if mission_id changed
            existing_mission_id = cra_entry.cra_entry_missions.first&.mission_id
            if mission_id != existing_mission_id
              # Remove old association
              CraEntryMission.where(cra_entry_id: cra_entry.id).delete_all

              # Add new association if mission_id provided
              CraEntryMission.create!(cra_entry_id: cra_entry.id, mission_id: mission.id) if mission.present?
            end

            { entry: cra_entry, cra: cra }
          end
        rescue ActiveRecord::RecordInvalid => e
          ApplicationResult.fail(
            error: :validation_error,
            status: :unprocessable_content,
            message: "Failed to update entry: #{e.message}"
          )
        end
      end

      # === Utility Methods ===

      def extract_mission_id
        entry_params[:mission_id] ||
          entry_params.dig(:mission, :id) ||
          cra_entry.cra_entry_missions.first&.mission_id
      end

      # === Serialization ===

      def serialize_entry(entry)
        CraEntrySerializer.new(entry).serialize
      end

      def serialize_cra(cra)
        CraSerializer.new(cra).serialize
      end

      def find_and_validate_mission(mission_id)
        return ApplicationResult.success(data: { mission: nil }) unless mission_id.present?

        mission = Mission.find_by(id: mission_id)
        unless mission.present?
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: 'Mission not found'
          )
        end

        # Validate mission access using domain rules
        unless ::Domain::CraEntry::CraEntry.user_has_mission_access?(mission_id, current_user)
          return ApplicationResult.fail(
            error: :forbidden,
            status: :forbidden,
            message: 'User does not have access to the specified mission'
          )
        end

        ApplicationResult.success(data: { mission: mission })
      end
    end
  end
end
