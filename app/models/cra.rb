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

  # Transition methods for CRA lifecycle
  def submit!
    raise CraErrors::InvalidTransitionError.new(status, 'submitted') unless can_transition_to?('submitted')
    update!(status: 'submitted')
  end

  def lock!
    raise CraErrors::InvalidTransitionError.new(status, 'locked') unless can_transition_to?('locked')
    update!(status: 'locked')
  end

  def can_transition_to?(new_status)
    case new_status.to_s
    when 'submitted'
      draft?
    when 'locked'
      submitted?
    else
      false
    end
  end

  def display_name
    "#{month}/#{year} (#{status.humanize})"
  end

  # Simple soft delete method (business logic moved to services)
  def discard
    update(deleted_at: Time.current) if deleted_at.nil?
  end

  # Recalculate total_days and total_amount based on associated CRA entries
  # Used by LifecycleService for submit/lock operations
  def recalculate_totals
    # Calculate totals from active (non-deleted) entries associated with this CRA
    active_entries = CraEntry.joins(:cra_entry_cras)
                           .where(cra_entry_cras: { cra_id: id })
                           .where(deleted_at: nil)

    # Calculate total days (sum of quantities)
    total_days = active_entries.sum(:quantity)

    # Calculate total amount (sum of quantity * unit_price)
    total_amount = active_entries.sum { |entry| entry.quantity * entry.unit_price }

    # Update the CRA with new totals
    update!(
      total_days: total_days,
      total_amount: total_amount
    )

    Rails.logger.info "[Cra] Recalculated totals for CRA #{id}: #{total_days} days, #{total_amount} amount"
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



  # Simple validation for enum values
  def validate_enum_values
    return unless status.present?

    unless VALID_STATUSES.include?(status.to_s)
      errors.add(:status, :invalid, message: "must be one of: #{VALID_STATUSES.join(', ')}")
    end
  end
end
