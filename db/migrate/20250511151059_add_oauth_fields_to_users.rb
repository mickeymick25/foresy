# frozen_string_literal: true

# AddOauthFieldsToUsers
#
# Migration to add OAuth fields (provider, uid, name) to users table.
# Enables support for OAuth authentication with external providers like GitHub and Google.
class AddOauthFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :name, :string
  end
end
