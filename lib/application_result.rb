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

module ApplicationResult
  # Internal Result Object
  class ResultObject
    attr_reader :success, :status, :data, :error, :message, :meta

    def initialize(success:, status:, data:, error:, message:, meta: {})
      @success = success
      @status = status
      @data = data
      @error = error
      @message = message
      @meta = meta
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
      raise "Cannot call value! on failed result" unless success?
      data
    end

    # Helpers pour les contrôleurs
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

  # SUCCESS PATTERNS
  def self.success(data:, meta: {})
    ResultObject.new(
      success: true,
      status: :ok,
      data: data,
      error: nil,
      message: nil,
      meta: meta
    )
  end

  def self.created(data:, meta: {})
    ResultObject.new(
      success: true,
      status: :created,
      data: data,
      error: nil,
      message: nil,
      meta: meta
    )
  end

  def self.no_content(meta: {})
    ResultObject.new(
      success: true,
      status: :no_content,
      data: nil,
      error: nil,
      message: nil,
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

  # FACTORY METHODS pour compatibilité avec les différents formats de services

  # Pour CRA Entries
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

  # Pour CRA
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

# Alias Result pour compatibilité temporaire
# Tous les services doivent migrer vers ApplicationResult.*
module Result
  def self.success(data:, meta: {})
    ApplicationResult.success(data: data, meta: meta)
  end

  def self.created(data:, meta: {})
    ApplicationResult.created(data: data, meta: meta)
  end

  def self.no_content(meta: {})
    ApplicationResult.no_content(meta: meta)
  end

  def self.fail(error:, status:, message: nil, meta: {})
    ApplicationResult.fail(error: error, status: status, message: message, meta: meta)
  end

  def self.bad_request(error:, message: nil, meta: {})
    ApplicationResult.bad_request(error: error, message: message, meta: meta)
  end

  def self.unauthorized(error:, message: nil, meta: {})
    ApplicationResult.unauthorized(error: error, message: message, meta: meta)
  end

  def self.forbidden(error:, message: nil, meta: {})
    ApplicationResult.forbidden(error: error, message: message, meta: meta)
  end

  def self.not_found(error:, message: nil, meta: {})
    ApplicationResult.not_found(error: error, message: message, meta: meta)
  end

  def self.conflict(error:, message: nil, meta: {})
    ApplicationResult.conflict(error: error, message: message, meta: meta)
  end

  def self.unprocessable_entity(error:, message: nil, meta: {})
    ApplicationResult.unprocessable_entity(error: error, message: message, meta: meta)
  end

  def self.internal_error(error:, message: nil, meta: {})
    ApplicationResult.internal_error(error: error, message: message, meta: meta)
  end

  # Factory methods pour compatibilité
  def self.success_entry(entry, cra = nil)
    ApplicationResult.success_entry(entry, cra)
  end

  def self.success_entries(entries, cra = nil, total_count: nil)
    ApplicationResult.success_entries(entries, cra, total_count: total_count)
  end

  def self.success_cra(cra)
    ApplicationResult.success_cra(cra)
  end

  def self.success_cras(cras, pagination: nil, totals: nil)
    ApplicationResult.success_cras(cras, pagination: pagination, totals: totals)
  end
end
