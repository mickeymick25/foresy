# frozen_string_literal: true

# Mission
#
# Pure domain model representing a professional mission between companies.
# Follows Domain-Driven / Relation-Driven Architecture principles:
# - NO business foreign keys to Company or User
# - ALL relationships via explicit relation tables (MissionCompany)
# - Pure domain entity with complete business logic
#
# Business Context:
# A Mission represents an operational contract between:
# - an independent company (represented by an Independent)
# - a client company
#
# Key Features:
# - Mission lifecycle with strict status transitions
# - Financial constraints based on mission type
# - Soft delete support
# - Creator-based authorization (MVP: only creator can modify)
# - Comprehensive validations for business rules
#
# Associations:
# - has_many :mission_companies (relation table)
# - has_many :companies, through: :mission_companies
# - has_one :independent_company, -> { where(mission_companies: { role: 'independent' }) },
#           through: :mission_companies, source: :company
# - has_one :client_company, -> { where(mission_companies: { role: 'client' }) },
#          through: :mission_companies, source: :company
#
# Validations:
# - name: required, 2-255 characters
# - mission_type: required enum (time_based | fixed_price)
# - status: required enum with lifecycle constraints
# - dates: start_date required, end_date optional but must be >= start_date
# - financial: daily_rate required if time_based, fixed_price required if fixed_price
# - currency: ISO 4217 format, defaults to EUR
#
# Scopes:
# - .active: returns non-deleted missions
# - .by_status: filter by mission status
# - .by_type: filter by mission type
# - .time_based: missions with time_based type
# - .fixed_price: missions with fixed_price type
# - .current: missions that are currently active (not completed)
# - .accessible_to: missions accessible to a user (via their companies)
class Mission < ApplicationRecord
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
  VALID_MISSION_TYPES = %w[time_based fixed_price].freeze
  VALID_STATUSES = %w[lead pending won in_progress completed].freeze

  # Enums matching PostgreSQL enum types
  enum :mission_type, { time_based: 'time_based', fixed_price: 'fixed_price' }, validate: false
  enum :status, { lead: 'lead', pending: 'pending', won: 'won', in_progress: 'in_progress', completed: 'completed' },
       validate: false

  # Custom validation for enum values (must run before PostgreSQL constraint)
  validate :validate_enum_values

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :mission_type, presence: true, inclusion: { in: %w[time_based fixed_price] }
  validates :status, presence: true, inclusion: { in: %w[lead pending won in_progress completed] }
  validates :start_date, presence: true
  validates :end_date, comparison: { greater_than_or_equal_to: :start_date }, allow_blank: true
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }

  # Financial validations based on mission type
  validate :validate_financial_fields

  # Creator validation (for authorization rules)
  validates :created_by_user_id, presence: true

  # Callbacks
  before_validation :set_default_currency
  before_validation :set_default_status

  # Associations via relation tables (Domain-Driven Architecture)
  has_many :mission_companies, dependent: :destroy
  has_many :companies, through: :mission_companies

  # CRA-related associations
  has_many :cra_missions
  has_many :cras, through: :cra_missions
  has_many :cra_entry_missions, dependent: :destroy
  has_many :cra_entries, through: :cra_entry_missions

  # Role-based associations
  has_one :independent_company, -> { where(mission_companies: { role: 'independent' }) },
          through: :mission_companies, source: :company

  has_one :client_company, -> { where(mission_companies: { role: 'client' }) },
          through: :mission_companies, source: :company

  # User association (for authorization) - FIXED: follows Rails naming conventions
  belongs_to :user, foreign_key: 'created_by_user_id'

  # Scopes
  scope :active, -> { where(deleted_at: nil) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_type, ->(type) { where(mission_type: type) }
  scope :time_based, -> { where(mission_type: 'time_based') }
  scope :fixed_price, -> { where(mission_type: 'fixed_price') }
  scope :current, -> { where.not(status: 'completed') }

  # Scope for user accessibility (FC 06 access rules)
  scope :accessible_to, lambda { |user|
    joins(:mission_companies)
      .joins('INNER JOIN user_companies ON user_companies.company_id = mission_companies.company_id')
      .where(user_companies: { user_id: user.id, role: %w[independent client] })
      .distinct
  }

  # Instance methods
  def active?
    deleted_at.nil?
  end

  def completed?
    status == 'completed'
  end

  def current?
    !completed?
  end

  def time_based?
    mission_type == 'time_based'
  end

  def fixed_price?
    mission_type == 'fixed_price'
  end

  def client?
    client_company.present?
  end

  def display_name
    "#{name} (#{status.humanize})"
  end

  def duration_in_days
    return nil unless end_date.present?

    (end_date - start_date).to_i + 1
  end

  def total_amount
    if time_based?
      daily_rate&.to_d
    elsif fixed_price?
      fixed_price&.to_d
    end
  end

  def currency_symbol
    case currency
    when 'EUR' then '€'
    when 'USD' then '$'
    when 'GBP' then '£'
    else currency
    end
  end

  # Business rule: Check if mission can be modified by user
  # MVP: Only creator can modify
  def modifiable_by?(user)
    return false unless user.present?

    created_by_user_id == user.id
  end

  # Business rule: Check if status transition is valid
  def can_transition_to?(new_status)
    valid_transitions = {
      'lead' => %w[pending],
      'pending' => %w[won],
      'won' => %w[in_progress],
      'in_progress' => %w[completed]
    }

    valid_transitions[status]&.include?(new_status) || false
  end

  # Business rule: Transition mission status
  def transition_to!(new_status)
    unless can_transition_to?(new_status)
      errors.add(:status, 'invalid_transition', message: "Cannot transition from #{status} to #{new_status}")
      return false
    end

    update!(status: new_status)
  end

  # Business rule: Check if post-won notifications should be sent
  def should_send_post_won_notification?
    status_was == 'won' && client? && client_company.present?
  end

  # Soft delete with business logic
  def discard
    # Check if mission is linked to CRA entries (business rule)
    if cra_entries?
      errors.add(:base, 'mission_in_use', message: 'Mission cannot be deleted as it has CRA entries')
      return false
    end

    update(deleted_at: Time.current) if deleted_at.nil?
  end

  # Check if mission has CRA entries
  # Business rule: Mission cannot be deleted if it has CRA entries
  def cra_entries?
    cra_entry_missions.exists?
  end

  private

  def validate_financial_fields
    case mission_type
    when 'time_based'
      errors.add(:daily_rate, 'required', message: 'is required for time-based missions') if daily_rate.nil?
      errors.add(:fixed_price, 'forbidden', message: 'cannot be set for time-based missions') if fixed_price.present?
    when 'fixed_price'
      errors.add(:fixed_price, 'required', message: 'is required for fixed-price missions') if fixed_price.nil?
      errors.add(:daily_rate, 'forbidden', message: 'cannot be set for fixed-price missions') if daily_rate.present?
    end
  end

  def set_default_currency
    self.currency = 'EUR' if currency.nil?
  end

  def set_default_status
    self.status = 'lead' if status.nil?
  end

  def validate_enum_values
    # Validate mission_type before it reaches PostgreSQL
    if mission_type.present? && !VALID_MISSION_TYPES.include?(mission_type.to_s)
      errors.add(:mission_type, :invalid, message: "must be one of: #{VALID_MISSION_TYPES.join(', ')}")
    end

    # Validate status before it reaches PostgreSQL
    if status.present? && !VALID_STATUSES.include?(status.to_s)
      errors.add(:status, :invalid, message: "must be one of: #{VALID_STATUSES.join(', ')}")
    end
  end
end
