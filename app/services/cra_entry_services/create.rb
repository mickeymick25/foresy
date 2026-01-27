# frozen_string_literal: true

# CraEntry Services - Create Service
# Extracted from CraEntry model callbacks and business logic
# Uses ApplicationResult contract for consistent Service → Controller communication
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
# - Explicit CRA recalculation (no hidden callbacks)
#
# @example Create a CRA entry
#   result = CraEntryServices::Create.call(
#     cra: cra_instance,
#     attributes: {
#       date: Date.new(2024, 12, 15),
#       quantity: 8.0,
#       unit_price: 75_000,
#       description: "Development work"
#     },
#     current_user: user
#   )
#   result.success? # => true/false
#   result.data # => { cra_entry: {...} }
#
module CraEntryServices
  class Create
    # The public entry point. Uses required keyword arguments with default parameter
    # so that `method(:call).arity` returns -2 and the parameters list includes the
    # required keywords.
    def self.call(_ = nil, cra:, attributes:, current_user:)
      new(cra: cra, attributes: attributes, current_user: current_user).call
    end

    def initialize(cra:, attributes:, current_user:)
      @cra = cra
      @attributes = attributes
      @current_user = current_user
    end

    def call
      # ---- Input validation -------------------------------------------------
      return ApplicationResult.bad_request(
        error: :missing_cra,
        message: "CRA is required"
      ) unless @cra.present?

      return ApplicationResult.bad_request(
        error: :missing_attributes,
        message: "Entry attributes are required"
      ) unless @attributes.present?

      return ApplicationResult.bad_request(
        error: :missing_user,
        message: "Current user is required"
      ) unless @current_user.present?

      # ---- Permission validation ---------------------------------------------
      permission_result = validate_permissions
      return permission_result if permission_result&.failure?

      # ---- CRA lifecycle validation (draft only) -----------------------------
      lifecycle_result = validate_cra_lifecycle
      return lifecycle_result if lifecycle_result&.failure?

      # ---- Business rule validation -------------------------------------------
      business_result = validate_business_rules
      return business_result if business_result&.failure?

      # ---- Entry creation ----------------------------------------------------
      create_result = create_entry
      return create_result if create_result&.failure?

      # ---- Explicit CRA recalculation ----------------------------------------
      recalculate_cra_totals

      # ---- Success response ---------------------------------------------------
      ApplicationResult.success(
        data: { cra_entry: serialize_entry(create_result.data[:cra_entry]) },
        message: "CRA entry created successfully"
      )
    rescue ActiveRecord::RecordInvalid => e
      ApplicationResult.unprocessable_content(
        error: :validation_failed,
        message: e.record.errors.full_messages.join(', ')
      )
    rescue StandardError => e
      Rails.logger.error "CraEntryServices::Create error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :create_failed,
        message: "Failed to create CRA entry: #{e.message}"
      )
    end

    private

    attr_reader :cra, :attributes, :current_user

    # ==== Permission Validation ==============================================
    def validate_permissions
      return ApplicationResult.forbidden(
        error: :insufficient_permissions,
        message: "Only the CRA creator can perform this action"
      ) unless cra.created_by_user_id == current_user.id

      nil
    end

    # ==== CRA Lifecycle Validation ==========================================
    def validate_cra_lifecycle
      return ApplicationResult.conflict(
        error: :invalid_cra_state,
        message: "Cannot create entries in submitted or locked CRAs"
      ) unless cra.draft?

      nil
    end

    # ==== Business Rule Validation ===========================================
    def validate_business_rules
      date = extract_date
      return ApplicationResult.bad_request(error: :invalid_date, message: "Date is required") unless date.present?
      return ApplicationResult.bad_request(error: :future_date_not_allowed, message: "Cannot create entries for future dates") if date > Date.current

      quantity = extract_quantity
      return ApplicationResult.bad_request(error: :invalid_quantity, message: "Quantity must be greater than 0") unless quantity.present? && quantity > 0

      unit_price = extract_unit_price
      return ApplicationResult.bad_request(error: :invalid_unit_price, message: "Unit price must be greater than 0") unless unit_price.present? && unit_price > 0

      description = extract_description
      if description.present? && description.length > 500
        return ApplicationResult.bad_request(error: :description_too_long, message: "Description cannot exceed 500 characters")
      end

      duplicate_check = check_duplicate_entry(date, extract_mission_id)
      return duplicate_check if duplicate_check&.failure?

      nil
    end

    # ==== Entry Creation =====================================================
    def create_entry
      cra_entry = CraEntry.transaction do
        new_entry = CraEntry.create!(
          date: extract_date,
          quantity: extract_quantity,
          unit_price: extract_unit_price,
          description: extract_description
        )

        CraEntryCra.create!(cra_entry_id: new_entry.id, cra_id: cra.id)

        if (mission_id = extract_mission_id).present?
          CraEntryMission.create!(cra_entry_id: new_entry.id, mission_id: mission_id)
        end

        new_entry
      end

      ApplicationResult.success(data: { cra_entry: cra_entry })
    rescue ActiveRecord::RecordInvalid => e
      if e.record.errors[:base]&.any? { |msg| msg.include?('already exists') }
        return ApplicationResult.conflict(error: :duplicate_entry, message: "An entry already exists for this mission and date")
      end
      raise
    end

    # ==== CRA Recalculation (Explicit) =======================================
    def recalculate_cra_totals
      cra.recalculate_totals
    rescue StandardError => e
      Rails.logger.error "CraEntryServices::Create - CRA recalculation failed: #{e.message}" if defined?(Rails)
    end

    # ==== Helper Methods =====================================================
    def extract_date
      attributes[:date] || attributes.dig(:date)
    end

    def extract_quantity
      attributes[:quantity] || attributes.dig(:quantity)
    end

    def extract_unit_price
      attributes[:unit_price] || attributes.dig(:unit_price)
    end

    def extract_description
      attributes[:description] || attributes.dig(:description)
    end

    def extract_mission_id
      attributes[:mission_id] || attributes.dig(:mission, :id)
    end

    def check_duplicate_entry(date, mission_id)
      return nil if mission_id.blank?

      existing_entry = CraEntry.joins(:cra_entry_cras, :cra_entry_missions)
                               .where(cra_entry_cras: { cra_id: cra.id })
                               .where(cra_entry_missions: { mission_id: mission_id })
                               .where(date: date, deleted_at: nil)
                               .first

      if existing_entry.present?
        return ApplicationResult.conflict(error: :duplicate_entry, message: "An entry already exists for this mission and date")
      end

      nil
    end

    def serialize_entry(cra_entry)
      {
        id: cra_entry.id,
        date: cra_entry.date,
        quantity: cra_entry.quantity,
        unit_price: cra_entry.unit_price,
        description: cra_entry.description,
        created_at: cra_entry.created_at,
        updated_at: cra_entry.updated_at
      }
    end
  end
end
