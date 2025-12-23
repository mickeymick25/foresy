# frozen_string_literal: true

# ApmService - Application Performance Monitoring Service
#
# Service de standardisation APM qui permet d'utiliser différentes solutions
# de monitoring (NewRelic, Datadog) de manière transparente.
#
# Compatibilité :
# - NewRelic : Utilise NewRelic::Agent.add_custom_attributes
# - Datadog : Supporte l'API active_span (moderne) et active.span (legacy)
# - Fallback : Ne crash jamais si aucun service APM n'est disponible
class ApmService
  class << self
    # Vérifie si au moins un service APM est disponible et activé
    # @return [Boolean] true si un service APM est disponible
    def enabled?
      new_relic_available? || datadog_available?
    end

    # Ajoute un tag simple
    # @param key [String] Clé du tag
    # @param value [String, Integer, Float, Boolean] Valeur du tag
    # @return [void]
    def tag(key, value)
      return unless enabled?

      attributes = { key => value }
      add_attributes(attributes)
    rescue StandardError => e
      Rails.logger.debug { "APM add_attributes error: #{e.message}" } if defined?(Rails)
    end

    # Ajoute plusieurs attributs d'un coup
    # @param attributes [Hash] Hash d'attributs à ajouter
    # @return [void]
    def add_attributes(attributes = {})
      return unless can_add_attributes?(attributes)

      # Utilise NewRelic si disponible
      add_attributes_newrelic(attributes) if new_relic_available?

      # Utilise Datadog si disponible
      add_attributes_datadog(attributes) if datadog_available?
    rescue StandardError => e
      Rails.logger.debug { "APM add_attributes error: #{e.message}" } if defined?(Rails)
    end

    # Suit une opération avec sa durée
    # @param operation_name [String] Nom de l'opération
    # @param duration [Float] Durée en secondes
    # @return [void]
    def track_operation(operation_name, duration = nil)
      return unless enabled?
      return if operation_name.nil?

      attributes = { 'operation' => operation_name }
      attributes['operation_duration'] = duration if duration.is_a?(Numeric)

      add_attributes(attributes)
    rescue StandardError => e
      Rails.logger.debug { "APM track_operation error: #{e.message}" } if defined?(Rails)
    end

    private

    # Vérifie si on peut ajouter des attributs (réduit la complexité cyclomatique)
    # @param attributes [Hash] Attributs à vérifier
    # @return [Boolean] true si on peut ajouter les attributs
    def can_add_attributes?(attributes)
      return false if attributes.nil? || attributes.empty?

      enabled?
    end

    # Vérifie si NewRelic est disponible
    # @return [Boolean]
    def new_relic_available?
      return false unless defined?(NewRelic)

      return false unless defined?(NewRelic::Agent)

      return false unless NewRelic::Agent.respond_to?(:add_custom_attributes)

      true
    rescue StandardError
      false
    end

    # Vérifie si Datadog est disponible
    # @return [Boolean]
    def datadog_available?
      return false unless defined?(Datadog)

      return false unless defined?(Datadog::Tracer)

      return false unless datadog_api_method_available?

      true
    rescue StandardError
      false
    end

    # Vérifie quelle API Datadog est disponible
    # @return [Boolean]
    def datadog_api_method_available?
      tracer = Datadog::Tracer
      return false unless tracer.respond_to?(:active)

      # Vérifie l'API moderne active_span
      if tracer.respond_to?(:active_span)
        span = tracer.active_span
        return span&.respond_to?(:set_tag)
      end

      # Vérifie l'API legacy active.span
      if tracer.respond_to?(:active)
        active = tracer.active
        return false unless active.respond_to?(:span)

        span = active.span
        return span.respond_to?(:set_tag)
      end

      false
    rescue StandardError
      false
    end

    # Ajoute des attributs via NewRelic
    # @param attributes [Hash] Attributs à ajouter
    # @return [void]
    def add_attributes_newrelic(attributes)
      return unless new_relic_available?

      # Convertit tous les attributs en strings pour NewRelic
      string_attributes = attributes.transform_keys(&:to_s).transform_values(&:to_s)
      NewRelic::Agent.add_custom_attributes(string_attributes)
    rescue StandardError => e
      Rails.logger.debug { "APM NewRelic error: #{e.message}" } if defined?(Rails)
    end

    # Ajoute des attributs via Datadog
    # @param attributes [Hash] Attributs à ajouter
    # @return [void]
    def add_attributes_datadog(attributes)
      return unless datadog_available?

      tracer = Datadog::Tracer
      return unless tracer.respond_to?(:active)

      # Utilise l'API active_span (moderne) si disponible
      return if add_attributes_datadog_modern_api(tracer, attributes)

      # Sinon utilise l'API legacy active.span
      add_attributes_datadog_legacy_api(tracer, attributes)
    rescue StandardError => e
      Rails.logger.debug { "APM Datadog error: #{e.message}" } if defined?(Rails)
    end

    # Ajoute des attributs via Datadog API moderne (active_span)
    # @param tracer [Object] Tracer Datadog
    # @param attributes [Hash] Attributs à ajouter
    # @return [Boolean] true si l'API moderne a été utilisée
    def add_attributes_datadog_modern_api(tracer, attributes)
      return false unless tracer.respond_to?(:active_span)

      span = tracer.active_span
      return false unless span.respond_to?(:set_tag)

      attributes.each do |key, value|
        span.set_tag(key.to_s, value.to_s)
      end

      true
    end

    # Ajoute des attributs via Datadog API legacy (active.span)
    # @param tracer [Object] Tracer Datadog
    # @param attributes [Hash] Attributs à ajouter
    # @return [void]
    def add_attributes_datadog_legacy_api(tracer, attributes)
      return unless tracer.respond_to?(:active)

      active = tracer.active
      return unless active.respond_to?(:span)

      span = active.span
      return unless span.respond_to?(:set_tag)

      attributes.each do |key, value|
        span.set_tag(key.to_s, value.to_s)
      end
    end
  end

  # Module d'aide pour les tests
  module TestHelpers
    class << self
      # Configure les mocks Datadog pour les tests - version simplifiée
      # @return [void]
      def setup_datadog_mocks
        # Simple et direct - toujours créer les mocks depuis le début
        datadog_module = Module.new
        stub_const('Datadog', datadog_module)

        datadog_tracer = double('Tracer')
        active_span = double('span')

        datadog_module.const_set('Tracer', datadog_tracer)

        allow(datadog_tracer).to receive(:active_span).and_return(active_span)
        allow(active_span).to receive(:set_tag)
        allow(datadog_tracer).to receive(:respond_to?).with(:active_span).and_return(true)
        allow(datadog_tracer).to receive(:respond_to?).with(:active).and_return(false)
      rescue StandardError
        # Ignore les erreurs lors du setup des mocks
      end

      # Configure les mocks NewRelic pour les tests - version simplifiée
      # @return [void]
      def setup_newrelic_mocks
        # Simple et direct - toujours créer les mocks depuis le début
        newrelic_module = Module.new
        stub_const('NewRelic', newrelic_module)

        newrelic_agent = double('Agent')
        newrelic_module.const_set('Agent', newrelic_agent)

        allow(newrelic_agent).to receive(:add_custom_attributes)
      rescue StandardError
        # Ignore les erreurs lors du setup des mocks
      end

      # Remet à zéro les mocks - version simplifiée
      # @return [void]
      def reset_mocks
        # Simple et direct - supprime les constantes sans vérifications complexes
        begin
          Object.send(:remove_const, :NewRelic) if defined?(NewRelic)
        rescue StandardError
          # Ignore les erreurs si la constante n'existe plus
        end

        begin
          Object.send(:remove_const, :Datadog) if defined?(Datadog)
        rescue StandardError
          # Ignore les erreurs si la constante n'existe plus
        end
      rescue StandardError
        # Ignore toutes les erreurs lors du reset
      end
    end
  end
end
