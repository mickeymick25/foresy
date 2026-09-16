# 📋 Plan de Suivi — Implémentation FC-08 v3.2.3

**Date de création :** 30 août 2026
**Feature Contract :** FC-08 v3.2.3 — Company & User-Company Relationships
**Statut :** 🟢 Terminé et MERGÉ — 19/19 tâches, PR #24 mergée le 15/09/2026
**Branche :** `feature/fc-08-companies`
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
| **Phase 7 — RSwag** | 1 | 0 | 0 | 1 | 100% |
| **Phase 8 — Quality Gates** | 4 | 0 | 0 | 4 | 100% |
| **Phase 9 — Régression** | 2 | 0 | 0 | 2 | 100% |
| **Phase 10 — PR** | 1 | 0 | 0 | 1 | 100% |
| **Total** | **19** | **0** | **0** | **19** | **100%** |

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
| P7.1 | RSwag — générer Swagger depuis request specs | ✅ | 14/09/2026 : 10 schémas centralisés FC-08 (companyOnboardingRequest, companyCreate/UpdateRequest, companyResponse, companyListResponse, userCompanyCreate/UpdateRequest, userCompanyResponse/ListResponse, ErrorStandardized plat §44) ajoutés à swagger_helper ; yaml régénéré (402 ex, 0 échec) ; audit routes↔swagger PASSÉ (pattern patch :update, on: :member repris de missions pour éliminer les routes PUT) |

### Phase 8 — Quality Gates

