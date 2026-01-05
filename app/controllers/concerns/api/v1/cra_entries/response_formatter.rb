# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      module ResponseFormatter
        extend ActiveSupport::Concern
        include Common::ResponseFormatter

        private

        def format_cra_entry_response(entry, status = :ok)
          data = format_cra_entry(entry)
          format_response(data, status)
        end

        def format_cra_entry_collection_response(entries)
          data = format_collection(entries, :format_cra_entry)
          format_response(data, :ok)
        end

        def format_cra_entry_with_mission_response(entry)
          data = {
            entry: format_cra_entry(entry),
            mission: entry.mission ? format_mission(entry.mission) : nil,
            cra: format_cra(entry.cra),
            calculations: {
              line_total: entry.line_total,
              daily_rate_equivalent: entry.unit_price,
              quantity_formatted: "#{entry.quantity} day(s)"
            }
          }

          format_response(data, :ok)
        end

        def format_cra_entry_creation_response(entry, cra)
          data = {
            entry: format_cra_entry(entry),
            cra: format_cra(cra),
            message: 'CRA entry created successfully',
            totals_updated: {
              cra_total_days: cra.total_days,
              cra_total_amount: cra.total_amount,
              currency: cra.currency
            },
            timestamp: Time.current.iso8601
          }

          format_response(data, :created)
        end

        def format_cra_entry_update_response(entry, cra)
          data = {
            entry: format_cra_entry(entry),
            cra: format_cra(cra),
            message: 'CRA entry updated successfully',
            totals_updated: {
              cra_total_days: cra.total_days,
              cra_total_amount: cra.total_amount,
              currency: cra.currency
            },
            timestamp: Time.current.iso8601
          }

          format_response(data, :ok)
        end

        def format_cra_entry_deletion_response(entry, cra)
          data = {
            deleted_entry: {
              id: entry.id,
              date: entry.date.iso8601,
              quantity: entry.quantity
            },
            cra: format_cra(cra),
            message: 'CRA entry deleted successfully',
            totals_updated: {
              cra_total_days: cra.total_days,
              cra_total_amount: cra.total_amount,
              currency: cra.currency
            },
            timestamp: Time.current.iso8601
          }

          format_response(data, :ok)
        end

        def format_cra_entry_validation_response(entry)
          data = {
            entry: format_cra_entry(entry),
            validation: {
              is_valid: entry.valid?,
              errors: entry.errors.full_messages,
              calculated_line_total: entry.line_total
            }
          }

          format_response(data, :ok)
        end

        def format_cra_entry_search_response(entries, pagination_meta, search_params = nil)
          data = format_collection(entries, :format_cra_entry)

          meta = pagination_meta.merge({
                                         search_applied: search_params.present?,
                                         filters: search_params,
                                         total_entries: entries.count,
                                         total_days: entries.sum(&:quantity),
                                         total_amount: entries.sum(&:line_total)
                                       })

          format_response(data, :ok, meta)
        end

        def format_entry_not_found_response(_entry_id = nil)
          not_found_response('CRA Entry')
        end

        def format_cra_not_found_response(_cra_id = nil)
          not_found_response('CRA')
        end

        def format_mission_not_found_response(_mission_id = nil)
          not_found_response('Mission')
        end

        def format_rate_limit_response(limit, reset_time, action = nil)
          rate_limit_data = {
            error: 'cra_entry_rate_limit_exceeded',
            message: action ? "Rate limit exceeded for #{action} action" : 'CRA entry rate limit exceeded',
            resource_type: 'CRA Entry',
            rate_limit: {
              limit: limit,
              window_seconds: 3600,
              reset_time: reset_time,
              retry_after_seconds: reset_time - Time.current.to_i
            }
          }

          headers['X-RateLimit-Limit'] = limit.to_s
          headers['X-RateLimit-Remaining'] = '0'
          headers['X-RateLimit-Reset'] = reset_time.to_s
          headers['Retry-After'] = (reset_time - Time.current.to_i).to_s

          render json: rate_limit_data, status: :too_many_requests
        end
      end
    end
  end
end
