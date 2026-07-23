# frozen_string_literal: true

# P5.1 — Migrer users.uuid et sessions.uuid de VARCHAR(36) vers UUID natif PostgreSQL
class ChangeUuidColumnsToNativeUuid < ActiveRecord::Migration[8.1]
  def up
    change_column :users, :uuid, :uuid, using: 'uuid::uuid'
    change_column :sessions, :uuid, :uuid, using: 'uuid::uuid'
  end

  def down
    change_column :users, :uuid, :string, limit: 36, null: false
    change_column :sessions, :uuid, :string, limit: 36, null: false
  end
end