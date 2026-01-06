# frozen_string_literal: true

module Api
  module V1
    module Cras
      # Service for updating CRAs with comprehensive business rule validation
      # Uses FC07-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = UpdateService.call(
      #     cra: cra,
      #     cra_params: { description: 'Updated description' },
      #     current_user: user
      #   )
      #   result.cra # => Cra
      #
      # @raise [CraErrors::CraLockedError] if CRA is locked
      # @raise [CraErrors::CraSubmittedError] if CRA is submitted
      # @raise [CraErrors::InvalidPayloadError] if parameters are invalid
      # @raise [CraErrors::InvalidTransitionError] if status transition is invalid
      # @raise [CraErrors::UnauthorizedError] if user is not the creator
      #
      class UpdateService
        Result = Struct.new(:cra, keyword_init: true)

        def self.call(cra:, cra_params:, current_user:)
          new(cra: cra, cra_params: cra_params, current_user: current_user).call
        end

        def initialize(cra:, cra_params:, current_user:)
          @cra = cra
          @cra_params = cra_params
          @current_user = current_user
        end

        def call
          Rails.logger.info "[Cras::UpdateService] Updating CRA #{@cra&.id} for user #{@current_user&.id}"

          validate_inputs!
          check_permissions!
          perform_update!

          Rails.logger.info "[Cras::UpdateService] Successfully updated CRA #{@cra.id}"
          Result.new(cra: @cra)
        end

        private

        attr_reader :cra, :cra_params, :current_user

        # === Validation ===

        def validate_inputs!
          raise CraErrors::CraNotFoundError unless cra.present?

          unless cra_params.present?
            raise CraErrors::InvalidPayloadError.new('CRA parameters are required',
                                                     field: :cra_params)
          end
          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                     field: :current_user)
          end
        end

        # === Permissions ===

        def check_permissions!
          check_ownership!
          check_cra_modifiable!
          check_status_transition! if cra_params[:status].present?
        end

        def check_ownership!
          return if cra.created_by_user_id == current_user.id

          raise CraErrors::UnauthorizedError, 'Only the CRA creator can modify this CRA'
        end

        def check_cra_modifiable!
          raise CraErrors::CraLockedError if cra.locked?
          raise CraErrors::CraSubmittedError, 'Submitted CRAs cannot be modified' if cra.submitted?
        end

        def check_status_transition!
          new_status = cra_params[:status].to_s
          return if new_status == cra.status
          return if cra.can_transition_to?(new_status)

          raise CraErrors::InvalidTransitionError.new(cra.status, new_status)
        end

        # === Update ===

        def perform_update!
          ActiveRecord::Base.transaction do
            update_attributes = build_update_attributes

            handle_update_error unless cra.update(update_attributes)

            cra.reload
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.warn "[Cras::UpdateService] Validation failed: #{e.record.errors.full_messages.join(', ')}"
          handle_record_invalid(e.record)
        end

        def build_update_attributes
          attributes = {}

          if cra_params[:month].present?
            month = cra_params[:month].to_i
            attributes[:month] = month if month.between?(1, 12)
          end

          if cra_params[:year].present?
            year = cra_params[:year].to_i
            attributes[:year] = year if year >= 2000
          end

          if cra_params[:status].present?
            new_status = cra_params[:status].to_s
            attributes[:status] = new_status if Cra::VALID_STATUSES.include?(new_status)
          end

          if cra_params[:description].present?
            description = cra_params[:description].to_s.strip
            attributes[:description] = description[0..2000]
          end

          if cra_params[:currency].present?
            currency = cra_params[:currency].to_s.upcase
            attributes[:currency] = currency if currency.match?(/\A[A-Z]{3}\z/)
          end

          attributes
        end

        def handle_update_error
          errors = cra.errors.full_messages

          if cra.errors[:status]&.any? { |msg| msg.include?('invalid_transition') }
            raise CraErrors::InvalidTransitionError.new(cra.status, cra_params[:status])
          elsif errors.any? { |msg| msg.include?('already exists') }
            raise CraErrors::DuplicateEntryError, 'A CRA already exists for this period'
          else
            raise CraErrors::InvalidPayloadError, errors.join(', ')
          end
        end

        def handle_record_invalid(record)
          if record.errors[:status]&.any? { |msg| msg.include?('invalid_transition') }
            raise CraErrors::InvalidTransitionError.new(cra.status, cra_params[:status])
          elsif record.errors.full_messages.any? { |msg| msg.include?('already exists') }
            raise CraErrors::DuplicateEntryError, 'A CRA already exists for this period'
          else
            raise CraErrors::InvalidPayloadError, record.errors.full_messages.join(', ')
          end
        end
      end
    end
  end
end
