# frozen_string_literal: true

# frozen_string_literal: true

# Migration for DDD Relation-Driven Correction
# Phase A: Create user_cras pivot table
#
# This migration creates the join table between User and CRA
# to eliminate the direct FK from CRA to User.
#
# Structure:
# - User ↔ user_cras ↔ CRA
# - Each CRA has exactly 1 creator (role = 'creator')
# - Supports future multi-role evolution (creator, contributor, reviewer)
#
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md

class CreateUserCrasTable < ActiveRecord::Migration[8.1]
  # Table naming follows Rails conventions for join tables (alphabetical order)
  TABLE_NAME = :user_cras

  def up
    # Create user_cras table WITHOUT FK initially (to avoid circular references during migration)
    create_table TABLE_NAME, id: :uuid do |t|
      # References to domain aggregates (no FK yet - added in Phase C)
      t.bigint :user_id, null: false
      t.uuid :cra_id, null: false

      # Role with default (supports future multi-role evolution)
      t.string :role, null: false, default: 'creator'

      # Timestamps
      t.datetime :created_at, null: false
    end

    # Standard indexes for query performance
    add_index TABLE_NAME, :cra_id
    add_index TABLE_NAME, :user_id
    add_index TABLE_NAME, [:user_id, :cra_id]

    # PLATINUM: Add CHECK constraint for valid roles only
    # This is a database-level invariant - prevents invalid roles
    # @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md#invariants
    execute <<~SQL.squish
      ALTER TABLE #{TABLE_NAME}
      ADD CONSTRAINT #{TABLE_NAME}_role_check
      CHECK (role IN ('creator', 'contributor', 'reviewer'))
    SQL
  end

  def down
    # Remove constraint first (required for dropping table)
    execute "ALTER TABLE #{TABLE_NAME} DROP CONSTRAINT IF EXISTS #{TABLE_NAME}_role_check"

    # Drop table (reversible operation)
    drop_table TABLE_NAME
  end
end
