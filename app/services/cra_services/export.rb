# frozen_string_literal: true

require 'csv'

# CRA Export Service
# Validates export formats and generates CSV/PDF exports
# Uses ApplicationResult contract for consistent Service → Controller communication
#
# CONTRACT:
# - Returns ApplicationResult exclusively
# - No business exceptions raised
# - No HTTP concerns in service
# - Single source of truth for business rules
#
# @example
#   result = CraServices::Export.call(
#     cra: cra_instance,
#     current_user: user_instance,
#     include_entries: true,
#     format: 'csv'
#   )
#   result.success? # => true/false
#   result.data # => CSV content string
#
class CraServices
  class Export
    UTF8_BOM = "\uFEFF"
    SUPPORTED_FORMATS = ['csv'].freeze

    def self.call(cra:, current_user:, include_entries: true, format: 'csv')
      new(cra: cra, current_user: current_user, include_entries: include_entries, format: format).call
    end

    def initialize(cra:, current_user:, include_entries:, format:)
      @cra = cra
      @current_user = current_user
      @include_entries = include_entries
      @format = format.to_s.downcase
    end

    def call
      # Input validation
      unless @cra.present?
        return ApplicationResult.fail(error: :invalid_cra, status: :bad_request,
                                      message: 'CRA is required')
      end

      # Format validation - CRITICAL FIX
      unless valid_format?
        return ApplicationResult.fail(
          error: :invalid_payload,
          status: :unprocessable_entity,
          message: "Export format '#{@format}' is not supported. Supported formats: #{SUPPORTED_FORMATS.join(', ')}"
        )
      end

      # Permission check
      unless permitted?
        return ApplicationResult.fail(error: :forbidden, status: :forbidden,
                                      message: 'User cannot export this CRA')
      end

      # Lifecycle check
      unless cra_submitted_or_locked?
        return ApplicationResult.fail(error: :invalid_lifecycle, status: :conflict,
                                      message: 'CRA must be submitted or locked')
      end

      recalc_totals_safe

      csv_content = generate_csv_safe
      unless csv_content
        return ApplicationResult.fail(error: :csv_generation_failed, status: :internal_error,
                                      message: 'Failed to generate CSV')
      end

      ApplicationResult.success(data: csv_content)
    rescue StandardError => e
      Rails.logger.warn "[CraServices::Export] Failed: #{e.message}"
      ApplicationResult.fail(error: :internal_error, status: :internal_error, message: e.message)
    end

    private

    def valid_format?
      # Only 'csv' format is currently supported
      # 'pdf' is planned for future versions
      @format.present? && SUPPORTED_FORMATS.include?(@format)
    end

    def permitted?
      return false unless @cra.present?
      return false unless @current_user.present?

      # Use modifiable_by? to handle both flag ON and OFF paths
      @cra.modifiable_by?(@current_user)
    end

    def cra_submitted_or_locked?
      return false unless @cra.present?

      %w[submitted locked].include?(@cra.status)
    end

    def recalc_totals_safe
      @cra.recalculate_totals if @cra.respond_to?(:recalculate_totals)
    rescue StandardError => e
      Rails.logger.warn "[CraServices::Export] recalc_totals failed: #{e.message}"
    end

    def generate_csv_safe
      UTF8_BOM + CSV.generate do |csv|
        csv << csv_headers
        append_entries(csv) if @include_entries
        append_total(csv)
      end
    rescue StandardError => e
      Rails.logger.warn "[CraServices::Export] generate_csv failed: #{e.message}"
      nil
    end

    def csv_headers
      %w[date mission_name quantity unit_price_eur line_total_eur description]
    end

    def append_entries(csv)
      @cra.cra_entries.includes(:cra_entry_missions, :missions).each do |entry|
        mission_name = entry.missions.first&.name || 'Mission sans nom'
        quantity = entry.quantity.to_f
        unit_price_eur = euros(entry.unit_price)
        line_total_eur = euros(calculate_line_total(entry))
        description = entry.description || ''

        csv << [
          entry.date.iso8601,
          mission_name,
          quantity,
          unit_price_eur,
          line_total_eur,
          description
        ]
      end
    rescue StandardError => e
      Rails.logger.warn "[CraServices::Export] append_entries failed: #{e.message}"
      # Continue with empty entries if there's an error
    end

    def append_total(csv)
      total_amount_eur = euros(@cra.total_amount)
      csv << ['TOTAL', '', '', '', total_amount_eur, '']
    end

    def euros(cents)
      format('%.2f', cents.to_i / 100.0)
    end

    def calculate_line_total(entry)
      # Calculate line total as quantity * unit_price (in cents)
      (entry.quantity.to_f * entry.unit_price).round
    end
  end
end
