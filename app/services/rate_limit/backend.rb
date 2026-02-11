# frozen_string_literal: true

# RateLimit::Backend - Abstract interface for rate limiting backends
#
# Implements the Strategy Pattern for rate limiting storage:
# - MemoryBackend for test environment (in-memory, deterministic)
# - RedisBackend for production (Redis-backed, distributed)
#
# All backends must implement:
# - increment(key, window:): Add a timestamp and return new count
# - count(key, window:): Count timestamps within the window
# - clear(key): Clear all timestamps for a key
#
# @abstract Subclass must implement increment, count, clear
module RateLimit
  class Backend
    # Increment count for key by adding current timestamp
    #
    # @param key [String] rate limit key (e.g., 'auth/login:192.168.x.x')
    # @param window [Float] window size in seconds
    # @return [Integer] new count after increment
    def increment(key, window:)
      raise NotImplementedError, "#{self.class}##{__method__} must be implemented"
    end

    # Count timestamps within the sliding window
    #
    # @param key [String] rate limit key
    # @param window [Float] window size in seconds
    # @return [Integer] count of timestamps within window
    def count(key, window:)
      raise NotImplementedError, "#{self.class}##{__method__} must be implemented"
    end

    # Clear all timestamps for a key
    #
    # @param key [String] rate limit key
    # @return [void]
    def clear(key)
      raise NotImplementedError, "#{self.class}##{__method__} must be implemented"
    end
  end
end
