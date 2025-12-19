# frozen_string_literal: true

# CreateSessions
#
# Migration to create the sessions table with UUID primary key.
# Sessions track user authentication state with tokens and expiration.
class CreateSessions < ActiveRecord::Migration[7.1]
  def change
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
end
