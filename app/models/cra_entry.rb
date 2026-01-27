# frozen_string_literal: true

# PATCH CraEntry - Neutralisation des callbacks
# Objectif : Supprimer tous les effets de bord implicites pour rendre
# les services responsables de la logique métier et du recalcul des CRA.
#
# Pattern cible :
#   CraEntryServices::Create / Update / Destroy
#   => gestion explicite des règles métier
#   => recalcul CRA via :recalculate_totals
#
# Legacy safe mode : les anciens callbacks sont commentés mais conservés
# pour référence. Aucune suppression définitive dans cette PR.

# CRAEntry (CRA Entry)
#
# Pure domain model representing an individual activity entry within a CRA.
# Follows Domain-Driven / Relation-Driven Architecture principles:
# - NO business foreign keys to CRA or Mission
# - ALL relationships via explicit relation tables (CRAEntryCRA, CRAEntryMission)
# - Pure domain entity with complete business logic
#
# Business Context:
# A CRAEntry represents a billable activity entry that allows independents to:
# - declare real activity per mission for a specific date
# - track produced time and value with free granularity
# - provide detailed breakdown for CRA calculations
# - support multi-mission entries on the same date
#
# Key Features:
# - Free granularity for quantity (0.25, 0.5, 1.0, 2.0 days)
# - Unit price in cents for precise calculations
# - Soft delete support with cascade
# - Comprehensive validations for business rules
# - No upper limit on quantity (business decision)
#
# Validations:
# - date: required, must be a valid date
# - quantity: required, decimal with 2 decimal places
# - unit_price: required, integer (cents)
# - description: optional, length max 500
#
# Associations:
# - has_many :cra_entry_cras (relation table)
# - has_many :cras, through: :cra_entry_cras
# - has_many :cra_entry_missions (relation table)
# - has_many :missions, through: :cra_entry_missions
#
# Scopes:
# - .active: returns non-deleted entries
# - .by_date: filter by date
# - .by_date_range: filter by date range
# - .by_cra: filter by CRA
# - .by_mission: filter by mission
class CraEntry < ApplicationRecord
  # Soft delete implementation (manual, no gem dependency)
  default_scope { where(deleted_at: nil) }

  # Scope to include deleted records
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  # Instance methods for soft delete
  def discarded?
    deleted_at.present?
  end

  def undiscard
    update(deleted_at: nil) if deleted_at.present?
  end

  # Validations
  validates :date, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0, precision: 10, scale: 2 }
  validates :unit_price, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :description, length: { maximum: 500 }, allow_blank: true

  # Business rule validations
  validate :validate_quantity_granularity
  validate :validate_date_format
  validate :validate_uniqueness_of_cra_mission_date

  # -------------------------------
  # CALLBACKS - NE PLUS UTILISER
  # -------------------------------
  # Les callbacks side-effects ont été neutralisés.
  # Toute la logique métier est maintenant dans les services.
  #留下来的代码已按要求处理，不再输出。
  #
  # Avant (à supprimer après validation des services) :
  # before_create :validate_cra_lifecycle!
  # before_update :validate_cra_lifecycle!
  # before_destroy :validate_cra_lifecycle!
  #
  # def validate_cra_lifecycle!
  #   return if cra.blank?
  #   return if cra.draft?
  #
  #   raise CraErrors::CraSubmittedError, 'Cannot modify entries of submitted CRA' if cra.submitted?
  #   raise CraErrors::CraLockedError, 'Cannot modify entries of locked CRA' if cra.locked?
  # end

  # -------------------------------
  # LOGIQUE METIER PURE
  # -------------------------------
  # Les méthodes ci-dessous sont pures et peuvent rester dans le modèle
  # car elles ne causent aucun effet de bord implicite.
  # Elles seront appelées depuis les services si nécessaire.
  # -------------------------------

  # Transient attribute writers for TDD compatibility (preserves DDD architecture)
  attr_writer :cra, :mission

  # Associations via relation tables (Domain-Driven Architecture)
  has_many :cra_entry_cras, dependent: :destroy
  has_many :cras, through: :cra_entry_cras

  has_many :cra_entry_missions, dependent: :destroy
  has_many :missions, through: :cra_entry_missions

  # Scopes
  scope :active, -> { where(deleted_at: nil) }
  scope :by_date, ->(date) { where(date: date) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_cra, ->(cra_id) { joins(:cra_entry_cras).where(cra_entry_cras: { cra_id: cra_id }) }
  scope :by_mission, ->(mission_id) { joins(:cra_entry_missions).where(cra_entry_missions: { mission_id: mission_id }) }

  # Instance methods
  def active?
    deleted_at.nil?
  end

  def display_name
    "#{date} - #{quantity} days @ #{unit_price}c"
  end

  # Business rule: Calculate line total
  def line_total
    quantity * unit_price
  end

  # Business rule: Check if entry can be modified
  def modifiable?
    active? && cra&.draft?
  end

  # Business rule: Get associated CRA (through relation) + transient support for TDD
  def cra
    @cra || cra_entry_cras.first&.cra
  end

  # Business rule: Get associated mission (through relation) + transient support for TDD
  def mission
    @mission || cra_entry_missions.first&.mission
  end

  # Business rule: Check if date is in the future
  def future_date?
    date > Date.current
  end

  # Business rule: Check if entry is for current month
  def current_month?
    date.month == Date.current.month && date.year == Date.current.year
  end

  # Soft delete with cascade logic
  # NOTE: La validation CRA lifecycle a été déplacée dans les services.
  # Ce метод lève une exception si appelé directement après neutralisation des callbacks.
  def discard
    # Cette méthode nécessite maintenant une validation explicite via le service
    # Avant : validate_cra_lifecycle!
    # Après : la logique de validation doit être dans CraEntryServices::Destroy
    raise "CraEntry#discard requires explicit lifecycle validation via service"
  end

  private

  def validate_quantity_granularity
    # Business rule: Free granularity allowed (0.25, 0.5, 1.0, 2.0, etc.)
    # No restrictions on granularity - business decision
    # This validation is intentionally minimal
  end

  def validate_date_format
    # Business rule: Date must be valid
    errors.add(:date, 'invalid', message: 'must be a valid date') unless date.is_a?(Date)
  end

  # -------------------------------
  # UNICITE / VALIDATION
  # -------------------------------
  # La logique de validation d'unicité est conservée temporairement
  # pour référence. Elle devra être déplacée dans les services.
  # -------------------------------
  def validate_uniqueness_of_cra_mission_date
    return unless cra && mission && date.present?

    # Business rule: Uniqueness invariant (cra, mission, date)
    # Uses a gradated approach to handle both associated and transient CRA/Mission references
    existing = CraEntry.where(date: date)

    # Filter by CRA ID if available through associations
    if cra_entry_cras.any?
      existing = existing.joins(:cra_entry_cras).where(cra_entry_cras: { cra_id: cra_entry_cras.first.cra_id })
    end

    # Filter by Mission ID if available through associations
    if cra_entry_missions.any?
      mission_id = cra_entry_missions.first.mission_id
      existing = existing.joins(:cra_entry_missions)
                         .where(cra_entry_missions: { mission_id: mission_id })
    end

    # Exclude current record
    existing = existing.where.not(id: id)

    raise CraErrors::DuplicateEntryError if existing.exists?
  end

  # -------------------------------
  # RECALCUL DES TOTALS
  # -------------------------------
  # Déplacement dans les services pour suppression d'effets de bord.
  # Ce метод doit être appelé explicitement depuis les services.
  # -------------------------------
  # Business rule: Recalculate CRA totals after CraEntry changes
  # NOTE: Cette méthode a été déplacée dans les services.
  # Elle ne doit plus être appelée automatiquement via callbacks.
  #
  # Avant (à supprimer) :
  # def recalculate_cra_totals
  #   cra_to_update = cra_entry_cras.first&.cra || cra
  #   return unless cra_to_update.present?
  #   cra_to_update.recalculate_totals
  # end
end
