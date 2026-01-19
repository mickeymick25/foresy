# frozen_string_literal: true



# CRAEntry (CRA Entry)
#
# Pure domain model representing an individual activity entry within a CRA.
# Follows Domain-Driven / Relation-Driven Architecture principles:
# - NO business foreign keys to CRA or Mission
# - ALL relationships via explicit relation tables (CRAEntryCRA, CRAEntryMission)
# - Pure domain entity with complete business logic
#
# Business Context:
# A CRAEntry represents a billable activity entry that allows independents to:
# - declare real activity per mission for a specific date
# - track produced time and value with free granularity
# - provide detailed breakdown for CRA calculations
# - support multi-mission entries on the same date
#
# Key Features:
# - Free granularity for quantity (0.25, 0.5, 1.0, 2.0 days)
# - Unit price in cents for precise calculations
# - Soft delete support with cascade
# - Comprehensive validations for business rules
# - No upper limit on quantity (business decision)
#
# Validations:
# - date: required, must be a valid date
# - quantity: required, decimal with 2 decimal places
# - unit_price: required, integer (cents)
# - description: optional, length max 500
#
# Associations:
# - has_many :cra_entry_cras (relation table)
# - has_many :cras, through: :cra_entry_cras
# - has_many :cra_entry_missions (relation table)
# - has_many :missions, through: :cra_entry_missions
#
# Scopes:
# - .active: returns non-deleted entries
# - .by_date: filter by date
# - .by_date_range: filter by date range
# - .by_cra: filter by CRA
# - .by_mission: filter by mission
class CraEntry < ApplicationRecord
  # Soft delete implementation (manual, no gem dependency)
  default_scope { where(deleted_at: nil) }

  # Scope to include deleted records
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  # Instance methods for soft delete
  def discarded?
    deleted_at.present?
  end

  def undiscard
    update(deleted_at: nil) if deleted_at.present?
  end

  # Validations
  validates :date, presence: true
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0, precision: 10, scale: 2 }
  validates :unit_price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :description, length: { maximum: 500 }, allow_blank: true

  # Business rule validations (simplified for pure domain model)
  validate :validate_date_format

  # Lifecycle validations - Check CRA status before allowing operations
  before_create :validate_cra_modifiable_for_create
  before_update :validate_cra_modifiable_for_update
  before_destroy :validate_cra_modifiable_for_destroy

  # Transient attribute writers for TDD compatibility (preserves DDD architecture)
  attr_writer :cra, :mission

  # Associations via relation tables (Domain-Driven Architecture)
  has_many :cra_entry_cras, dependent: :destroy
  has_many :cras, through: :cra_entry_cras

  has_many :cra_entry_missions, dependent: :destroy
  has_many :missions, through: :cra_entry_missions

  # Scopes
  scope :active, -> { where(deleted_at: nil) }
  scope :by_date, ->(date) { where(date: date) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_cra, ->(cra_id) { joins(:cra_entry_cras).where(cra_entry_cras: { cra_id: cra_id }) }
  scope :by_mission, ->(mission_id) { joins(:cra_entry_missions).where(cra_entry_missions: { mission_id: mission_id }) }

  # Instance methods
  def active?
    deleted_at.nil?
  end

  # Check if the entry can be modified (not in submitted or locked CRA)
  def modifiable?
    return false if discarded? || !cras.any?

    cra = cras.first
    return false if cra.nil?

    !cra.submitted? && !cra.locked?
  end

  def display_name
    "#{date} - #{quantity} days @ #{unit_price}c"
  end

  # Calculate line total (quantity * unit_price)
  # Used by ResponseFormatter for displaying entry totals
  def line_total
    quantity * unit_price
  end

  # Simple soft delete method (business logic moved to services)
  def discard
    return false if deleted_at.present?
    update(deleted_at: Time.current)
  end

  private

  def validate_date_format
    # Accept both Date objects and date strings
    return if date.is_a?(Date)

    # Try to convert string to date
    if date.is_a?(String)
      begin
        # Try to parse the date string - if it fails, we'll let the database validation handle it
        Date.parse(date)
      rescue ArgumentError
        # If parsing fails, add error
        errors.add(:date, 'invalid', message: 'must be a valid date')
      end
    else
      errors.add(:date, 'invalid', message: 'must be a valid date')
    end
  end

  # CRA lifecycle validation methods
  def validate_cra_modifiable_for_create
    # Try to get CRA from association, but also check if passed as attribute
    cra = cras.first
    cra ||= @cra if defined?(@cra) && @cra.present?

    return if cra.nil? # Skip if no CRA found

    if cra.locked?
      errors.add(:base, 'Cannot add entries to locked CRA')
      raise CraErrors::CraLockedError, 'Cannot add entries to locked CRA'
    elsif cra.submitted?
      errors.add(:base, 'Cannot add entries to submitted CRA')
      raise CraErrors::CraSubmittedError, 'Cannot add entries to submitted CRA'
    end
  end

  def validate_cra_modifiable_for_update
    # Reload associations to ensure we have the latest data
    cras.reload
    cra = cras.first
    return if cra.nil? # Skip if no CRA associated

    if cra.locked?
      errors.add(:base, 'Cannot modify entries in locked CRA')
      raise CraErrors::CraLockedError, 'Cannot modify entries in locked CRA'
    elsif cra.submitted?
      errors.add(:base, 'Cannot modify entries in submitted CRA')
      raise CraErrors::CraSubmittedError, 'Cannot modify entries in submitted CRA'
    end
  end

  def validate_cra_modifiable_for_destroy
    # Reload associations to ensure we have the latest data
    cras.reload
    cra = cras.first
    return if cra.nil? # Skip if no CRA associated

    if cra.locked?
      errors.add(:base, 'Cannot delete entries from locked CRA')
      raise CraErrors::CraLockedError, 'Cannot delete entries from locked CRA'
    elsif cra.submitted?
      errors.add(:base, 'Cannot delete entries from submitted CRA')
      raise CraErrors::CraSubmittedError, 'Cannot delete entries from submitted CRA'
    end
  end
end
