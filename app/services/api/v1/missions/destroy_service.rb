# frozen_string_literal: true

module Api
  module V1
    module Missions
      # Service for soft-deleting missions with comprehensive business rule validation
      # Uses FC06-compliant business exceptions instead of Result monads
      #
      # @example
      #   result = DestroyService.call(mission: mission, current_user: user)
      #   result.mission # => Mission (soft deleted)
      #
      # @raise [CraErrors::MissionLockedError] if mission is locked
      # @raise [CraErrors::MissionInUseError] if mission is linked to CRAs
      # @raise [CraErrors::MissionNotFoundError] if mission not found or already deleted
      # @raise [CraErrors::UnauthorizedError] if user lacks access
      #
      class DestroyService
        # Enhanced Result struct with proper error handling
        Result = Struct.new(:mission, :errors, :error_type, keyword_init: true) do
          def success?
            error_type.nil?
          end

          def value?
            success? ? mission : nil
          end

          def value!
            raise "Cannot call value! on failed result" unless success?
            mission
          end

          # Factory methods for different scenarios
          def self.success(mission)
            new(mission: mission, errors: nil, error_type: nil)
          end

          def self.failure(errors, error_type)
            new(mission: nil, errors: errors, error_type: error_type)
          end
        end

        def self.call(mission:, current_user:)
          new(mission: mission, current_user: current_user).call
        end

        def initialize(mission:, current_user:)
          @mission = mission
          @current_user = current_user
        end

        def call
          Rails.logger.info "[Missions::DestroyService] Deleting mission #{@mission&.id}"

          validate_inputs!
          check_permissions!
          check_business_rules!
          perform_soft_delete!

          Rails.logger.info "[Missions::DestroyService] Successfully deleted mission #{@mission.id}"
          Result.success(@mission)
        rescue CraErrors::MissionNotFoundError => e
          Rails.logger.warn "[Missions::DestroyService] Mission not found: #{e.message}"
          Result.failure([e.message], :not_found)
        rescue CraErrors::UnauthorizedError, CraErrors::NoIndependentCompanyError => e
          Rails.logger.warn "[Missions::DestroyService] Unauthorized: #{e.message}"
          Result.failure([e.message], :forbidden)
        rescue CraErrors::MissionLockedError => e
          Rails.logger.warn "[Missions::DestroyService] Mission locked: #{e.message}"
          Result.failure([e.message], :conflict)
        rescue CraErrors::MissionInUseError => e
          Rails.logger.warn "[Missions::DestroyService] Mission in use: #{e.message}"
          Result.failure([e.message], :conflict)
        rescue CraErrors::InvalidPayloadError => e
          Rails.logger.warn "[Missions::DestroyService] Validation failed: #{e.message}"
          Result.failure([e.message], :validation_failed)
        rescue StandardError => e
          Rails.logger.error "[Missions::DestroyService] Unexpected error: #{e.message}"
          Rails.logger.error "[Missions::DestroyService] Backtrace: #{e.backtrace.first(5).join("\n")}" if e.respond_to?(:backtrace)
          Result.failure([e.message], :internal_error)
        end

        private

        attr_reader :mission, :current_user

        # === Validation ===

        def validate_inputs!
          raise CraErrors::MissionNotFoundError unless mission.present?

          unless current_user.present?
            raise CraErrors::InvalidPayloadError.new('Current user is required',
                                                     field: :current_user)
          end
        end

        def check_permissions!
          check_mission_not_deleted!
          check_ownership!
          check_mission_access!
          check_mission_modifiable!
        end

        def check_mission_not_deleted!
          raise CraErrors::MissionNotFoundError, 'Mission is already deleted' if mission.discarded?
        end

        def check_ownership!
          # Only the creator can delete a mission
          return if mission.created_by_user_id == current_user.id

          raise CraErrors::UnauthorizedError, 'Only the mission creator can delete this mission'
        end

        def check_mission_access!
          accessible_missions = Mission.accessible_to(current_user)
          return if accessible_missions.exists?(id: mission.id)

          raise CraErrors::UnauthorizedError, 'User does not have access to this mission'
        end

        def check_mission_modifiable!
          raise CraErrors::MissionLockedError if mission.locked?

          # Check if mission has specific status that prevents deletion
          allowed_statuses = %w[draft lead active]
          return if allowed_statuses.include?(mission.status)

          raise CraErrors::InvalidPayloadError, 'Mission cannot be deleted in current status'
        end

        # === Business Rules ===

        def check_business_rules!
          check_mission_usage!
          check_cra_dependencies!
        end

        def check_mission_usage!
          # Check if mission is being used in active CRAs
          active_cras_with_mission = CraMission.joins(:cra)
                                              .where(mission_id: mission.id)
                                              .where.not(cras: { status: 'locked' })
                                              .exists?

          if active_cras_with_mission
            raise CraErrors::MissionInUseError, 'Mission is linked to active CRAs and cannot be deleted'
          end
        end

        def check_cra_dependencies!
          # Check if mission has any CRA entries
          cra_entries_with_mission = CraEntry.joins(:cra_entry_missions)
                                           .where(cra_entry_missions: { mission_id: mission.id })
                                           .where(deleted_at: nil)
                                           .exists?

          if cra_entries_with_mission
            raise CraErrors::MissionInUseError, 'Mission has CRA entries and cannot be deleted'
          end
        end

        # === Delete ===

        def perform_soft_delete!
          ActiveRecord::Base.transaction do
            raise CraErrors::InternalError, 'Failed to delete mission' unless mission.discard

            mission.reload
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "[Missions::DestroyService] Soft delete failed: #{e.message}"
            raise CraErrors::InternalError, 'Failed to delete mission'
          end
        end
      end
    end
  end
end
