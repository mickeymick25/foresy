# frozen_string_literal: true

# UserMission
#
# Relation table between User and Mission aggregates.
# Follows Domain-Driven / Relation-Driven Architecture principles:
# - EXPLICIT relationship, no FK in aggregate tables
# - ON DELETE CASCADE for mission/user lifecycle
# - Trigger protection for creator immutability
# - No global unique index → allows future multi-role support
#
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md
#
class UserMission < ApplicationRecord
  # ⚠️ PLATINUM: No global unique index on (user_id, mission_id)
  # This allows one user to have multiple roles on the same mission
  # (creator, contributor, reviewer) in future evolution

  ROLES = %w[creator contributor reviewer].freeze
  DEFAULT_ROLE = 'creator'

  # Associations
  belongs_to :user, optional: false
  belongs_to :mission, optional: false

  # Validations
  validates :user_id, presence: true
  validates :mission_id, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }

  # Check constraint is enforced at DB level via migration
  # This is a safety net for Rails-level validation

  # Scopes
  scope :creators, -> { where(role: 'creator') }
  scope :contributors, -> { where(role: 'contributor') }
  scope :reviewers, -> { where(role: 'reviewer') }
  scope :for_mission, ->(mission_id) { where(mission_id: mission_id) }
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
    # Find the creator for a specific mission
    # @param mission_id [UUID] the mission ID
    # @return [UserMission, nil] the creator record or nil
    def mission_creator(mission_id)
      creators.for_mission(mission_id).first
    end

    # Find all missions created by a specific user
    # @param user_id [Integer] the user ID
    # @return [ActiveRecord::Relation<UserMission>] user's created missions
    def user_created_missions(user_id)
      creators.for_user(user_id)
    end
  end
end
