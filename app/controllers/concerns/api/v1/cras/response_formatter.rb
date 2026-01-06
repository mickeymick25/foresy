# frozen_string_literal: true

module Api
  module V1
    module Cras
      # ResponseFormatter - FC07 Compliant CRA Response Formatting
      # Provides class methods for formatting CRA responses in API controllers
      #
      # Usage:
      #   Cras::ResponseFormatter.single(cra)
      #   Cras::ResponseFormatter.collection(cras, pagination: pagination_data)
      #
      module ResponseFormatter
        extend ActiveSupport::Concern

        class << self
          # Format a single CRA for API response
          # @param cra [Cra] the CRA to format
          # @param include_entries [Boolean] whether to include CRA entries
          # @return [Hash] formatted CRA data (direct, no wrapper - aligned with FC-06 pattern)
          def single(cra, include_entries: false)
            return {} unless cra

            data = format_cra(cra)
            data[:entries] = format_entries(cra.cra_entries) if include_entries && cra.respond_to?(:cra_entries)
            data[:missions] = format_missions(cra) if cra.respond_to?(:cra_missions)

            # Return direct object (no data wrapper) - aligned with tests and FC-06 pattern
            data
          end

          # Format a collection of CRAs for API response
          # @param cras [Array<Cra>] the CRAs to format
          # @param pagination [Hash] pagination metadata
          # @return [Hash] formatted collection with pagination (with wrapper for lists)
          def collection(cras, pagination: nil)
            {
              data: cras.map { |cra| format_cra(cra) },
              meta: pagination || {}
            }
          end

          private

          def format_cra(cra)
            {
              id: cra.id,
              month: cra.month,
              year: cra.year,
              status: cra.status,
              description: cra.description,
              total_days: cra.total_days,
              total_amount: cra.total_amount,
              currency: cra.currency,
              created_by_user_id: cra.created_by_user_id,
              locked_at: cra.locked_at&.iso8601,
              created_at: cra.created_at.iso8601,
              updated_at: cra.updated_at.iso8601
            }
          end

          def format_entries(entries)
            return [] unless entries

            entries.map do |entry|
              {
                id: entry.id,
                date: entry.date&.iso8601,
                quantity: entry.quantity,
                unit_price: entry.unit_price,
                line_total: entry.line_total,
                description: entry.description,
                created_at: entry.created_at.iso8601,
                updated_at: entry.updated_at.iso8601
              }
            end
          end

          def format_missions(cra)
            return [] unless cra.respond_to?(:cra_missions) && cra.cra_missions.any?

            cra.cra_missions.includes(:mission).map do |cra_mission|
              mission = cra_mission.mission
              next unless mission

              {
                id: mission.id,
                name: mission.name,
                mission_type: mission.mission_type,
                status: mission.status,
                daily_rate: mission.daily_rate,
                currency: mission.currency
              }
            end.compact
          end
        end

        # Instance methods for use in controllers
        private

        def format_single_cra(cra, include_entries: false)
          Api::V1::Cras::ResponseFormatter.single(cra, include_entries: include_entries)
        end

        def format_cra_collection(cras, pagination: nil)
          Api::V1::Cras::ResponseFormatter.collection(cras, pagination: pagination)
        end

        def render_cra_response(cra, status: :ok, include_entries: false)
          render json: format_single_cra(cra, include_entries: include_entries), status: status
        end

        def render_cra_collection_response(cras, pagination: nil, status: :ok)
          render json: format_cra_collection(cras, pagination: pagination), status: status
        end

        def render_cra_created_response(cra)
          render json: {
            data: Api::V1::Cras::ResponseFormatter.send(:format_cra, cra),
            message: 'CRA created successfully',
            timestamp: Time.current.iso8601
          }, status: :created
        end

        def render_cra_updated_response(cra, include_entries: false)
          render json: {
            data: Api::V1::Cras::ResponseFormatter.send(:format_cra, cra),
            entries: include_entries ? Api::V1::Cras::ResponseFormatter.send(:format_entries, cra.cra_entries) : nil,
            message: 'CRA updated successfully',
            timestamp: Time.current.iso8601
          }.compact, status: :ok
        end

        def render_cra_archived_response(cra)
          render json: {
            success: true,
            message: 'CRA archived successfully',
            cra_id: cra.id,
            timestamp: Time.current.iso8601
          }, status: :ok
        end

        def render_cra_submitted_response(cra)
          render json: {
            data: Api::V1::Cras::ResponseFormatter.send(:format_cra, cra),
            message: 'CRA submitted successfully',
            previous_status: 'draft',
            new_status: 'submitted',
            timestamp: Time.current.iso8601
          }, status: :ok
        end

        def render_cra_locked_response(cra)
          render json: {
            data: Api::V1::Cras::ResponseFormatter.send(:format_cra, cra),
            message: 'CRA locked successfully',
            previous_status: 'submitted',
            new_status: 'locked',
            locked_at: cra.locked_at&.iso8601,
            timestamp: Time.current.iso8601
          }, status: :ok
        end
      end
    end
  end
end
