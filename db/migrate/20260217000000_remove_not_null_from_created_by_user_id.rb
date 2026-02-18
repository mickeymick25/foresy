# frozen_string_literal: true

# Migration: Remove NOT NULL constraints from created_by_user_id columns
# Part of DDD Relation-Driven Correction - Release 3
#
# This migration makes created_by_user_id columns nullable, allowing the models
# to work without requiring these legacy columns.
#
# The business logic now uses user_missions and user_cras pivot tables
# instead of direct foreign keys to users.
#
# Future migration will drop these columns entirely.

class RemoveNotNullFromCreatedByUserId < ActiveRecord::Migration[8.1]
  def up
    # Make created_by_user_id nullable in missions table
    change_column_null :missions, :created_by_user_id, true

    # Make created_by_user_id nullable in cras table
    change_column_null :cras, :created_by_user_id, true
  end

  def down
    # Revert to NOT NULL (if needed for rollback)
    change_column_null :missions, :created_by_user_id, false
    change_column_null :cras, :created_by_user_id, false
  end
end
