# frozen_string_literal: true

module Api
  module V1
    module Missions
      # Rate limiting concern for mission-related operations
      # Provides centralized rate limiting functionality for create, update, and destroy operations
      module RateLimitable
        extend ActiveSupport::Concern

        private

        # Check rate limit for the current endpoint and client IP
        # @param endpoint [String] The endpoint identifier for rate limiting
        # @param limit [Integer] Maximum number of requests allowed (default: from config)
        # @param window [Integer] Time window in seconds (default: from config)
        # @return [void]
        # @raise [ActionController::TooManyRequests] if rate limit exceeded
        #
        # @example
        #   check_rate_limit!('missions_create')
        def check_rate_limit!(endpoint = 'missions', limit: nil, window: nil)
          client_ip = extract_client_ip_for_rate_limiting

          # Use default limits if not specified
          limit ||= get_default_rate_limit(endpoint)
          window ||= get_default_rate_window(endpoint)

          allowed, retry_after = RateLimitService.check_rate_limit(
            endpoint,
            client_ip,
            limit: limit,
            window: window
          )

          unless allowed
            response.headers['Retry-After'] = retry_after.to_s
            raise ActionController::TooManyRequests,
                  "Rate limit exceeded for endpoint: #{endpoint}"
          end
        end

        # Extract client IP for rate limiting from request headers
        # Handles X-Forwarded-For, X-Real-IP, and REMOTE_ADDR
        # @return [String] Client IP address
        #
        # @example
        #   extract_client_ip_for_rate_limiting
        #   # => "192.168.1.1"
        def extract_client_ip_for_rate_limiting
          # Check for forwarded IP addresses first
          forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
          if forwarded_for.present?
            # Take the first IP in the chain (original client)
            forwarded_for.split(',').first.strip
          else
            # Fall back to real IP or remote address
            request.env['HTTP_X_REAL_IP'] ||
            request.env['REMOTE_ADDR'] ||
            'unknown'
          end
        end

        # Get default rate limit for a specific endpoint
        # @param endpoint [String] Endpoint identifier
        # @return [Integer] Default rate limit
        #
        # @example
        #   get_default_rate_limit('missions_create')
        #   # => 10
        def get_default_rate_limit(endpoint)
          # Endpoint-specific rate limits
          case endpoint
          when 'missions_create', 'missions_update', 'missions_destroy'
            10  # 10 requests per window
          when 'missions_list'
            60  # 60 requests per window
          else
            30  # Default for other endpoints
          end
        end

        # Get default rate window for a specific endpoint
        # @param endpoint [String] Endpoint identifier
        # @return [Integer] Rate window in seconds
        #
        # @example
        #   get_default_rate_window('missions_create')
        #   # => 3600
        def get_default_rate_window(endpoint)
          # Endpoint-specific time windows
          case endpoint
          when 'missions_create', 'missions_update', 'missions_destroy'
            3600  # 1 hour window for write operations
          when 'missions_list'
            3600  # 1 hour window for read operations
          else
            3600  # Default 1 hour window
          end
        end

        # Reset rate limit for a specific endpoint and client IP
        # Useful for testing or admin operations
        # @param endpoint [String] Endpoint identifier
        # @param client_ip [String] Client IP address (optional, uses current if not provided)
        # @return [void]
        #
        # @example
        #   reset_rate_limit!('missions_create')
        def reset_rate_limit!(endpoint, client_ip = nil)
          client_ip ||= extract_client_ip_for_rate_limiting
          RateLimitService.reset_rate_limit(endpoint, client_ip)
        end

        # Get current rate limit status for display purposes
        # @param endpoint [String] Endpoint identifier
        # @return [Hash] Rate limit status information
        #
        # @example
        #   get_rate_limit_status('missions_create')
        #   # => { allowed: true, remaining: 8, reset_time: 1234567890 }
        def get_rate_limit_status(endpoint)
          client_ip = extract_client_ip_for_rate_limiting
          limit = get_default_rate_limit(endpoint)
          window = get_default_rate_window(endpoint)

          RateLimitService.get_rate_limit_status(
            endpoint,
            client_ip,
            limit: limit,
            window: window
          )
        end
      end
    end
  end
end
