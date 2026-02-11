# frozen_string_literal: true

# MemoryBackend - In-memory rate limiting backend for testing and CI environments
#
# Implements a thread-safe sliding window algorithm using a Hash store.
# Used automatically in test environment (Rails.env.test?) to avoid Redis dependency.
#
# == Architecture (FC-05)
#
# - Thread-safe via single Mutex (no Concurrent::Hash + Mutex duplication)
# - Sliding window: timestamps older than `window` are rejected
# - Deterministic: no external dependencies, predictable behavior
# - Passive: no logging, no error handling, pure interface implementation
#
# @see RateLimit::Backend Interface contract
module RateLimit
  class MemoryBackend < Backend
    # Thread-safe in-memory store: key => [timestamp1, timestamp2, ...]
    # @return [Hash{String => Array<Float>}]
    attr_reader :store

    # Initialize the in-memory store
    #
    # @return [void]
    def initialize
      super
      @store = Hash.new { |h, k| h[k] = [] }
      @mutex = Mutex.new
    end

    # Increment the request count for a key within the sliding window
    #
    # @param key [String] rate limit key (e.g., 'auth/login:192.168.x.x')
    # @param window [Integer] window size in seconds
    # @return [Integer] new count after increment
    #
    # @example
    #   backend.increment('auth/login:1.2.3.4', window: 60)
    #   # => 1
    def increment(key, window:)
      @mutex.synchronize do
        now = Time.current.to_f
        window_start = now - window

        # Remove expired timestamps from the sliding window
        @store[key].reject! { |ts| ts < window_start }

        # Add current timestamp
        @store[key] << now

        # Return current count within window
        @store[key].size
      end
    end

    # Count the number of requests for a key within the sliding window
    #
    # @param key [String] rate limit key
    # @param window [Integer] window size in seconds
    # @return [Integer] count of requests within the window
    #
    # @example
    #   backend.count('auth/login:1.2.3.4', window: 60)
    #   # => 3
    def count(key, window:)
      @mutex.synchronize do
        now = Time.current.to_f
        window_start = now - window

        @store[key].count { |ts| ts >= window_start }
      end
    end

    # Clear all timestamps for a specific key
    #
    # @param key [String] rate limit key
    # @return [void]
    #
    # @example
    #   backend.clear('auth/login:1.2.3.4')
    def clear(key)
      @mutex.synchronize { @store.delete(key) }
    end
  end
end
