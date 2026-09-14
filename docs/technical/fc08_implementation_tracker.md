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
| **Phase 1 — Préparation** | 2 | 0 | 0 | 2 | 100% |
| **Phase 2 — Model Specs (RED)** | 2 | 0 | 0 | 2 | 100% |
| **Phase 3 — Migration DB** | 1 | 0 | 0 | 1 | 100% |
| **Phase 4 — Model Implementation (GREEN)** | 2 | 0 | 0 | 2 | 100% |
| **Phase 5 — Request Specs (RED)** | 2 | 0 | 0 | 2 | 100% |
| **Phase 6 — Controllers/Services (GREEN)** | 2 | 0 | 0 | 2 | 100% |
| **Phase 7 — RSwag** | 1 | 1 | 0 | 0 | 0% |
| **Phase 8 — Quality Gates** | 4 | 4 | 0 | 0 | 0% |
| **Phase 9 — Régression** | 2 | 2 | 0 | 0 | 0% |
| **Phase 10 — PR** | 1 | 1 | 0 | 0 | 0% |
| **Total** | **19** | **8** | **0** | **11** | **58%** |

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
| P2.2 | UserCompany model specs — RED | ✅ | 25 exemples, 11 échecs attendus (RED confirmé 14/09/2026) : unicité (user, company, role), soft deletion, scopes .active/.deleted, pas de résurrection implicite §27. Factory :user_company alignée sur convention user_cras (associations créées, rôle déterministe + traits) |

### Phase 3 — Migration DB

| ID | Tâche | Statut | Migration |
|---|---|---|---|
| P3.1 | Créer migration FC-08 | ✅ | Migration `20260914000001_fc08_company_user_company_contract.rb` appliquée en test : siren NOT NULL + UNIQUE (index remplacé), siret nullable (unique conservé), vat_regime string nullable, user_companies.deleted_at, enum conservé, garde-fou données §47.1 + down complet |

### Phase 4 — Model Implementation (GREEN)

| ID | Tâche | Statut | Implémentation |
|---|---|---|---|
| P4.1 | Company model — GREEN | ✅ | GREEN 27/27 le 14/09/2026 : siren presence+uniqueness+format, siret allow_nil (format+uniqueness conservés), scope .deleted (remplace only_deleted, cf. contrat §29), display_name nil-safe avec fallback siren |
| P4.2 | UserCompany model — GREEN | ✅ | GREEN 25/25 le 14/09/2026 : unicité (user_id, company_id, role) INV-18, discard/undiscard/discarded? §27, scopes .active/.deleted, doc contrat |

### Phase 5 — Request Specs (RED)

| ID | Tâche | Statut | Specs à écrire |
|---|---|---|---|
| P5.1 | Company request specs — RED | ✅ | 19 exemples RED confirmés 14/09/2026 (routes ajoutées, contrôleurs absents) : list/atomic create/independent+client/invalid+duplicate SIREN/SIRET absent+duplicate/atomicité/flat JSON/show/patch/soft delete/cross-user 403/404 |
| P5.2 | UserCompany request specs — RED | ✅ | 13 exemples RED confirmés 14/09/2026 : list own/POST add role/duplicate role/invalid role/user_id ignoré (§42)/show/PATCH role only + attributs protégés ignorés/DELETE soft delete/cross-user 403/401 |

### Phase 6 — Controllers/Services (GREEN)

| ID | Tâche | Statut | Implémentation |
|---|---|---|---|
| P6.1 | CompaniesController — GREEN | ✅ | GREEN 32/32 (avec P6.2) le 14/09/2026 : wrap_parameters §40 (role exclu, INV-22), paramètres forts §42, autorisation UserCompany.active §43, onboarding atomique CompanyServices::Create (INV-16/17), erreurs standardisées plates §44, soft delete |
| P6.2 | UserCompaniesController — GREEN | ✅ | GREEN 32/32 (avec P6.1) le 14/09/2026 : CRUD, PATCH role only (user_id/company_id/deleted_at structurellement ignorés), autorisation propriétaire, user_id forcé à l'utilisateur courant (§42), soft delete |

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

### 2026-09-14 — [P4.1] Company model — GREEN

- **Étape TDD :** GREEN
- **Fichiers modifiés :** app/models/company.rb
- **Tests :** 27 exemples, 0 échec (spec/models/company_spec.rb)
- **Commit :** feat(fc08): P4.1 Company model GREEN (SIREN requis+unique, SIRET optionnel, scope .deleted)

### 2026-09-14 — [P2.2] UserCompany model specs — RED

- **Étape TDD :** RED (Step 6 du §63)
- **Fichiers modifiés :** spec/models/user_company_spec.rb, spec/factories/user_companies.rb
- **Tests :** 25 exemples, 11 échecs attendus (unicité (user, company, role), soft deletion, scopes .active/.deleted, pas de résurrection implicite §27). Correctif factory : associations créées (convention user_cras) + rôle déterministe + traits independent/client. Rôle invalide rejeté à l'affectation (enum strict, §25) — pin de comportement
- **Commit :** test(fc08): P2.2 RED UserCompany model specs

### 2026-09-14 — [P4.2] UserCompany model — GREEN

- **Étape TDD :** GREEN (Step 7 du §63)
- **Fichiers modifiés :** app/models/user_company.rb
- **Tests :** 25 exemples, 0 échec. Régression précoce missions/CRA + specs FC-08 : 144 exemples, 0 échec
- **Commit :** feat(fc08): P4.2 UserCompany model GREEN (unicite user+company+role, soft delete, scopes)

### 2026-09-14 — [P5.1 + P5.2] Request specs — RED

- **Étape TDD :** RED (Step 8 du §63)
- **Fichiers modifiés :** spec/requests/api/v1/companies/companies_spec.rb (19 ex), spec/requests/api/v1/user_companies/user_companies_spec.rb (13 ex), config/routes.rb (resources companies + user_companies)
- **Tests :** 32 exemples, 32 échecs (contrôleurs absents) — conventions maison : DSL RSwag, AuthenticationService.login, erreurs standardisées (codes UPPER_SNAKE), DELETE → 200
- **Commit :** test(fc08): P5 request specs RED (companies + user_companies) + routes

### 2026-09-14 — [P6.1 + P6.2] Controllers/Services — GREEN

- **Étape TDD :** GREEN (Step 9 du §63)
- **Fichiers modifiés :** app/services/company_services.rb (namespace Zeitwerk, pattern cra_services.rb), app/services/company_services/create.rb (onboarding atomique), app/controllers/api/v1/companies_controller.rb, app/controllers/api/v1/user_companies_controller.rb
- **Tests :** 32 request specs GREEN (19+13). Régression globale : 948 exemples, 2 échecs — spec d'audit p4_6 épingle .only_deleted sur Company, mise à jour vers .deleted (contrat FC-08 §29) → 20/20 vert
- **Décision :** erreurs standardisées plates {code, message, details} (§44, format render_error existant) ; rôle invalide → 422
- **Commit :** feat(fc08): P6 contrôleurs + services GREEN (onboarding atomique, autorisation, soft delete)

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