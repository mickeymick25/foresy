# frozen_string_literal: true

# RateLimitService - Service for Redis sliding window rate limiting
#
# Implements IP-based rate limiting with sliding window algorithm
# for protection against brute force attacks on authentication endpoints.
#
# SECURITY FEATURES:
# - Redis-only state (no internal data exposed)
# - IP-based identification (stateless servers compatible)
# - Generic error messages only
# - Sliding window algorithm for accurate rate limiting
#
# SUPPORTED ENDPOINTS:
# - POST /api/v1/auth/login (5 requests/minute)
# - POST /api/v1/signup (3 requests/minute)
# - POST /api/v1/auth/refresh (10 requests/minute)
#
# EDGE CASES:
# - Redis unavailable → fail closed (HTTP 429)
# - IP absente → fallback sur request.remote_ip
# - Endpoint hors scope → AUCUN impact
#
# LOGGING & MONITORING:
# - Log des événements de dépassement
# - Aucun IP ni token en clair dans les logs
# - Tag : rate_limit.exceeded
class RateLimitService
  WINDOW_SIZE = 60 # 1 minute in seconds

  # Rate limits per endpoint (requests per minute)
  # Key format: endpoint path without /api/v1 prefix
  LIMITS = {
    'auth/login' => 5,
    'auth/signup' => 3,
    'auth/refresh' => 10
  }.freeze

  # Check if rate limit is exceeded for given endpoint and client IP
  #
  # @param endpoint [String] endpoint path (e.g., 'auth/login')
  # @param client_ip [String] client IP address
  # @return [Array] [allowed (Boolean), retry_after (Integer)]
  def self.check_rate_limit(endpoint, client_ip, _request = nil)
    limit = LIMITS[endpoint]
    return [true, 0] if limit.nil?

    key = "rate_limit:#{endpoint}:#{client_ip}"

    begin
      now = Time.current.to_i

      current_requests = count_current_requests(key, now)

      if current_requests >= limit
        retry_after = calculate_retry_after(key, now)
        log_rate_limit_exceeded(endpoint, client_ip, current_requests, limit)

        [false, retry_after]
      else
        add_request_to_window(key, now)

        [true, 0]
      end
    rescue StandardError => e
      Rails.logger.warn "RateLimitService Redis error: #{e.message}"
      log_redis_unavailable(endpoint, client_ip, e.message)
      [false, 60]
    end
  end

  # Extract client IP from request considering reverse proxies
  #
  # @param request [ActionDispatch::Request] Rails request object
  # @return [String] client IP address
  def self.extract_client_ip(request)
    # Extract client IP considering reverse proxies
    # Priority: X-Forwarded-For > X-Real-IP > REMOTE_ADDR
    forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
    if forwarded_for.present?
      # X-Forwarded-For can contain multiple IPs, take the first one
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
    key = "rate_limit:#{endpoint}:#{client_ip}"
    redis.zcard(key)
  rescue StandardError => e
    Rails.logger.warn "RateLimitService Redis error: #{e.message}"
    0
  end

  # Clear rate limit for a specific endpoint and IP (useful for testing)
  #
  # @param endpoint [String] endpoint path
  # @param client_ip [String] client IP address
  def self.clear_rate_limit(endpoint, client_ip)
    key = "rate_limit:#{endpoint}:#{client_ip}"
    redis.del(key)
  rescue StandardError => e
    Rails.logger.warn "RateLimitService Redis error: #{e.message}"
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
    # Extract endpoint from /api/v1/endpoint format
    endpoint = request_path.sub('/api/v1/', '')
    LIMITS.key?(endpoint)
  end

  # Extract endpoint from request path
  #
  # @param request_path [String] request path (e.g., '/api/v1/auth/login')
  # @return [String] endpoint key (e.g., 'auth/login')
  def self.extract_endpoint(request_path)
    request_path.sub('/api/v1/', '')
  end

  private_class_method def self.redis
    require 'redis'
    @redis ||= ::Redis.new(url: ENV['REDIS_URL'] || 'redis://localhost:6379/0')
  end

  private_class_method def self.count_current_requests(key, now)
    window_start = now - WINDOW_SIZE

    # Get the count from the pipeline result (second operation)
    result = redis.pipelined do |pipeline|
      pipeline.zremrangebyscore(key, 0, window_start)
      pipeline.zcard(key)
    end

    result[1] # zcard result is the second operation in the pipeline
  end

  private_class_method def self.calculate_retry_after(key, now)
    oldest_request = redis.zrange(key, 0, 0, with_scores: true)&.first&.last
    return 60 unless oldest_request

    retry_after = (oldest_request + WINDOW_SIZE - now).ceil
    [retry_after, 60].min
  end

  private_class_method def self.add_request_to_window(key, now)
    # Add request to the sliding window when under limit
    redis.pipelined do |pipeline|
      pipeline.zadd(key, now, SecureRandom.uuid)
      pipeline.expire(key, WINDOW_SIZE * 2)
    end
  end

  private_class_method def self.log_rate_limit_exceeded(endpoint, client_ip, current_requests, limit)
    # Mask IP for security (only log first 2 octets)
    masked_ip = mask_ip(client_ip)

    Rails.logger.info do
      {
        message: 'Rate limit exceeded',
        event: 'rate_limit.exceeded',
        endpoint: endpoint,
        client_ip_masked: masked_ip,
        current_requests: current_requests,
        limit: limit,
        window_size_seconds: WINDOW_SIZE
      }.to_json
    end
  end

  private_class_method def self.log_redis_unavailable(endpoint, client_ip, error_message)
    # Mask IP for security (only log first 2 octets)
    masked_ip = mask_ip(client_ip)

    Rails.logger.warn do
      {
        message: 'Redis unavailable - failing closed',
        event: 'rate_limit.redis_unavailable',
        endpoint: endpoint,
        client_ip_masked: masked_ip,
        redis_error: error_message,
        action: 'fail_closed'
      }.to_json
    end
  end

  private_class_method def self.mask_ip(ip)
    return 'unknown' if ip == 'unknown' || ip.nil?

    # IPv4 masking: 192.168.1.100 -> 192.168.x.x
    if ip.match?(/^\d+\.\d+\.\d+\.\d+$/)
      parts = ip.split('.')
      "#{parts[0]}.#{parts[1]}.x.x"
    # IPv6 masking: 2001:db8::1 -> 2001:db8::x
    elsif ip.include?(':')
      parts = ip.split(':')
      "#{parts[0]}:#{parts[1]}:...:x"
    else
      # Unknown format, mask most of it
      ip.length > 4 ? "#{ip[0..3]}...x" : 'masked'
    end
  end
end
