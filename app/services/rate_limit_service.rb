# frozen_string_literal: true

require 'redis'

# RateLimitService - Service de rate limiting à fenêtre glissante (contrat FC-05 v1)
#
# Contrat   : docs/technical/guides/2026_09_25_fc05_rate_limiting_contract.md (A1-A9, CTO 25/09)
# Audit     : docs/technical/audits/[DONE]_2026_09_25_fc05_rate_limiting_audit.md (BACKLOG #20)
# Chantier  : BACKLOG #23 — Remediation contractuelle FC-05
#
# == Contrat de sélection (6 états)
#
#   1. REDIS_URL absente, dev/test        → MemoryBackend
#   2. REDIS_URL absente, production      → RateLimit::RedisConfigurationError (A1)
#   3. REDIS_URL présente + Redis joignable → RedisBackend (protection distribuée)
#   4/5. Redis indisponible / timeout     → fallback MemoryBackend + warning structuré (A2)
#   6. Erreur interne inattendue          → log error + propagation — JAMAIS un 429 (A3/A4)
#
# == Sémantique
#
# - 429 (`[false, window]`) émis UNIQUEMENT sur dépassement de limite constaté (A4).
# - Redis indisponible = dégradation explicite (protection locale par processus),
#   jamais masquée en RATE_LIMIT_EXCEEDED — Redis error ≠ 429.
# - Retour de Redis → retour au backend distribué (le fallback n'est pas mémoïsé).
class RateLimitService
  WINDOW_SIZE = 60

  # Limites par endpoint (requêtes par fenêtre) — contrat FC-05 §4
  LIMITS = {
    'auth/login' => 5,
    'auth/signup' => 3,
    'auth/refresh' => 10,
    'missions:create' => 20,
    'missions:update' => 60,
    'cras:create' => 10,
    'cras:update_destroy' => 50,
    'cras:submit_lock' => 5,
    'cra_entries:create' => 20,
    'cra_entries:create_burst' => 5,
    'cra_entries:update_destroy' => 50
  }.freeze

  # Fenêtres par endpoint (secondes) — défaut : WINDOW_SIZE
  WINDOWS = {
    'missions:create' => 3600,
    'missions:update' => 3600,
    'cras:create' => 3600,
    'cras:update_destroy' => 3600,
    'cras:submit_lock' => 3600,
    'cra_entries:create' => 3600,
    'cra_entries:create_burst' => 600,
    'cra_entries:update_destroy' => 3600
  }.freeze

  # Sélection du backend (contrat §2) — exécutée à chaque requête : dégradation et
  # retour au distribué sont détectés en continu (A2). Pas de mémoïsation.
  def self.backend
    select_backend
  end

  def self.select_backend
    redis_url = ENV.fetch('REDIS_URL', nil)

    if redis_url.blank?
      return RateLimit::MemoryBackend.new unless Rails.env.production?

      raise RateLimit::RedisConfigurationError, 'REDIS_URL not configured for production environment'
    end

    begin
      ::Redis.new(url: redis_url).ping
      RateLimit::RedisBackend.new
    rescue Redis::CannotConnectError, Redis::TimeoutError => e
      log_backend_fallback(nil, e)
      memory_fallback
    end
  end

  # Fallback mémoire au niveau processus : les compteurs s'accumulent pendant
  # l'indisponibilité (protection locale par processus, contrat §2)
  def self.memory_fallback
    @memory_fallback ||= RateLimit::MemoryBackend.new
  end

  def self.log_backend_fallback(endpoint, error)
    payload = {
      tag: 'rate_limit.backend_fallback',
      message: 'Redis unavailable - degrading to per-process MemoryBackend',
      backend: 'MemoryBackend',
      protection: 'local_per_process',
      redis_error: "#{error.class}: #{error.message}",
      endpoint: endpoint
    }.to_json
    Rails.logger.warn(payload)
  end
  private_class_method :log_backend_fallback

  def self.window_for(endpoint)
    WINDOWS.fetch(endpoint, WINDOW_SIZE)
  end
  private_class_method :window_for

  # Get Redis connection (private for test stubbing / RedisBackend)
  #
  # @return [Redis] Redis connection
  def self.redis
    ::Redis.new(
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
    )
  end
  private_class_method :redis

  def initialize(backend: nil)
    @backend = backend
  end

  def backend
    @backend || self.class.backend
  end

  # Check if rate limit is exceeded (class method)
  #
  # @param endpoint [String] endpoint key (e.g., 'auth/login', 'missions:create')
  # @param key_component [String] IP (auth, A5) ou user_id (endpoints métier, A6)
  # @param _request [ActionDispatch::Request, nil] optional request object
  # @return [Array] [allowed (Boolean), retry_after (Integer)]
  def self.check_rate_limit(endpoint, key_component, _request = nil)
    new.check_rate_limit(endpoint, key_component)
  end

  # Check if rate limit is exceeded (instance method)
  #
  # 429 émis UNIQUEMENT sur dépassement de limite constaté (A4).
  # CannotConnectError / TimeoutError → fallback MemoryBackend par processus + warning (A2).
  # Toute autre erreur interne → log error + propagation explicite (A3) — jamais de 429.
  #
  # @param endpoint [String] endpoint key
  # @param key_component [String] composant de clé (IP ou user_id selon A5/A6)
  # @return [Array] [allowed (Boolean), retry_after (Integer)]
  def check_rate_limit(endpoint, key_component)
    limit = LIMITS[endpoint]
    return [true, 0] if limit.nil?

    window = self.class.send(:window_for, endpoint)
    key = rate_limit_key(endpoint, key_component)

    begin
      count = count_request(key, window)
    rescue Redis::CannotConnectError, Redis::TimeoutError => e
      self.class.send(:log_backend_fallback, endpoint, e)
      count = count_in_fallback(key, window)
    end

    if count > limit
      log_rate_limit_exceeded(endpoint, key_component, count, limit, window)
      [false, window]
    else
      [true, 0]
    end
  rescue StandardError => e
    log_internal_error(endpoint, e)
    raise
  end

  # Extract client IP from request considering reverse proxies
  #
  # @param request [ActionDispatch::Request] Rails request object
  # @return [String] client IP address
  def self.extract_client_ip(request)
    forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
    if forwarded_for.present?
      forwarded_for.split(',').first.strip
    else
      request.env['HTTP_X_REAL_IP'] || request.env['REMOTE_ADDR'] || 'unknown'
    end
  end

  # Get current request count for monitoring/debugging
  def self.current_count(endpoint, client_ip)
    new.current_count(endpoint, client_ip)
  end

  def current_count(endpoint, client_ip)
    key = rate_limit_key(endpoint, client_ip)
    backend.count(key, window: self.class.send(:window_for, endpoint))
  end

  # Clear rate limit for a specific endpoint and key (useful for testing)
  def self.clear_rate_limit(endpoint, client_ip)
    new.clear_rate_limit(endpoint, client_ip)
  end

  def clear_rate_limit(endpoint, client_ip)
    key = rate_limit_key(endpoint, client_ip)
    backend.clear(key)
  end

  # Get configuration for display/monitoring
  #
  # @return [Hash] rate limit configuration
  def self.config
    LIMITS.dup
  end

  # Check if endpoint should be rate-limited
  #
  # @param request_path [String] request path (e.g., '/api/v1/auth/login')
  # @return [Boolean] true if endpoint should be rate-limited
  def self.rate_limited_endpoint?(request_path)
    endpoint = request_path.sub('/api/v1/', '')
    LIMITS.key?(endpoint)
  end

  # Réinitialise le stockage du backend actif + fallback (support de test)
  def self.reset_storage!
    backend.clear_all!
    memory_fallback.clear_all!
  end

  # Build rate limit key for endpoint and key component
  def rate_limit_key(endpoint, key_component)
    "rate_limit:#{endpoint}:#{key_component}"
  end

  # Log rate limit exceeded event (429 — dépassement réel, A4)
  def log_rate_limit_exceeded(endpoint, key_component, current_requests, limit, window)
    masked_key = mask_ip(key_component)

    log_data = {
      tag: 'rate_limit.exceeded',
      message: 'Rate limit exceeded',
      endpoint: endpoint,
      client_masked: masked_key,
      current_requests: current_requests,
      limit: limit,
      window_size_seconds: window
    }

    Rails.logger.info { log_data.to_json }
    log_data.to_json
  end

  private

  def count_request(key, window)
    backend.increment(key, window: window)
    backend.count(key, window: window)
  end

  def count_in_fallback(key, window)
    self.class.send(:memory_fallback).tap do |fallback|
      fallback.increment(key, window: window)
    end.count(key, window: window)
  end

  def log_internal_error(endpoint, error)
    payload = {
      tag: 'rate_limit.internal_error',
      message: 'Rate limit check failed - NOT a rate limit exceeded',
      endpoint: endpoint,
      error_class: error.class.to_s,
      error_message: error.message
    }.to_json
    Rails.logger.error(payload)
  end

  # Mask key component (IP ou user_id) for security in logs
  def mask_ip(component)
    return 'unknown' if component == 'unknown' || component.blank?

    if component.match?(/^\d+\.\d+\.\d+\.\d+$/)
      parts = component.split('.')
      "#{parts[0]}.#{parts[1]}.x.x"
    elsif component.include?(':')
      parts = component.split(':')
      "#{parts[0]}:#{parts[1]}:...:x"
    else
      component.length > 4 ? "#{component[0..3]}...x" : 'masked'
    end
  end
end
