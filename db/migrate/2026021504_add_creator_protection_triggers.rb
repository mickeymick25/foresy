# frozen_string_literal: true

# Migration: Phase D - Add Creator Protection Triggers
# Part of DDD Relation-Driven Correction (PLATINUM)
#
# Purpose:
# - Prevent manual deletion of the last creator
# - Prevent role downgrade from creator to other roles
# - Allow CASCADE deletion via HARD mission/user delete
# - Use session variable to distinguish manual DELETE from CASCADE
#
# Technical Note:
# PostgreSQL triggers cannot distinguish between manual DELETE and CASCADE DELETE.
# We use a session variable 'foresy_cascade_delete' to signal CASCADE operations.
# When set to 'true', the trigger allows the deletion (it's a cascade).
#
# Usage for CASCADE operations:
#   SET LOCAL foresy_cascade_delete = 'true';
#   DELETE FROM users WHERE id = X;
#
# Order of execution:
# 1. 2026021501_create_user_missions_table.rb
# 2. 2026021502_create_user_cras_table.rb
# 3. 2026021503_add_creator_constraints.rb
# 4. This migration (Phase D - triggers)
#
# @see docs/technical/corrections/2026-02-15-DDD_Relation-Driven_Correction.md

class AddCreatorProtectionTriggers < ActiveRecord::Migration[8.1]
  def up
    # ============================================================
    # user_missions triggers
    # ============================================================

    # Trigger Function: Protect mission creator from deletion
    # - If session variable foresy_cascade_delete = 'true' → ALLOW (CASCADE)
    # - If mission still exists → BLOCK (manual delete)
    # - If mission doesn't exist → ALLOW (CASCADE from hard delete)
    execute <<-SQL
      CREATE OR REPLACE FUNCTION protect_mission_creator_delete()
      RETURNS TRIGGER AS $$
      BEGIN
        -- Check if this is a CASCADE operation (set by parent deletion)
        IF current_setting('app.foresy_cascade_delete', true) = 'true' THEN
          RETURN OLD; -- Allow CASCADE deletion
        END IF;

        -- Check if mission still exists (physical existence)
        -- If mission exists → manual delete → BLOCK
        -- If mission doesn't exist → CASCADE from hard delete → ALLOW
        IF EXISTS (SELECT 1 FROM missions WHERE id = OLD.mission_id) THEN
          RAISE EXCEPTION 'Cannot manually delete the creator of a mission';
        END IF;

        RETURN OLD; -- Allow CASCADE from hard mission delete
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      CREATE TRIGGER trigger_protect_mission_creator_delete
      BEFORE DELETE ON user_missions
      FOR EACH ROW
      EXECUTE FUNCTION protect_mission_creator_delete();
    SQL

    # Trigger Function: Prevent role downgrade from creator
    execute <<-SQL
      CREATE OR REPLACE FUNCTION protect_mission_creator_role()
      RETURNS TRIGGER AS $$
      BEGIN
        IF OLD.role = 'creator' AND NEW.role != 'creator' THEN
          RAISE EXCEPTION 'Cannot change role of mission creator';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      CREATE TRIGGER trigger_protect_mission_creator_role
      BEFORE UPDATE OF role ON user_missions
      FOR EACH ROW
      EXECUTE FUNCTION protect_mission_creator_role();
    SQL

    # ============================================================
    # user_cras triggers
    # ============================================================

    # Trigger Function: Protect CRA creator from deletion
    execute <<-SQL
      CREATE OR REPLACE FUNCTION protect_cra_creator_delete()
      RETURNS TRIGGER AS $$
      BEGIN
        -- Check if this is a CASCADE operation (set by parent deletion)
        IF current_setting('app.foresy_cascade_delete', true) = 'true' THEN
          RETURN OLD; -- Allow CASCADE deletion
        END IF;

        -- Check if CRA still exists (physical existence)
        IF EXISTS (SELECT 1 FROM cras WHERE id = OLD.cra_id) THEN
          RAISE EXCEPTION 'Cannot manually delete the creator of a CRA';
        END IF;

        RETURN OLD; -- Allow CASCADE from hard CRA delete
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      CREATE TRIGGER trigger_protect_cra_creator_delete
      BEFORE DELETE ON user_cras
      FOR EACH ROW
      EXECUTE FUNCTION protect_cra_creator_delete();
    SQL

    # Trigger Function: Prevent role downgrade from creator
    execute <<-SQL
      CREATE OR REPLACE FUNCTION protect_cra_creator_role()
      RETURNS TRIGGER AS $$
      BEGIN
        IF OLD.role = 'creator' AND NEW.role != 'creator' THEN
          RAISE EXCEPTION 'Cannot change role of CRA creator';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      CREATE TRIGGER trigger_protect_cra_creator_role
      BEFORE UPDATE OF role ON user_cras
      FOR EACH ROW
      EXECUTE FUNCTION protect_cra_creator_role();
    SQL

    # ============================================================
    # Helper function to safely set cascade mode
    # ============================================================
    execute <<-SQL
      CREATE OR REPLACE FUNCTION foresy_set_cascade_mode(enabled boolean)
      RETURNS void AS $$
      BEGIN
        IF enabled THEN
          PERFORM set_config('app.foresy_cascade_delete', 'true', false);
        ELSE
          PERFORM set_config('app.foresy_cascade_delete', 'false', false);
        END IF;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    # Drop helper function first
    execute "DROP FUNCTION IF EXISTS foresy_set_cascade_mode(boolean)"

    # Drop triggers in reverse order
    execute "DROP TRIGGER IF EXISTS trigger_protect_cra_creator_role ON user_cras"
    execute "DROP TRIGGER IF EXISTS trigger_protect_cra_creator_delete ON user_cras"
    execute "DROP TRIGGER IF EXISTS trigger_protect_mission_creator_role ON user_missions"
    execute "DROP TRIGGER IF EXISTS trigger_protect_mission_creator_delete ON user_missions"

    # Drop functions
    execute "DROP FUNCTION IF EXISTS protect_cra_creator_role()"
    execute "DROP FUNCTION IF EXISTS protect_cra_creator_delete()"
    execute "DROP FUNCTION IF EXISTS protect_mission_creator_role()"
    execute "DROP FUNCTION IF EXISTS protect_mission_creator_delete()"
  end
end