| ID | Tâche | Statut | Commande |
|---|---|---|---|
| P8.1 | RuboCop | ✅ | `bundle exec rubocop` — 234 fichiers, 0 offense (14/09/2026) |
| P8.2 | Brakeman | ✅ | 0 warning introduit par FC-08. 2 warnings Command Injection PRÉEXISTANTS dans GitLedgerRepository (code CRA hors périmètre, commits 10680ec2/a0ea0f97, entrée d'ignore obsolète antérieure) — documentés per contract §63 step 12 « explicitly document » |
| P8.3 | RSpec full suite | ✅ | `bundle exec rspec` — 948 exemples, 0 échec |
| P8.4 | RSwag suite | ✅ | Adaptation notée : pas de tag :swagger dans le projet — équivalent exécuté = `rake rswag:specs:swaggerize` (402 ex, 0 échec) + `rake swagger:audit_coverage` (PASSÉ, 35/35 routes — re-vérifié 14/09/2026 lors de la vérification d'implémentation) |

### Phase 9 — Régression

| ID | Tâche | Statut | Vérification |
|---|---|---|---|
| P9.1 | FC-06 regression | ✅ | 21 exemples, 0 échec (14/09/2026) |
| P9.2 | FC-07 regression | ✅ | 158 exemples, 0 échec (14/09/2026) |

### Phase 10 — PR

| ID | Tâche | Statut | Action |
|---|---|---|---|
| P10.1 | Pull Request | ✅ | PR #24 **MERGÉE** le 15/09/2026 (main `059bbfb5..d57cff40`) : https://github.com/mickeymick25/foresy/pull/24 — description au format maison, evidence de tests, DoD 9/9, CI 6/6 verts |

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

### 2026-09-14 — [P7 + P8 + P9] RSwag, Quality Gates, Régression

- **Étape TDD :** Documentation + gates (Steps 10-14 du §63)
- **Fichiers modifiés :** spec/swagger_helper.rb (10 schémas FC-08 + ErrorStandardized), config/routes.rb (patch member pour audit), specs request (schema refs), corrections RuboCop (spec/models, spec/factories)
- **Tests :** swaggerize 402/0 ; audit routes↔swagger PASSÉ ; rubocop 0 offense ; rspec full 948/0 ; FC-06 21/0 ; FC-07 158/0 ; brakeman 2 warnings préexistants hors périmètre (documentés)
- **Décision :** P8.4 adapté — pas de tag :swagger dans la maison, équivalent swaggerize + audit_coverage
- **Commit :** chore(fc08): P7-P9 swagger + quality gates + régression

### 2026-09-14 — [E2E] Tests de bout en bout FC-08

- **Fichiers modifiés :** bin/e2e/e2e_companies.sh (NOUVEAU — 17 étapes, 19 assertions), bin/e2e/e2e_cra_lifecycle.sh (payload company migré vers onboarding atomique FC-08 §38 + compat macOS : sed au lieu de head -n -1, set -e retiré car make_request retourne le code HTTP comme statut)
- **Tests :** e2e_companies.sh 19/19 PASSED en HTTP réel contre le serveur de dev (scénarios Gherkin 1, 2, 3, 5, 6, 8, 9, 10, 12, 13, 14, 15)
- **Dette notée :** e2e_cra_lifecycle.sh et e2e_auth_flow.sh ont des bugs latents préexistants (return HTTP > 255 tronqué, parse d'environnement) qui les rendaient inexécutables même avant FC-08 — réparation complète hors périmètre FC-08
- **Commit :** test(fc08): E2E companies (19/19 HTTP réel) + compat scripts hérités

### 2026-09-14 — [P10.1] Pull Request #24 ouverte

- **URL :** https://github.com/mickeymick25/foresy/pull/24
- **Description :** `docs/technical/changes/2026-09-14-FC08_Companies_PR_Description.md` (résumé, evidence de tests, 18 commits, DoD 9/9, points d'attention revue)
- **Commit :** docs(fc08): description de PR (P10.1) au format maison

### 2026-09-15 — [Gate CTO] Revue pre-merge PR #24 (A/B/C)

- **Gate A — Invariants :** spec d'architecture ajouté (`spec/models/fc08_architecture_invariants_spec.rb`, 7/7) : INV-01/02/03/04/06 épinglés par tests → 21/22 invariants testés, INV-15 justifié (aucun code de simulation dans `app/` — vérifié). Commits `ff73a65e` + `7262d92c` (newline RuboCop)
- **Gate B — CI :** 4 jobs rouges investigués sur 3 runs. RuboCop = offense newline (corrigée). Security Audit = CVE rubyzip (D-9, préexistante). E2E = signup 500 préexistant (D-8). Quality Gate = agrégat. Fausse alerte intermédiaire : 28 échecs causés par la pollution E2E de la base dev (D-10) — base nettoyée → **955/955 vert** ; la CI (base test propre) l'avait confirmé (Tests & Coverage SUCCESS)
- **Gate C — Diff :** 111 fichiers = ~22 code FC-08 + 89 docs, dont ~79 du commit de réorg `b7f3cb0e` (réalisé sur main avant la branche ; main jamais poussé — il voyage donc dans la PR). Expliqué au CTO
- **Décision (discipline one feature = one contract) :** D-8/D-9/D-10 documentés au registre de dette avec plan d'action CI Gate (§5) — correctifs en commits séparés sur accord CTO, pas dans le périmètre FC-08
- **Commit :** docs(fc08): gate CTO — dette D-8/D-9/D-10 + plan d'action CI

### 2026-09-15 — [CI Gate] D-9 + D-8 corrigés (2 jobs débloqués)

- **D-9** : `bundle update rubyzip` 3.2.2 → 3.6.0 — `bundle-audit check --update` → 0 vulnérabilité ; suite 955/0. Commit `17943769`
- **D-8** : mécanisme confirmé dans le code source Rails (`rescuable.rb` : « the most recently declared is the highest priority match ») — `StandardError` déclaré en dernier dans `StandardizedError` avalait les handlers spécifiques. Fix : `StandardError` déclaré en premier. TDD : RED spec (`signup {}` → 400, commité dans `users_spec.rb`) → GREEN. Suite 956/0 (contrat p1_2 : générique → 500, préservé) ; smoke 15/15. Commit `19b9c16c`
- **RAG d'abord** : le plan D-8 a été corrigé après requête hub (`guides/error_contract.md` = contrat officiel ParameterMissing → 400 ; P1.2 = historique du bloc temporaire, piste distincte)
- **Statut plan §5 :** étapes 1-2 ✅ — reste D-10 (isolement) + gate finale (6 checks verts)

### 2026-09-15 — [Dette D-5] Brakeman GitLedger — RÉSOLUE

- **Durcissement :** garde `SAFE_ID_PATTERN` (alnum/-/_ max 64) sur cra_id dans `GitLedgerRepository` — un ID malveillant court-circuite sans invoquer Git (contrat renforcé vs simple argv-array)
- **Specs :** `git_ledger_integration_spec.rb` 13/0 (contrats d'erreur préservés : false/nil gracieux) ; `p6_1_git_ledger_security_spec.rb` mis à jour vers le contrat renforcé (malveillant → 0 invocation Git ; ID valide → argv array) — 23/0
- **Brakeman :** `config/brakeman.ignore` régénéré (2 fingerprints D-5 ignorés avec justification FALSE POSITIVE, entrée obsolète `ed1fa52b` supprimée) → **0 warning**
- **Suite :** 957/0 (sur `foresy_test`)
- **Commit :** fix: D-5 durcissement GitLedger + ignore Brakeman régénéré

### 2026-09-15 — [Dette D-4] Scripts E2E hérités — RÉSOLUE

- **Branche :** `chore/d4-e2e-scripts-repair` (process : branche dédiée + PR, fin des pushes directs sur main)
- **e2e_cra_lifecycle.sh — 4 corrections structurelles :** (1) pattern `run_request`/`HTTP_CODE`/`HTTP_BODY` — le return-code historique tronquait les codes > 255 (422→166, 500→244, 409→153) ; (2) `"month": $(date +%m)` = JSON invalide (`09`, zéro non significatif) → `%-m` — cause racine du 500 « parsing request parameters » ; (3) comparaisons flottantes (l'API renvoie `30000.0`, awk `float_eq`) ; (4) code mort nettoyé (`X_response` captures vides, user_id inexistant dans la réponse signup)
- **Audit intégral préalable :** le fichier a été relu ligne à ligne après conversion (15 sites, aucun risque de staleness HTTP_BODY)
- **e2e_auth_flow.sh :** conforme en l'état (curl direct, pas de return-code) — vérifié PASSED
- **Rejeux :** cra PASSED ×3, auth PASSED ×2 — déterminisme prouvé
- **Commit :** fix: D-4 réparation scripts E2E hérités

### 2026-09-15 — [Dette D-10] Isolement bases test/dev — RÉSOLUE

- **Fix :** `foresy_test` créée dans le conteneur (`DATABASE_URL` sur le service `db` + `bin/rails db:prepare`) ; piège documenté (retirer DATABASE_URL vise localhost → Postgres injoignable depuis le conteneur)
- **Validation :** suite 956/0 sur `foresy_test` ; rejeu E2E ×2 (dev re-polluée : 6 companies) puis suite sur `foresy_test` — toujours 956/0 → isolement prouvé
- **Documentation :** `docs/technical/testing/test_database_isolation.md`
- **Commit :** chore: D-10 isolement bases test/dev

### 2026-09-14 — [E2E] Correction rejouabilité e2e_companies.sh (vérification implémentation)

- **Constat :** re-vérification de l'implémentation FC-08 : `e2e_companies.sh` utilisait des SIREN/SIRET en dur (123456789, etc.) ; les données E2E persistent en base dev et FC-08 applique UNIQUE(siren)/UNIQUE(siret) (INV-09/12) — toute rejouée échouait en 422 « Siren has already been taken » (comportement FC-08 correct, script non rejouable)
- **Fichiers modifiés :** bin/e2e/e2e_companies.sh — identifiants dérivés du RUN_ID (timestamp, cohérent avec les emails) : TEST_SIREN/TEST_SIRET, CLIENT_SIREN, NO_SIRET_SIREN, ORPHAN_SIREN ; l'étape 12 (Scenario 9) réutilise volontairement TEST_SIREN comme doublon de l'étape 3
- **Tests :** 2 exécutions consécutives 19/19 PASSED en HTTP réel contre le serveur de dev — rejouabilité prouvée ; scénarios Gherkin couverts inchangés (1, 2, 3, 5, 6, 8, 9, 10, 12, 13, 14, 15)
- **Commit :** à inclure dans la PR (P10.1)

### 2026-09-16 — [Vérification] Dette D-1→D-11 — niveau platinium

- **Périmètre :** toute la dette du registre, depuis D-1 (D-4 incluse) — branche `chore/d4-e2e-scripts-repair` (HEAD `1de4d154`)
- **Méthode :** revue du contrat/registre/journal + revue de code + exécutions réelles (suite, specs ciblées, RuboCop, Brakeman, bundle-audit, smoke, E2E rejoués ×2) + requêtes hub RAG (`foresy__knowledge`/`foresy__memories` via proxy MCP documenté — outils `chroma_*` non attachés à la session) + API GitHub
- **Résultats :** suite 957/0 (`foresy_test`), Brakeman 0 warning (3 ignorés justifiés), bundle-audit 0 vuln, smoke 15/15, e2e_cra ×2 PASSED, e2e_auth ×2 PASSED, specs ciblées 7/0 + 13/0 + 10/0 + 4/0
- **Conformes platinium :** D-1 (spec invariants), D-8 (TDD + RAG d'abord), D-9, D-10 ; conformes à leur déclaration (ouvertes) : D-2, D-6, D-7, D-11 ; D-3 résolue (v0.1.1)
- **Anomalies :** A1 RuboCop cassé par D-5 (2 offenses L92 `SAFE_ID_PATTERN` — `Lint/UselessConstantScoping`, `Style/RedundantFreeze`) ; A2 PR D-4 non ouverte (branche poussée) ; A3 commentaire obsolète e2e_cra L23-24 (`make_request`) ; A4 journal D-5 « p6_1 23/0 » (réel 10/0, 23 = somme 13+10) ; A5 memory-indexer en attente (hub `fc08::006` périmée, pré-D-4) ; A6 identité Git conteneur `foresy-ledger` (traçabilité humaine) ; annexe hub : `e2e_mcp_test.py` `anyio.run(main())` → `anyio.run(main)`
- **Rapport complet :** `docs/technical/changes/2026-09-16-D1-D11_Debt_Verification_Report.md`
- **Décision :** correctifs étiquetés proposés sur accord (`style(d5)`, `docs(d4)`, PR D-4) — mémoire `fc08::007` proposée, validation humaine en attente
- **Commit :** à valider (workflow mémoire : l'agent propose, l'humain valide, Git trace, puis memory-indexer)

---

## 🔗 Références

- [FC-08 v3.2.3](../FeatureContract/08_Feature%20Contract%20—%20Entreprise%20Indépendant_%5B3.2.3%5D)
- [TDD Implementation Order](../FeatureContract/08_Feature%20Contract%20—%20Entreprise%20Indépendant_%5B3.2.3%5D) — Section 63
- [Invariants](../FeatureContract/08_Feature%20Contract%20—%20Entreprise%20Indépendant_%5B3.2.3%5D) — INV-01 à INV-22
- [Gherkin Scenarios](../FeatureContract/08_Feature%20Contract%20—%20Entreprise%20Indépendant_%5B3.2.3%5D) — Section 55

---

## ✅ Definition of Done Checklist

- [x] Architecture : Company sans user_id, User sans company_id, UserCompany explicite, RDD respecté, no default_scope (INV-01/02/03/20, tests spec/models)
- [x] Database : UUID PK retenus, SIREN NOT NULL + UNIQUE, SIRET nullable + unique, vat_regime ajouté, UserCompany.deleted_at ajouté, enum conservé, (user_id, company_id, role) unique (migration 20260914000001 + schema.rb)
- [x] Models : Validations Company + UserCompany, scopes actifs, pas de default_scope (27/27 + 25/25)
- [x] API : Company CRUD + UserCompany CRUD, atomicité, PATCH role only, authorization, standardized errors, wrap_parameters (32/32)
- [x] TDD : Model specs RED first (9+11 échecs attendus mesurés), request specs RED first (32 échecs mesurés), edge cases, atomicité, authorization
- [x] RSwag : Tous endpoints documentés (10 schémas centralisés), yaml régénéré depuis specs, audit routes PASSÉ
- [x] Quality : RSpec 948/948, RSwag swaggerize 402/402, RuboCop 0 offense, Brakeman 0 warning FC-08 (2 préexistants hors périmètre, documentés)
- [x] Regression : FC-06 21/21, FC-07 158/158, pas de breaking change (audit p4_6 mis à jour vers .deleted conformément au contrat §29)
- [x] Git : Feature branch, commits atomiques RED/GREEN, 1 PR à ouvrir (description ci-dessous), evidence de tests

---

**Document créé le :** 30 août 2026
**Propriétaire :** Équipe technique Foresy