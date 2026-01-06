# frozen_string_literal: true

# GitLedgerPayload
#
# Helper module for building canonical JSON payloads for Git Ledger commits.
# Used by GitLedgerService to serialize CRA data for immutable audit trail.
module GitLedgerPayload
  class << self
    def build(cra)
      # FC-07 PLATINUM: Canonical JSON payload with all contract fields
      {
        'cra_id' => cra.id,
        'month' => cra.month,
        'year' => cra.year,
        'missions' => cra.missions.map(&:id).sort,
        'entries' => build_entries(cra),
        'totals' => build_totals(cra),
        'locked_at' => cra.locked_at&.iso8601,
        'currency' => cra.currency,
        'description' => cra.description,
        'status' => cra.status,
        'created_by_user_id' => cra.created_by_user_id,
        'created_at' => cra.created_at.iso8601,
        'updated_at' => cra.updated_at.iso8601
      }
    end

    private

    def build_entries(cra)
      # FC-07 PLATINUM: Build entries with proper structure and deterministic ordering
      entries = cra.cra_entries.active.map do |entry|
        {
          'id' => entry.id,
          'date' => entry.date.iso8601,
          'quantity' => entry.quantity.to_f,
          'unit_price' => entry.unit_price,
          'description' => entry.description,
          'mission_id' => entry.mission&.id
        }
      end
      # Deterministic ordering by date then ID for canonical JSON
      entries.sort_by { |e| [e['date'], e['id']] }
    end

    def build_totals(cra)
      # FC-07 PLATINUM: Server-side calculations only, never trusted from client
      {
        'total_days' => (cra.total_days || cra.calculate_total_days).to_f,
        'total_amount' => cra.total_amount || cra.calculate_total_amount
      }
    end
  end
end
