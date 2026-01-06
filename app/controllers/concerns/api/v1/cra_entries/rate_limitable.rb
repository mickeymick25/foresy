# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      module RateLimitable
        extend ActiveSupport::Concern
        include Common::RateLimitable

        private

        def default_endpoint
          "cra_entries:#{action_name}"
        end

        def rate_limit_scope
          'cra_entries'
        end

        def rate_limit_config
          {
            limit: cra_entry_rate_limit,
            window: cra_entry_rate_window,
            message: 'CRA entry rate limit exceeded'
          }
        end

        def cra_entry_rate_limit
          case action_name
          when 'create'
            20 # 20 CRA entry creations per hour
          when 'update', 'destroy'
            50 # 50 modifications per hour
          when 'index', 'show'
            100 # 100 read operations per hour
          else
            30 # default for other actions
          end
        end

        def cra_entry_rate_window
          3600 # 1 hour in seconds
        end

        def check_cra_entry_rate_limit!
          limiter = RedisRateLimiter.new(
            key: cra_entry_rate_limit_key,
            limit: cra_entry_rate_limit,
            window: cra_entry_rate_window
          )

          unless limiter.allow?
            Rails.logger.warn "CRA entry rate limit exceeded for #{cra_entry_rate_limit_key}"
            handle_rate_limit_exceeded('CRA entry rate limit exceeded')
          end
        end

        def cra_entry_rate_limit_key
          "#{cra_entry_rate_limit_scope}:#{extract_client_identifier}"
        end

        def cra_entry_rate_limit_scope
          "#{default_endpoint}:#{current_user&.id || 'anonymous'}"
        end

        def extract_client_identifier
          # Enhanced version for CRA entry-specific rate limiting
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

        def render_cra_entry_rate_limit_response(limit, reset_time)
          headers['X-RateLimit-Limit'] = limit.to_s
          headers['X-RateLimit-Remaining'] = '0'
          headers['X-RateLimit-Reset'] = reset_time.to_s
          headers['Retry-After'] = (reset_time - Time.current.to_i).to_s

          render json: {
            error: 'cra_entry_rate_limit_exceeded',
            message: 'CRA entry operation rate limit exceeded',
            resource_type: 'CRA Entry',
            rate_limit: {
              limit: limit,
              reset_time: reset_time,
              window_seconds: cra_entry_rate_window
            }
          }, status: :too_many_requests
        end

        def check_cra_locked_for_entry_modification!(cra)
          return unless cra.present?

          if cra.submitted? || cra.locked?
            Rails.logger.warn "Attempt to modify entries in #{cra.status} CRA #{cra.id}"
            error_message = if cra.locked?
                              'Cannot modify entries in locked CRA'
                            else
                              'Cannot modify entries in submitted CRA'
                            end
            handle_cra_locked_error(error_message)
          end
        end

        def check_entry_creation_rate_limit!
          # Additional specific rate limiting for entry creation
          limiter = RedisRateLimiter.new(
            key: "cra_entry_creation:#{current_user&.id || 'anonymous'}",
            limit: 5, # Max 5 entries per 10 minutes
            window: 600 # 10 minutes
          )

          unless limiter.allow?
            Rails.logger.warn "CRA entry creation rate limit exceeded for user #{current_user&.id}"
            handle_rate_limit_exceeded('CRA entry creation rate limit exceeded (max 5 per 10 minutes)')
          end
        end

        def check_entry_bulk_operation_rate_limit!(count)
          if count > 10
            Rails.logger.warn "Bulk CRA entry operation with #{count} entries - rate limiting"
            handle_rate_limit_exceeded('Bulk operation rate limit exceeded')
          end
        end
      end
    end
  end
end
