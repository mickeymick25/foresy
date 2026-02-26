# frozen_string_literal: true

# CraEntryServices::List - Service de listage des entrées CRA
#
# Pattern architectural CraEntryServices:
# - self.call => new => #call
# - ApplicationResult pour tous les retours
# - Retourne data: { cra_entries: [...] }
#
# Responsabilités :
# - Liste les entrées CRA pour un CRA donné
# - Filtre optionnel par date
# - Tri par date décroissante
#
class CraEntryServices::List
  def self.call(cra:, current_user: nil)
    new(cra: cra, current_user: current_user).call
  end

  def initialize(cra:, current_user: nil)
    @cra = cra
    @current_user = current_user
  end

  def call
    # Validation des paramètres
    unless @cra.present?
      return ApplicationResult.bad_request(
        error: :missing_cra,
        message: 'CRA is required'
      )
    end

    # Récupération des entrées
    entries = @cra.cra_entries.order(date: :desc)

    ApplicationResult.success(
      data: { cra_entries: entries },
      message: "#{entries.count} entries found"
    )
  rescue StandardError => e
    Rails.logger.error "CraEntryServices::List error: #{e.message}" if defined?(Rails)
    ApplicationResult.internal_error(
      error: :list_failed,
      message: "Failed to list CRA entries: #{e.message}"
    )
  end
end
