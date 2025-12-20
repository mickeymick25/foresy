# 🧪 Stratégie de Test Migration End-to-End - pgcrypto Elimination

**Date :** 19 décembre 2025  
**Objectif :** Valider la migration pgcrypto → UUID Ruby sur environnement de staging  
**Contexte :** Simulation des contraintes RDS/CloudSQL (privilèges limités)  

---

## 🎯 Problème à Résoudre

### Contraintes Environnements Managés
Les environnements managés (AWS RDS, Google Cloud SQL, Heroku, Azure) ont des **restrictions strictes** :

- **pgcrypto extension** : Nécessite privilèges superuser
- **CREATE EXTENSION** : Échoue si pas de droits suffisants
- **Dépendances critiques** : Application ne peut pas démarrer sans UUIDs

### Objectif de Test
Valider une **migration progressive** qui :
1. **Fonctionne avec pgcrypto** (environnements permissifs)
2. **Fonctionne sans pgcrypto** (environnements restrictifs) 
3. **Conserve l'intégrité des données** dans tous les cas
4. **Peut être testée** sur environnement proche production

---

## 🧪 Environnements de Test

### 1. Environnement Développement Local (Contrôle Total)
**Configuration :** PostgreSQL avec tous privilèges  
**Test :** Validation de la logique de migration  
**Attendu :** pgcrypto disponible, migration fonctionne

### 2. Environnement Staging Simulé (Privilèges Limités)
**Configuration :** PostgreSQL avec restrictions  
**Simulation :** Désactivation de pgcrypto ou erreur lors de l'activation  
**Test :** Validation de la migration sans pgcrypto  
**Attendu :** Migration fonctionne même sans pgcrypto

### 3. Test de Régression
**Configuration :** Données existantes avec UUIDs pgcrypto  
**Test :** Migration de données réelles  
**Attendu :** Aucune perte de données, cohérence maintenue

---

## 📋 Plan de Test Progressif

### Phase 1 : Test sur Environnement de Développement

#### 1.1 État Initial (AVEC pgcrypto)
```bash
# Vérifier que pgcrypto est activé
docker-compose run --rm web bundle exec rails runner "
puts 'pgcrypto enabled: ' + ActiveRecord::Base.connection.extension_enabled?('pgcrypto').to_s
puts 'Users table ID type: ' + User.column_for_attribute('id').type.to_s
puts 'Sessions table ID type: ' + Session.column_for_attribute('id').type.to_s
"
```

#### 1.2 Création Données de Test
```bash
# Créer des données avec UUIDs pgcrypto
docker-compose run --rm web bundle exec rails runner "
user = User.create!(email: 'test-pgcrypto@example.com', password: 'password123')
session = user.create_session(ip_address: '127.0.0.1', user_agent: 'test-agent')
puts 'User ID: ' + user.id.to_s + ' (type: ' + user.id.class.to_s + ')'
puts 'Session ID: ' + session.id.to_s + ' (type: ' + session.id.class.to_s + ')'
"
```

#### 1.3 Application Migration Test
```bash
# Appliquer la migration progressive
bundle exec rails db:migrate

# Vérifier l'état après migration
docker-compose run --rm web bundle exec rails runner "
puts 'pgcrypto still enabled: ' + ActiveRecord::Base.connection.extension_enabled?('pgcrypto').to_s
puts 'Users table ID type: ' + User.column_for_attribute('id').type.to_s
puts 'Sessions table ID type: ' + Session.column_for_attribute('id').type.to_s
puts 'Total users: ' + User.count.to_s
puts 'Total sessions: ' + Session.count.to_s
"
```

### Phase 2 : Test sur Environnement Simulé (SANS pgcrypto)

#### 2.1 Simulation RDS/CloudSQL
```sql
-- Désactiver pgcrypto pour simuler les contraintes managées
-- (À exécuter manuellement sur la base de données)
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
-- Ou plus simple : DROP EXTENSION pgcrypto; (si possible)
```

#### 2.2 Test Migration Sans pgcrypto
```bash
# Recréer la base sans pgcrypto
docker-compose run --rm web bundle exec rails db:drop db:create

# Vérifier que pgcrypto ne peut pas être activé
docker-compose run --rm web bundle exec rails runner "
begin
  ActiveRecord::Base.connection.execute('CREATE EXTENSION pgcrypto;')
  puts 'pgcrypto activation: SUCCESS (unexpected)'
rescue => e
  puts 'pgcrypto activation: FAILED (expected) - ' + e.message
end
"
```

#### 2.3 Test Application Migration
```bash
# Essayer d'appliquer les migrations (doit échouer sur pgcrypto)
bundle exec rails db:migrate

# Vérifier si l'application peut démarrer sans pgcrypto
docker-compose run --rm web bundle exec rails runner "
puts 'Application can start: ' + (User.count rescue 'FAILED').to_s
"
```

### Phase 3 : Migration Progressive Safe

#### 3.1 Migration en Deux Étapes

