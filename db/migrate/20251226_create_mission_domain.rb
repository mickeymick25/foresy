# frozen_string_literal: true

# Migration for Mission Management feature (FC 06)
# Implements Domain-Driven / Relation-Driven Architecture
#
# Creates:
# - PostgreSQL enums for types and statuses
# - companies table (legal entities that users can belong to)
# - user_companies table (User-Company relations with roles)
# - missions table (pure domain model, no FK to Company/User)
# - mission_companies table (Mission-Company relations with roles)
#
# Architecture Rules:
# - NO business foreign keys in domain models
# - ALL relationships via explicit relation tables
# - Domain models remain pure and auditable
#
# Foreign Key Compatibility:
# - References to existing users table use bigint (existing users use bigint PK)
# - New tables (companies, missions) use UUID as primary keys
# - Relation tables use appropriate types for their references

class CreateMissionDomain < ActiveRecord::Migration[8.1]
  def change
    # Enable UUID extension for PostgreSQL
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # ============================================
    # Create PostgreSQL Enums
    # ============================================

    create_enum :mission_type_enum, %w[time_based fixed_price]
    create_enum :mission_status_enum, %w[lead pending won in_progress completed]
    create_enum :user_company_role_enum, %w[independent client]
    create_enum :mission_company_role_enum, %w[independent client]

    # ============================================
    # Create Companies Table
    # ============================================

    create_table :companies, id: :uuid do |t|
      # Basic company information
      t.string :name, null: false, comment: 'Company legal name'
      t.string :siret, null: false, comment: 'SIRET number (14 digits for French companies)'
      t.string :siren, comment: 'SIREN number (9 digits, parent of SIRET)'
      t.string :legal_form, comment: 'Legal form (SARL, SAS, Auto-entrepreneur, etc.)'

      # Address information
      t.string :address_line_1
      t.string :address_line_2
      t.string :city
      t.string :postal_code
      t.string :country, default: 'FR', comment: 'ISO 3166-1 alpha-2 country code'

      # Tax and financial information
      t.string :tax_number, comment: 'TVA/VAT number'
      t.string :currency, default: 'EUR', comment: 'ISO 4217 currency code'

      # Audit fields
      t.timestamps
      t.datetime :deleted_at, comment: 'Soft delete timestamp'
    end

    # Add indexes for companies
    add_index :companies, :siret, unique: true
    add_index :companies, :siren
    add_index :companies, :name
    add_index :companies, :deleted_at
    add_index :companies, :currency

    # ============================================
    # Create User-Companies Relation Table
    # ============================================

    create_table :user_companies, id: :uuid do |t|
      # Foreign key to existing users table (uses bigint)
      t.bigint :user_id, null: false, comment: 'Reference to users.id (bigint)'

      # Foreign key to new companies table (uses uuid)
      t.uuid :company_id, null: false, comment: 'Reference to companies.id (uuid)'

      # Role in the company relationship
      t.enum :role, enum_type: :user_company_role_enum, null: false

      # Audit field
      t.timestamps
    end

    # Add indexes for user_companies
    add_index :user_companies, :user_id
    add_index :user_companies, :company_id
    add_index :user_companies, :role
    add_index :user_companies, %i[user_id company_id role], unique: true, name: 'unique_user_company_role'

    # Add foreign key constraints
    add_foreign_key :user_companies, :users, column: :user_id
    add_foreign_key :user_companies, :companies, column: :company_id

    # ============================================
    # Create Missions Table (Pure Domain Model)
    # ============================================

    create_table :missions, id: :uuid do |t|
      # Basic mission information
      t.string :name, null: false, comment: 'Mission name/title'
      t.text :description, comment: 'Mission description and scope'

      # Mission classification
      t.enum :mission_type, enum_type: :mission_type_enum, null: false
      t.enum :status, enum_type: :mission_status_enum, null: false, default: 'lead'

      # Temporal information
      t.date :start_date, null: false, comment: 'Mission start date'
      t.date :end_date, comment: 'Mission end date (optional for open-ended missions)'

      # Financial information (conditional based on mission_type)
      t.integer :daily_rate, comment: 'Daily rate in cents - required if time_based'
      t.integer :fixed_price, comment: 'Fixed price in cents - required if fixed_price'
      t.string :currency, default: 'EUR', null: false, comment: 'ISO 4217 currency code'

      # Creator reference for authorization (MVP: only creator can modify)
      t.bigint :created_by_user_id, comment: 'User who created the mission (bigint to match users.id)'

      # Audit fields
      t.timestamps
      t.datetime :deleted_at, comment: 'Soft delete timestamp'
    end

    # Add indexes for missions
    add_index :missions, :name
    add_index :missions, :mission_type
    add_index :missions, :status
    add_index :missions, :start_date
    add_index :missions, :end_date
    add_index :missions, :currency
    add_index :missions, :deleted_at
    add_index :missions, :created_by_user_id

    # ============================================
    # Create Mission-Companies Relation Table
    # ============================================

    create_table :mission_companies, id: :uuid do |t|
      # Foreign keys
      t.uuid :mission_id, null: false, comment: 'Reference to missions.id (uuid)'
      t.uuid :company_id, null: false, comment: 'Reference to companies.id (uuid)'

      # Role in the mission relationship
      t.enum :role, enum_type: :mission_company_role_enum, null: false

      # Audit field
      t.timestamps
    end

    # Add indexes for mission_companies
    add_index :mission_companies, :mission_id
    add_index :mission_companies, :company_id
    add_index :mission_companies, :role
    add_index :mission_companies, %i[mission_id company_id role], unique: true, name: 'unique_mission_company_role'

    # Add foreign key constraints
    add_foreign_key :mission_companies, :missions, column: :mission_id
    add_foreign_key :mission_companies, :companies, column: :company_id

    # ============================================
    # Add Business Rule Constraints
    # ============================================

    # Mission type and financial fields constraint
    add_check_constraint :missions,
      "(mission_type = 'time_based' AND daily_rate IS NOT NULL AND fixed_price IS NULL) OR
       (mission_type = 'fixed_price' AND fixed_price IS NOT NULL AND daily_rate IS NULL)",
      name: 'mission_type_financial_constraint'

    # Mission dates constraint
    add_check_constraint :missions,
      "(end_date IS NULL OR start_date <= end_date)",
      name: 'mission_dates_constraint'

    # Currency format constraint
    add_check_constraint :missions,
      "currency ~ '^[A-Z]{3}$'",
      name: 'mission_currency_format_constraint'

    # Company country format constraint
    add_check_constraint :companies,
      "country ~ '^[A-Z]{2}$'",
      name: 'company_country_format_constraint'
  end
end
