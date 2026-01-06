# frozen_string_literal: true

# CRAEntryCra
#
# Relation model between CRA and CRAEntry.
# Implements Domain-Driven / Relation-Driven Architecture:
# - Pure relation table (no business logic)
# - Explicit, auditable relationships
# - 1:N relationship via relation table (CRA has many CRAEntries)
#
# Business Rules:
# - A CRA can contain multiple CRAEntries
# - A CRAEntry belongs to exactly one CRA
# - Relationship is mandatory for CRAEntries to be associated with a CRA
# - Cascade delete ensures data integrity
#
# Architecture:
# - CRA ↔ CRAEntry relations via this table
# - No business foreign keys in CRA or CRAEntry models
# - All relationships are explicit and trackable

class CraEntryCra < ApplicationRecord
  # Associations
  belongs_to :cra, class_name: 'Cra', foreign_key: 'cra_id', inverse_of: :cra_entry_cras
  belongs_to :cra_entry, class_name: 'CraEntry', foreign_key: 'cra_entry_id', inverse_of: :cra_entry_cras

  # Validations
  validates :cra_id, presence: true
  validates :cra_entry_id, presence: true

  # Ensure unique relationships
  validates :cra_entry_id, uniqueness: { scope: :cra_id, message: 'can only belong to one CRA' }

  # Custom validations for business rules
  validate :ensure_business_rule_compliance

  # Business rule: Recalculate CRA totals when link is created or destroyed

  # Scopes
  scope :by_cra, ->(cra_id) { where(cra_id: cra_id) }
  scope :by_cra_entry, ->(cra_entry_id) { where(cra_entry_id: cra_entry_id) }

  # Instance methods
  def display_link
    "CRA #{cra_id} ↔ CRAEntry #{cra_entry_id}"
  end

  private

  def ensure_business_rule_compliance
    # Business Rule: A CRAEntry can only belong to one CRA
    if cra_id.present? && cra_entry_id.present?
      existing_link = CraEntryCra.where(cra_id: cra_id, cra_entry_id: cra_entry_id).where.not(id: id).exists?
      if existing_link
        errors.add(:cra_entry_id, 'already_linked',
                   message: 'This CRAEntry is already linked to this CRA')
      end
    end
  end

  # Business rule: Recalculate CRA totals when link is created or destroyed
end
