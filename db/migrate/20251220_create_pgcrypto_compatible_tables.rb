# frozen_string_literal: true

# Migration unique pour tables users et sessions
#
# Cette migration crée une architecture 100% compatible avec tous les environnements
# PostgreSQL managés (AWS RDS, Google Cloud SQL, Heroku, Azure Database).
#
# Caractéristiques:
# - AUCUNE dépendance à pgcrypto ou autres extensions PostgreSQL
# - IDs bigint standards (auto-increment)
# - Colonne uuid (string) pour identifiants publics via SecureRandom.uuid
# - Compatible avec tous les environnements sans privilèges superuser
#
# Résultat:
# - Déploiement garanti sur tous les environnements managés
# - Génération UUID via Ruby (SecureRandom.uuid) dans les modèles
# - Performance optimale avec IDs bigint pour les jointures
class CreatePgcryptoCompatibleTables < ActiveRecord::Migration[7.1]
  def up
    Rails.logger.info "=== DÉBUT Migration: Tables sans dépendance pgcrypto ==="

    # Étape 1: Création de la table users
    create_users_table

    # Étape 2: Création de la table sessions
    create_sessions_table

    Rails.logger.info "=== FIN Migration RÉUSSIE ==="
    Rails.logger.info "✅ Tables créées avec IDs bigint (pas de dépendance pgcrypto)"
    Rails.logger.info "✅ Génération UUID via Ruby (SecureRandom.uuid)"
    Rails.logger.info "✅ Compatible tous environnements managés"
  end

  def down
    Rails.logger.info "=== DÉBUT Rollback ==="

    drop_table :sessions, force: :cascade if table_exists?(:sessions)
    drop_table :users, force: :cascade if table_exists?(:users)

    Rails.logger.info "=== FIN Rollback RÉUSSI ==="
  end

  private

  def create_users_table
    Rails.logger.info "Création de la table users (bigint IDs)..."

    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest
      t.string :provider
      t.string :uid
      t.string :name
      t.boolean :active, default: true, null: false

      # Colonne uuid (string) pour identifiant public - généré par Ruby
      t.string :uuid, limit: 36, null: false

      t.timestamps
    end

    # Index unique sur email
    add_index :users, :email, unique: true, name: 'index_users_on_email'

    # Index unique composite sur provider + uid (pour OAuth)
    add_index :users, %i[provider uid], unique: true,
              name: 'index_users_on_provider_and_uid',
              where: '(provider IS NOT NULL)'

    # Index unique sur uuid
    add_index :users, :uuid, unique: true, name: 'index_users_on_uuid'

    Rails.logger.info "✅ Table users créée"
  end

  def create_sessions_table
    Rails.logger.info "Création de la table sessions (bigint IDs)..."

    create_table :sessions do |t|
      t.bigint :user_id, null: false
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_activity_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.boolean :active, default: true, null: false

      # Colonne uuid (string) pour identifiant public - généré par Ruby
      t.string :uuid, limit: 36, null: false

      t.timestamps
    end

    # Foreign key vers users
    add_foreign_key :sessions, :users, column: :user_id

    # Index sur active
    add_index :sessions, :active, name: 'index_sessions_on_active'

    # Index sur expires_at
    add_index :sessions, :expires_at, name: 'index_sessions_on_expires_at'

    # Index unique sur token
    add_index :sessions, :token, unique: true, name: 'index_sessions_on_token'

    # Index sur user_id
    add_index :sessions, :user_id, name: 'index_sessions_on_user_id'

    # Index unique sur uuid
    add_index :sessions, :uuid, unique: true, name: 'index_sessions_on_uuid'

    Rails.logger.info "✅ Table sessions créée"
  end
end
