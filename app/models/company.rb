# frozen_string_literal: true

# Company
#
# Represents a legal entity (company) that can be associated with users and missions.
# Supports French business identifiers (SIREN/SIRET) and international standards.
#
# Architecture:
# - Pure domain model (no business foreign keys)
# - Soft delete support with deleted_at
# - Relation-driven via user_companies and mission_companies tables
#
# Validations:
# - name must be present and at least 2 characters
# - siret must be present, unique, and properly formatted (14 digits for French companies)
# - siren is optional but must be 9 digits if present
# - currency defaults to EUR (ISO 4217)
#
# Associations:
# - has_many :user_companies (relation table)
# - has_many :users, through: :user_companies
# - has_many :mission_companies (relation table)
# - has_many :missions, through: :mission_companies
#
# Scopes:
# - .active: returns companies that are not soft deleted
# - .by_siret: find company by SIRET number
# - .by_siren: find company by SIREN number
class Company < ApplicationRecord
  # Soft delete implementation (manual, no gem dependency)
  default_scope { where(deleted_at: nil) }

  # Method to soft delete a record
  def discard
    update(deleted_at: Time.current) if deleted_at.nil?
  end

  # Method to restore a soft-deleted record
  def undiscard
    update(deleted_at: nil) if deleted_at.present?
  end

  # Check if record is discarded
  def discarded?
    deleted_at.present?
  end

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :siret, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: /\A\d{14}\z/, message: 'must be 14 digits for French companies' }
  validates :siren, format: { with: /\A\d{9}\z/, message: 'must be 9 digits' }, allow_blank: true
  validates :legal_form, length: { maximum: 100 }, allow_blank: true
  validates :country, length: { maximum: 2 }, format: { with: /\A[A-Z]{2}\z/ }
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }

  # Address validations (optional but structured)
  validates :address_line_1, length: { maximum: 255 }, allow_blank: true
  validates :address_line_2, length: { maximum: 255 }, allow_blank: true
  validates :city, length: { maximum: 100 }, allow_blank: true
  validates :postal_code, length: { maximum: 20 }, allow_blank: true
  validates :tax_number, length: { maximum: 50 }, allow_blank: true

  # Callbacks
  before_validation :set_default_country, if: -> { country.nil? }
  before_validation :set_default_currency, if: -> { currency.nil? }
  before_validation :normalize_siret, if: :siret_changed?
  before_validation :normalize_siren, if: :siren_changed?
  before_validation :upcase_country, if: :country_changed?
  before_validation :upcase_currency, if: :currency_changed?

  # Associations via relation tables (Domain-Driven Architecture)
  has_many :user_companies, dependent: :destroy
  has_many :users, through: :user_companies

  has_many :mission_companies, dependent: :destroy
  has_many :missions, through: :mission_companies

  # Scopes
  scope :active, -> { where(deleted_at: nil) }
  scope :by_siret, ->(siret) { where(siret: siret&.gsub(/\s+/, '')) }
  scope :by_siren, ->(siren) { where(siren: siren&.gsub(/\s+/, '')) }
  scope :with_role, lambda { |role|
    joins(:user_companies).where(user_companies: { role: role }).distinct
  }

  # Instance methods
  def active?
    deleted_at.nil?
  end

  def full_address
    address_parts = [address_line_1, address_line_2, city, postal_code, country_name].compact
    address_parts.join(', ')
  end

  def country_name
    ISO3166::Country[country]&.name || country
  end

  def display_name
    "#{name} (#{siret})"
  end

  # Role-based associations
  def independent_users
    users.joins(:user_companies).where(user_companies: { company_id: id, role: 'independent' })
  end

  def client_users
    users.joins(:user_companies).where(user_companies: { company_id: id, role: 'client' })
  end

  def independent_missions
    missions.joins(:mission_companies).where(mission_companies: { company_id: id, role: 'independent' })
  end

  def client_missions
    missions.joins(:mission_companies).where(mission_companies: { company_id: id, role: 'client' })
  end

  private

  def normalize_siret
    self.siret = siret&.gsub(/\s+/, '') if siret.present?
  end

  def normalize_siren
    self.siren = siren&.gsub(/\s+/, '') if siren.present?
  end

  def upcase_country
    self.country = country&.upcase if country.present?
  end

  def upcase_currency
    self.currency = currency&.upcase if currency.present?
  end

  def set_default_country
    self.country = 'FR' if country.nil?
  end

  def set_default_currency
    self.currency = 'EUR' if currency.nil?
  end
end
