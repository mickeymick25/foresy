# frozen_string_literal: true

# CRA Errors - FC07 Business Exceptions
#
# Exceptions métier pour la gestion des CRA (Compte Rendu d'Activité)
# Conformes au contrat FC07 avec codes d'erreur HTTP explicites
#
# Usage dans les services:
#   raise CraErrors::CraLockedError if cra.locked?
#
# Usage dans les controllers:
#   rescue_from CraErrors::CraLockedError, with: :handle_cra_locked
#
module CraErrors
  # Base class for all application business errors (not inheriting from StandardError)
  # This prevents ErrorRenderable from catching these exceptions as 500 errors
  class ApplicationBusinessError < StandardError
    attr_reader :code, :http_status

    def initialize(message = nil, code: nil, http_status: :unprocessable_entity)
      @code = code
      @http_status = http_status
      super(message || default_message)
    end

    def default_message
      'An error occurred with the business logic'
    end

    def to_h
      {
        error: self.class.name.demodulize.underscore,
        code: code,
        message: message
      }
    end
  end

  # Base class for all CRA-related errors
  class BaseError < ApplicationBusinessError
    def default_message
      'An error occurred with the CRA'
    end
  end

  # 409 Conflict - CRA is locked and cannot be modified
  class CraLockedError < BaseError
    def initialize(message = nil)
      super(
        message || 'CRA is locked and cannot be modified',
        code: :cra_locked,
        http_status: :conflict
      )
    end
  end

  # 409 Conflict - CRA is submitted and cannot be modified
  class CraSubmittedError < BaseError
    def initialize(message = nil)
      super(
        message || 'CRA is submitted and cannot be modified',
        code: :cra_submitted,
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

  # 409 Conflict - Duplicate entry exists
  class DuplicateEntryError < BaseError
    def initialize(message = nil)
      super(
        message || 'An entry already exists for this mission and date',
        code: :duplicate_entry,
        http_status: :conflict
      )
    end
  end

  # 404 Not Found - CRA not found or not accessible
  class CraNotFoundError < BaseError
    def initialize(message = nil)
      super(
        message || 'CRA not found',
        code: :not_found,
        http_status: :not_found
      )
    end
  end

  # 404 Not Found - CRA Entry not found
  class EntryNotFoundError < BaseError
    def initialize(message = nil)
      super(
        message || 'CRA entry not found',
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

  # 404 Not Found - Mission not found or not accessible
  class MissionNotFoundError < BaseError
    def initialize(message = nil)
      super(
        message || 'Mission not found or not accessible',
        code: :mission_not_found,
        http_status: :not_found
      )
    end
  end

  # 422 Unprocessable Entity - Mission not linked to CRA
  class MissionNotLinkedError < BaseError
    def initialize(message = nil)
      super(
        message || 'Mission is not linked to this CRA',
        code: :mission_not_linked,
        http_status: :unprocessable_entity
      )
    end
  end

  # 422 Unprocessable Entity - Date out of CRA period
  class DateOutOfPeriodError < BaseError
    def initialize(message = nil)
      super(
        message || 'Entry date is outside the CRA period',
        code: :date_out_of_period,
        http_status: :unprocessable_entity
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
