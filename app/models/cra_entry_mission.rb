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

  # Custom validations for business rules
  validate :ensure_business_rule_compliance

  # Scopes
  scope :by_cra_entry, ->(cra_entry_id) { where(cra_entry_id: cra_entry_id) }
  scope :by_mission, ->(mission_id) { where(mission_id: mission_id) }

  # Instance methods
  def display_link
    "CRAEntry #{cra_entry_id} ↔ Mission #{mission_id}"
  end

  # Business rule: Get associated CRA through CRAEntry
  def cra
    cra_entry.cra
  end

  # Business rule: Get the date of the CRAEntry
  def entry_date
    cra_entry.date
  end

  private

  def ensure_business_rule_compliance
    # Business Rule: A CRAEntry can only be linked to one mission
    if cra_entry_id.present? && mission_id.present?
      existing_link = CraEntryMission.where(cra_entry_id: cra_entry_id,
                                            mission_id: mission_id).where.not(id: id).exists?
      if existing_link
        errors.add(:mission_id, 'already_linked',
                   message: 'This CRAEntry is already linked to this mission')
      end
    end
  end
end
