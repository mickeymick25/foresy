# frozen_string_literal: true

# FixUsersActiveColumn
#
# Migration to fix the users.active column by adding proper constraints
# and backfilling existing records with default values.
#
# Uses a temporary class to avoid model dependencies and implements
# batch processing for large tables to prevent locking issues.
class FixUsersActiveColumn < ActiveRecord::Migration[7.1]
  # Temporary class to avoid model dependencies
  class MigrationUser < ActiveRecord::Base
    self.table_name = 'users'
  end

  def up
    # Backfill existing users with active: true using batch processing
    # This prevents table locking issues on large datasets
    batch_update_users

    # Add NOT NULL constraint
    change_column_null :users, :active, false

    # Add default value
    change_column_default :users, :active, true
  end

  def down
    # Remove constraints
    change_column_default :users, :active, nil
    change_column_null :users, :active, true

    # Don't backfill on rollback - preserve existing data as it was
  end

  private

  # Batch processing for large tables
  def batch_update_users
    # Process in batches to avoid long table locks
    batch_size = 1000

    updated_count = 0
    loop do
      # Find batch of records with active = nil
      batch = MigrationUser.where(active: nil).limit(batch_size)

      break if batch.empty?

      # Update this batch
      count = batch.update_all(active: true)
      updated_count += count

      # Log progress for large migrations
      log_progress(updated_count) if (updated_count % 10_000).zero?
    end

    Rails.logger.info "Total users updated with active: true: #{updated_count}"
  rescue StandardError => e
    Rails.logger.error "Error during users backfill: #{e.message}"
    raise
  end

  def log_progress(count)
    Rails.logger.info "Updated #{count} users with active: true"
  end
end
