# frozen_string_literal: true

# Migration: Phase C - Add Creator Constraints and Foreign Keys
# Part of DDD Relation-Driven Correction (PLATINUM)
#
# Purpose:
# - Add FK constraints with CASCADE for automatic cleanup
# - Add partial unique index for creator role (exactly 1 creator per mission/cra)
# - Enforce referential integrity at database level
#
# Order of execution:
# 1. 2026021501_create_user_missions_table.rb
# 2. 2026021502_create_user_cras_table.rb
# 3. This migration (Phase C - constraints)
# 4. 2026021504_add_creator_protection_triggers.rb (Phase D - triggers)
#
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md

class AddCreatorConstraints < ActiveRecord::Migration[8.1]
  def up
    # ============================================
    # user_missions table - FK + Partial Unique
    # ============================================

    # Add FK to users with CASCADE (user deletion → automatic pivot deletion)
    execute <<-SQL.squish
      ALTER TABLE user_missions
      ADD CONSTRAINT fk_user_missions_user
      FOREIGN KEY (user_id)
      REFERENCES users(id)
      ON DELETE CASCADE
    SQL

    # Add FK to missions with CASCADE
    # Note: This allows hard-delete of mission to cascade to user_missions
    # Trigger will block manual deletion of creator while mission exists
    execute <<-SQL.squish
      ALTER TABLE user_missions
      ADD CONSTRAINT fk_user_missions_mission
      FOREIGN KEY (mission_id)
      REFERENCES missions(id)
      ON DELETE CASCADE
    SQL

    # Add partial unique index for creator role
    # Ensures exactly 1 creator per mission (cannot have 2 creators)
    # Uses WHERE to allow future multi-role support (different roles allowed)
    add_index "user_missions",
              ["mission_id", "role"],
              name: "idx_user_missions_mission_creator",
              unique: true,
              where: "role = 'creator'"

    # ============================================
    # user_cras table - FK + Partial Unique
    # ============================================

    # Add FK to users with CASCADE
    execute <<-SQL.squish
      ALTER TABLE user_cras
      ADD CONSTRAINT fk_user_cras_user
      FOREIGN KEY (user_id)
      REFERENCES users(id)
      ON DELETE CASCADE
    SQL

    # Add FK to cras with CASCADE
    execute <<-SQL.squish
      ALTER TABLE user_cras
      ADD CONSTRAINT fk_user_cras_cra
      FOREIGN KEY (cra_id)
      REFERENCES cras(id)
      ON DELETE CASCADE
    SQL

    # Add partial unique index for creator role
    add_index "user_cras",
              ["cra_id", "role"],
              name: "idx_user_cras_cra_creator",
              unique: true,
              where: "role = 'creator'"
  end

  def down
    # Remove indexes first (required before dropping FK constraints)
    remove_index "user_cras", name: "idx_user_cras_cra_creator"
    remove_index "user_missions", name: "idx_user_missions_mission_creator"

    # Remove FK constraints
    execute "ALTER TABLE user_cras DROP CONSTRAINT IF EXISTS fk_user_cras_cra"
    execute "ALTER TABLE user_cras DROP CONSTRAINT IF EXISTS fk_user_cras_user"
    execute "ALTER TABLE user_missions DROP CONSTRAINT IF EXISTS fk_user_missions_mission"
    execute "ALTER TABLE user_missions DROP CONSTRAINT IF EXISTS fk_user_missions_user"
  end
end
