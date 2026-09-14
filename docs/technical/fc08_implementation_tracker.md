# 📋 Plan de Suivi — Implémentation FC-08 v3.2.3

**Date de création :** 30 août 2026
**Feature Contract :** FC-08 v3.2.3 — Company & User-Company Relationships
**Statut :** 🟡 En cours
**Branche :** `feature/fc-08-companies` (à créer)
**Référence :** `docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]`

---

## 📊 Vue d'Ensemble

| Phase | Tâches | ⬜ À faire | 🟡 En cours | ✅ Terminé | % Avancement |
|---|---|---|---|---|---|
| **Phase 1 — Préparation** | 2 | 2 | 0 | 0 | 0% |
| **Phase 2 — Model Specs (RED)** | 2 | 2 | 0 | 0 | 0% |
| **Phase 3 — Migration DB** | 1 | 1 | 0 | 0 | 0% |
| **Phase 4 — Model Implementation (GREEN)** | 2 | 2 | 0 | 0 | 0% |
| **Phase 5 — Request Specs (RED)** | 2 | 2 | 0 | 0 | 0% |
| **Phase 6 — Controllers/Services (GREEN)** | 2 | 2 | 0 | 0 | 0% |
| **Phase 7 — RSwag** | 1 | 1 | 0 | 0 | 0% |
| **Phase 8 — Quality Gates** | 4 | 4 | 0 | 0 | 0% |
| **Phase 9 — Régression** | 2 | 2 | 0 | 0 | 0% |
| **Phase 10 — PR** | 1 | 1 | 0 | 0 | 0% |
| **Total** | **19** | **19** | **0** | **0** | **0%** |

---

## 📋 Tâches Détaillées

### Phase 1 — Préparation

| ID | Tâche | Statut | Notes |
|---|---|---|---|
| P1.1 | Contract Freeze — confirmer FC-08 v3.2.3 figé | ✅ | Validé par review architecte. Gel acté le 14/09/2026 : statut Implementation-Ready / TDD-Ready, versions 3.0→3.2.3 tracées dans le repo |
| P1.2 | Schema Verification — inspecter db/schema.rb, indexes, enums, models existants | ✅ | Constats 14/09/2026 : siren nullable + index non-unique (→ NOT NULL + UNIQUE) ; siret NOT NULL + unique (→ nullable, unique conservé) ; vat_regime absent (→ ajouter) ; user_companies.deleted_at absent (→ ajouter) ; UNIQUE(user_id, company_id, role) déjà présent ; enum user_company_role_enum = independent/client déjà conforme ; aucun contrôleur companies/user_companies ; convention maison .only_deleted (contrat exige .deleted) |

### Phase 2 — Model Specs (RED)

| ID | Tâche | Statut | Specs à écrire |
|---|---|---|---|
| P2.1 | Company model specs — RED | ✅ | 27 exemples, 9 échecs attendus (RED confirmé 14/09/2026) : SIREN requis/unique, SIRET optionnel, vat_regime, scope .deleted, contraintes DB (siren NOT NULL+UNIQUE, siret multi-NULL) |
| P2.2 | UserCompany model specs — RED | ⬜ | user association, company association, role presence, valid roles (independent/client), PostgreSQL enum, uniqueness (user_id, company_id, role), multiple roles same company, multiple companies, soft deletion, .active scope, .deleted scope, absence of default_scope |

### Phase 3 — Migration DB

| ID | Tâche | Statut | Migration |
|---|---|---|---|
| P3.1 | Créer migration FC-08 | ✅ | Migration `20260914000001_fc08_company_user_company_contract.rb` appliquée en test : siren NOT NULL + UNIQUE (index remplacé), siret nullable (unique conservé), vat_regime string nullable, user_companies.deleted_at, enum conservé, garde-fou données §47.1 + down complet |

### Phase 4 — Model Implementation (GREEN)

| ID | Tâche | Statut | Implémentation |
|---|---|---|---|
| P4.1 | Company model — GREEN | ⬜ | Validations (name, SIREN presence/format/uniqueness, SIRET format/uniqueness), scopes (.active, .deleted), pas de default_scope |
| P4.2 | UserCompany model — GREEN | ⬜ | Validations (user, company, role presence, role enum), uniqueness (user_id, company_id, role), scopes (.active, .deleted), pas de default_scope |

### Phase 5 — Request Specs (RED)

| ID | Tâche | Statut | Specs à écrire |
|---|---|---|---|
| P5.1 | Company request specs — RED | ⬜ | GET /companies (empty, with companies), POST /companies (atomic Company+UserCompany, role independent/client, invalid SIREN, duplicate SIREN, SIRET absent, duplicate SIRET, atomicity rollback), GET /companies/:id (authorized, unauthorized, not found), PATCH /companies/:id (authorized, unauthorized), DELETE /companies/:id (soft delete), flat JSON wrapping, standardized errors |
| P5.2 | UserCompany request specs — RED | ⬜ | GET /user_companies (list own), POST /user_companies (add role, duplicate role, invalid role), GET /user_companies/:id (authorized, cross-user), PATCH /user_companies/:id (role only, not user_id/company_id/deleted_at), DELETE /user_companies/:id (soft delete), authentication, authorization, cross-user access |

### Phase 6 — Controllers/Services (GREEN)

