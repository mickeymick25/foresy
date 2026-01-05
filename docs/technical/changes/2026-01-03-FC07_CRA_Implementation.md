# FC-07 CRA Implementation Status

> **Document de suivi de l'implémentation FC-07 (Compte Rendu d'Activité)**
> 
> Dernière mise à jour : 3 Janvier 2026

## ⚠️ STATUT : EN COURS - TESTS ÉCHOUENT

**Raison** : Refactorisation des concerns avec corrections Zeitwerk. Les tests RSpec échouent après les modifications de namespacing.

Voir : [📋 Correction Technique](../corrections/2026-01-03-FC07_Concerns_Namespace_Fix.md)

## 📊 État Global

| Composant | État | Tests |
|-----------|------|-------|
| Modèles | ✅ Complet | ✅ Complet |
| Contrôleurs | 🔧 Refactorisé | 🔴 Échouent |
| Services | ✅ Complet | ⚠️ À valider |
| Migrations | ✅ Complet | N/A |
| Concerns | 🔧 Namespace corrigé | 🔴 À tester |
| Zeitwerk | ✅ OK | N/A |
| Rubocop | ⚠️ À revalider | - |
| Brakeman | ⚠️ À revalider | - |

**Résumé des tests :**
- Tests CRA (cras_spec.rb) : 🔴 **ÉCHOUENT** - Erreurs 500, format réponse
- Tests CRA Entries (cra_entries_spec.rb) : ⚠️ **À VALIDER**
- Tests Services : ⚠️ À revalider après fix concerns
- Rubocop : ⚠️ À revalider
- Brakeman : ⚠️ À revalider

## 🔴 Problèmes Identifiés (3 Jan 2026)

1. **Namespacing Concerns** - Corrigé de `Cras::*` vers `Api::V1::Cras::*`
2. **CraErrors Autoload** - Déplacé de `lib/errors/cra_errors.rb` vers `lib/cra_errors.rb`
3. **Méthode cra_params** - Ajoutée dans CrasController
4. **ErrorRenderable** - Fix re-raise logic (dev only au lieu de non-production)
5. **ResponseFormatter** - Créé avec méthodes de classe `single()` et `collection()`

## 🎯 Actions Requises

- [ ] Analyser les erreurs 500 dans les tests
- [ ] Aligner format de réponse API avec attentes des tests
- [ ] Valider authentification JWT dans les tests
- [ ] Revalider Rubocop et Brakeman
- [ ] Merger seulement quand tous les tests passent

---

## ✅ Implémentations Terminées

### 1. Modèles (Domain Models)

#### Cra (`app/models/cra.rb`)
- ✅ Validations complètes (month, year, status, currency, etc.)
- ✅ Énumération PostgreSQL pour status (`draft`, `submitted`, `locked`)
- ✅ Soft delete avec `deleted_at`
- ✅ Lifecycle transitions (`submit!`, `lock!`)
- ✅ Calculs financiers (`calculate_total_days`, `calculate_total_amount`)
- ✅ Scope `accessible_to` corrigé pour inclure les CRAs créés par l'utilisateur

#### CraEntry (`app/models/cra_entry.rb`)
- ✅ Validations (date, quantity, unit_price)
- ✅ Calcul `line_total` (retourne Integer en centimes)
- ✅ Soft delete avec règles métier FC-07
- ✅ Associations via tables de relation

#### Tables de Relation
- ✅ `CraMission` - Relation CRA ↔ Mission
- ✅ `CraEntryCra` - Relation CraEntry ↔ CRA
- ✅ `CraEntryMission` - Relation CraEntry ↔ Mission

### 2. Contrôleurs

#### CrasController (`app/controllers/api/v1/cras_controller.rb`)
- ✅ CRUD complet (create, index, show, update, destroy)
- ✅ Actions lifecycle (`submit`, `lock`)
- ✅ Pagination avec Pagy
- ✅ Gestion des erreurs spécifiques
- ✅ Rate limiting
- ✅ Contrôle d'accès

#### CraEntriesController (`app/controllers/api/v1/cra_entries_controller.rb`)
- ✅ CRUD complet
- ✅ Création avec associations automatiques
- ✅ Intégration CraMissionLinker
- ✅ Validation unicité (cra_id, mission_id, date)
- ✅ Blocage modifications si CRA submitted ou locked

### 3. Services

#### CraMissionLinker (`app/services/cra_mission_linker.rb`)
- ✅ Liaison automatique CRA-Mission lors de création d'entrée
- ✅ Gestion des doublons
- ✅ Logging

#### GitLedgerService (`app/services/git_ledger_service.rb`)
- ✅ Création de commits pour CRAs verrouillés
- ✅ Audit trail immutable
- ✅ Transaction atomique avec DB

#### GitLedgerRepository (`app/services/git_ledger_repository.rb`)
- ✅ Opérations Git bas niveau (init, commit, cleanup)
- ✅ Sécurisation Command Injection (`Shellwords.escape`)
- ✅ Détection réécriture d'historique

#### GitLedgerPayload (`app/services/git_ledger_payload.rb`)
- ✅ Construction payload JSON canonique
- ✅ Sérialisation CRA entries et totaux

