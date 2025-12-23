# frozen_string_literal: true

# Session
#
# Represents a user session, including its authentication token, expiration,
# and last activity timestamp. Used to track and validate API access.
#
# Associations:
# - belongs_to :user
#
# Validations:
# - token must be present and unique
# - expires_at and last_activity_at must be present
#
# Scopes:
# - .active: sessions not yet expired
# - .expired: sessions that have passed their expiration time
#
# Instance methods:
# - #active?: returns true if session is still valid
# - #expired?: returns true if session has expired
# - #refresh!: updates last_activity_at to current time
class Session < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :last_activity_at, presence: true

  # UUID validation for pgcrypto compatibility fix
  # Ensures UUID format and uniqueness when uuid column is present
  validates :uuid,
            uniqueness: true,
            presence: true,
            format: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
            if: :uuid_column_present?

  before_validation :set_defaults, on: :create
  before_validation :generate_uuid, on: :create

  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  def active?
    expires_at > Time.current
  end

  def expired?
    !active?
  end

  def refresh!
    update(last_activity_at: Time.current)
  end

  private

  def set_defaults
    self.token ||= SecureRandom.hex(32)
    self.last_activity_at ||= Time.current
  end

  def generate_uuid
    # Generate UUID only if uuid column exists and uuid is not already set
    self.uuid ||= SecureRandom.uuid if uuid_column_present?
  end

  def uuid_column_present?
    # Check if uuid column exists in the table
    self.class.column_names.include?('uuid')
  end
end
