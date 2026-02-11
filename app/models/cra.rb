# frozen_string_literal: true

# CRA (Compte Rendu d'Activité)
#
# Pure domain model representing a monthly activity report for independents.
# Follows Domain-Driven / Relation-Driven Architecture principles:
# - NO business foreign keys to Mission or Company
# - ALL relationships via explicit relation tables (CRAMission, CRAEntryCRA)
# - Pure domain entity with complete business logic
#
# Business Context:
# A CRA represents a legal and contractual artifact that allows independents to:
# - declare real activity per mission
# - track produced time and value
# - maintain monthly, auditable, versioned history
# - provide functional base for invoicing, fiscal reporting, long-term analytics
#
# Key Features:
# - CRA lifecycle with strict status transitions (draft → submitted → locked)
# - Financial calculations (total_days, total_amount) computed server-side only
# - Soft delete support with cascade
# - Multi-mission support within a single CRA
# - Comprehensive validations for business rules
#
# Associations:
# - has_many :cra_missions (relation table)
# - has_many :missions, through: :cra_missions
# - has_many :cra_entries (via cra_entry_cras relation table)
# - has_many :cra_entry_cras (relation table)
#
# Validations:
# - month: required, 1-12
# - year: required
# - status: required enum (draft | submitted | locked)
# - description: optional, length max 2000
# - currency: required, ISO 4217 format, defaults to EUR
# - created_by_user_id: required, audit-only
# - uniqueness: (created_by_user_id, month, year) where deleted_at IS NULL
#
# Scopes:
# - .active: returns non-deleted CRAs
# - .by_status: filter by CRA status
# - .by_month: filter by month
# - .by_year: filter by year
# - .by_user: filter by creator user
# - .draft: CRAs in draft status
# - .submitted: CRAs in submitted status
# - .locked: CRAs in locked status
# - .accessible_to: CRAs accessible to a user (via their companies and missions)

# NOTE: GitLedgerError is now handled via Rails Zeitwerk autoloading
# See app/exceptions/application_error.rb for the definition

