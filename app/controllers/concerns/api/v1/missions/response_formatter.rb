# frozen_string_literal: true

module Api
  module V1
    module Missions
      # Response formatting concern for mission-related operations
      # Provides centralized response formatting functionality for consistency
      module ResponseFormatter
        extend ActiveSupport::Concern

        class_methods do
          # Format a single mission for response
          # @param mission [Mission] The mission object to format
          # @param options [Hash] Formatting options
          # @option options [Boolean] :include_companies Whether to include company information
          # @option options [Boolean] :include_financial Whether to include financial information
          # @option options [Boolean] :include_dates Whether to include date information
          # @return [Hash] Formatted mission data
          #
          # @example
          #   ResponseFormatter.single(mission, include_companies: true)
          def single(mission, options = {})
            return nil unless mission.present?

            options = {
              include_companies: true,
              include_financial: true,
              include_dates: true
            }.merge(options)

            response = {
              id: mission.id,
              name: mission.name,
              description: mission.description,
              mission_type: mission.mission_type,
              status: mission.status,
              created_at: mission.created_at,
              updated_at: mission.updated_at
            }

            # Include financial information
            if options[:include_financial]
              if mission.time_based?
                response[:daily_rate] = mission.daily_rate
              elsif mission.fixed_price?
                response[:fixed_price] = mission.fixed_price
              end
              response[:currency] = mission.currency if mission.currency.present?
            end

            # Include date information
            if options[:include_dates]
              response[:start_date] = mission.start_date.iso8601 if mission.start_date.present?
              response[:end_date] = mission.end_date.iso8601 if mission.end_date.present?
            end

            # Include company information if requested and available
            if options[:include_companies] && mission.respond_to?(:mission_companies)
              response[:companies] = format_mission_companies(mission.mission_companies)
            end

            response
          end

          # Format a collection of missions for response
          # @param missions [ActiveRecord::Relation] The missions collection to format
          # @param options [Hash] Formatting options
          # @option options [Hash] :pagination Pagination information
          # @option options [Boolean] :include_companies Whether to include company information
          # @return [Hash] Formatted missions collection with meta information
          #
          # @example
          #   ResponseFormatter.collection(missions, pagination: pagination_info)
          def collection(missions, options = {})
            options = {
              include_companies: true,
              include_financial: true,
              include_dates: true
            }.merge(options)

            formatted_missions = missions.map { |mission| single(mission, options) }

            response = {
              data: formatted_missions,
              meta: {
                total: missions.respond_to?(:total_count) ? missions.total_count : missions.count,
                count: missions.count
              }
            }

            # Include pagination information if provided
            if options[:pagination].present?
              response[:pagination] = format_pagination(options[:pagination])
            end

            response
          end

          # Format error response
          # @param errors [Array<String>|ResultObject] Array of error messages or ResultObject
          # @param error_type [Symbol] Type of error (or options Hash for ResultObject)
          # @param options [Hash] Additional options
          # @return [Hash] Formatted error response
          #
          # @example ('ancienne API)
          #   ResponseFormatter.error(['Invalid data'], :validation_failed)
          # @example (nouvelle API ApplicationResult)
          #   ResponseFormatter.error(result_object)
          def error(result_or_errors, error_type_or_options = nil, options = {})
            # Détecter si on utilise la nouvelle API ApplicationResult
            if result_or_errors.respond_to?(:success?)
              # Nouvelle API ApplicationResult
              errors = result_or_errors.error
              error_type = result_or_errors.error
              options = options.merge(result_or_errors.meta || {})
            else
              # Ancienne API pour compatibilité
              errors = result_or_errors
              error_type = error_type_or_options
            end

            {
              error: true,
              error_type: error_type,
              messages: Array(errors),
              timestamp: Time.current.iso8601
            }.merge(options)
          end

          # Format success response
          # @param data [Hash] Success data
          # @param message [String] Success message
          # @param options [Hash] Additional options
          # @return [Hash] Formatted success response
          #
          # @example
          #   ResponseFormatter.success({ mission: mission_data }, 'Mission created successfully')
          def success(data, message = nil, options = {})
            {
              success: true,
              data: data,
              message: message,
              timestamp: Time.current.iso8601
            }.merge(options)
          end

          # Format mission companies information
          # @param mission_companies [ActiveRecord::Association] The mission_companies association
          # @return [Array<Hash>] Formatted company information
          #
          # @example
          #   format_mission_companies(mission.mission_companies)
          def format_mission_companies(mission_companies)
            mission_companies.map do |mc|
              {
                id: mc.company_id,
                role: mc.role,
                company: format_company_basic_info(mc.company)
              }
            end
          end

          # Format basic company information
          # @param company [Company] The company object
          # @return [Hash] Formatted basic company information
          #
          # @example
          #   format_company_basic_info(company)
          def format_company_basic_info(company)
            return nil unless company.present?

            {
              id: company.id,
              name: company.name,
              siret: company.siret
            }
          end

          # Format pagination information
          # @param pagination [Hash] Pagination information
          # @return [Hash] Formatted pagination information
          #
          # @example
          #   format_pagination(pagy_info)
          def format_pagination(pagination)
            {
              page: pagination[:page] || 1,
              per_page: pagination[:per_page] || 20,
              total: pagination[:total] || 0,
              pages: pagination[:pages] || 1,
              has_next: pagination[:next] || false,
              has_prev: pagination[:prev] || false,
              next_page: pagination[:next] ? (pagination[:page] + 1) : nil,
              prev_page: pagination[:prev] ? (pagination[:page] - 1) : nil
            }
          end

          # Format mission statistics
          # @param stats [Hash] Mission statistics
          # @return [Hash] Formatted statistics
          #
          # @example
          #   format_mission_stats({ total: 100, active: 25 })
          def format_mission_stats(stats)
            {
              total_missions: stats[:total] || 0,
              active_missions: stats[:active] || 0,
              completed_missions: stats[:completed] || 0,
              draft_missions: stats[:draft] || 0,
              cancelled_missions: stats[:cancelled] || 0,
              time_based_missions: stats[:time_based] || 0,
              fixed_price_missions: stats[:fixed_price] || 0,
              total_value: stats[:total_value] || 0,
              currency: stats[:currency] || 'EUR'
            }
          end

          # Format mission for export
          # @param mission [Mission] The mission to format for export
          # @param format [String] Export format (csv, json, xlsx)
          # @return [Hash] Formatted mission for export
          #
          # @example
          #   format_for_export(mission, 'csv')
          def format_for_export(mission, format = 'csv')
            base_data = single(mission, include_companies: true)

            case format
            when 'csv'
              # Flatten for CSV export
              {
                id: mission.id,
                name: mission.name,
                description: mission.description,
                mission_type: mission.mission_type,
                status: mission.status,
                start_date: mission.start_date&.iso8601,
                end_date: mission.end_date&.iso8601,
                daily_rate: mission.daily_rate,
                fixed_price: mission.fixed_price,
                currency: mission.currency,
                independent_company: mission.mission_companies.find_by(role: 'independent')&.company&.name,
                client_company: mission.mission_companies.find_by(role: 'client')&.company&.name,
                created_at: mission.created_at,
                updated_at: mission.updated_at
              }
            when 'json', 'xlsx'
              base_data
            else
              base_data
            end
          end
        end

        # Instance methods for response formatting (delegated to class methods)

        # Format a single mission for response
        # @param mission [Mission] The mission object to format
        # @param options [Hash] Formatting options
        # @return [Hash] Formatted mission data
        def format_single(mission, options = {})
          self.class.single(mission, options)
        end

        # Format a collection of missions for response
        # @param missions [ActiveRecord::Relation] The missions collection to format
        # @param options [Hash] Formatting options
        # @return [Hash] Formatted missions collection
        def format_collection(missions, options = {})
          self.class.collection(missions, options)
        end

        # Format error response
        # @param errors [Array<String>] Array of error messages
        # @param error_type [Symbol] Type of error
        # @param options [Hash] Additional options
        # @return [Hash] Formatted error response
        def format_error(errors, error_type, options = {})
          self.class.error(errors, error_type, options)
        end

        # Format success response
        # @param data [Hash] Success data
        # @param message [String] Success message
        # @param options [Hash] Additional options
        # @return [Hash] Formatted success response
        def format_success(data, message = nil, options = {})
          self.class.success(data, message, options)
        end
      end
    end
  end
end
