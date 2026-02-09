# frozen_string_literal: true

require 'redis'

# RateLimitService - Service for sliding window rate limiting
#
# Implements IP-based rate limiting with sliding window algorithm
# for protection against brute force attacks on authentication endpoints.
#
# == Architecture (FC-05)
#
# - Uses Strategy Pattern for backend selection
# - MemoryBackend in test (no Redis dependency)
# - RedisBackend in production (distributed rate limiting)
# - Fail-closed on Redis failure (429, not 500)
#
# == Supported Endpoints
#
# - POST /api/v1/auth/login (5 requests/minute)
# - POST /api/v1/signup (3 requests/minute)
# - POST /api/v1/auth/refresh (10 requests/minute)
#
# == Interface (Strategy Pattern)
#
# @see RateLimit::Backend
# @see RateLimit::MemoryBackend
# @see RateLimit::RedisBackend
class RateLimitService
  WINDOW_SIZE = 60 # 1 minute in seconds

  # Rate limits per endpoint (requests per minute)
  # Key format: endpoint path without /api/v1 prefix
  LIMITS = {
    'auth/login' => 5,
    'auth/signup' => 3,
    'auth/refresh' => 10
  }.freeze

  # Singleton backend instance (memoized per process)
  #
  # @return [RateLimit::Backend]
  def self.backend
    @backend ||= if Rails.env.test?
      RateLimit::MemoryBackend.new
    else
      RateLimit::RedisBackend.new
    end
  end

  # Initialize the rate limit service with a backend
  #
  # @param backend [RateLimit::Backend] optional backend (auto-selected if nil)
  # @return [void]
  def initialize(backend: nil)
    @backend = backend || self.class.backend
  end

  # Get Redis connection (private for test stubbing)
  #
  # @return [Redis] Redis connection
  def self.redis
    ::Redis.new(
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
    )
  end
  private_class_method :redis

  # Check if rate limit is exceeded (class method)
  #
  # @param endpoint [String] endpoint path (e.g., 'auth/login')
  # @param client_ip [String] client IP address
  # @param _request [ActionDispatch::Request, nil] optional request object
  # @return [Array] [allowed (Boolean), retry_after (Integer)]
  def self.check_rate_limit(endpoint, client_ip, _request = nil)
    limit = LIMITS[endpoint]
    return [true, 0] if limit.nil?

    new.check_rate_limit(endpoint, client_ip)
  end

  # Check if rate limit is exceeded (instance method)
  #
  # @param endpoint [String] endpoint path
  # @param client_ip [String] client IP address
  # @return [Array] [allowed (Boolean), retry_after (Integer)]
  def check_rate_limit(endpoint, client_ip)
    limit = LIMITS[endpoint]
    return [true, 0] if limit.nil?

    key = rate_limit_key(endpoint, client_ip)

    @backend.increment(key, window: WINDOW_SIZE)
    count = @backend.count(key, window: WINDOW_SIZE)

    if count > limit
      log_rate_limit_exceeded(endpoint, client_ip, count, limit)
      [false, WINDOW_SIZE]
    else
      [true, 0]
    end
  rescue Redis::CannotConnectError => e
    log_redis_unavailable(endpoint, client_ip, e.message)
    [false, WINDOW_SIZE]
  rescue StandardError => e
    log_redis_unavailable(endpoint, client_ip, e.message)
    [false, WINDOW_SIZE]
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
  #
  # @param endpoint [String] endpoint path
  # @param client_ip [String] client IP address
  # @return [Integer] current request count in the window
  def self.current_count(endpoint, client_ip)
    new.current_count(endpoint, client_ip)
  end

  # Instance method for getting current count
  #
  # @param endpoint [String] endpoint path
  # @param client_ip [String] client IP address
  # @return [Integer] count
  def current_count(endpoint, client_ip)
    key = rate_limit_key(endpoint, client_ip)
    @backend.count(key, window: WINDOW_SIZE)
  end

  # Clear rate limit for a specific endpoint and IP (useful for testing)
  #
  # @param endpoint [String] endpoint path
  # @param client_ip [String] client IP address
  def self.clear_rate_limit(endpoint, client_ip)
    new.clear_rate_limit(endpoint, client_ip)
  end

  # Instance method for clearing rate limit
  #
  # @param endpoint [String] endpoint path
  # @param client_ip [String] client IP address
  def clear_rate_limit(endpoint, client_ip)
    key = rate_limit_key(endpoint, client_ip)
    @backend.clear(key)
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

  # Extract endpoint from request path
  #
  # @param request_path [String] request path
  # @return [String] endpoint key
  def self.extract_endpoint(request_path)
    request_path.sub('/api/v1/', '')
  end



  # Build rate limit key for endpoint and IP
  #
  # @param endpoint [String] endpoint path
  # @param client_ip [String] client IP address
  # @return [String] rate limit key
  def rate_limit_key(endpoint, client_ip)
    "rate_limit:#{endpoint}:#{client_ip}"
  end

  # Log rate limit exceeded event
  #
  # @param endpoint [String] endpoint path
  # @param client_ip [String] client IP address
  # @param current_requests [Integer] current request count
  # @param limit [Integer] rate limit
  # @return [void]
  def log_rate_limit_exceeded(endpoint, client_ip, current_requests, limit)
    masked_ip = mask_ip(client_ip)

    log_data = {
      tag: 'rate_limit.exceeded',
      message: 'Rate limit exceeded',
      endpoint: endpoint,
      client_ip_masked: masked_ip,
      current_requests: current_requests,
      limit: limit,
      window_size_seconds: WINDOW_SIZE
    }

    Rails.logger.info { log_data.to_json }
    log_data.to_json
  end

  # Log Redis unavailable event
  #
  # @param endpoint [String] endpoint path
  # @param client_ip [String] client IP address
  # @param error_message [String] error message
  # @return [void]
  def log_redis_unavailable(endpoint, client_ip, error_message)
    masked_ip = mask_ip(client_ip)

    log_data = {
      tag: 'rate_limit.redis_unavailable',
      message: 'Redis unavailable - failing closed',
      endpoint: endpoint,
      client_ip_masked: masked_ip,
      redis_error: error_message,
      action: 'fail_closed'
    }

    Rails.logger.warn { log_data.to_json }
    log_data.to_json
  end

  # Mask IP address for security in logs
  #
  # @param ip [String] IP address
  # @return [String] masked IP address
  def mask_ip(ip)
    return 'unknown' if ip == 'unknown' || ip.nil?

    if ip.match?(/^\d+\.\d+\.\d+\.\d+$/)
      parts = ip.split('.')
      "#{parts[0]}.#{parts[1]}.x.x"
    elsif ip.include?(':')
      parts = ip.split(':')
      "#{parts[0]}:#{parts[1]}:...:x"
    else
      ip.length > 4 ? "#{ip[0..3]}...x" : 'masked'
    end
  end
end
