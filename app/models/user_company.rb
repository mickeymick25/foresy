# frozen_string_literal: true

# UserCompany
#
# Relation model between User and Company with roles.
# Implements Domain-Driven / Relation-Driven Architecture:
# - Pure relation table (no business logic)
# - Explicit, auditable relationships
# - Role-based user-company associations
#
# Business Context:
# A User can belong to one or more Companies
# Each User-Company relationship carries a role:
# - independent: User represents an independent company
# - client: User represents a client company
#
# Architecture:
# - User ↔ Company relations via this table
# - No business foreign keys in User or Company models
# - All relationships are explicit and trackable
#
# Validations (FC-08 v3.2.3 — contract §25, §26, §45):
# - user_id and company_id are required
# - role must be either 'independent' or 'client' (§25)
# - Unique constraint on (user_id, company_id, role) (INV-18) — a User can hold
#   independent AND client roles for the same Company (§10)
# - Users can have multiple companies with different roles (§11)
#
# Soft deletion (§27, INV-21):
# - deleted_at marks the relationship as ended; records are retained for audit
# - A deleted relationship is NOT implicitly resurrected by creating an identical
#   active relationship — reactivation is an explicit operation (undiscard)
#
# Scopes:
# - .active / .deleted: explicit lifecycle scopes (INV-19, no default_scope INV-20)
# - .by_role / .independent / .client / .for_user / .for_company
class UserCompany < ApplicationRecord
  # Associations
  belongs_to :user, class_name: 'User', foreign_key: 'user_id', inverse_of: :user_companies
  belongs_to :company, class_name: 'Company', foreign_key: 'company_id', inverse_of: :user_companies

  # Enums matching PostgreSQL enum type
  enum :role, { independent: 'independent', client: 'client' }, validate: false

  # Validations (FC-08 v3.2.3)
  validates :user_id, presence: true
  validates :company_id, presence: true
  validates :role, presence: true, inclusion: { in: %w[independent client] }

  # INV-18 / §26: UNIQUE(user_id, company_id, role) — multiple roles coexist
  # for the same User and Company, but an identical (user, company, role) exists once
  validates :user_id, uniqueness: { scope: %i[user_id company_id role],
                                    message: 'already has this role for this company' }

  # Soft deletion (FC-08 contract §27, INV-21)
  def discard
    update(deleted_at: Time.current) if deleted_at.nil?
  end

  def undiscard
    update(deleted_at: nil) if deleted_at.present?
  end

  def discarded?
    deleted_at.present?
  end

  # Scopes (FC-08 contract §30 — explicit lifecycle, no default_scope, INV-19/20)
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :independent, -> { where(role: 'independent') }
  scope :client, -> { where(role: 'client') }
  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :for_company, ->(company) { where(company_id: company.id) }

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

  def user_display_name
    user.name || user.email
  end

  def company_display_name
    company.display_name
  end

  def relationship_summary
    "#{user_display_name} - #{company_display_name} (#{display_role})"
  end
end