### 4. Migrations

```
db/migrate/20260102104544_create_cras.rb
db/migrate/20260102111556_create_cra_entries.rb
db/migrate/20260102111707_create_cra_missions.rb
db/migrate/20260102111826_create_cra_entry_cras.rb
db/migrate/20260102111926_create_cra_entry_missions.rb
db/migrate/20260102171723_change_created_by_user_id_type_to_bigint.rb
```

### 5. Configuration

#### Pagy (`config/initializers/pagy.rb`)
- ✅ Configuration de la pagination
- ✅ Limite par défaut : 20 items/page
- ✅ Gestion overflow

---

## 📋 Décisions CTO (Session du 2 Janvier 2026)

### 1. Soft Delete : Comportement officiel
| Situation | Réponse HTTP |
|-----------|--------------|
| Entry soft-deleted | **404 Not Found** |
| Accès via `with_deleted` | ❌ Interdit dans les controllers |

**Justification DDD** : Une entité supprimée n'existe plus dans le langage du domaine.

### 2. CRA Submitted : Règle métier FC-07
| État CRA | CREATE Entry | PATCH Entry | DELETE Entry |
|----------|--------------|-------------|--------------|
| `draft` | ✅ | ✅ | ✅ |
| `submitted` | ❌ 409 | ❌ 409 | ❌ 409 |
| `locked` | ❌ 409 | ❌ 409 | ❌ 409 |

**Justification** : Un CRA soumis est un engagement contractuel. Toute modification après soumission = risque légal.

### 3. Messages d'erreur : Format unifié
```
"Cannot modify entry from submitted or locked CRA"
```

### 4. line_total : Integer en centimes
- ✅ Pas de Float pour les montants financiers
- ✅ `line_total = (quantity * unit_price).to_i`
- ✅ Stockage et exposition en centimes

### 5. Validation errors : Format Array
```ruby
# Spec pattern correct
expect(json_response['message'].any? { |m| m.include?("can't be blank") }).to be true
```

---

## 🔧 Corrections Apportées (Session du 2 Janvier 2026)

### 1. Helper d'authentification pour tests
**Fichier :** `spec/support/auth_helpers.rb`

Ajout de la méthode `token_for(user)` pour générer des tokens JWT valides dans les tests :

```ruby
def token_for(user)
  session = user.sessions.create!(
    ip_address: '127.0.0.1',
    user_agent: 'RSpec Test',
    expires_at: 30.days.from_now
  )
  payload = { user_id: user.id, session_id: session.id }
  JsonWebToken.encode(payload)
end
```

### 2. Type de colonne `created_by_user_id`
**Problème :** La colonne était de type `uuid` mais `users.id` est de type `bigint`

**Solution :** Migration `20260102171723_change_created_by_user_id_type_to_bigint.rb`

### 3. Pagination avec Pagy
**Problème :** Méthode `.page()` non disponible (Kaminari non installé)

**Solution :** Installation et configuration de `pagy` gem

### 4. Scope `accessible_to` 
**Problème :** Les CRAs nouvellement créés (sans missions) n'étaient pas accessibles

**Solution :** Modification du scope pour inclure les CRAs créés par l'utilisateur :

```ruby
scope :accessible_to, lambda { |user|
  via_missions_ids = joins(:cra_missions)
    .joins('INNER JOIN missions ON missions.id = cra_missions.mission_id')
    .joins('INNER JOIN mission_companies ON mission_companies.mission_id = missions.id')
    .joins('INNER JOIN user_companies ON user_companies.company_id = mission_companies.company_id')
    .where(user_companies: { user_id: user.id, role: %w[independent client] })
    .select(:id)

  where(created_by_user_id: user.id).or(where(id: via_missions_ids))
}
```

### 5. Associations Mission ↔ CRA
**Fichier :** `app/models/mission.rb`

Ajout des associations manquantes :

```ruby
has_many :cra_missions, dependent: :destroy
has_many :cras, through: :cra_missions
has_many :cra_entry_missions, dependent: :destroy
has_many :cra_entries, through: :cra_entry_missions
```

### 6. Controller CraEntries : before_action fix
**Problème :** `set_cra` n'était appelé que pour `create` et `index`

**Solution :** `before_action :set_cra` sans restriction (nécessaire pour tous les endpoints)

### 7. Règles métier submitted/locked
**Fichier :** `app/controllers/api/v1/cra_entries_controller.rb`

```ruby
def validate_cra_modifiable!
  return unless @cra
  unless @cra.draft?
    render json: {
      error: 'CRA Locked',
      message: 'Cannot add entries to submitted or locked CRAs'
    }, status: :conflict
  end
end

def validate_entry_modifiable!
  return unless @cra_entry
  unless @cra.draft?
    render json: {
      error: 'CRA Locked',
      message: 'Cannot modify entry from submitted or locked CRA'
    }, status: :conflict
  end
end
```

### 8. CraEntry#discard : Règle FC-07
**Fichier :** `app/models/cra_entry.rb`

