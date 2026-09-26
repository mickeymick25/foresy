# frozen_string_literal: true

module RateLimit
  # Levée quand REDIS_URL est absente en production (contrat FC-05, décision A1).
  # Pas de fallback silencieux : une configuration manquante est une erreur explicite.
  class RedisConfigurationError < StandardError; end
end
