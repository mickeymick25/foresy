# frozen_string_literal: true

class AddActiveToSessions < ActiveRecord::Migration[7.1]
  def change
    add_column :sessions, :active, :boolean, default: true, null: false
    add_index :sessions, :active
  end
end
