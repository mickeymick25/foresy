# frozen_string_literal: true

# Feature Flags Configuration
#
# This file centralizes feature flags used to control rollout of new features.
# Flags are managed via environment variables for safe deployment.
#
# Usage:
#   if USE_USER_RELATIONS
#     # Use new relation-driven code path
#   else
#     # Use legacy code path
#   end
#
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md

# DDD Relation-Driven Architecture
# Controls whether the application reads from user_missions/user_cras pivot tables
# instead of direct created_by_user_id columns.
#
# Values:
#   'true'  → Use pivot tables (new relation-driven architecture)
#   'false' → Use legacy columns (backward compatibility)
#
# Deployment strategy:
#   1. Deploy with USE_USER_RELATIONS = 'false' (default)
#   2. Run backfill and verify integrity
#   3. Gradually increase USE_USER_RELATIONS = 'true' via rollout strategy
#   4. Once 100% reached, hard-code to 'true' and remove flag
#
USE_USER_RELATIONS = ActiveModel::Type::Boolean.new.cast(ENV.fetch('USE_USER_RELATIONS', 'false'))

# Feature flag for multi-role support (future evolution)
# When enabled, users can have multiple roles (creator, contributor, reviewer)
# on the same mission or CRA.
#
# Currently not implemented - reserved for future use.
#
USE_MULTI_ROLES = ActiveModel::Type::Boolean.new.cast(ENV.fetch('USE_MULTI_ROLES', 'false'))

# Feature flag for new notification system (FC-09)
# When enabled, uses the new notification architecture.
#
NOTIFICATION_SYSTEM_V2 = ActiveModel::Type::Boolean.new.cast(ENV.fetch('NOTIFICATION_SYSTEM_V2', 'false'))

# Convenience methods for checking feature flags
module FeatureFlags
  # @return [true, false] whether relation-driven architecture is enabled
  def self.relation_driven?
    USE_USER_RELATIONS
  end

  # @return [true, false] whether multi-role support is enabled
  def self.multi_role?
    USE_MULTI_ROLES
  end

  # @return [true, false] whether new notification system is enabled
  def self.notifications_v2?
    NOTIFICATION_SYSTEM_V2
  end
end
