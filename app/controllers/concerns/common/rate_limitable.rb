# frozen_string_literal: true

module Common
  module RateLimitable
    extend ActiveSupport::Concern

    private

    # Shared method for extracting client IP from request headers.
    # Used by AuthenticationController, UsersController, MissionsController
    # and CRA rate limiting concerns. Extracted to eliminate duplication
    # (audit point C6 — 3 copies of identical logic).
    def extract_client_ip_for_rate_limiting
      forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
      if forwarded_for.present?
        forwarded_for.split(',').first.strip
      else
        request.env['HTTP_X_REAL_IP'] || request.env['REMOTE_ADDR'] || 'unknown'
      end
    end

    def check_rate_limit!
      limiter = RedisRateLimiter.new(
        key: rate_limit_key,
        limit: rate_limit_config[:limit],
        window: rate_limit_config[:window]
      )

      unless limiter.allow?
        Rails.logger.warn "Rate limit exceeded for #{rate_limit_key}"
        handle_rate_limit_exceeded(rate_limit_config[:message])
      end
    end

    def rate_limit_key
      "#{rate_limit_scope}:#{extract_client_identifier}"
    end

    def rate_limit_scope
      default_endpoint
    end

    def default_endpoint
      "#{controller_name}:#{action_name}"
    end

    def rate_limit_config
      {
        limit: default_rate_limit,
        window: default_rate_window,
        message: 'Rate limit exceeded'
      }
    end

    def default_rate_limit
      100 # requests per window
    end

    def default_rate_window
      3600 # 1 hour in seconds
    end

    def extract_client_identifier
      # Enhanced version for rate limiting
      api_key ||
        request.headers['X-User-ID'] ||
        request.headers['X-Client-Id'] ||
        client_ip ||
        'anonymous'
    end

    def api_key
      request.headers['X-API-Key'] || request.headers['Authorization']&.sub(/^Bearer /, '')
    end

    def client_ip
      request.remote_ip ||
        request.headers['X-Forwarded-For']&.split(',')&.first&.strip ||
        request.headers['X-Real-IP'] ||
        '0.0.0.0'
    end
  end

  # Redis-based rate limiter implementation
  class RedisRateLimiter
    def initialize(key:, limit:, window:)
      @key = "rate_limit:#{key}"
      @limit = limit
      @window = window
      @redis = Redis.new(url: redis_connection_url)
    end

    def allow?
      current = @redis.get(@key).to_i
      current < @limit
    end

    def increment!
      @redis.multi do |multi|
        multi.incr(@key)
        multi.expire(@key, @window)
      end
    end

    def reset_time
      ttl = @redis.ttl(@key)
      ttl.positive? ? Time.current.to_i + ttl : Time.current.to_i + @window
    end

    private

    def redis_connection_url
      redis_url = ENV.fetch('REDIS_URL', nil)

      return redis_url if redis_url.present?

      # In production-like environments, Redis must be explicitly configured
      if Rails.env.production? || ENV['RENDER'] || ENV['CI']
        raise RedisConnectionError, <<~MSG
          Redis URL not configured for production environment.

          Please set the REDIS_URL environment variable:

          For Render:
            - Go to your service dashboard
            - Add Environment Variable: REDIS_URL=redis://your-redis-service:6379/0

          For other platforms:
            - Configure REDIS_URL in your deployment platform
            - Example: REDIS_URL=redis://username:password@host:port/db

          Local development fallback is not available in production.
        MSG
      end

      # Development fallback - only for non-production environments
      'redis://localhost:6379/0'
    end
  end

  # Custom error for Redis connection issues
  class RedisConnectionError < StandardError
  end
end