```ruby
def discard
  if cra && !cra.draft?
    errors.add(:base, 'Cannot delete entry from submitted or locked CRA')
    return false
  end
  update(deleted_at: Time.current) if deleted_at.nil?
end
```

### 9. Unicité des entries
**Fichier :** `app/controllers/api/v1/cra_entries_controller.rb`

```ruby
def entry_exists_for_mission_and_date?(mission_id, date)
  @cra.cra_entries
      .joins(:cra_entry_missions)
      .where(cra_entry_missions: { mission_id: mission_id })
      .where(date: date)
      .where(deleted_at: nil)
      .exists?
end
```

### 10. Specs corrigées
- ✅ CraMissionLinker : ajout du stub `allow(...).to receive(...)`
- ✅ Array.include : pattern `.any? { |m| m.include?(...) }`
- ✅ line_total : comparaison avec `.to_i`
- ✅ Soft delete : 404 au lieu de 409
- ✅ CRA submitted : DELETE → 409 Conflict
- ✅ Large quantities : date/mission uniques pour éviter conflit unicité

---

## 📁 Fichiers Modifiés

```
app/controllers/api/v1/cras_controller.rb
app/controllers/api/v1/cra_entries_controller.rb
app/models/cra.rb
app/models/cra_entry.rb
app/models/mission.rb
app/services/git_ledger_service.rb
app/services/git_ledger_repository.rb (nouveau)
app/services/git_ledger_payload.rb (nouveau)
config/initializers/pagy.rb (nouveau)
db/migrate/20260102171723_change_created_by_user_id_type_to_bigint.rb (nouveau)
spec/support/auth_helpers.rb
spec/factories/cra.rb
spec/requests/api/v1/cras_spec.rb
spec/requests/api/v1/cra_entries_spec.rb
Gemfile (ajout pagy)
```

---

## 🧪 Commandes de Test

```bash
# Démarrer les services
docker compose up -d

# Tests CRA uniquement
docker compose run --rm web bundle exec rspec spec/requests/api/v1/cras_spec.rb

# Tests CRA Entries uniquement
docker compose run --rm web bundle exec rspec spec/requests/api/v1/cra_entries_spec.rb

# Tous les tests
docker compose run --rm web bundle exec rspec

# Tests avec documentation
docker compose run --rm web bundle exec rspec --format documentation

# Rubocop
docker compose run --rm web bundle exec rubocop

# Brakeman (sécurité)
docker compose run --rm web bundle exec brakeman
```

---

## 📝 Notes Techniques

### Sécurité
- Les CRAs inaccessibles retournent 404 (et non 403) pour ne pas révéler leur existence
- Authentification JWT requise sur tous les endpoints
- Rate limiting sur les opérations de création/modification

### Architecture
- Domain-Driven Design avec tables de relation explicites
- Pas de clés étrangères métier dans les modèles purs
- Soft delete pour toutes les entités
- GitLedgerService pour l'immutabilité légale

### Performance
- Pagination avec Pagy (léger et performant)
- Eager loading des associations (`.includes()`)
- Index sur les colonnes fréquemment requêtées

### Conformité FC-07
- ✅ Lifecycle CRA strict (draft → submitted → locked)
- ✅ Immutabilité après verrouillage
- ✅ Audit trail Git Ledger
- ✅ Montants en centimes (Integer)
- ✅ Soft delete avec exclusion par default_scope

---

## 🔍 Qualité du Code

### Rubocop ✅
- **114 fichiers inspectés**
- **0 offense détectée**

**Refactorisations effectuées :**
- `CrasController` : Extraction méthodes helper (`check_locked_and_render`, etc.)
- `CraMissionLinker` : Conversion `class << self`, méthodes privées extraites
- `GitLedgerService` : Séparation en 3 fichiers distincts :
  - `git_ledger_service.rb` (88 lignes) - Service principal
  - `git_ledger_repository.rb` (117 lignes) - Opérations Git
  - `git_ledger_payload.rb` (43 lignes) - Construction payload
- Correction lignes trop longues (>120 chars)
- Correction naming variables (`cra_2024` → `cra_year_twenty_twenty_four`)

### Brakeman ✅
- **0 warning de sécurité**
- **1 warning ignoré** (Mass Assignment dans controller de test E2E)

**Corrections sécurité :**
- Command Injection × 2 → `Shellwords.escape()` ajouté dans `GitLedgerRepository`
- Fichier `config/brakeman.ignore` créé avec justification

---

## 🎯 Statut Final

**FC-07 CRA Implementation : 🔴 EN COURS - TESTS ÉCHOUENT**

- ❌ Tests RSpec CRA échouent après refactorisation concerns
- ✅ Architecture DDD respectée
- ✅ Règles métier FC-07 définies
- ✅ Git Ledger implémenté
- ✅ Zeitwerk : All is good!
- ⚠️ Rubocop : À revalider
- ⚠️ Brakeman : À revalider
- 🔴 **NE PAS MERGER** - Corriger tests avant validation

**Voir** : [📋 Correction Technique](../corrections/2026-01-03-FC07_Concerns_Namespace_Fix.md)