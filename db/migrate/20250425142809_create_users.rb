# frozen_string_literal: true

# Migration to create the users table with email and password digest.
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest

      t.timestamps
    end
  end
end
