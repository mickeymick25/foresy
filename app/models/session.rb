class Session < ApplicationRecord
  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :last_activity_at, presence: true

  before_validation :set_defaults, on: :create

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
end 