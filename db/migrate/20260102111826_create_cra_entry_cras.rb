class CreateCraEntryCras < ActiveRecord::Migration[8.1]
  def change
    # Create the cra_entry_cras relation table
    create_table :cra_entry_cras, id: :uuid do |t|
      # Foreign key references (explicit relations for Domain-Driven Architecture)
      t.uuid :cra_id, null: false, comment: 'Reference to CRA'
      t.uuid :cra_entry_id, null: false, comment: 'Reference to CRAEntry'

      # Rails timestamp
      t.timestamps
    end

    # Add foreign key constraints
    add_foreign_key :cra_entry_cras, :cras, column: :cra_id, on_delete: :cascade
    add_foreign_key :cra_entry_cras, :cra_entries, column: :cra_entry_id, on_delete: :cascade

    # Add indexes for performance and business rules
    add_index :cra_entry_cras, :cra_id, comment: 'Find CRA entries for a CRA'
    add_index :cra_entry_cras, :cra_entry_id, comment: 'Find CRA for an entry'

    # Business rule: Ensure one CRA per entry (1:N relationship via relation table)
    add_index :cra_entry_cras, [:cra_id, :cra_entry_id],
              unique: true,
              name: 'index_cra_entry_cras_unique_cra_entry',
              comment: 'Enforce: One CRA per entry relationship'

    # Performance index for queries by both CRA and entry
    add_index :cra_entry_cras, [:cra_entry_id, :cra_id],
              name: 'index_cra_entry_cras_entry_cra'
  end
end
