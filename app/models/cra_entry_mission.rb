# frozen_string_literal: true

# CRAEntryMission
#
# Relation model between CRAEntry and Mission.
# Implements Domain-Driven / Relation-Driven Architecture:
# - Pure relation table (no business logic)
# - Explicit, auditable relationships
# - Links CRAEntries to specific missions for activity tracking
#
# Business Rules:
# - A CRAEntry can be linked to exactly one mission
# - A mission can have multiple CRAEntries across different CRAs and dates
# - Supports multi-mission entries on the same date within a CRA
# - Enables precise activity tracking per mission
#
# Architecture:
# - CRAEntry ↔ Mission relations via this table
# - No business foreign keys in CRAEntry or Mission models
# - All relationships are explicit and trackable

class CraEntryMission < ApplicationRecord
  # Associations
  belongs_to :cra_entry, class_name: 'CraEntry', foreign_key: 'cra_entry_id', inverse_of: :cra_entry_missions
  belongs_to :mission, class_name: 'Mission', foreign_key: 'mission_id', inverse_of: :cra_entry_missions

  # Validations
  validates :cra_entry_id, presence: true
  validates :mission_id, presence: true

  # Ensure unique relationships
  validates :mission_id, uniqueness: { scope: :cra_entry_id, message: 'can only be linked once to a CRAEntry' }

  # Basic validations only (business logic moved to services)

  # Scopes
  scope :by_cra_entry, ->(cra_entry_id) { where(cra_entry_id: cra_entry_id) }
  scope :by_mission, ->(mission_id) { where(mission_id: mission_id) }

  # Instance methods
  def display_link
    "CRAEntry #{cra_entry_id} ↔ Mission #{mission_id}"
  end

  # Note: Complex business logic moved to CRA services

  private

  # Business rule validation logic moved to CRA services
end
