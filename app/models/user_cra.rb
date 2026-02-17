# frozen_string_literal: true

# UserCra
#
# Relation table between User and CRA aggregates.
# Follows Domain-Driven / Relation-Driven Architecture principles:
# - EXPLICIT relationship, no FK in aggregate tables
# - ON DELETE CASCADE for cra/user lifecycle
# - Trigger protection for creator immutability
# - No global unique index → allows future multi-role support
#
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md
#
class UserCra < ApplicationRecord
  self.table_name = 'user_cras'

  # Roles for multi-role support (future evolution)
  ROLES = %w[creator contributor reviewer].freeze
  DEFAULT_ROLE = 'creator'

  # Attributes
  attribute :user_id, :integer
  attribute :cra_id, :uuid
  attribute :role, :string
  attribute :created_at, :datetime

  # Validations
  validates :user_id, presence: true
  validates :cra_id, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }

  # ⚠️ PLATINUM: PAS de validates_uniqueness sur (user_id, cra_id)
  # Cela permet l'évolution future vers rôles multiples

  # Associations
  belongs_to :user, optional: false
  belongs_to :cra, optional: false

  # Scopes
  scope :creators, -> { where(role: 'creator') }
  scope :contributors, -> { where(role: 'contributor') }
  scope :reviewers, -> { where(role: 'reviewer') }
  scope :for_cra, ->(cra_id) { where(cra_id: cra_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :by_role, ->(role) { where(role: role) }

  # Business methods
  def creator?
    role == 'creator'
  end

  def contributor?
    role == 'contributor'
  end

  def reviewer?
    role == 'reviewer'
  end

  class << self
    # Find the creator for a specific CRA
    # @param cra_id [UUID] the CRA ID
    # @return [UserCra, nil] the creator record or nil
    def cra_creator(cra_id)
      creators.for_cra(cra_id).first
    end

    # Find all CRAs created by a specific user
    # @param user_id [Integer] the user ID
    # @return [ActiveRecord::Relation<UserCra>] user's created CRAs
    def user_created_cras(user_id)
      creators.for_user(user_id).joins(:cra)
    end
  end
end
