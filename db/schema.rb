# frozen_string_literal: true

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

ActiveRecord::Schema[7.1].define(version: 20_251_216_144_630) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'plpgsql'

  create_table 'sessions', force: :cascade do |t|
    t.bigint 'user_id', null: false
    t.string 'token', null: false
    t.datetime 'expires_at', null: false
    t.datetime 'last_activity_at', null: false
    t.string 'ip_address'
    t.string 'user_agent'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.boolean 'active', default: true, null: false
    t.index ['active'], name: 'index_sessions_on_active'
    t.index ['expires_at'], name: 'index_sessions_on_expires_at'
    t.index ['token'], name: 'index_sessions_on_token', unique: true
    t.index ['user_id'], name: 'index_sessions_on_user_id'
  end

  create_table 'users', force: :cascade do |t|
    t.string 'email'
    t.string 'password_digest'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'provider'
    t.string 'uid'
    t.string 'name'
    t.boolean 'active', default: true, null: false
  end

  add_foreign_key 'sessions', 'users'
end