| ID | Tâche | Statut | Implémentation |
|---|---|---|---|
| P6.1 | CompaniesController — GREEN | ⬜ | wrap_parameters :company (include all Company attrs, exclude role), CRUD actions, authorization via UserCompany, atomic Company+UserCompany creation, standardized errors, CompaniesController < Api::V1::BaseController |
| P6.2 | UserCompaniesController — GREEN | ⬜ | CRUD actions, PATCH role only, authorization (own relationships only), cross-user rejection, standardized errors, UserCompaniesController < Api::V1::BaseController |

### Phase 7 — RSwag

| ID | Tâche | Statut | Description |
|---|---|---|---|
| P7.1 | RSwag — générer Swagger depuis request specs | ⬜ | Company schema, UserCompany schema, role values, request/response bodies, error responses, authentication, authorization |

### Phase 8 — Quality Gates

| ID | Tâche | Statut | Commande |
|---|---|---|---|
| P8.1 | RuboCop | ⬜ | `bundle exec rubocop` — 0 offenses |
| P8.2 | Brakeman | ⬜ | `bundle exec brakeman` — 0 warnings |
| P8.3 | RSpec full suite | ⬜ | `bundle exec rspec` — 0 failures |
| P8.4 | RSwag suite | ⬜ | `bundle exec rspec --tag swagger` — 0 failures |

### Phase 9 — Régression

| ID | Tâche | Statut | Vérification |
|---|---|---|---|
| P9.1 | FC-06 regression | ⬜ | `bundle exec rspec spec/requests/api/v1/missions spec/models/mission_lifecycle_spec.rb` — 0 failures |
| P9.2 | FC-07 regression | ⬜ | `bundle exec rspec spec/requests/api/v1/cras spec/requests/api/v1/cra_entries spec/services/cra_services` — 0 failures |

### Phase 10 — PR

| ID | Tâche | Statut | Action |
|---|---|---|---|
| P10.1 | Pull Request | ⬜ | Feature branch `feature/fc-08-companies`, PR vers main, description avec tests evidence, Definition of Done checklist |

---

## 📝 Journal d'Exécution (TDD)

### 2026-09-14 — [P1.1] Contract Freeze

- **Étape TDD :** N/A (préparation)
- **Fichiers modifiés :** docs/technical/fc08_implementation_tracker.md
- **Tests :** N/A
- **Commit :** cf. historique branche feature/fc-08-companies

### 2026-09-14 — [P1.2] Schema Verification

- **Étape TDD :** N/A (préparation)
- **Fichiers modifiés :** docs/technical/fc08_implementation_tracker.md
- **Tests :** N/A — inspection db/schema.rb, db/migrate/20260101000000_initial_schema.rb, app/models/company.rb, app/models/user_company.rb
- **Commit :** docs(fc08): P1.1-P1.2 gel contrat v3.2.3 + verification schema

### 2026-09-14 — [P2.1] Company model specs — RED

- **Étape TDD :** RED
- **Fichiers modifiés :** spec/models/company_spec.rb
- **Tests :** 27 exemples, 9 échecs attendus (SIREN requis/unique, SIRET optionnel, vat_regime storage+nullable, scope .deleted, UNIQUE(siren) DB, siren NOT NULL DB, siret multi-NULL DB)
- **Commit :** test(fc08): P2.1 RED Company model specs

### 2026-09-14 — [P3.1] Migration DB

- **Étape TDD :** Migration (Step 4 du §63)
- **Fichiers modifiés :** db/migrate/20260914000001_fc08_company_user_company_contract.rb
- **Tests :** 2 contraintes DB désormais GREEN (siren NOT NULL, UNIQUE siren) ; 5 RED restants (4 model-level + siret multi-NULL dépendant du retrait de la présence SIRET en P4.1)
- **Commit :** db(fc08): P3.1 migration contrat Company/UserCompany

---

## 🔗 Références

- [FC-08 v3.2.3](../FeatureContract/08_Feature%20Contract%20—%20Entreprise%20Indépendant_%5B3.2.3%5D)
- [TDD Implementation Order](../FeatureContract/08_Feature%20Contract%20—%20Entreprise%20Indépendant_%5B3.2.3%5D) — Section 63
- [Invariants](../FeatureContract/08_Feature%20Contract%20—%20Entreprise%20Indépendant_%5B3.2.3%5D) — INV-01 à INV-22
- [Gherkin Scenarios](../FeatureContract/08_Feature%20Contract%20—%20Entreprise%20Indépendant_%5B3.2.3%5D) — Section 55

---

## ✅ Definition of Done Checklist

- [ ] Architecture : Company sans user_id, User sans company_id, UserCompany explicite, RDD respecté, no default_scope
- [ ] Database : UUID PK retenus, SIREN NOT NULL + UNIQUE, SIRET nullable + unique, vat_regime ajouté, UserCompany.deleted_at ajouté, enum conservé, (user_id, company_id, role) unique
- [ ] Models : Validations Company + UserCompany, scopes actifs, pas de default_scope
- [ ] API : Company CRUD + UserCompany CRUD, atomicité, PATCH role only, authorization, standardized errors, wrap_parameters
- [ ] TDD : Model specs RED first, request specs RED first, edge cases testés, atomicité testée, authorization testée
- [ ] RSwag : Tous endpoints documentés, schémas depuis specs, exemples inclus
- [ ] Quality : RSpec 0 failures, RSwag 0 failures, RuboCop 0 offenses, Brakeman 0 warnings
- [ ] Regression : FC-06 green, FC-07 green, pas de breaking change
- [ ] Git : Feature branch, commits propres, 1 PR, evidence de tests

---

**Document créé le :** 30 août 2026
**Propriétaire :** Équipe technique Foresy