class CreateCras < ActiveRecord::Migration[8.1]
  def change
    # Create PostgreSQL enum types for CRA
    execute <<-SQL
      CREATE TYPE cra_status AS ENUM ('draft', 'submitted', 'locked');
    SQL

    # Create the cras table with all required fields
    create_table :cras, id: :uuid do |t|
      # Core business fields
      t.integer :month, null: false, comment: 'Month (1-12)'
      t.integer :year, null: false, comment: 'Year'
      t.column :status, :cra_status, null: false, default: 'draft', comment: 'CRA lifecycle status'
      t.text :description, comment: 'Non-financial metadata (description)'

      # Calculated fields (server-side only)
      t.decimal :total_days, precision: 10, scale: 2, comment: 'Calculated total days'
      t.integer :total_amount, comment: 'Calculated total amount (in cents)'

      # Currency and audit fields
      t.string :currency, null: false, default: 'EUR', comment: 'ISO 4217 currency code'
      t.uuid :created_by_user_id, null: false, comment: 'Audit-only: user who created the CRA'

      # Lifecycle and soft delete fields
      t.datetime :locked_at, comment: 'Timestamp when CRA was locked'
      t.datetime :deleted_at, comment: 'Soft delete timestamp'

      # Rails timestamps
      t.timestamps
    end

    # Add indexes for performance and business rules
    add_index :cras, [:created_by_user_id, :month, :year],
              unique: true,
              name: 'index_cras_unique_user_month_year',
              where: 'deleted_at IS NULL',
              comment: 'Enforce uniqueness: 1 CRA max per (user, month, year)'

    # Performance indexes
    add_index :cras, :status, comment: 'Filter by CRA status'
    add_index :cras, :month, comment: 'Filter by month'
    add_index :cras, :year, comment: 'Filter by year'
    add_index :cras, :locked_at, comment: 'Find locked CRAs'
    add_index :cras, :deleted_at, comment: 'Soft delete queries'

    # User access indexes
    add_index :cras, :created_by_user_id, comment: 'Find CRAs by creator'
  end
end
