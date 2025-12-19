# frozen_string_literal: true

# EnablePgcryptoAndMigrateToUuid
#
# Migration to convert users and sessions tables from bigint IDs to UUIDs.
# This provides non-predictable identifiers for better API security.
#
# IMPORTANT: This migration recreates tables, so existing data will be lost.
# Only run on development/staging or ensure proper data backup for production.
class EnablePgcryptoAndMigrateToUuid < ActiveRecord::Migration[7.1]
  def up
    # Enable pgcrypto extension for gen_random_uuid()
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    # Drop existing tables (foreign key constraint requires order)
    drop_table :sessions, if_exists: true
    drop_table :users, if_exists: true

    # Recreate users table with UUID primary key
    create_table :users, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :email
      t.string :password_digest
      t.string :provider
      t.string :uid
      t.string :name
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, %i[provider uid], unique: true, where: 'provider IS NOT NULL'

    # Recreate sessions table with UUID primary key and foreign key
    create_table :sessions, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_activity_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :sessions, :token, unique: true
    add_index :sessions, :expires_at
    add_index :sessions, :active
  end

  def down
    # Drop UUID tables
    drop_table :sessions, if_exists: true
    drop_table :users, if_exists: true

    # Recreate users table with bigint primary key
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :provider
      t.string :uid
      t.string :name
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    # Recreate sessions table with bigint primary key
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_activity_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :sessions, :token, unique: true
    add_index :sessions, :expires_at
    add_index :sessions, :active
  end
end
