# frozen_string_literal: true

# User
#
# Represents a system user with authentication credentials.
# Supports secure password handling, session management, and validation.
#
# Associations:
# - has_many :sessions, dependent: :destroy
#
# Validations:
# - email must be present, unique, and correctly formatted
# - password must be present and at least 6 characters long when required
# - active must be a boolean (true or false)
#
# Callbacks:
# - after_initialize: sets default value for active
# - before_save: ensures email is downcased
#
# Scopes:
# - .active: returns only active users
#
# Instance methods:
# - #active_sessions: returns currently active sessions
# - #create_session: creates a new session with optional metadata
# - #invalidate_all_sessions!: marks all active sessions as expired
class User < ApplicationRecord
  has_secure_password validations: false

  has_many :sessions, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :active, inclusion: { in: [true, false] }

  before_save :downcase_email
  after_initialize :set_default_active, if: :new_record?

  scope :active, -> { where(active: true) }

  def active_sessions
    sessions.active
  end

  def create_session(ip_address: nil, user_agent: nil)
    sessions.create!(
      expires_at: 24.hours.from_now,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end

  def invalidate_all_sessions!
    sessions.active.update_all(expires_at: Time.current)
  end

  def active?
    active
  end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def password_required?
    (new_record? || password.present?) && provider.blank?
  end

  def set_default_active
    self.active = true if active.nil?
  end
end
