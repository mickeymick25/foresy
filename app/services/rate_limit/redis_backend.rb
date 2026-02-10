# frozen_string_literal: true

# RedisBackend - Redis-backed rate limiting backend for production environments
#
# Implements a sliding window algorithm using Redis Sorted Sets (ZSET).
# Uses RateLimitService.redis for Redis connection (enables test mocking).
#
# == Architecture (FC-05)
#
# - Passive backend: no logging, no error handling, pure interface
# - Sliding window via ZSET: each request stored with timestamp as score
# - Fail-closed: Redis::CannotConnectError propagates via RateLimitService
# - Deterministic: zadd uses timestamp as member, no UUID needed
# - Exclusive dependency on RateLimitService.redis for test mocking
#
# == Algorithm
#
#   ZREM key 0 (now - window)    # Remove expired entries
#   ZADD key now now              # Add current request
#   ZCARD key                     # Count in window
#
# @see RateLimit::Backend Interface contract
module RateLimit
  class RedisBackend < Backend
    # Get Redis connection exclusively via RateLimitService
    # Enables test mocking and fail-closed behavior
    #
    # @return [Redis] Redis connection
    def redis
      RateLimitService.send(:redis)
    end

    # Increment the request count for a key within the sliding window
    #
    # @param key [String] rate limit key (e.g., 'rate_limit:auth/login:1.2.3.4')
    # @param window [Integer] window size in seconds
    # @return [Integer] new count after increment
    def increment(key, window:)
      now = Time.current.to_f
      window_start = now - window

      redis.pipelined do |pipeline|
        pipeline.zremrangebyscore(key, 0, window_start)
        pipeline.zadd(key, now, now)
        pipeline.zcard(key)
      end.last
    end

    # Count the number of requests for a key within the sliding window
    #
    # @param key [String] rate limit key
    # @param window [Integer] window size in seconds
    # @return [Integer] count of requests within the window
    def count(key, window:)
      now = Time.current.to_f
      window_start = now - window
      redis.zcount(key, window_start, now)
    end

    # Clear all timestamps for a specific key
    #
    # @param key [String] rate limit key
    # @return [void]
    def clear(key)
      redis.del(key)
    end
  end
end
