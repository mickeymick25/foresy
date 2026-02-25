# frozen_string_literal: true

module Api
  module V1
    module CraEntries
      # Simple stateless ResponseFormatter for CRA Entries
      # Uses class methods (self.) for easy access from controllers
      module ResponseFormatter
        extend self

        # Format a single CRA entry
        # @param entry [CraEntry] The CRA entry to format
        # @param cra [Cra, nil] Optional parent CRA for additional context (unused, kept for compatibility)
        # @return [Hash] Formatted entry hash
        def single(entry, cra = nil)
          {
            id: entry.id,
            date: entry.date.iso8601,
            quantity: to_number(entry.quantity),
            unit_price: to_number(entry.unit_price),
            description: entry.description,
            line_total: to_number(entry.line_total),
            created_at: entry.created_at&.iso8601,
            updated_at: entry.updated_at&.iso8601
          }
        end

        # Format a collection of CRA entries
        # @param entries [Array<CraEntry>] Collection of CRA entries
        # @param cra [Cra, nil] Optional parent CRA for additional context
        # @return [Array<Hash>] Array of formatted entry hashes
        def collection(entries, cra = nil)
          entries.map { |entry| single(entry, cra) }
        end

        private

        # Convert BigDecimal to float for proper JSON serialization
        # Rails serializes BigDecimal as string by default, which causes type mismatches
        # @param value [BigDecimal, Integer, Float, nil]
        # @return [Float, Integer, nil]
        def to_number(value)
          return nil if value.nil?
          return value if value.is_a?(Integer)
          return value.to_f if value.respond_to?(:to_f)

          value
        end
      end
    end
  end
end
