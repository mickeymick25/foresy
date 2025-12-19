# frozen_string_literal: true

# CreateUsers
#
# Initial migration to create the users table with UUID primary key.
# Supports both traditional authentication (email/password) and OAuth providers.
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

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
  end
end
