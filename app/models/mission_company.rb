# frozen_string_literal: true

# MissionCompany
#
# Relation model between Mission and Company with roles.
# Implements Domain-Driven / Relation-Driven Architecture:
# - Pure relation table (no business logic)
# - Explicit, auditable relationships
# - Role-based access control for missions
#
# Business Rules:
# - A Mission MUST have exactly 1 Company with role 'independent'
# - A Mission MAY have at most 1 Company with role 'client'
# - Role is mandatory (independent | client)
#
# Architecture:
# - Mission ↔ Company relations via this table
# - No business foreign keys in Mission model
# - All relationships are explicit and trackable
#
# Validations:
# - mission_id and company_id are required
# - role must be either 'independent' or 'client'
# - Unique constraint on mission_id + role (ensures only 1 independent per mission)
# - Unique constraint on mission_id + company_id (prevents duplicate relations)
#
# Scopes:
# - .by_role: filter by role (independent/client)
# - .independent: missions where company has independent role
# - .client: missions where company has client role
class MissionCompany < ApplicationRecord
  # Associations
  belongs_to :mission, class_name: 'Mission', foreign_key: 'mission_id', inverse_of: :mission_companies
  belongs_to :company, class_name: 'Company', foreign_key: 'company_id', inverse_of: :mission_companies

  # Enums matching PostgreSQL enum type
  enum :role, { independent: 'independent', client: 'client' }, validate: false

  # Validations
  validates :mission_id, presence: true
  validates :company_id, presence: true
  validates :role, presence: true, inclusion: { in: %w[independent client] }

  # Ensure unique relationships
  validates :mission_id, uniqueness: { scope: %i[company_id role] }
  validates :mission_id, uniqueness: { scope: :role, message: 'can only have one company with each role' }

  # Custom validations for business rules
  validate :ensure_business_rule_compliance

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :independent, -> { where(role: 'independent') }
  scope :client, -> { where(role: 'client') }

  # Instance methods
  def independent?
    role == 'independent'
  end

  def client?
    role == 'client'
  end

  def display_role
    role.humanize
  end

  private

  def ensure_business_rule_compliance
    # Business Rule: A Mission can have at most 1 independent company
    if mission_id.present? && role == 'independent'
      existing_independent = MissionCompany.where(mission_id: mission_id, role: 'independent').where.not(id: id).exists?
      if existing_independent
        errors.add(:role, 'mission_already_has_independent',
                   message: 'A mission can only have one independent company')
      end
    end

    # Business Rule: A Mission can have at most 1 client company
    if mission_id.present? && role == 'client'
      existing_client = MissionCompany.where(mission_id: mission_id, role: 'client').where.not(id: id).exists?
      if existing_client
        errors.add(:role, 'mission_already_has_client',
                   message: 'A mission can only have one client company')
      end
    end
  end
end
