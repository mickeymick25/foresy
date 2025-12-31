# FC-06 Missions Implementation

**Date:** 31 décembre 2025  
**Feature Contract:** 06 — Mission Management  
**Status:** ✅ TERMINÉ — Platinum Level  
**Author:** Co-CTO

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
- `spec/factories/missions.rb`
- `spec/factories/companies.rb`
- `spec/factories/mission_companies.rb`
- `spec/factories/user_companies.rb`

### Configuration
- `.rubocop.yml` - Ajout AllowedIdentifiers

### Documentation
- `README.md` - Mise à jour
- `docs/BRIEFING.md` - Mise à jour
- `docs/BACKLOG.md` - FC-06 marqué terminé

---

## 📊 Métriques Qualité

| Métrique | Avant | Après |
|----------|-------|-------|
| Tests RSpec | 221 | 290 (+69) |
| Fichiers RuboCop | 82 | 93 |
| Offenses RuboCop | 0 | 0 |
| Vulnérabilités Brakeman | 0 | 0 |
| Swagger specs | ~100 | 119 |

---

## 🚀 Prochaines Étapes

1. **FC-07 — CRA mensuel** : Utiliser les Missions pour le suivi d'activité
2. **FC-08 — Entreprise indépendant** : Enrichir le modèle Company
3. **FC-09 — Validation CRA** : Verrouillage et conformité

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
- [x] PR ready to merge

---

**Niveau atteint : 🏆 PLATINUM**