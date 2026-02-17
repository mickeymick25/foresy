# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_02_171723) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "cra_status", ["draft", "submitted", "locked"]
  create_enum "mission_company_role_enum", ["independent", "client"]
  create_enum "mission_status_enum", ["lead", "pending", "won", "in_progress", "completed"]
  create_enum "mission_type_enum", ["time_based", "fixed_price"]
  create_enum "user_company_role_enum", ["independent", "client"]

  create_table "companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "city"
    t.string "country", default: "FR", comment: "ISO 3166-1 alpha-2 country code"
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", comment: "ISO 4217 currency code"
    t.datetime "deleted_at", comment: "Soft delete timestamp"
    t.string "legal_form", comment: "Legal form (SARL, SAS, Auto-entrepreneur, etc.)"
    t.string "name", null: false, comment: "Company legal name"
    t.string "postal_code"
    t.string "siren", comment: "SIREN number (9 digits, parent of SIRET)"
    t.string "siret", null: false, comment: "SIRET number (14 digits for French companies)"
    t.string "tax_number", comment: "TVA/VAT number"
    t.datetime "updated_at", null: false
    t.index ["currency"], name: "index_companies_on_currency"
    t.index ["deleted_at"], name: "index_companies_on_deleted_at"
    t.index ["name"], name: "index_companies_on_name"
    t.index ["siren"], name: "index_companies_on_siren"
    t.index ["siret"], name: "index_companies_on_siret", unique: true
    t.check_constraint "country::text ~ '^[A-Z]{2}$'::text", name: "company_country_format_constraint"
  end

  create_table "cra_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false, comment: "Date of the CRA entry"
    t.datetime "deleted_at", comment: "Soft delete timestamp"
    t.text "description", comment: "Optional description"
    t.decimal "quantity", precision: 10, scale: 2, null: false, comment: "Billable quantity (in days, free granularity: 0.25, 0.5, 1.0, 2.0)"
    t.integer "unit_price", null: false, comment: "Unit price in cents"
    t.datetime "updated_at", null: false
    t.index ["date", "deleted_at"], name: "index_cra_entries_date_active"
    t.index ["date"], name: "index_cra_entries_on_date", comment: "Filter entries by date"
    t.index ["deleted_at"], name: "index_cra_entries_on_deleted_at", comment: "Soft delete queries"
    t.index ["quantity"], name: "index_cra_entries_on_quantity", comment: "Calculate totals and analytics"
    t.index ["unit_price"], name: "index_cra_entries_on_unit_price", comment: "Price filtering and calculations"
  end

  create_table "cra_entry_cras", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cra_entry_id", null: false, comment: "Reference to CRAEntry"
    t.uuid "cra_id", null: false, comment: "Reference to CRA"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cra_entry_id", "cra_id"], name: "index_cra_entry_cras_entry_cra"
    t.index ["cra_entry_id"], name: "index_cra_entry_cras_on_cra_entry_id", comment: "Find CRA for an entry"
    t.index ["cra_id", "cra_entry_id"], name: "index_cra_entry_cras_unique_cra_entry", unique: true, comment: "Enforce: One CRA per entry relationship"
    t.index ["cra_id"], name: "index_cra_entry_cras_on_cra_id", comment: "Find CRA entries for a CRA"
  end

  create_table "cra_entry_missions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cra_entry_id", null: false, comment: "Reference to CRAEntry"
    t.datetime "created_at", null: false
    t.uuid "mission_id", null: false, comment: "Reference to Mission"
    t.datetime "updated_at", null: false
    t.index ["cra_entry_id"], name: "index_cra_entry_missions_on_cra_entry_id", comment: "Find missions for a CRA entry"
    t.index ["mission_id", "cra_entry_id"], name: "index_cra_entry_missions_mission_entry"
    t.index ["mission_id"], name: "index_cra_entry_missions_on_mission_id", comment: "Find CRA entries for a mission"
  end

  create_table "cra_missions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cra_id", null: false, comment: "Reference to CRA"
    t.datetime "created_at", null: false
    t.uuid "mission_id", null: false, comment: "Reference to Mission"
    t.datetime "updated_at", null: false
    t.index ["cra_id", "mission_id"], name: "index_cra_missions_unique_cra_mission", unique: true, comment: "Enforce: One mission per CRA maximum"
    t.index ["cra_id"], name: "index_cra_missions_on_cra_id", comment: "Find missions for a CRA"
    t.index ["mission_id", "cra_id"], name: "index_cra_missions_mission_cra"
    t.index ["mission_id"], name: "index_cra_missions_on_mission_id", comment: "Find CRAs for a mission"
  end

  create_table "cras", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", null: false, comment: "Audit-only: user who created the CRA"
    t.string "currency", default: "EUR", null: false, comment: "ISO 4217 currency code"
    t.datetime "deleted_at", comment: "Soft delete timestamp"
    t.text "description", comment: "Non-financial metadata (description)"
    t.datetime "locked_at", comment: "Timestamp when CRA was locked"
    t.integer "month", null: false, comment: "Month (1-12)"
    t.enum "status", default: "draft", null: false, comment: "CRA lifecycle status", enum_type: "cra_status"
    t.integer "total_amount", comment: "Calculated total amount (in cents)"
    t.decimal "total_days", precision: 10, scale: 2, comment: "Calculated total days"
    t.datetime "updated_at", null: false
    t.integer "year", null: false, comment: "Year"
    t.index ["created_by_user_id", "month", "year"], name: "index_cras_unique_user_month_year", unique: true, where: "(deleted_at IS NULL)", comment: "Enforce uniqueness: 1 CRA max per (user, month, year)"
    t.index ["created_by_user_id"], name: "index_cras_on_created_by_user_id", comment: "Find CRAs by creator"
    t.index ["deleted_at"], name: "index_cras_on_deleted_at", comment: "Soft delete queries"
    t.index ["locked_at"], name: "index_cras_on_locked_at", comment: "Find locked CRAs"
    t.index ["month"], name: "index_cras_on_month", comment: "Filter by month"
    t.index ["status"], name: "index_cras_on_status", comment: "Filter by CRA status"
    t.index ["year"], name: "index_cras_on_year", comment: "Filter by year"
  end

  create_table "mission_companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false, comment: "Reference to companies.id (uuid)"
    t.datetime "created_at", null: false
    t.uuid "mission_id", null: false, comment: "Reference to missions.id (uuid)"
    t.enum "role", null: false, enum_type: "mission_company_role_enum"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_mission_companies_on_company_id"
    t.index ["mission_id", "company_id", "role"], name: "unique_mission_company_role", unique: true
    t.index ["mission_id"], name: "index_mission_companies_on_mission_id"
    t.index ["role"], name: "index_mission_companies_on_role"
  end

  create_table "missions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id", comment: "User who created the mission (bigint to match users.id)"
    t.string "currency", default: "EUR", null: false, comment: "ISO 4217 currency code"
    t.integer "daily_rate", comment: "Daily rate in cents - required if time_based"
    t.datetime "deleted_at", comment: "Soft delete timestamp"
    t.text "description", comment: "Mission description and scope"
    t.date "end_date", comment: "Mission end date (optional for open-ended missions)"
    t.integer "fixed_price", comment: "Fixed price in cents - required if fixed_price"
    t.enum "mission_type", null: false, enum_type: "mission_type_enum"
    t.string "name", null: false, comment: "Mission name/title"
    t.date "start_date", null: false, comment: "Mission start date"
    t.enum "status", default: "lead", null: false, enum_type: "mission_status_enum"
    t.datetime "updated_at", null: false
    t.index ["created_by_user_id"], name: "index_missions_on_created_by_user_id"
    t.index ["currency"], name: "index_missions_on_currency"
    t.index ["deleted_at"], name: "index_missions_on_deleted_at"
    t.index ["end_date"], name: "index_missions_on_end_date"
    t.index ["mission_type"], name: "index_missions_on_mission_type"
    t.index ["name"], name: "index_missions_on_name"
    t.index ["start_date"], name: "index_missions_on_start_date"
    t.index ["status"], name: "index_missions_on_status"
    t.check_constraint "currency::text ~ '^[A-Z]{3}$'::text", name: "mission_currency_format_constraint"
    t.check_constraint "end_date IS NULL OR start_date <= end_date", name: "mission_dates_constraint"
    t.check_constraint "mission_type = 'time_based'::mission_type_enum AND daily_rate IS NOT NULL AND fixed_price IS NULL OR mission_type = 'fixed_price'::mission_type_enum AND fixed_price IS NOT NULL AND daily_rate IS NULL", name: "mission_type_financial_constraint"
  end

  create_table "sessions", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "last_activity_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["active"], name: "index_sessions_on_active"
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
    t.index ["uuid"], name: "index_sessions_on_uuid", unique: true
  end

  create_table "user_companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "company_id", null: false, comment: "Reference to companies.id (uuid)"
    t.datetime "created_at", null: false
    t.enum "role", null: false, enum_type: "user_company_role_enum"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false, comment: "Reference to users.id (bigint)"
    t.index ["company_id"], name: "index_user_companies_on_company_id"
    t.index ["role"], name: "index_user_companies_on_role"
    t.index ["user_id", "company_id", "role"], name: "unique_user_company_role", unique: true
    t.index ["user_id"], name: "index_user_companies_on_user_id"
  end

  create_table "user_cras", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cra_id", null: false
    t.datetime "created_at", null: false
    t.string "role", default: "creator", null: false
    t.bigint "user_id", null: false
    t.index ["cra_id", "role"], name: "idx_user_cras_cra_creator", unique: true, where: "((role)::text = 'creator'::text)"
    t.index ["cra_id"], name: "index_user_cras_on_cra_id"
    t.index ["user_id", "cra_id"], name: "index_user_cras_on_user_id_and_cra_id"
    t.index ["user_id"], name: "index_user_cras_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['creator'::character varying, 'contributor'::character varying, 'reviewer'::character varying]::text[])", name: "user_cras_role_check"
  end

  create_table "user_missions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "mission_id", null: false
    t.string "role", default: "creator", null: false
    t.bigint "user_id", null: false
    t.index ["mission_id", "role"], name: "idx_user_missions_mission_creator", unique: true, where: "((role)::text = 'creator'::text)"
    t.index ["mission_id"], name: "index_user_missions_on_mission_id"
    t.index ["user_id", "mission_id"], name: "index_user_missions_on_user_id_and_mission_id"
    t.index ["user_id"], name: "index_user_missions_on_user_id"
    t.check_constraint "role::text = ANY (ARRAY['creator'::character varying, 'contributor'::character varying, 'reviewer'::character varying]::text[])", name: "user_missions_role_check"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest"
    t.string "provider"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.string "uuid", limit: 36, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  add_foreign_key "cra_entry_cras", "cra_entries", on_delete: :cascade
  add_foreign_key "cra_entry_cras", "cras", on_delete: :cascade
  add_foreign_key "cra_entry_missions", "cra_entries", on_delete: :cascade
  add_foreign_key "cra_entry_missions", "missions", on_delete: :cascade
  add_foreign_key "cra_missions", "cras", on_delete: :cascade
  add_foreign_key "cra_missions", "missions", on_delete: :cascade
  add_foreign_key "mission_companies", "companies"
  add_foreign_key "mission_companies", "missions"
  add_foreign_key "sessions", "users"
  add_foreign_key "user_companies", "companies"
  add_foreign_key "user_companies", "users"
  add_foreign_key "user_cras", "cras", name: "fk_user_cras_cra", on_delete: :cascade
  add_foreign_key "user_cras", "users", name: "fk_user_cras_user", on_delete: :cascade
  add_foreign_key "user_missions", "missions", name: "fk_user_missions_mission", on_delete: :cascade
  add_foreign_key "user_missions", "users", name: "fk_user_missions_user", on_delete: :cascade
end
