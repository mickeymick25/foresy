# frozen_string_literal: true

module SoftDeletable
  extend ActiveSupport::Concern

  included do
    # Soft delete implementation (shared across Cra and CraEntry models)
    # Provides consistent soft delete behavior with audit trail
    default_scope { where(deleted_at: nil) }

    # Scope to include deleted records for admin/recovery operations
    scope :with_deleted, -> { unscope(where: :deleted_at) }

    # Scope to get only soft-deleted records
    scope :deleted, -> { where.not(deleted_at: nil) }

    # Scope to get active (non-deleted) records
    scope :active, -> { where(deleted_at: nil) }
  end

  # Instance methods for soft delete operations
  def discarded?
    deleted_at.present?
  end

  # Alias for consistency with other gems
  alias deleted? discarded?

  def active?
    deleted_at.nil?
  end

  # Restore a soft-deleted record
  # @return [Boolean] true if restoration was successful
  def undiscard
    return false if active?

    update(deleted_at: nil)
  end

  # Perform soft delete with optional reason
  # @param reason [String] optional reason for deletion
  # @return [Boolean] true if deletion was successful
  def discard(reason = nil)
    return false if discarded?

    # Store deletion reason if provided (if column exists)
    if respond_to?(:deletion_reason) && reason.present?
      update(deleted_at: Time.current, deletion_reason: reason)
    else
      update(deleted_at: Time.current)
    end
  end

  # Check if record can be modified (not soft-deleted)
  # @return [Boolean] true if record is active and modifiable
  def modifiable?
    (active? && !respond_to?(:locked?)) || !locked?
  end

  # Get the time since deletion (in days)
  # @return [Integer, nil] number of days since deletion, nil if not deleted
  def days_since_deletion
    return nil unless discarded?

    (Time.current.to_date - deleted_at.to_date).to_i
  end

  # Check if deletion is recent (within specified days)
  # @param days [Integer] number of days to consider as "recent"
  # @return [Boolean] true if deleted within the specified timeframe
  def recently_deleted?(days = 30)
    return false unless discarded?

    days_since_deletion <= days
  end

  # Class methods for soft delete operations
  class_methods do
    # Restore multiple soft-deleted records
    # @param ids [Array] array of record IDs to restore
    # @return [Integer] number of successfully restored records
    def restore_multiple(ids)
      where(id: ids, deleted_at: nil).update_all(deleted_at: nil)
    end

    # Permanently delete soft-deleted records older than specified days
    # @param days [Integer] number of days after which to permanently delete
    # @return [Integer] number of permanently deleted records
    def permanently_delete_older_than(days)
      deleted.where('deleted_at < ?', days.days.ago).delete_all
    end

    # Get statistics about soft deleted records
    # @return [Hash] statistics about deletion patterns
    def deletion_statistics
      {
        total_active: active.count,
        total_deleted: deleted.count,
        deletion_rate: deleted.count.to_f / count * 100,
        recent_deletions: recently_deleted.count
      }
    end

    # Scope for recently deleted records
    # @param days [Integer] number of days to consider as "recent"
    # @return [ActiveRecord::Relation] records deleted within timeframe
    def recently_deleted(days = 30)
      deleted.where('deleted_at >= ?', days.days.ago)
    end
  end
end
