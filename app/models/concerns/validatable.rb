# frozen_string_literal: true

# Validatable Concern
#
# Concern pour factoriser les validations communes entre les modèles
# Évite la duplication de code et assure la cohérence des règles métier
#
# Usage:
#   class Cra < ApplicationRecord
#     include Validatable
#
#     validates_presence :month, :year, :status
#     validates_numericality :year, greater_than: 2000
#     validates_length :description, maximum: 2000
#   end
module Validatable
  extend ActiveSupport::Concern

  included do
    # Valider la présence avec options personnalisées
    def self.validates_presence(*attributes)
      options = attributes.extract_options!
      validates(*attributes, presence: options)
    end

    # Valider la présence avec conditions
    def self.validates_presence_if(attribute, condition_attribute)
      validates attribute, presence: true, if: -> { send(condition_attribute).present? }
    end

    # Valider la présence uniquement si un autre attribut est présent
    def self.validates_presence_unless(attribute, condition_attribute)
      validates attribute, presence: true, unless: -> { send(condition_attribute).blank? }
    end

    # Valider la présence avec message personnalisé
    def self.validates_presence_with_message(attribute, message)
      validates attribute, presence: { message: message }
    end
  end

  # Valider une date
  # @param attribute [Symbol] nom de l'attribut date
  # @param options [Hash] options de validation
  # @option options [Boolean] :future_only autoriser seulement les dates futures
  # @option options [Boolean] :past_only autoriser seulement les dates passées
  # @option options [Date] :before autoriser seulement avant cette date
  # @option options [Date] :after autoriser seulement après cette date
  def validate_date(attribute, options = {})
    value = send(attribute)
    return if value.blank?

    errors.add(attribute, 'must be a valid date') unless value.is_a?(Date) || value.is_a?(Time)

    if value.is_a?(Date) || value.is_a?(Time)
      if options[:future_only] && value <= Date.current
        errors.add(attribute, 'must be in the future')
      elsif options[:past_only] && value >= Date.current
        errors.add(attribute, 'must be in the past')
      elsif options[:before] && value >= options[:before]
        errors.add(attribute, "must be before #{options[:before]}")
      elsif options[:after] && value <= options[:after]
        errors.add(attribute, "must be after #{options[:after]}")
      end
    end
  end

  # Valider une période (mois/année)
  # @param month_attribute [Symbol] nom de l'attribut mois
  # @param year_attribute [Symbol] nom de l'attribut année
  def validate_period(month_attribute, year_attribute)
    month = send(month_attribute)
    year = send(year_attribute)
    return if month.blank? || year.blank?

    # Valider le mois
    errors.add(month_attribute, 'must be between 1 and 12') if month.to_i < 1 || month.to_i > 12

    # Valider l'année
    current_year = Date.current.year
    if year.to_i < 2000
      errors.add(year_attribute, 'must be 2000 or later')
    elsif year.to_i > current_year + 5
      errors.add(year_attribute, 'cannot be more than 5 years in the future')
    end
  end

  # Valider une devise
  # @param attribute [Symbol] nom de l'attribut devise
  def validate_currency(attribute)
    currency = send(attribute)
    return if currency.blank?

    errors.add(attribute, 'must be a valid ISO 4217 currency code') unless currency.match?(/\A[A-Z]{3}\z/)
  end

  # Valider une quantité avec granularité
  # @param attribute [Symbol] nom de l'attribut quantité
  # @param options [Hash] options de validation
  # @option options [Float] :step granularité (défaut: 0.25)
  # @option options [Float] :maximum quantité maximale
  # @option options [Float] :minimum quantité minimale
  def validate_quantity(attribute, options = {})
    quantity = send(attribute)
    return if quantity.blank?

    step = options[:step] || 0.25
    maximum = options[:maximum]
    minimum = options[:minimum] || 0

    # Vérifier la granularité
    remainder = (quantity.to_f / step) % 1
    if remainder > 0.001 && remainder < 0.999 # Tolérance pour les erreurs de précision
      errors.add(attribute, "must be in increments of #{step}")
    end

    # Vérifier les limites
    errors.add(attribute, "must be greater than #{minimum}") if quantity.to_f <= minimum
    errors.add(attribute, "cannot exceed #{maximum}") if maximum && quantity.to_f > maximum
  end

  # Valider un prix unitaire (en centimes)
  # @param attribute [Symbol] nom de l'attribut prix
  # @param options [Hash] options de validation
  # @option options [Integer] :maximum prix maximal en centimes
  # @option options [Integer] :minimum prix minimal en centimes
  def validate_unit_price(attribute, options = {})
    price = send(attribute)
    return if price.blank?

    errors.add(attribute, 'must be a positive integer') unless price.is_a?(Integer) && price.positive?

    errors.add(attribute, "cannot exceed #{options[:maximum]} cents") if options[:maximum] && price > options[:maximum]

    if options[:minimum] && price < options[:minimum]
      errors.add(attribute, "must be at least #{options[:minimum]} cents")
    end
  end

  # Valider l'unicité avec condition
  # @param attribute [Symbol] nom de l'attribut
  # @param scope [Symbol, Array] attribut(s) pour le scope d'unicité
  # @param conditions [Hash] conditions supplémentaires
  def validate_uniqueness(attribute, scope: nil, conditions: {})
    value = send(attribute)
    return if value.blank?

    relation = where(attribute => value)

    # Appliquer le scope si spécifié
    if scope.present?
      if scope.is_a?(Array)
        scope.each do |s|
          relation = relation.where(s => send(s))
        end
      else
        relation = relation.where(scope => send(scope))
      end
    end

    # Appliquer les conditions supplémentaires
    conditions.each do |key, val|
      relation = relation.where(key => val)
    end

    # Exclure l'enregistrement courant si on fait une mise à jour
    relation = relation.where.not(id: id) if persisted?

    errors.add(attribute, 'has already been taken') if relation.exists?
  end

  # Valider les champs financiers
  # @param attributes [Array] attributs financiers à valider
  def validate_financial_fields(*attributes)
    attributes.each do |attribute|
      value = send(attribute)
      next if value.blank?

      errors.add(attribute, 'must be a positive number') unless value.is_a?(Numeric) && value >= 0
    end
  end

  # Valider les champs décimaux
  # @param attribute [Symbol] nom de l'attribut
  # @param options [Hash] options de validation
  # @option options [Integer] :precision précision maximale
  # @option options [Integer] :scale échelle (décimales)
  # @option options [Float] :minimum valeur minimale
  # @option options [Float] :maximum valeur maximale
  def validate_decimal(attribute, options = {})
    value = send(attribute)
    return if value.blank?

    unless value.is_a?(Numeric)
      errors.add(attribute, 'must be a number')
      return
    end

    precision = options[:precision]
    scale = options[:scale]
    minimum = options[:minimum]
    maximum = options[:maximum]

    # Vérifier la précision et l'échelle
    if precision && scale
      total_digits = value.to_s.gsub('.', '').length
      decimal_places = value.to_s.split('.').last.length
      if total_digits > precision || decimal_places > scale
        errors.add(attribute, "must have at most #{precision} total digits with #{scale} decimal places")
      end
    end

    # Vérifier les limites
    errors.add(attribute, "must be at least #{minimum}") if minimum && value < minimum
    errors.add(attribute, "cannot exceed #{maximum}") if maximum && value > maximum
  end

  # Valider un code postal
  # @param attribute [Symbol] nom de l'attribut
  # @param country [String] code pays pour la validation spécifique
  def validate_postal_code(attribute, country = 'FR')
    code = send(attribute)
    return if code.blank?

    case country.upcase
    when 'FR'
      errors.add(attribute, 'must be a valid French postal code (5 digits)') unless code.match?(/\A\d{5}\z/)
    when 'US'
      errors.add(attribute, 'must be a valid US ZIP code') unless code.match?(/\A\d{5}(-\d{4})?\z/)
    else
      # Validation générique pour autres pays
      errors.add(attribute, 'must be a valid postal code') unless code.match?(/\A[A-Za-z0-9\-\s]{3,10}\z/)
    end
  end

  # Méthodes de classe pour les validations communes
  class_methods do
    # Valider l'unicité avec message personnalisé
    def validates_unique(attribute, **options)
      validates attribute, uniqueness: options
    end

    # Valider la longueur avec options avancées
    def validates_length_range(attribute, minimum: nil, maximum: nil, **options)
      validation_options = { length: {} }
      validation_options[:length][:minimum] = minimum if minimum
      validation_options[:length][:maximum] = maximum if maximum
      validation_options.merge!(options)

      validates attribute, validation_options
    end

    # Valider le format avec patterns prédéfinis
    def validates_format_predefined(attribute, type, **options)
      patterns = {
        email: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i,
        phone: /\A\+?[\d\s\-()]{10,}\z/,
        url: %r{\Ahttps?://[^\s]+\z},
        slug: /\A[a-z0-9-]+\z/,
        uuid: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
      }

      pattern = patterns[type.to_sym]
      if pattern
        validates attribute, format: { with: pattern, message: "must be a valid #{type}" }.merge(options)
      else
        raise ArgumentError, "Unknown format type: #{type}"
      end
    end
  end
end
