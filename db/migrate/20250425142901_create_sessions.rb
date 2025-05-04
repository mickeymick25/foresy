# frozen_string_literal: true

# Migration to create the sessions table, which stores user session data
# including token, expiration, last activity, IP, and user agent.
class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_activity_at, null: false
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_session_indexes
  end

  private

  def add_session_indexes
    add_index :sessions, :token, unique: true
    add_index :sessions, :expires_at
  end
end
