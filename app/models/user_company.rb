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
# Validations:
# - user_id and company_id are required
# - role must be either 'independent' or 'client'
# - Unique constraint on user_id + company_id (prevents duplicate relations)
# - Users can have multiple companies with different roles
#
# Scopes:
# - .by_role: filter by role (independent/client)
# - .independent: users in companies with independent role
# - .client: users in companies with client role
# - .for_user: all relations for a specific user
# - .for_company: all relations for a specific company
class UserCompany < ApplicationRecord
  # Associations
  belongs_to :user, class_name: 'User', foreign_key: 'user_id', inverse_of: :user_companies
  belongs_to :company, class_name: 'Company', foreign_key: 'company_id', inverse_of: :user_companies

  # Enums matching PostgreSQL enum type
  enum :role, { independent: 'independent', client: 'client' }, validate: false

  # Validations
  validates :user_id, presence: true
  validates :company_id, presence: true
  validates :role, presence: true, inclusion: { in: %w[independent client] }

  # Ensure unique user-company relationship (no duplicates)
  validates :user_id, uniqueness: { scope: :company_id, message: 'can only be associated once with a company' }

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
