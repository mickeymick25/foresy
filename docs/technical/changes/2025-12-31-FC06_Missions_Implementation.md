# FC-06 Missions Implementation

**Date:** 31 décembre 2025  
**Feature Contract:** 06 — Mission Management  
**Status:** ✅ **PR #12 MERGED** — Platinum Level  
**Author:** Co-CTO  
**Last Updated:** 1 janvier 2026 (PR #12 merged, CTO approved)

---

## 📋 Résumé

Implémentation complète du Feature Contract 06 — Missions, permettant aux indépendants de créer et gérer leurs missions professionnelles. Cette feature constitue le pivot fonctionnel de Foresy, servant de base au CRA, à la facturation et au reporting.

---

## 🎯 Objectifs Atteints

| Objectif | Statut |
|----------|--------|
| CRUD Missions complet | ✅ |
| Architecture Domain-Driven | ✅ |
| Relations via tables dédiées | ✅ |
| Lifecycle management | ✅ |
| Contrôle d'accès par rôle | ✅ |
| Soft delete avec protection CRA | ✅ |
| Tests RSpec complets | ✅ |
| Swagger auto-généré | ✅ |
| RuboCop 0 offense | ✅ |
| Brakeman 0 vulnérabilité | ✅ |

---

## 🏗️ Architecture Implémentée

### Principe Fondamental
```
❌ Aucune clé étrangère métier dans les Domain Models
✅ Toutes les relations passent par des tables dédiées
```

### Modèles Créés

#### Mission (Domain Model Pur)
- `id` : UUID
- `name` : String (required, 2-255 chars)
- `description` : Text (optional)
- `mission_type` : Enum (time_based | fixed_price)
- `status` : Enum (lead → pending → won → in_progress → completed)
- `start_date` : Date (required)
- `end_date` : Date (optional)
- `daily_rate` : Integer (required if time_based)
- `fixed_price` : Integer (required if fixed_price)
- `currency` : String (ISO 4217, default EUR)
- `created_by_user_id` : BigInt (creator reference)
- `deleted_at` : DateTime (soft delete)

#### MissionCompany (Relation Table)
- `id` : UUID
- `mission_id` : UUID (FK)
- `company_id` : UUID (FK)
- `role` : Enum (independent | client)

#### Company (Domain Model)
- `id` : UUID
- `name`, `siret`, `siren`, `legal_form`
- `address_line_1`, `address_line_2`, `city`, `postal_code`, `country`
- `tax_number`, `currency`
- `deleted_at` : DateTime (soft delete)

#### UserCompany (Relation Table)
- `id` : UUID
- `user_id` : BigInt (FK)
- `company_id` : UUID (FK)
- `role` : Enum (independent | client)

---

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/missions` | Créer une mission |
| GET | `/api/v1/missions` | Lister les missions accessibles |
| GET | `/api/v1/missions/:id` | Détail d'une mission |
| PATCH | `/api/v1/missions/:id` | Modifier une mission |
| DELETE | `/api/v1/missions/:id` | Archiver une mission |

### Codes de Réponse

| HTTP | Code | Description |
|------|------|-------------|
| 201 | created | Mission créée |
| 200 | ok | Succès |
| 401 | unauthorized | JWT invalide |
| 403 | forbidden | Pas de company independent |
| 404 | not_found | Mission inaccessible |
| 409 | conflict | Mission liée à un CRA |
| 422 | unprocessable_entity | Validation échouée |
| 429 | too_many_requests | Rate limit dépassé |

---

## 🔄 Mission Lifecycle

```
lead → pending → won → in_progress → completed
```

- **Pas de retour arrière autorisé**
- **Pas de transition automatique**
- Transition invalide → 422 `invalid_transition`

---

## 🔐 Règles d'Accès

### Création
- L'utilisateur DOIT avoir une Company avec rôle `independent`
- La Company client est optionnelle

### Lecture
- Accès autorisé si l'utilisateur appartient à une Company liée à la Mission
- Sinon → 404 (pas de leak d'information)

### Modification
- MVP : Seul le créateur peut modifier
- Transition de statut validée

### Suppression
- Soft delete uniquement
- Interdite si Mission liée à un CRA → 409

---

## 🧪 Tests Implémentés

### Statistiques
- **Total tests projet** : 290 examples, 0 failures
- **Tests Missions** : 30 examples, 0 failures
- **Swagger specs** : 119 examples générées

### Couverture
- ✅ Création mission (time_based, fixed_price)
- ✅ Création avec client_company_id
- ✅ Validation mission_type
- ✅ Validation daily_rate/fixed_price
- ✅ Liste des missions accessibles
- ✅ Détail mission
- ✅ Modification mission
- ✅ Transition de statut (valides et invalides)
- ✅ Archivage mission
- ✅ Protection CRA (mock)
- ✅ Rate limiting
- ✅ Contrôle d'accès (403, 404)
- ✅ Authentification (401)

---

## 🔧 Corrections Appliquées

### 1. Validation Enum PostgreSQL
**Problème :** Les valeurs enum invalides causaient une erreur 500 (PostgreSQL constraint)

**Solution :** Ajout de validation custom `validate_enum_values` avant l'envoi à PostgreSQL
```ruby
VALID_MISSION_TYPES = %w[time_based fixed_price].freeze
VALID_STATUSES = %w[lead pending won in_progress completed].freeze

validate :validate_enum_values
```

### 2. Méthode discard Dupliquée
**Problème :** Deux définitions de `discard` dans le modèle Mission

**Solution :** Fusion en une seule méthode avec logique métier CRA

### 3. Séparation mission_params
**Problème :** `client_company_id` passé à `Mission.new` causait des erreurs

**Solution :** Création de `mission_attributes` (sans client_company_id) et `client_company_id` séparé

### 4. Nommage RuboCop
**Problème :** `has_client?` et `has_cra_entries?` violaient Naming/PredicatePrefix

**Solution :** Renommage en `client?` et `cra_entries?`

### 5. Configuration RuboCop
**Problème :** `address_line_1` et `address_line_2` violaient Naming/VariableNumber

**Solution :** Ajout dans `AllowedIdentifiers` (convention de nommage base de données)

### 6. Renommage Endpoints E2E (Platinum Compliance)
**Problème :** Les endpoints `/__e2e__/setup` et `/__e2e__/cleanup` n'étaient pas assez explicites pour un auditeur sécurité

**Solution :** Renommage vers `/__test_support__/e2e/setup` et `/__test_support__/e2e/cleanup`
- Terme `__test_support__` reconnu (Rails, RSpec)
- Clairement non-métier et non-public
- Facile à blacklister
- Namespace `TestSupport::E2e::SetupController`

---

## 📁 Fichiers Modifiés/Créés

### Modèles
- `app/models/mission.rb` - Domain model pur
- `app/models/mission_company.rb` - Table de relation
- `app/models/company.rb` - Entité légale
- `app/models/user_company.rb` - Relation User-Company

### Contrôleurs
- `app/controllers/api/v1/missions_controller.rb` - CRUD complet

### Migrations
- `db/migrate/20251226_create_mission_domain.rb` - Création des tables

### Tests
- `spec/requests/api/v1/missions/missions_spec.rb` - 30 tests
- `bin/e2e/e2e_missions.sh` - 6 tests E2E
- `spec/factories/missions.rb`
- `spec/factories/companies.rb`
- `spec/factories/mission_companies.rb`
- `spec/factories/user_companies.rb`

### Configuration
- `.rubocop.yml` - Ajout AllowedIdentifiers

### E2E Infrastructure
- `app/controllers/__test_support__/e2e/setup_controller.rb` - Endpoints E2E isolés
- `bin/e2e/e2e_missions.sh` - Script de tests E2E missions

### Documentation
- `README.md` - Mise à jour
- `docs/BRIEFING.md` - Mise à jour
- `docs/BACKLOG.md` - FC-06 marqué terminé

---

## 📊 Métriques Qualité

| Métrique | Avant | Après |
|----------|-------|-------|
| Tests RSpec | 221 | 290 (+69) |
| Tests E2E | 0 | 6 |
| Fichiers RuboCop | 82 | 93 |
| Offenses RuboCop | 0 | 0 |
| Vulnérabilités Brakeman | 0 | 0 |
| Swagger specs | ~100 | 119 |

---

## 🧪 Tests E2E

### Endpoints de Support
| Endpoint | Description |
|----------|-------------|
| `POST /__test_support__/e2e/setup` | Crée contexte test (User + Company + relation) |
| `DELETE /__test_support__/e2e/cleanup` | Nettoie les données E2E |

⚠️ **Sécurité :** Ces endpoints n'existent qu'en `RAILS_ENV=test` ou `E2E_MODE=true`. Toute exposition en production est une faille critique.

### Tests Couverts (6/6)
1. ✅ Création Mission (independent) → 201
2. ✅ Accès autorisé (GET mission) → 200
3. ✅ Accès interdit (autre company) → 404
4. ✅ Lifecycle complet (lead → completed)
5. ✅ Transition invalide → 422
6. ✅ Modification post-WON → 200

### Usage
```bash
# Local
./bin/e2e/e2e_missions.sh

# Staging/CI
STAGING_URL=https://api.example.com E2E_MODE=true ./bin/e2e/e2e_missions.sh
```

---

## 🚀 Prochaines Étapes

1. **FC-07 — CRA mensuel** : Utiliser les Missions pour le suivi d'activité
2. **FC-08 — Entreprise indépendant** : Enrichir le modèle Company
3. **FC-09 — Validation CRA** : Verrouillage et conformité

---

## 📌 Notes Techniques

### Protection CRA (Placeholder)
La méthode `Mission#cra_entries?` retourne actuellement `false` (placeholder). Elle sera implémentée dans FC-07 pour vérifier les liaisons CRA effectives.

### Notifications Post-WON (Prévu)
La méthode `Mission#should_send_post_won_notification?` existe mais n'est pas encore appelée. Sera implémentée dans un FC futur avec les conditions :
- Company client liée
- Représentant client existant
- Email client présent

---

## ✅ Definition of Done

- [x] RSpec green (290 tests, 0 failures)
- [x] Swagger auto-generated (119 specs)
- [x] RuboCop OK (93 files, 0 offenses)
- [x] Brakeman OK (0 vulnerabilities)
- [x] README updated
- [x] BRIEFING.md updated
- [x] BACKLOG.md updated
- [x] Technical changelog created
- [x] E2E tests implemented (6/6 passing)
- [x] E2E endpoints renamed (Platinum compliance)
- [x] PR ready to merge
- [x] **PR #12 reviewed & approved by CTO** (1 janvier 2026)
- [x] **PR #12 MERGED** ✅

---

## 🔍 Clarifications CTO (Post-Review)

Suite à la review CTO de la PR #12, les points suivants ont été clarifiés :

### Comportement Post-WON
| Aspect | Décision |
|--------|----------|
| Modifications après `won` | ✅ Autorisées |
| Champs contractuels | Modifiables (pas de blocage technique) |
| Notifications client | Placeholder en place, implémentation future |
| Tests explicites post-won | Non requis pour MVP |

### Points d'anticipation (Backlog)
- 📌 Définir précisément les "champs contractuels" (daily_rate, fixed_price, dates, currency)
- 📌 Versionning/historisation des modifications (futur FC)
- 📌 Service de notification réel (futur FC)

### Sécurité E2E Endpoints
- ✅ Vérifié : endpoints `/__test_support__/e2e/*` n'existent pas en production
- ✅ Double protection : routes conditionnelles + `before_action :verify_e2e_mode!`

---

**Niveau atteint : 🏆 PLATINUM**  
**PR Status : ✅ MERGED (1 janvier 2026)**