# frozen_string_literal: true

# P4.7 final — Supprimer la colonne legacy created_by_user_id
# Toutes les lectures utilisent creator_user_id (via tables pivot user_cras/user_missions)
# L'unicité (user, month, year) reste garantie au niveau application (Cra#validate_uniqueness)
class DropCreatedByUserId < ActiveRecord::Migration[8.1]
  def up
    remove_index :cras, name: 'index_cras_unique_user_month_year'
    remove_index :cras, name: 'index_cras_on_created_by_user_id'
    remove_index :missions, name: 'index_missions_on_created_by_user_id'

    remove_column :cras, :created_by_user_id
    remove_column :missions, :created_by_user_id

    add_index :user_cras, %w[user_id cra_id], name: 'idx_user_cras_unique_creator',
           unique: true, where: "role = 'creator'"
  end

  def down
    add_column :cras, :created_by_user_id, :bigint
    add_column :missions, :created_by_user_id, :bigint

    add_index :cras, %w[created_by_user_id month year], name: 'index_cras_unique_user_month_year',
           unique: true, where: 'deleted_at IS NULL'
    add_index :cras, :created_by_user_id, name: 'index_cras_on_created_by_user_id'
    add_index :missions, :created_by_user_id, name: 'index_missions_on_created_by_user_id'

    remove_index :user_cras, name: 'idx_user_cras_unique_creator'
  end
end