class Cra < ApplicationRecord
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

  # Valid enum values (for validation before PostgreSQL)
  VALID_STATUSES = %w[draft submitted locked].freeze

  # Enums matching PostgreSQL enum types
  enum :status, { draft: 'draft', submitted: 'submitted', locked: 'locked' }, validate: false

  # Custom validation for enum values (must run before PostgreSQL constraint)
  validate :validate_enum_values

  # Validations
  validates :month, presence: true, inclusion: { in: 1..12, message: 'must be between 1 and 12' }
  validates :year, presence: true, numericality: { only_integer: true, greater_than: 2000 }
  validates :status, presence: true, inclusion: { in: %w[draft submitted locked] }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :currency, presence: true,
                       format: { with: /\A[A-Z]{3}\z/, message: 'must be a valid ISO 4217 currency code' }
  validates :created_by_user_id, presence: true

  # Financial validations
  validate :validate_financial_fields

  # Uniqueness validation (user, month, year)
  validate :validate_uniqueness

  # Callbacks
  before_validation :set_default_currency
  before_validation :set_default_status

  # Associations via relation tables (Domain-Driven Architecture)
  has_many :cra_missions
  has_many :missions, through: :cra_missions

  has_many :cra_entry_cras, dependent: :destroy
  has_many :cra_entries, through: :cra_entry_cras

  # Creator association (for authorization) - FIXED: follows Rails naming conventions
  belongs_to :user, class_name: 'User', foreign_key: 'created_by_user_id', optional: true

  # Scopes
  scope :active, -> { where(deleted_at: nil) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_month, ->(month) { where(month: month) }
  scope :by_year, ->(year) { where(year: year) }
  scope :by_user, ->(user_id) { where(created_by_user_id: user_id) }

  scope :draft, -> { where(status: 'draft') }
  scope :submitted, -> { where(status: 'submitted') }
  scope :locked, -> { where(status: 'locked') }

  # Scope for user accessibility (FC 06 access rules via missions + creator access)
  # A CRA is accessible if:
  # 1. The user created it (created_by_user_id)
  # 2. OR the user has access to missions associated with the CRA
  scope :accessible_to, lambda { |user|
    # Get IDs of CRAs accessible via missions
    via_missions_ids = joins(:cra_missions)
                       .joins('INNER JOIN missions ON missions.id = cra_missions.mission_id')
                       .joins('INNER JOIN mission_companies ON mission_companies.mission_id = missions.id')
                       .joins('INNER JOIN user_companies ON user_companies.company_id = mission_companies.company_id')
                       .where(user_companies: { user_id: user.id, role: %w[independent client] })
                       .select(:id)

    # CRAs created by user OR accessible via missions
    where(created_by_user_id: user.id).or(where(id: via_missions_ids))
  }

  # Instance methods
  def active?
    deleted_at.nil?
  end

  def draft?
    status == 'draft'
  end

  def submitted?
    status == 'submitted'
  end

  def locked?
    status == 'locked'
  end

  def modifiable?
    draft? || submitted?
  end

  def display_name
    "#{month}/#{year} (#{status.humanize})"
  end

  # Business rule: Check if CRA can be modified by user
  def modifiable_by?(user)
    return false unless user.present?
    return false if locked?

    created_by_user_id == user.id
  end

  # Business rule: Check if status transition is valid
  def can_transition_to?(new_status)
    valid_transitions = {
      'draft' => %w[submitted],
      'submitted' => %w[locked]
    }

    valid_transitions[status]&.include?(new_status) || false
  end

  # Business rule: Transition CRA status
  def transition_to!(new_status)
    unless can_transition_to?(new_status)
      errors.add(:status, "Cannot transition from #{status} to #{new_status}")
      return false
    end

    update!(status: new_status)
  end

  # Business rule: Calculate total days from CRA entries
  def calculate_total_days
    cra_entries.active.sum(:quantity) || 0
  end

  # Business rule: Calculate total amount from CRA entries
  def calculate_total_amount
    # total_amount = sum(quantity * unit_price)
    cra_entries.active.sum('quantity * unit_price') || 0
  end

  # Business rule: Recalculate totals (server-side only)
  def recalculate_totals
    new_total_days = calculate_total_days
    new_total_amount = calculate_total_amount

    # Only save if values have actually changed
    if total_days != new_total_days || total_amount != new_total_amount
      self.total_days = new_total_days
      self.total_amount = new_total_amount
      save(validate: false)
    end
  end

  # Business rule: Submit CRA (draft → submitted)
  def submit!
    unless draft?
      errors.add(:base, 'Only draft CRAs can be submitted')
      return false
    end

    # Recalculate totals before submission
    recalculate_totals

    update!(status: 'submitted')
  end

  # Business rule: Lock CRA (submitted → locked) with Git versioning
  # Implements FC-07 PLATINUM contract: Atomic transaction with Git Ledger
  #
  # Contract Requirements:
  # - CRA lock, totals recalculation and Git commit executed in single DB transaction
  # - Any Git failure triggers complete rollback
  # - Git error → 500 internal_error, CRA remains unlocked
  def lock!
    unless submitted?
      errors.add(:base, 'Only submitted CRAs can be locked')
      return false
    end

    # Atomic transaction as per FC-07 PLATINUM contract
    # This ensures: lock + recalcul + Git commit are all-or-nothing
    transaction do
      # Step 1: Recalculate totals (server-side only, never trusted from client)
      recalculate_totals

      # Step 2: Lock the CRA (status change)
      update!(status: 'locked', locked_at: Time.current)

      # Step 3: Commit to Git Ledger (FC-07 PLATINUM requirement)
      # If this fails, entire transaction rolls back (including CRA lock)
      GitLedgerService.commit_cra_lock!(self)
    end
  rescue GitLedgerService::GitLedgerError => e
    Rails.logger.error "[CRA::lock!] Git Ledger commit failed for CRA #{id}: #{e.message}"
    errors.add(:base, 'Failed to create immutable audit trail - CRA remains unlocked')
    # Re-raise as StandardError to trigger 500 response in controller
    raise StandardError, "Git Ledger commit failed: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[CRA::lock!] Transaction failed for CRA #{id}: #{e.message}"
    errors.add(:base, "Failed to lock CRA: #{e.message}")
    raise
  end

  # Soft delete with business logic
  def discard
    # Check if CRA is submitted or locked (business rule)
    if submitted? || locked?
      errors.add(:base, 'Submitted or locked CRAs cannot be deleted')
      return false
    end

    update(deleted_at: Time.current) if deleted_at.nil?
  end

  private

  def validate_financial_fields
    # Business rule: currency must be ISO 4217
    if currency.present? && !/\A[A-Z]{3}\z/.match?(currency)
      errors.add(:currency, 'invalid', message: 'must be a valid ISO 4217 currency code')
    end
  end

  def validate_uniqueness
    # Business rule: 1 CRA max per (user, month, year) - FC-07 contract: exclude deleted CRAs
    scope = Cra.where(created_by_user_id: created_by_user_id, month: month, year: year, deleted_at: nil)
    scope = scope.where.not(id: id) if persisted?

    errors.add(:base, 'A CRA already exists for this user, month, and year') if scope.exists?
  end

  def set_default_currency
    self.currency = 'EUR' if currency.nil?
  end

  def set_default_status
    self.status = 'draft' if status.nil?
  end

  def validate_enum_values
    # Validate status before it reaches PostgreSQL
    if status.present? && !VALID_STATUSES.include?(status.to_s)
      errors.add(:status, :invalid, message: "must be one of: #{VALID_STATUSES.join(', ')}")
    end
  end
end
