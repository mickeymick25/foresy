# frozen_string_literal: true

# Migration corrective pour remplacer pgcrypto par UUID Ruby
# Résout le problème de compatibilité avec les environnements managés
# (AWS RDS, Google Cloud SQL, Heroku Postgres) qui nécessitent
# des privilèges superuser pour activer pgcrypto
#
# Approche sûre : Ajoute des colonnes uuid supplémentaires sans modifier
# les données existantes, permettant une transition progressive
class RemovePgcryptoCompatibilityFix < ActiveRecord::Migration[7.1]
  def up
    Rails.logger.info "Début migration pgcrypto → UUID Ruby"

    # Étape 1 : Ajouter colonnes uuid (string) aux tables existantes
    # Ces colonnes seront utilisées pour la génération automatique côté Ruby
    # Note: L'extension pgcrypto reste en place pour la compatibilité
    # avec les environnements qui la supportent

    # Pour la table users - ajouter colonne uuid string
    unless column_exists?(:users, :uuid)
      add_column :users, :uuid, :string, limit: 36, null: false, default: nil
      add_index :users, :uuid, unique: true, name: 'index_users_on_uuid'

      # Générer UUID pour les utilisateurs existants
      execute <<-SQL
        UPDATE users SET uuid = replace(id::text, '-', '') WHERE uuid IS NULL;
      SQL
    end

    # Pour la table sessions - ajouter colonne uuid string
    unless column_exists?(:sessions, :uuid)
      add_column :sessions, :uuid, :string, limit: 36, null: false, default: nil
      add_index :sessions, :uuid, unique: true, name: 'index_sessions_on_uuid'

      # Générer UUID pour les sessions existantes
      execute <<-SQL
        UPDATE sessions SET uuid = replace(id::text, '-', '') WHERE uuid IS NULL;
      SQL
    end

    Rails.logger.info "Migration pgcrypto → UUID Ruby terminée avec succès"
    Rails.logger.info "Nouvelles colonnes uuid ajoutées aux tables users et sessions"
    Rails.logger.info "Les UUID seront générés automatiquement côté Ruby via les modèles"
  end

  def down
    # Cette migration peut être partiellement annulée
    begin
      remove_index :sessions, name: 'index_sessions_on_uuid' if index_exists?(:sessions, :uuid)
      remove_column :sessions, :uuid if column_exists?(:sessions, :uuid)

      remove_index :users, name: 'index_users_on_uuid' if index_exists?(:users, :uuid)
      remove_column :users, :uuid if column_exists?(:users, :uuid)

      Rails.logger.info "Colonnes uuid supprimées avec succès"
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error "Erreur lors de la suppression des colonnes uuid: #{e.message}"
    end

    # Note: Impossible de recréer l'extension pgcrypto sans privilèges superuser
    Rails.logger.warn "Impossible de recréer l'extension pgcrypto (nécessite privilèges superuser)"
  end

end
