# frozen_string_literal: true

# lib/application_result.rb
# FAÇADE UNIQUE ApplicationResult - Solution Platinum Architecture
# Remplace tous les alias complexes par une façade simple et stable
#
# CONTRAT PLATINUM:
# - UNE seule constante publique: ApplicationResult
# - Interface uniforme et prévisible
# - Auto-suffisante, aucun require magique
# - Compatible avec tous les services CRA/CRA Entries

class ApplicationResult
  # Internal Result Object – inherits from ApplicationResult so that
  # instances are recognised as ApplicationResult objects by `be_a` matchers.
  class ResultObject < ApplicationResult
    attr_reader :success, :status, :data, :error, :message, :meta

    def initialize(success:, status:, data:, error:, **options)
      super()
      @success = success
      @status = status
      @data = data
      @error = error
      @message = options[:message]
      @meta = options[:meta] || {}
    end

    def success?
      success == true
    end

    def failure?
      success == false
    end

    def value
      success? ? data : nil
    end

    def value!
      raise 'Cannot call value! on failed result' unless success?

      data
    end

    # Helpers for controllers
    def items
      data&.[](:items)
    end

    def item
      data&.[](:item)
    end

    def cra
      data&.[](:cra)
    end

    def total_count
      data&.[](:total_count)
    end

    def pagination
      data&.[](:pagination)
    end

    def totals
      data&.[](:totals)
    end
  end

  # SUCCESS PATTERNS – accept an optional `message` keyword so callers can
  # provide a human‑readable success description (used by service tests).
  def self.success(data:, message: nil, meta: {})
    ResultObject.new(
      success: true,
      status: :ok,
      data: data,
      error: nil,
      message: message,
      meta: meta
    )
  end

  def self.created(data:, message: nil, meta: {})
    ResultObject.new(
      success: true,
      status: :created,
      data: data,
      error: nil,
      message: message,
      meta: meta
    )
  end

  def self.no_content(message: nil, meta: {})
    ResultObject.new(
      success: true,
      status: :no_content,
      data: nil,
      error: nil,
      message: message,
      meta: meta
    )
  end

  # FAILURE PATTERNS
  def self.fail(error:, status:, message: nil, meta: {})
    ResultObject.new(
      success: false,
      status: status,
      data: nil,
      error: error,
      message: message,
      meta: meta
    )
  end

  def self.bad_request(error:, message: nil, meta: {})
    fail(error: error, status: :bad_request, message: message, meta: meta)
  end

  def self.unauthorized(error:, message: nil, meta: {})
    fail(error: error, status: :unauthorized, message: message, meta: meta)
  end

  def self.forbidden(error:, message: nil, meta: {})
    fail(error: error, status: :forbidden, message: message, meta: meta)
  end

  def self.not_found(error:, message: nil, meta: {})
    fail(error: error, status: :not_found, message: message, meta: meta)
  end

  def self.conflict(error:, message: nil, meta: {})
    fail(error: error, status: :conflict, message: message, meta: meta)
  end

  def self.unprocessable_entity(error:, message: nil, meta: {})
    fail(error: error, status: :unprocessable_entity, message: message, meta: meta)
  end

  def self.internal_error(error:, message: nil, meta: {})
    fail(error: error, status: :internal_error, message: message, meta: meta)
  end

  # FACTORY METHODS for compatibility with various service return formats

  # For CRA Entries
  def self.success_entry(entry, cra = nil)
    data = { item: entry }
    data[:cra] = cra if cra.present?
    success(data: data)
  end

  def self.success_entries(entries, cra = nil, total_count: nil)
    data = { items: entries }
    data[:cra] = cra if cra.present?
    data[:total_count] = total_count if total_count.present?
    success(data: data)
  end

  # For CRA
  def self.success_cra(cra)
    success(data: { item: cra })
  end

  def self.success_cras(cras, pagination: nil, totals: nil)
    data = { items: cras }
    data[:pagination] = pagination if pagination.present?
    data[:totals] = totals if totals.present?
    success(data: data)
  end
end
