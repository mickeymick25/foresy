# frozen_string_literal: true

# CraMissionLinker Service
#
# Service responsable de la création automatique des liens entre CRA et Mission.
# Implements FC 07 - CRA Management avec Domain-Driven Architecture.
#
# Fonctionnalités:
# - Création automatique du lien CRAMission lors de la première CRAEntry d'une mission
# - Respect de la règle métier: "Une mission ne peut apparaître qu'une seule fois dans un CRA"
# - Centralisation de la logique de liaison (aucun endpoint direct)
# - Gestion transactionnelle avec rollback en cas d'erreur
# - Logging pour audit et debugging
#
# Usage:
#   CraMissionLinker.link_cra_to_mission!(cra_id, mission_id)
#
# Erreurs gérées:
# - Mission déjà liée au CRA (erreur métier)
# - CRA inexistant
# - Mission inexistante
# - Erreurs de base de données (rollback automatique)
class CraMissionLinker
  class << self
    # Link a CRA to a mission (create CRAMission relation)
    #
    # @param cra_id [UUID] ID du CRA
    # @param mission_id [UUID] ID de la mission
    # @return [CraMission] La relation créée
    # @raise [ActiveRecord::RecordInvalid] Si la mission est déjà liée au CRA
    # @raise [ActiveRecord::RecordNotFound] Si le CRA ou la mission n'existe pas
    def link_cra_to_mission!(cra_id, mission_id)
      validate_ids!(cra_id, mission_id)
      validate_records_exist!(cra_id, mission_id)

      existing_link = find_existing_link(cra_id, mission_id)
      return existing_link if existing_link

      create_link(cra_id, mission_id)
    rescue ActiveRecord::RecordInvalid => e
      handle_record_invalid(e, cra_id, mission_id)
    rescue StandardError => e
      handle_standard_error(e, cra_id, mission_id)
    end

    # Vérifie si une mission est liée à un CRA donné
    def mission_linked_to_cra?(cra_id, mission_id)
      return false unless cra_id.present? && mission_id.present?

      CraMission.exists?(cra_id: cra_id, mission_id: mission_id)
    end

    # Récupère toutes les missions liées à un CRA
    def get_missions_for_cra(cra_id)
      return Mission.none unless cra_id.present?

      Mission.joins(:cra_missions).where(cra_missions: { cra_id: cra_id })
    end

    # Récupère tous les CRAs liés à une mission
    def get_cras_for_mission(mission_id)
      return Cra.none unless mission_id.present?

      Cra.joins(:cra_missions).where(cra_missions: { mission_id: mission_id })
    end

    # Supprime le lien entre un CRA et une mission
    def unlink_cra_from_mission!(cra_id, mission_id)
      cra_mission = CraMission.find_by!(
        cra_id: cra_id,
        mission_id: mission_id
      )

      cra_mission.destroy!
    end

    # Logique de métadonnées pour debugging et audit
    def debug_info(cra_id, mission_id)
      {
        cra_exists: Cra.with_deleted.exists?(id: cra_id),
        mission_exists: Mission.with_deleted.exists?(id: mission_id),
        already_linked: mission_linked_to_cra?(cra_id, mission_id),
        cra_status: Cra.find_by(id: cra_id)&.status,
        mission_name: Mission.find_by(id: mission_id)&.name
      }.compact
    end

    private

    def validate_ids!(cra_id, mission_id)
      return if cra_id.present? && mission_id.present?

      raise ArgumentError, 'cra_id and mission_id are required'
    end

    def validate_records_exist!(cra_id, mission_id)
      cra = Cra.with_deleted.find_by(id: cra_id)
      raise ActiveRecord::RecordNotFound, "CRA not found with id: #{cra_id}" unless cra
      raise ActiveRecord::RecordNotFound, 'CRA is deleted' if cra.discarded?

      mission = Mission.with_deleted.find_by(id: mission_id)
      raise ActiveRecord::RecordNotFound, "Mission not found with id: #{mission_id}" unless mission
      raise ActiveRecord::RecordNotFound, 'Mission is deleted' if mission.discarded?
    end

    def find_existing_link(cra_id, mission_id)
      existing = CraMission.find_by(cra_id: cra_id, mission_id: mission_id)
      return nil unless existing

      Rails.logger.info "[CraMissionLinker] Mission #{mission_id} already linked to CRA #{cra_id}"
      existing
    end

    def create_link(cra_id, mission_id)
      cra_mission = nil
      ActiveRecord::Base.transaction do
        cra_mission = CraMission.create!(cra_id: cra_id, mission_id: mission_id)
        Rails.logger.info "[CraMissionLinker] Created link between CRA #{cra_id} and Mission #{mission_id}"
      end
      cra_mission
    end

    def handle_record_invalid(error, cra_id, mission_id)
      # Vérification défensive complète - error.record peut être nil, errors peut être nil
      already_linked = error.record.respond_to?(:errors) &&
                       error.record.errors[:mission_id]&.include?('can only appear once in a CRA')
      if already_linked
        Rails.logger.warn "[CraMissionLinker] Mission #{mission_id} already linked to CRA #{cra_id}"
        raise ActiveRecord::RecordInvalid, 'Mission is already linked to this CRA'
      end

      log_db_error(error, cra_id, mission_id)
      raise
    end

    def handle_standard_error(error, cra_id, mission_id)
      Rails.logger.error "[CraMissionLinker] Unexpected error: CRA #{cra_id}, Mission #{mission_id}"
      Rails.logger.error "[CraMissionLinker] #{error.message}"
      raise
    end

    def log_db_error(error, cra_id, mission_id)
      Rails.logger.error "[CraMissionLinker] DB error: CRA #{cra_id}, Mission #{mission_id}"
      Rails.logger.error "[CraMissionLinker] #{error.message}"
    end
  end
end
