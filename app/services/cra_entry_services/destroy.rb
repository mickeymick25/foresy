# frozen_string_literal: true

# CraEntryServices::Destroy - Service de suppression d'une entrée CRA
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
# - Suppression dans une transaction
# - Recalcul des totaux CRA
#
class CraEntryServices::Destroy
  def self.call(cra_entry:, current_user:)
    new(cra_entry: cra_entry, current_user: current_user).call
  end

  def initialize(cra_entry:, current_user:)
    @cra_entry = cra_entry
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
        message: "Only the CRA creator can delete entries"
      )
    end

    # Vérification du lifecycle - только draft
    unless @cra_entry.cra.draft?
      return ApplicationResult.conflict(
        error: :invalid_transition,
        message: "Cannot delete entries of a CRA that is not in draft"
      )
    end

    # Effectuer la suppression dans une transaction
    begin
      ActiveRecord::Base.transaction do
        @cra_entry.destroy!
        @cra_entry.cra.recalculate_totals

        ApplicationResult.success(
          data: { cra_entry_id: @cra_entry.id },
          message: "CRA Entry deleted successfully"
        )
      end
    rescue ActiveRecord::RecordNotDestroyed => e
      ApplicationResult.unprocessable_entity(
        error: :destroy_failed,
        message: e.record.errors.full_messages.join(', ')
      )
    rescue StandardError => e
      Rails.logger.error "CraEntryServices::Destroy error: #{e.message}" if defined?(Rails)
      ApplicationResult.internal_error(
        error: :destroy_failed,
        message: "Failed to delete CRA Entry: #{e.message}"
      )
    end
  end
end
