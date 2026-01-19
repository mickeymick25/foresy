# frozen_string_literal: true

# Serializer for CraEntry model
# Implements the standardized Result contract for CRA API responses
#
# Contract Format:
# {
#   data: {
#     id: uuid,
#     type: "cra_entry",
#     attributes: { ... },
#     relationships: { ... }
#   }
# }
#
# Usage:
# CraEntrySerializer.new(entry).serialize
# CraEntrySerializer.collection(entries).serialize
class CraEntrySerializer
  attr_reader :entry

  def initialize(entry)
    @entry = entry
  end

  # Serialize a single CRA entry
  def serialize
    return nil unless entry

    {
      data: {
        id: entry.id.to_s,
        type: "cra_entry",
        attributes: {
          date: entry.date&.iso8601,
          quantity: entry.quantity.to_f,
          unit_price: entry.unit_price.to_i,
          description: entry.description,
          created_at: entry.created_at&.iso8601,
          updated_at: entry.updated_at&.iso8601,
          deleted_at: entry.deleted_at&.iso8601,
          mission = entry.cra_entry_missions.first&.mission
          mission_id: mission&.id&.to_s
        },
        relationships: build_relationships
      }
    }
  end

  # Serialize a collection of CRA entries
  def self.collection(entries)
    new_entries = entries.is_a?(ActiveRecord::Relation) ? entries : entries.compact
    {
      data: new_entries.map { |entry| new(entry).serialize[:data] },
      meta: {
        count: new_entries.size
      }
    }
  end

  # JSON API compliant relationships
  def build_relationships
    {
      cra: build_cra_relationship,
      mission: build_mission_relationship
    }.compact
  end

  private

  def build_cra_relationship
    return nil unless entry.respond_to?(:cra) && entry.cra.present?

    {
      data: {
        id: entry.cra.id.to_s,
        type: "cra"
      }
    }
  end

  def build_mission_relationship
    return nil unless entry.respond_to?(:mission) && entry.cra_entry_missions.first&.mission.present?

    {
      data: {
        id: entry.cra_entry_missions.first&.mission.id.to_s,
        type: "mission"
      }
    }
  end
end
