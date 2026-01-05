class CreateCraMissions < ActiveRecord::Migration[8.1]
  def change
    # Create the cra_missions relation table
    create_table :cra_missions, id: :uuid do |t|
      # Foreign key references (explicit relations for Domain-Driven Architecture)
      t.uuid :cra_id, null: false, comment: 'Reference to CRA'
      t.uuid :mission_id, null: false, comment: 'Reference to Mission'

      # Rails timestamp
      t.timestamps
    end

    # Add foreign key constraints
    add_foreign_key :cra_missions, :cras, column: :cra_id, on_delete: :cascade
    add_foreign_key :cra_missions, :missions, column: :mission_id, on_delete: :cascade

    # Add indexes for performance and business rules
    add_index :cra_missions, :cra_id, comment: 'Find missions for a CRA'
    add_index :cra_missions, :mission_id, comment: 'Find CRAs for a mission'

    # Business rule: A mission can only appear once in a CRA
    add_index :cra_missions, [:cra_id, :mission_id],
              unique: true,
              name: 'index_cra_missions_unique_cra_mission',
              comment: 'Enforce: One mission per CRA maximum'

    # Performance index for queries by both CRA and mission
    add_index :cra_missions, [:mission_id, :cra_id],
              name: 'index_cra_missions_mission_cra'
  end
end
