# frozen_string_literal: true

# CraEntryServices::Update - Service de mise à jour d'une entrée CRA
#
# Pattern architectural CraEntryServices:
# - self.call => new => #call
# - ApplicationResult pour tous les retours
# - Transactions atomiques
# - Recalcul CRA explicite
#
# Responsabilités :
# - Validation des paramètres d'entrée
# - Vérification des permissions (utilisateur = créateur du CRA)
# - Vérification du lifecycle CRA (draft uniquement)
# - Mise à jour dans une transaction
# - Recalcul des totaux CRA
#
class CraEntryServices::Update
  def self.call(cra_entry:, attributes:, current_user:)
    new(cra_entry: cra_entry, attributes: attributes, current_user: current_user).call
  end

  def initialize(cra_entry:, attributes:, current_user:)
    @cra_entry = cra_entry
    @attributes = attributes
    @current_user = current_user
  end

  def call
    # Validation des paramètres d'entrée
    return ApplicationResult.bad_request(
      error: :missing_cra_entry,
      message: "CRA Entry is required"
    ) unless @cra_entry.present?

    return ApplicationResult.bad_request(
      error: :missing_user,
      message: "Current user is required"
    ) unless @current_user.present?

    # Vérification des permissions
    unless @cra_entry.cra.created_by_user_id == @current_user.id
      return ApplicationResult.forbidden(
        error: :insufficient_permissions,
        message: "Only the CRA creator can update entries"
      )
    end

    # Vérification du lifecycle - только draft
    unless @cra_entry.cra.draft?
      return ApplicationResult.conflict(
        error: :invalid_transition,
        message: "Cannot update entries of a CRA that is not in draft"
      )
    end

    # Effectuer la mise à jour dans une transaction
    begin
      ActiveRecord::Base.transaction do
        @cra_entry.update!(@attributes)
        @cra_entry.cra.recalculate_totals

        ApplicationResult.success(
          data: { cra_entry: @cra_entry },
          message: "CRA Entry updated successfully"
        )
      end
    rescue ActiveRecord::RecordInvalid => e
      ApplicationResult.unprocessable_content(
        error: :validation_failed,
        message: e.record.errors.full_messages.join(', ')
      )
    rescue StandardError => e
      Rails.logger.error "CraEntryServices::Update error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :update_failed,
        message: "Failed to update CRA Entry: #{e.message}"
      )
    end
  end
end
