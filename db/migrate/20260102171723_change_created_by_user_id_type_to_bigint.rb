class ChangeCreatedByUserIdTypeToBigint < ActiveRecord::Migration[8.1]
  def up
    # Remove the old indexes first
    remove_index :cras, name: 'index_cras_unique_user_month_year', if_exists: true
    remove_index :cras, :created_by_user_id, if_exists: true

    # Drop the uuid column and recreate as bigint
    remove_column :cras, :created_by_user_id

    add_column :cras, :created_by_user_id, :bigint, null: false, comment: 'Audit-only: user who created the CRA'

    # Recreate indexes
    add_index :cras, [:created_by_user_id, :month, :year],
              unique: true,
              name: 'index_cras_unique_user_month_year',
              where: 'deleted_at IS NULL',
              comment: 'Enforce uniqueness: 1 CRA max per (user, month, year)'

    add_index :cras, :created_by_user_id, comment: 'Find CRAs by creator'
  end

  def down
    # Remove indexes first
    remove_index :cras, name: 'index_cras_unique_user_month_year', if_exists: true
    remove_index :cras, :created_by_user_id, if_exists: true

    # Drop the bigint column and recreate as uuid
    remove_column :cras, :created_by_user_id

    add_column :cras, :created_by_user_id, :uuid, null: false, comment: 'Audit-only: user who created the CRA'

    # Recreate indexes
    add_index :cras, [:created_by_user_id, :month, :year],
              unique: true,
              name: 'index_cras_unique_user_month_year',
              where: 'deleted_at IS NULL',
              comment: 'Enforce uniqueness: 1 CRA max per (user, month, year)'

    add_index :cras, :created_by_user_id, comment: 'Find CRAs by creator'
  end
end
