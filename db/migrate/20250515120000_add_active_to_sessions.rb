# frozen_string_literal: true

# AddActiveToSessions
#
# Migration to add 'active' column to sessions table.
# Enables session activation/deactivation functionality.
class AddActiveToSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :sessions, :active, :boolean, default: true, null: false
    add_index :sessions, :active
  end
end
