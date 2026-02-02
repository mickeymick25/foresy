# frozen_string_literal: true

# Mission Errors - FC06 Business Exceptions
#
# Exceptions métier pour la gestion des Missions
# Conformes au contrat FC06 avec codes d'erreur HTTP explicites
#
# Usage dans les services:
#   raise MissionErrors::MissionLockedError if mission.locked?
#
# Usage dans les controllers:
#   rescue_from MissionErrors::MissionLockedError, with: :handle_mission_locked
#
module MissionErrors
  # Base class for all Mission-related errors
  class BaseError < StandardError
    attr_reader :code, :http_status

    def initialize(message = nil, code: nil, http_status: :unprocessable_entity)
      @code = code
      @http_status = http_status
      super(message || default_message)
    end

    def default_message
      'An error occurred with the Mission'
    end

    def to_h
      {
        error: self.class.name.demodulize.underscore,
        code: code,
        message: message
      }
    end
  end

  # 409 Conflict - Mission is locked and cannot be modified
  class MissionLockedError < BaseError
    def initialize(message = nil)
      super(
        message || 'Mission is locked and cannot be modified',
        code: :mission_locked,
        http_status: :conflict
      )
    end
  end

  # 409 Conflict - Mission is in use and cannot be deleted
  class MissionInUseError < BaseError
    def initialize(message = nil)
      super(
        message || 'Mission is in use and cannot be modified',
        code: :mission_in_use,
        http_status: :conflict
      )
    end
  end

  # 422 Unprocessable Entity - Invalid status transition
  class InvalidTransitionError < BaseError
    def initialize(from_status = nil, to_status = nil)
      message = if from_status && to_status
                  "Invalid transition from '#{from_status}' to '#{to_status}'"
                else
                  'Invalid status transition'
                end
      super(message, code: :invalid_transition, http_status: :unprocessable_entity)
    end
  end

  # 422 Unprocessable Entity - Invalid payload/parameters
  class InvalidPayloadError < BaseError
    attr_reader :field

    def initialize(message = nil, field: nil)
      @field = field
      super(
        message || 'Invalid payload',
        code: :invalid_payload,
        http_status: :unprocessable_entity
      )
    end

    def to_h
      super.merge(field: field).compact
    end
  end

  # 409 Conflict - Duplicate mission exists
  class DuplicateEntryError < BaseError
    def initialize(message = nil)
      super(
        message || 'A mission with this name already exists',
        code: :duplicate_entry,
        http_status: :conflict
      )
    end
  end

  # 404 Not Found - Mission not found or not accessible
  class MissionNotFoundError < BaseError
    def initialize(message = nil)
      super(
        message || 'Mission not found',
        code: :not_found,
        http_status: :not_found
      )
    end
  end

  # 403 Forbidden - User not authorized
  class UnauthorizedError < BaseError
    def initialize(message = nil)
      super(
        message || 'User is not authorized to perform this action',
        code: :unauthorized,
        http_status: :forbidden
      )
    end
  end

  # 403 Forbidden - No independent company
  class NoIndependentCompanyError < BaseError
    def initialize(message = nil)
      super(
        message || 'User must have an independent company to perform this action',
        code: :no_independent_company,
        http_status: :forbidden
      )
    end
  end

  # 500 Internal Server Error - Unexpected error
  class InternalError < BaseError
    def initialize(message = nil)
      super(
        message || 'An unexpected error occurred',
        code: :internal_error,
        http_status: :internal_server_error
      )
    end
  end
end
