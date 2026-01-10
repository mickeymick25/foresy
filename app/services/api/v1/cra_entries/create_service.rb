# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      # Service for creating CRA entries with comprehensive business rule validation
      # Uses FC07-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = CreateService.call(
      #     cra: cra,
      #     entry_params: { date: '2025-01-15', quantity: 1, unit_price: 50000 },
      #     mission_id: mission.id,
      #     current_user: user
      #   )
      #   result.entry # => CraEntry
      #
      # @raise [CraErrors::CraLockedError] if CRA is locked
      # @raise [CraErrors::CraSubmittedError] if CRA is submitted
      # @raise [CraErrors::InvalidPayloadError] if parameters are invalid
      # @raise [CraErrors::DuplicateEntryError] if entry already exists for mission/date
      # @raise [CraErrors::UnauthorizedError] if user lacks access
      # @raise [CraErrors::MissionNotFoundError] if mission not accessible
      #
      class CreateService
        Result = Struct.new(:entry, keyword_init: true) do
          def success?
            true
          end
        end

        def self.call(cra:, entry_params:, mission_id:, current_user:)
          new(cra: cra, entry_params: entry_params, mission_id: mission_id, current_user: current_user).call
        end

        def initialize(cra:, entry_params:, mission_id:, current_user:)
          @cra = cra
          @entry_params = entry_params
          @mission_id = mission_id
          @current_user = current_user
        end

        def call
          Rails.logger.info "[CraEntries::CreateService] Creating entry for CRA #{@cra&.id}, user #{@current_user&.id}"

          validate_inputs!
          check_permissions!
          entry = build_entry!
          check_duplicate!
          save_entry!(entry)

          Rails.logger.info "[CraEntries::CreateService] Successfully created entry #{entry.id}"
          Result.new(entry: entry)
        end

        private

        attr_reader :cra, :entry_params, :mission_id, :current_user

        # === Validation ===

        def validate_inputs!
          raise CraErrors::InvalidPayloadError.new('CRA is required', field: :cra) unless cra.present?

          unless entry_params.present?
            raise CraErrors::InvalidPayloadError.new('Entry parameters are required',
                                                     field: :entry_params)
          end
          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                     field: :current_user)
          end

          validate_entry_params!
          validate_mission_id! if mission_id.present?

          # Check mission existence early to avoid validation issues later
          check_mission_exists! if mission_id.present?
        end

        def validate_entry_params!
          raise CraErrors::InvalidPayloadError.new('Date is required', field: :date) unless entry_params[:date].present?

          unless entry_params[:quantity].present?
            raise CraErrors::InvalidPayloadError.new('Quantity is required',
                                                     field: :quantity)
          end
          unless entry_params[:unit_price].present?
            raise CraErrors::InvalidPayloadError.new('Unit price is required',
                                                     field: :unit_price)
          end

          validate_date!
          validate_quantity!
          validate_unit_price!
          validate_description!
        end

        def validate_date!
          return unless entry_params[:date].present?

          Date.parse(entry_params[:date].to_s)
        rescue ArgumentError
          raise CraErrors::InvalidPayloadError.new('Date must be in valid format (YYYY-MM-DD)', field: :date)
        end

        def validate_quantity!
          return unless entry_params[:quantity].present?

          quantity = entry_params[:quantity].to_d
          unless quantity.positive?
            raise CraErrors::InvalidPayloadError.new('Quantity must be greater than 0',
                                                     field: :quantity)
          end
          if quantity > 365
            raise CraErrors::InvalidPayloadError.new('Quantity cannot exceed 365 days',
                                                     field: :quantity)
          end
        end

        def validate_unit_price!
          return unless entry_params[:unit_price].present?

          unit_price = entry_params[:unit_price].to_i
          unless unit_price.positive?
            raise CraErrors::InvalidPayloadError.new('Unit price must be greater than 0',
                                                     field: :unit_price)
          end
          if unit_price > 100_000_000
            raise CraErrors::InvalidPayloadError.new('Unit price cannot exceed 1,000,000 EUR',
                                                     field: :unit_price)
          end
        end

        def validate_description!
          return unless entry_params[:description].present?

          description = entry_params[:description].to_s
          if description.length > 500
            raise CraErrors::InvalidPayloadError.new('Description cannot exceed 500 characters',
                                                     field: :description)
          end
        end

        def validate_mission_id!
          return if valid_mission_id_format?

          raise CraErrors::InvalidPayloadError.new('Invalid mission_id format', field: :mission_id)
        end

        def valid_mission_id_format?
          if mission_id.is_a?(String)
            mission_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i) ||
              mission_id.match?(/\A[0-9]+\z/)
          elsif mission_id.is_a?(Integer)
            mission_id.positive?
          else
            false
          end
        end

        # === Permissions ===

        def check_permissions!
          check_cra_access!
          check_cra_modifiable!
          check_mission_access! if mission_id.present?
        end

        def check_cra_access!
          accessible_cras = Cra.accessible_to(current_user)
          return if accessible_cras.exists?(id: cra.id)

          raise CraErrors::UnauthorizedError, 'User does not have access to this CRA'
        end

        def check_cra_modifiable!
          raise CraErrors::CraLockedError if cra.locked?
          raise CraErrors::CraSubmittedError, 'Cannot add entries to submitted CRAs' if cra.submitted?
        end

        def check_mission_exists!
          mission = Mission.find_by(id: mission_id)
          raise CraErrors::MissionNotFoundError, 'Mission does not exist' unless mission.present?
        end

        def check_mission_access!
          return if user_has_mission_access?

          raise CraErrors::MissionNotFoundError, 'User does not have access to the specified mission'
        end

        def user_has_mission_access?
          Mission.joins(:mission_companies)
                 .joins('INNER JOIN user_companies ON user_companies.company_id = mission_companies.company_id')
                 .where(id: mission_id)
                 .where(user_companies: { user_id: current_user.id, role: %w[independent client] })
                 .exists?
        end

        # === Build Entry ===

        def build_entry!
          entry = CraEntry.new(build_entry_attributes)

          # NOTE: Associations are created later in save_entry! to avoid validation issues
          # This allows for proper factory associations and cleaner test data setup

          raise CraErrors::InvalidPayloadError, entry.errors.full_messages.join(', ') unless entry.valid?

          entry
        end

        def build_entry_attributes
          {
            date: parse_date(entry_params[:date]),
            quantity: entry_params[:quantity].to_d,
            unit_price: entry_params[:unit_price].to_i,
            description: entry_params[:description]&.to_s&.strip
          }.compact
        end

        def parse_date(date_param)
          return nil if date_param.blank?

          Date.parse(date_param.to_s)
        rescue ArgumentError
          nil
        end

        # === Duplicate Check ===

        def check_duplicate!
          return unless mission_id.present?

          entry_date = parse_date(entry_params[:date])
          return unless duplicate_entry_exists?(entry_date)

          raise CraErrors::DuplicateEntryError
        end

        def duplicate_entry_exists?(date)
          CraEntry.joins(:cra_entry_cras, :cra_entry_missions)
                  .where(cra_entry_cras: { cra_id: cra.id })
                  .where(cra_entry_missions: { mission_id: mission_id })
                  .where(date: date)
                  .where(deleted_at: nil)
                  .exists?
        end

        # === Save ===

        def save_entry!(entry)
          ActiveRecord::Base.transaction do
            entry.save!
            CraEntryCra.find_or_create_by!(cra_id: cra.id, cra_entry_id: entry.id)

            if mission_id.present?
              CraEntryMission.create!(cra_entry_id: entry.id, mission_id: mission_id)
              CraMissionLinker.link_cra_to_mission!(cra.id, mission_id)
            end

            # Recalculate CRA totals after creating the entry
            recalculate_cra_totals!

            entry.reload
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "[CraEntries::CreateService] Validation failed: #{e.record.errors.full_messages.join(', ')}"
          raise CraErrors::InvalidPayloadError, e.record.errors.full_messages.join(', ')
        end

        def recalculate_cra_totals!
          # Get all active (non-deleted) entries for this CRA
          active_entries = CraEntry.joins(:cra_entry_cras)
                                   .where(cra_entry_cras: { cra_id: cra.id })
                                   .where(deleted_at: nil)

          # Calculate total days (sum of quantities)
          total_days = active_entries.sum(:quantity)

          # Calculate total amount (sum of quantity * unit_price)
          total_amount = active_entries.sum { |entry| entry.quantity * entry.unit_price }

          # Update CRA with new totals
          cra.update!(total_days: total_days, total_amount: total_amount)

          Rails.logger.info "[CraEntries::CreateService] Recalculated totals for CRA #{cra.id}: " \
                            "#{total_days} days, #{total_amount} amount"
        end
      end
    end
  end
end
