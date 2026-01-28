# frozen_string_literal: true

require 'csv'

module Api
  module V1
    module Cras
      class ExportService
        SUPPORTED_FORMATS = %w[csv].freeze
        UTF8_BOM = "\uFEFF"

        def initialize(cra:, format:, options: {})
          @cra = cra
          @format = format&.downcase
          @options = options
        end

        def call
          validate_format!

          case @format
          when 'csv' then export_csv
          end
        end

        private

        def validate_format!
          return if SUPPORTED_FORMATS.include?(@format)

          raise CraErrors::InvalidPayloadError,
                "format must be one of: #{SUPPORTED_FORMATS.join(', ')}"
        end

        def export_csv
          {
            data: generate_csv,
            filename: filename,
            content_type: 'text/csv'
          }
        end

        def filename
          "cra_#{@cra.year}_#{format('%02d', @cra.month)}.csv"
        end

        def generate_csv
          # UTF-8 BOM for Excel compatibility
          # Ruby 3.4: CSV.generate does not accept keyword arguments
          UTF8_BOM + CSV.generate do |csv|
            csv << headers
            append_entries(csv) if include_entries?
            append_total(csv)
          end
        end

        def include_entries?
          @options.fetch(:include_entries, true)
        end

        def headers
          %w[
            date
            mission_name
            quantity
            unit_price_eur
            line_total_eur
            description
          ]
        end

        def append_entries(csv)
          @cra.cra_entries.includes(:cra_entry_missions, :missions).find_each do |entry|
            csv << [
              entry.date.iso8601,
              entry.mission&.name,
              entry.quantity,
              euros(entry.unit_price),
              euros(entry.line_total),
              entry.description
            ]
          end
        end

        def append_total(csv)
          csv << [
            'TOTAL',
            nil,
            @cra.total_days,
            nil,
            euros(@cra.total_amount),
            nil
          ]
        end

        def euros(cents)
          format('%.2f', cents.to_i / 100.0)
        end
      end
    end
  end
end
