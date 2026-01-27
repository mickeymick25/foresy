# frozen_string_literal: true

# app/application/services/cra_entries/create.rb
# Adapted to use Domain::CraEntry::CraEntry for business validations
# New Application layer structure - Step 6 of migration plan
# Single responsibility: Create CRA entries with business rule validation
# Returns ApplicationResult exclusively - no business exceptions raised



module Services
  module CraEntries
      # Service for creating CRA entries
      # Uses ApplicationResult contract and Domain::CraEntry::CraEntry for business rules
      #
      # CONTRACT:
      # - Returns ApplicationResult exclusively
      # - Uses Domain::CraEntry::CraEntry for business validation
      # - No HTTP concerns in service
      # - Single source of truth for business rules (Domain::CraEntry::CraEntry)
      #
      # @example
      #   result = Create.call(
      #     cra: cra,
      #     entry_params: {
      #       date: Date.new(2024, 12, 15),
      #       quantity: 8.0,
      #       unit_price: 75000,
      #       description: "Development work"
      #     },
      #     current_user: user
      #   )
      #   result.ok? # => true/false
      #   result.data # => { id: "...", date: "...", ... }
      #
      class Create
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
          return validation_result unless validation_result.nil?

          # Business validation using Domain object
          domain_validation_result = validate_business_rules
          return domain_validation_result unless domain_validation_result.nil?

          # Permission validation
          permission_result = validate_permissions
          return permission_result unless permission_result.nil?

          # Business logic validation
          business_result = validate_business_logic
          return business_result unless business_result.nil?

          # Create the entry
          create_result = create_entry
          return create_result unless create_result.nil?

          # Success response
          ApplicationResult.success(
            data: serialize_entry(create_result[:entry])
          )
        end

        private

        attr_reader :cra, :entry_params, :current_user

        # === Input Validation ===

        def validate_inputs
          return ApplicationResult.fail(
            error: :not_found,
            status: :not_found,
            message: "Not Found"
          ) unless cra.present?

          return ApplicationResult.fail(
            error: :bad_request,
            status: :bad_request,
            message: "Entry parameters are required"
          ) unless entry_params.present?

          return ApplicationResult.fail(
            error: :bad_request,
            status: :bad_request,
            message: "Current user is required"
          ) unless current_user.present?

          nil # All input validations passed
        end

        # === Business Validation Using Domain ===

        def validate_business_rules
          # Create Domain object for validation
          domain_entry = ::Domain::CraEntry::CraEntry.new(
            date: entry_params[:date],
            quantity: entry_params[:quantity],
            unit_price: entry_params[:unit_price],
            description: entry_params[:description]
          )

          # Check if domain object is valid
          unless domain_entry.valid?
            return ApplicationResult.fail(
              error: :validation_error,
              status: :unprocessable_content,
              message: "Invalid entry data: #{domain_entry.errors.full_messages.join(', ')}"
            )
          end

          nil # Business rule validations passed
        end

        # === Permission Validation ===

        def validate_permissions
          # Check if user has permission to modify this CRA
          unless cra.created_by_user_id == current_user.id
            return ApplicationResult.fail(
              error: :forbidden,
              status: :forbidden,
              message: "Forbidden"
            )
          end

          # Check if CRA is modifiable (business rule)
          unless cra.status == "draft"
            return ApplicationResult.fail(
              error: :conflict,
              status: :conflict,
              message: "Cannot modify entries in submitted or locked CRAs"
            )
          end

          nil # Permission validations passed
        end

        # === Business Logic Validation ===

        def validate_business_logic
          # Check for duplicate entry (business rule)
          mission_id = extract_mission_id
          if mission_id.present?
            existing_entry = CraEntry.joins(:cra_entry_cras, :cra_entry_missions)
                                   .where(cra_entry_cras: { cra_id: cra.id })
                                   .where(cra_entry_missions: { mission_id: mission_id })
                                   .where(date: entry_params[:date])
                                   .where(deleted_at: nil)
                                   .first

            if existing_entry.present?
              return ApplicationResult.fail(
                error: :conflict,
                status: :conflict,
                message: "An entry already exists for this mission and date"
              )
            end
          end

          # Validate mission access if mission_id is provided
          if mission_id.present?
            mission = Mission.find_by(id: mission_id)
            return ApplicationResult.fail(
              error: :not_found,
              status: :not_found,
              message: "Not Found"
            ) unless mission.present?

            # Check mission access via company relationships (business rule)
            user_company_ids = UserCompany.where(user_id: current_user.id).pluck(:company_id)
            mission_company_ids = MissionCompany.where(mission_id: mission_id).pluck(:company_id)

            unless (user_company_ids & mission_company_ids).any?
              return ApplicationResult.fail(
                error: :validation_error,
                status: :unprocessable_content,
                message: "Mission does not belong to user's company"
              )
            end
          end

          nil # Business logic validations passed
        end

        # === Entry Creation ===

        def create_entry
          begin
            # Create the entry with associations in a transaction
            entry = CraEntry.transaction do
              new_entry = CraEntry.create!(
                date: entry_params[:date],
                quantity: entry_params[:quantity],
                unit_price: entry_params[:unit_price],
                description: entry_params[:description],
                created_by_user_id: current_user.id
              )

              # Associate with CRA
              CraEntryCra.create!(
                cra_entry_id: new_entry.id,
                cra_id: cra.id
              )

              # Associate with Mission if provided
              mission_id = extract_mission_id
              if mission_id.present?
                CraEntryMission.create!(
                  cra_entry_id: new_entry.id,
                  mission_id: mission_id
                )
              end

              new_entry
            end

            { entry: entry }
          rescue StandardError => e
            ApplicationResult.fail(
              error: :internal_error,
              status: :internal_server_error,
              message: "Failed to create entry: #{e.message}"
            )
          end
        end

        # === Helper Methods ===

        def extract_mission_id
          entry_params[:mission_id] || entry_params.dig(:mission, :id)
        end

        def serialize_entry(entry)
          {
            id: entry.id,
            date: entry.date,
            quantity: entry.quantity,
            unit_price: entry.unit_price,
            description: entry.description,
            created_at: entry.created_at,
            updated_at: entry.updated_at
          }
        end
      end
    end
  end
