# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      # Service for updating CRA entries with comprehensive business rule validation
      # Uses FC07-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = UpdateService.call(
      #     entry: entry,
      #     entry_params: { quantity: 2, unit_price: 60000 },
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
      # @raise [CraErrors::EntryNotFoundError] if entry not found
      #
      class UpdateService
        Result = Struct.new(:entry, keyword_init: true)

        def self.call(entry:, entry_params:, mission_id:, current_user:)
          new(entry: entry, entry_params: entry_params, mission_id: mission_id, current_user: current_user).call
        end

        def initialize(entry:, entry_params:, mission_id:, current_user:)
          @entry = entry
          @entry_params = entry_params
          @mission_id = mission_id
          @current_user = current_user
        end

        def call
          Rails.logger.info "[CraEntries::UpdateService] Updating entry #{@entry&.id}"

          validate_inputs!
          check_permissions!
          validate_entry_params!
          check_duplicate!
          perform_update!

          # Recalculate CRA totals after updating the entry
          recalculate_cra_totals!

          Rails.logger.info "[CraEntries::UpdateService] Successfully updated entry #{@entry.id}"
          Result.new(entry: @entry)
        end

        private

        attr_reader :entry, :entry_params, :mission_id, :current_user

        # === Validation ===

        def validate_inputs!
          raise CraErrors::EntryNotFoundError unless entry.present?

          unless entry_params.present?
            raise CraErrors::InvalidPayloadError.new('Entry parameters are required',
                                                     field: :entry_params)
          end
          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                     field: :current_user)
          end
        end

        def check_permissions!
          check_cra_exists!
          check_cra_access!
          check_cra_modifiable!
          check_entry_modifiable!
          check_mission_access! if mission_id_changed?
        end

        def check_cra_exists!
          raise CraErrors::CraNotFoundError, 'Entry is not associated with a valid CRA' unless cra.present?
        end

        def check_cra_access!
          accessible_cras = Cra.accessible_to(current_user)
          return if accessible_cras.exists?(id: cra.id)

          raise CraErrors::UnauthorizedError, 'User does not have access to this CRA'
        end

        def check_cra_modifiable!
          raise CraErrors::CraLockedError if cra.locked?
          raise CraErrors::CraSubmittedError, 'Cannot modify entries in submitted CRAs' if cra.submitted?
        end

        def check_entry_modifiable!
          return if entry.modifiable?

          raise CraErrors::InvalidPayloadError, 'Entry cannot be modified'
        end

        def check_mission_access!
          return unless mission_id.present?
          return if user_has_mission_access?

          raise CraErrors::MissionNotFoundError, 'User does not have access to the specified mission'
        end

        def validate_entry_params!
          validate_date! if entry_params[:date].present?
          validate_quantity! if entry_params[:quantity].present?
          validate_unit_price! if entry_params[:unit_price].present?
          validate_description! if entry_params[:description].present?
        end

        def validate_date!
          date = Date.parse(entry_params[:date].to_s)
          raise CraErrors::InvalidPayloadError.new('Date cannot be in the future', field: :date) if date > Date.current

          if date < 2.years.ago.to_date
            raise CraErrors::InvalidPayloadError.new('Date cannot be more than 2 years in the past',
                                                     field: :date)
          end
        rescue ArgumentError
          raise CraErrors::InvalidPayloadError.new('Date must be a valid date', field: :date)
        end

        def validate_quantity!
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
          description = entry_params[:description].to_s
          if description.length > 500
            raise CraErrors::InvalidPayloadError.new('Description cannot exceed 500 characters',
                                                     field: :description)
          end
        end

        # === Duplicate Check ===

        def check_duplicate!
          return unless mission_id_changed? || date_changed?

          new_date = entry_params[:date].present? ? parse_date(entry_params[:date]) : entry.date
          new_mission_id = mission_id || current_mission_id

          return unless duplicate_entry_exists?(new_mission_id, new_date)

          raise CraErrors::DuplicateEntryError
        end

        def duplicate_entry_exists?(check_mission_id, date)
          return false unless check_mission_id && date

          CraEntry.joins(:cra_entry_cras, :cra_entry_missions)
                  .where(cra_entry_cras: { cra_id: cra.id })
                  .where(cra_entry_missions: { mission_id: check_mission_id })
                  .where(date: date)
                  .where(deleted_at: nil)
                  .where.not(id: entry.id)
                  .exists?
        end

        # === Update ===

        def perform_update!
          ActiveRecord::Base.transaction do
            entry.assign_attributes(build_update_attributes)
            handle_mission_association_update!
            entry.save!
            entry.reload
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "[CraEntries::UpdateService] Validation failed: #{e.record.errors.full_messages.join(', ')}"
          raise CraErrors::InvalidPayloadError, e.record.errors.full_messages.join(', ')
        end

        def build_update_attributes
          attributes = {}
          attributes[:date] = parse_date(entry_params[:date]) if entry_params[:date].present?
          attributes[:quantity] = entry_params[:quantity].to_d if entry_params[:quantity].present?
          attributes[:unit_price] = entry_params[:unit_price].to_i if entry_params[:unit_price].present?
          attributes[:description] = entry_params[:description].to_s.strip if entry_params[:description].present?
          attributes
        end

        def handle_mission_association_update!
          return if current_mission_id == mission_id

          entry.cra_entry_missions.destroy_all if current_mission_id.present?

          if mission_id.present?
            entry.cra_entry_missions.create!(mission_id: mission_id)
            CraMissionLinker.link_cra_to_mission!(cra.id, mission_id)
          end
        end

        # === Helpers ===

        def cra
          @cra ||= entry.cra
        end

        def current_mission_id
          @current_mission_id ||= entry.cra_entry_missions.first&.mission_id
        end

        def mission_id_changed?
          mission_id.present? && current_mission_id != mission_id
        end

        def date_changed?
          return false unless entry_params[:date].present?

          parse_date(entry_params[:date]) != entry.date
        end

        def parse_date(date_param)
          return nil if date_param.blank?

          Date.parse(date_param.to_s)
        rescue ArgumentError
          nil
        end

        def user_has_mission_access?
          Mission.joins(:mission_companies)
                 .joins('INNER JOIN user_companies ON user_companies.company_id = mission_companies.company_id')
                 .where(id: mission_id)
                 .where(user_companies: { user_id: current_user.id, role: %w[independent client] })
                 .exists?
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

          Rails.logger.info "[CraEntries::UpdateService] Recalculated totals for CRA #{cra.id}: " \
                            "#{total_days} days, #{total_amount} amount"
        end
      end
    end
  end
end