**Étape 1 : Migration de Compatibilité**
```ruby
# db/migrate/20251219_step1_pgcrypto_compatibility.rb
class Step1PgcryptoCompatibility < ActiveRecord::Migration[7.1]
  def up
    Rails.logger.info "Étape 1: Ajout colonnes uuid pour compatibilité"

    # Ajouter colonnes uuid sans toucher aux IDs existants
    add_column :users, :uuid, :string, limit: 36, null: false, default: nil
    add_column :sessions, :uuid, :string, limit: 36, null: false, default: nil

    # Générer UUIDs pour les enregistrements existants
    # Utiliser les UUIDs existants si possible
    execute "UPDATE users SET uuid = id::text WHERE uuid IS NULL;"
    execute "UPDATE sessions SET uuid = id::text WHERE uuid IS NULL;"

    # Ajouter indexes
    add_index :users, :uuid, unique: true, name: 'index_users_on_uuid'
    add_index :sessions, :uuid, unique: true, name: 'index_sessions_on_uuid'

    Rails.logger.info "Étape 1 terminée: Colonnes uuid ajoutées"
  end
end
```

**Étape 2 : Migration d'Élimination**
```ruby
# db/migrate/20251219_step2_pgcrypto_elimination.rb
class Step2PgcryptoElimination < ActiveRecord::Migration[7.1]
  def up
    Rails.logger.info "Étape 2: Élimination dépendance pgcrypto"

    # Cette étape ne sera appliquée que si l'étape 1 a réussi
    # et que l'environnement supporte la suppression de pgcrypto

    # 1. Sauvegarder les données avec mapping old_id -> new_id
    # 2. Supprimer les tables avec UUID IDs
    # 3. Recréer avec integer IDs
    # 4. Restaurer les données avec nouveaux IDs
    # 5. Conserver les colonnes uuid pour la compatibilité

    # Voir la migration complète dans la section suivante
  end
end
```

---

## 🚨 Tests de Régression Critiques

### Test 1 : Intégrité des Données
```bash
# Avant migration
user_count_before = User.count
session_count_before = Session.count

# Après migration
user_count_after = User.count  
session_count_after = Session.count

# Vérifier que les comptes correspondent
raise "Data loss detected!" if user_count_before != user_count_after
raise "Session loss detected!" if session_count_before != session_count_after
```

### Test 2 : Fonctionnalité OAuth
```bash
# Tester que l'authentification OAuth fonctionne après migration
docker-compose run --rm web bundle exec rspec spec/requests/api/v1/oauth_spec.rb
```

### Test 3 : Génération UUID
```bash
# Tester que les nouveaux UUIDs sont générés correctement
docker-compose run --rm web bundle exec rails runner "
new_user = User.create!(email: 'uuid-test@example.com', password: 'password123')
puts 'New user UUID: ' + new_user.uuid.to_s
puts 'UUID format valid: ' + (new_user.uuid.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)).to_s
"
```

---

## ⚠️ Gestion des Erreurs

### Scénario 1 : pgcrypto Non Disponible
```ruby
def safe_enable_extension(extension_name)
  begin
    enable_extension extension_name
    Rails.logger.info "#{extension_name} extension enabled successfully"
    true
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.warn "Cannot enable #{extension_name} extension: #{e.message}"
    Rails.logger.warn "Continuing without #{extension_name} extension"
    false
  end
end
```

### Scénario 2 : Migration Partielle Échoue
```ruby
def up
  begin
    # Tentative de migration complète
    execute_migration_steps
  rescue => e
    Rails.logger.error "Migration failed: #{e.message}"
    Rails.logger.error "Rolling back to safe state"
    
    # Stratégie de rollback ou migration alternative
    execute_fallback_strategy
  end
end
```

---

## 📊 Critères de Validation

### Critères Techniques
- ✅ **Tests passent** : 149/149 tests RSpec réussissent
- ✅ **pgcrypto optionnel** : Application fonctionne avec ou sans pgcrypto
- ✅ **UUIDs générés** : SecureRandom.uuid produit des UUIDs valides
- ✅ **Données intactes** : Aucune perte de données pendant la migration

### Critères Opérationnels  
- ✅ **Downtime minimal** : Migration < 5 secondes
- ✅ **Rollback possible** : Stratégie de retour en arrière définie
- ✅ **Monitoring** : Logs détaillés de chaque étape
- ✅ **Documentation** : Guide de déploiement complet

### Critères Environnement
- ✅ **Développement local** : Migration fonctionne
- ✅ **Staging simulé** : Migration fonctionne sans pgcrypto
- ✅ **Production RDS** : Migration compatible avec contraintes
- ✅ **Cloud SQL** : Migration compatible avec restrictions

---

## 🎯 Prochaines Étapes

1. **Implémenter la stratégie progressive** (2 migrations étapes)
2. **Tester sur environnement développement** (Phase 1)
3. **Tester sur environnement simulé** (Phase 2)  
4. **Validation complète** (Phase 3)
5. **Déploiement production** avec monitoring renforcé

---

**Cette stratégie garantit une migration sûre et testable qui fonctionne sur tous les environnements, avec ou sans pgcrypto.**

---

*Stratégie de test développée le 19 décembre 2025*  
*Priorité : CRITIQUE - Validation avant déploiement production*  
*Contact : Équipe technique pour exécution des tests*