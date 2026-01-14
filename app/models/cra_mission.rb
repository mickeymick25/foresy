# frozen_string_literal: true

# CRAMission
#
# Relation model between CRA and Mission with automatic linking.
# Implements Domain-Driven / Relation-Driven Architecture:
# - Pure relation table (no business logic)
# - Explicit, auditable relationships
# - Automatic creation via CraMissionLinker service
#
# Business Rules:
# - A CRA can be linked to multiple missions
# - A mission can only appear once in a CRA
# - Link is created automatically when first CRAEntry is added
# - Centralized via CraMissionLinker service (no direct endpoints)
#
# Architecture:
# - CRA ↔ Mission relations via this table
# - No business foreign keys in CRA or Mission models
# - All relationships are explicit and trackable

class CraMission < ApplicationRecord
  # Associations
  belongs_to :cra, class_name: 'Cra', foreign_key: 'cra_id', inverse_of: :cra_missions
  belongs_to :mission, class_name: 'Mission', foreign_key: 'mission_id', inverse_of: :cra_missions

  # Validations
  validates :cra_id, presence: true
  validates :mission_id, presence: true

  # Ensure unique relationships
  validates :mission_id, uniqueness: { scope: :cra_id, message: 'can only appear once in a CRA' }

  # Basic validations only (business logic moved to services)

  # Scopes
  scope :by_cra, ->(cra_id) { where(cra_id: cra_id) }
  scope :by_mission, ->(mission_id) { where(mission_id: mission_id) }

  # Instance methods
  def display_link
    "CRA #{cra_id} ↔ Mission #{mission_id}"
  end

  private

  # Business rule validation logic moved to CRA services
end
