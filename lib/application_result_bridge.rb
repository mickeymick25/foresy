# lib/application_result_bridge.rb
# Bridge entre ApplicationResult et Shared::Result pour compatibilité
# Permet aux contrôleurs refactorés de fonctionner avec les services existants

require_relative 'application_result'

module ApplicationResultBridge
  # Convertit ApplicationResult en format compatible Shared::Result
  def self.to_shared_result(application_result)
    raise ArgumentError, "Expected ApplicationResult, got #{application_result.class}" unless application_result.is_a?(ApplicationResult)

    if application_result.ok?
      # Pour ok results, on adapte le format selon le status
      case application_result.status
      when :created
        # Convertit en format success_entry
        Api::V1::CraEntries::Shared::Result.success_entry(
          extract_entry_from_data(application_result.data),
          extract_cra_from_data(application_result.data)
        )
      when :ok
        # Pour les autres operations ok, utilise success avec data
        Api::V1::CraEntries::Shared::Result.success(
          success: true,
          data: application_result.data,
          errors: nil,
          error_type: nil
        )
      else
        # Autres statuses OK
        Api::V1::CraEntries::Shared::Result.success(
          success: true,
          data: application_result.data,
          errors: nil,
          error_type: nil
        )
      end
    else
      # Pour les failures, convertit en format failure
      errors = [application_result.message || application_result.error.to_s]
      error_type = map_status_to_error_type(application_result.status)
      Api::V1::CraEntries::Shared::Result.failure(errors, error_type)
    end
  end

  # Extrait l'entry des données ApplicationResult
  def self.extract_entry_from_data(data)
    return nil unless data.is_a?(Hash)

    # Essaye différents formats possibles
    if data[:entry]
      data[:entry]
    elsif data[:data] && data[:data][:entry]
      data[:data][:entry]
    elsif data[:item]
      data[:item]
    elsif data[:data] && data[:data][:item]
      data[:data][:item]
    else
      data # Retourne les données brutes si pas de format spécifique
    end
  end

  # Extrait le CRA des données ApplicationResult
  def self.extract_cra_from_data(data)
    return nil unless data.is_a?(Hash)

    # Essaye différents formats possibles
    if data[:cra]
      data[:cra]
    elsif data[:data] && data[:data][:cra]
      data[:data][:cra]
    else
      nil # Pas de CRA trouvé
    end
  end

  # Mappe les status ApplicationResult vers les error_type Shared::Result
  def self.map_status_to_error_type(status)
    case status
    when :invalid_payload
      :validation_failed
    when :forbidden
      :forbidden
    when :not_found
      :not_found
    when :conflict
      :duplicate_entry # Ou autre type de conflict approprié
    when :internal_error
      :internal_error
    else
      :validation_failed # Fallback
    end
  end

  # Helper pour créer un ApplicationResult depuis un Shared::Result
  def self.from_shared_result(shared_result)
    if shared_result.success?
      ApplicationResult.new(
        ok?: true,
        status: :ok,
        data: shared_result.data,
        error: nil,
        message: nil
      )
    else
      ApplicationResult.new(
        ok?: false,
        status: map_error_type_to_status(shared_result.error_type),
        data: nil,
        error: shared_result.error_type,
        message: shared_result.errors&.first
      )
    end
  end

  # Mappe les error_type Shared::Result vers les status ApplicationResult
  def self.map_error_type_to_status(error_type)
    case error_type
    when :validation_failed
      :invalid_payload
    when :forbidden
      :forbidden
    when :not_found
      :not_found
    when :duplicate_entry
      :conflict
    when :internal_error
      :internal_error
    else
      :invalid_payload # Fallback
    end
  end
end
