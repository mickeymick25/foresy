class CreateCraEntries < ActiveRecord::Migration[8.1]
  def change
    # Create the cra_entries table with all required fields
    create_table :cra_entries, id: :uuid do |t|
      # Core business fields
      t.date :date, null: false, comment: 'Date of the CRA entry'
      t.decimal :quantity, precision: 10, scale: 2, null: false, comment: 'Billable quantity (in days, free granularity: 0.25, 0.5, 1.0, 2.0)'
      t.integer :unit_price, null: false, comment: 'Unit price in cents'
      t.text :description, comment: 'Optional description'

      # Soft delete field
      t.datetime :deleted_at, comment: 'Soft delete timestamp'

      # Rails timestamps
      t.timestamps
    end

    # Add indexes for performance and business rules
    add_index :cra_entries, :date, comment: 'Filter entries by date'
    add_index :cra_entries, :quantity, comment: 'Calculate totals and analytics'
    add_index :cra_entries, :unit_price, comment: 'Price filtering and calculations'
    add_index :cra_entries, :deleted_at, comment: 'Soft delete queries'

    # Composite index for common queries (entries by date range)
    add_index :cra_entries, [:date, :deleted_at], name: 'index_cra_entries_date_active'
  end
end
