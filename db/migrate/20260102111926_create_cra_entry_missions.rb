class CreateCraEntryMissions < ActiveRecord::Migration[8.1]
  def change
    # Create the cra_entry_missions relation table
    create_table :cra_entry_missions, id: :uuid do |t|
      # Foreign key references (explicit relations for Domain-Driven Architecture)
      t.uuid :cra_entry_id, null: false, comment: 'Reference to CRAEntry'
      t.uuid :mission_id, null: false, comment: 'Reference to Mission'

      # Rails timestamp
      t.timestamps
    end

    # Add foreign key constraints
    add_foreign_key :cra_entry_missions, :cra_entries, column: :cra_entry_id, on_delete: :cascade
    add_foreign_key :cra_entry_missions, :missions, column: :mission_id, on_delete: :cascade

    # Add indexes for performance and business rules
    add_index :cra_entry_missions, :cra_entry_id, comment: 'Find missions for a CRA entry'
    add_index :cra_entry_missions, :mission_id, comment: 'Find CRA entries for a mission'

    # Performance index for queries by both CRA entry and mission
    add_index :cra_entry_missions, [:mission_id, :cra_entry_id],
              name: 'index_cra_entry_missions_mission_entry'
  end
end
