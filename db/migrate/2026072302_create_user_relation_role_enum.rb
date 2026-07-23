# frozen_string_literal: true

# P5.2 — Migrer user_missions.role et user_cras.role de string vers enum PostgreSQL
class CreateUserRelationRoleEnum < ActiveRecord::Migration[8.1]
  def up
    create_enum :user_relation_role, %w[creator contributor reviewer]

    # Drop partial indexes that use (role)::text predicate (incompatible with enum cast)
    remove_index :user_cras, name: 'idx_user_cras_cra_creator'
    remove_index :user_missions, name: 'idx_user_missions_mission_creator'

    # Remove default first (string default can't cast to enum)
    change_column_default :user_missions, :role, nil
    change_column_default :user_cras, :role, nil

    # Change column type with USING cast
    change_column :user_missions, :role, :enum, enum_type: :user_relation_role, null: false, using: 'role::user_relation_role'
    change_column :user_cras, :role, :enum, enum_type: :user_relation_role, null: false, using: 'role::user_relation_role'

    # Set default back as enum value
    change_column_default :user_missions, :role, 'creator'
    change_column_default :user_cras, :role, 'creator'

    # Remove check constraints (now handled by enum type)
    remove_check_constraint :user_missions, name: 'user_missions_role_check'
    remove_check_constraint :user_cras, name: 'user_cras_role_check'

    # Recreate partial indexes with simplified predicate (no ::text cast needed for enum)
    add_index :user_cras, %w[cra_id role], name: 'idx_user_cras_cra_creator', unique: true, where: "role = 'creator'"
    add_index :user_missions, %w[mission_id role], name: 'idx_user_missions_mission_creator', unique: true, where: "role = 'creator'"
  end

  def down
    # Drop enum-style indexes
    remove_index :user_cras, name: 'idx_user_cras_cra_creator'
    remove_index :user_missions, name: 'idx_user_missions_mission_creator'

    # Add back check constraints
    add_check_constraint :user_missions, "role::text = ANY (ARRAY['creator'::character varying::text, 'contributor'::character varying::text, 'reviewer'::character varying::text])", name: 'user_missions_role_check'
    add_check_constraint :user_cras, "role::text = ANY (ARRAY['creator'::character varying::text, 'contributor'::character varying::text, 'reviewer'::character varying::text])", name: 'user_cras_role_check'

    # Revert column to string
    change_column_default :user_missions, :role, nil
    change_column_default :user_cras, :role, nil
    change_column :user_missions, :role, :string, default: 'creator', null: false
    change_column :user_cras, :role, :string, default: 'creator', null: false

    # Recreate string-style indexes
    add_index :user_cras, %w[cra_id role], name: 'idx_user_cras_cra_creator', unique: true, where: "((role)::text = 'creator'::text)"
    add_index :user_missions, %w[mission_id role], name: 'idx_user_missions_mission_creator', unique: true, where: "((role)::text = 'creator'::text)"

    drop_enum :user_relation_role
  end
end