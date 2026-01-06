# frozen_string_literal: true

module Api
  module V1
    module Cras
      module RateLimitable
        extend ActiveSupport::Concern
        include Common::RateLimitable

        private

        def default_endpoint
          "cras:#{action_name}"
        end

        def rate_limit_scope
          'cras'
        end

        def rate_limit_config
          {
            limit: cra_rate_limit,
            window: cra_rate_window,
            message: 'CRA rate limit exceeded'
          }
        end

        def cra_rate_limit
          case action_name
          when 'create'
            10 # 10 CRA creations per hour
          when 'update', 'destroy'
            50 # 50 modifications per hour
          when 'submit', 'lock'
            5 # 5 lifecycle actions per hour
          when 'index', 'show'
            100 # 100 read operations per hour
          else
            20 # default for other actions
          end
        end

        def cra_rate_window
          3600 # 1 hour in seconds
        end

        def check_cra_rate_limit!
          limiter = RedisRateLimiter.new(
            key: cra_rate_limit_key,
            limit: cra_rate_limit,
            window: cra_rate_window
          )

          unless limiter.allow?
            Rails.logger.warn "CRA rate limit exceeded for #{cra_rate_limit_key}"
            handle_rate_limit_exceeded('CRA rate limit exceeded')
          end
        end

        def cra_rate_limit_key
          "#{cra_rate_limit_scope}:#{extract_client_identifier}"
        end

        def cra_rate_limit_scope
          "#{default_endpoint}:#{current_user&.id || 'anonymous'}"
        end

        def extract_client_identifier
          # Enhanced version for CRA-specific rate limiting
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

        def render_cra_rate_limit_response(limit, reset_time)
          headers['X-RateLimit-Limit'] = limit.to_s
          headers['X-RateLimit-Remaining'] = '0'
          headers['X-RateLimit-Reset'] = reset_time.to_s
          headers['Retry-After'] = (reset_time - Time.current.to_i).to_s

          render json: {
            error: 'cra_rate_limit_exceeded',
            message: 'CRA operation rate limit exceeded',
            resource_type: 'CRA',
            rate_limit: {
              limit: limit,
              reset_time: reset_time,
              window_seconds: cra_rate_window
            }
          }, status: :too_many_requests
        end
      end
    end
  end
end
