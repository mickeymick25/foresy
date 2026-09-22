# Suivi — Hygiène documentaire (pré-travail W2-D2)

**Date :** 20 septembre 2026
**Décision CTO :** GO pré-travail (20/09) — audit branches + préfixage daté de `docs/technical/` + marqueur `[DONE]` vérifié par tests — **avant implémentation W2-D2**
**Périmètre :** 148 documents sous `docs/technical/` · branches git du projet
**État de base :** `main` @ `025b90b2` (PR #36) — W2-D2 (GO 20/09) **gated** sur ce pré-travail

---

## 1. Conventions proposées (à valider CTO avant exécution)

| # | Convention | Proposition | Point d'arbitrage |
|---|---|---|---|
| C1 | Préfixe date | `YYYY_MM_DD_<nom>.md` (format demandé par le CTO, ex. `[DONE]_2026_09_20_p6_wave2_tracker.md`) — appliqué à **tous** les docs, y compris normalisation des 86 déjà datés en `YYYY-MM-DD-` (précédent documenté BRIEFING/index.md : format `YYYY-MM-DD-`) | Séparateur `_` (instruction du 20/09) vs `-` (standard maison existant) — recommandation : **uniformiser en `YYYY_MM_DD_`**, un seul passage mécanique, références corrigées dans le même cycle |
| C2 | Marqueur clôturé | `[DONE]_` en tête : `[DONE]_YYYY_MM_DD_<nom>.md` — uniquement si implémentation **réellement vérifiée** (base de preuve au §3) | Précédent existant : répertoire `[DONE]_remediation/` (casse `[Done]`) — recommandation : normaliser en `[DONE]_` partout (répertoire inclus) |
| C3 | Docs vivants | Guides et registres actifs : préfixe date **sans** `[DONE]` | — |
| C4 | Sources de date | (a) date du nom existant · (b) `git log --follow --diff-filter=A` (62 docs, scripts `tmp/`) · (c) date de création connue (docs du jour) | Les dates sont conservées même si le contenu a été mis à jour après (date = création) |

## 2. Audit des branches git — suivi

| Branche | État vérifié (20/09) | Décision | Suivi |
|---|---|---|---|
| `feat/p6-wave1` (local + origin) | **Mergée** (PR #35 → main) | **Clôturée localement le 20/09** (`git branch -d`, était @ `b51347f9`) ; suppression origin = action GitHub humaine | ✅ FAIT |
| `chore/p61-coverage-lock` (local + origin) | **Mergée** (PR #34, base verrou 72,0) | **Clôturée localement le 20/09** (`git branch -d`, était @ `4c7dce6b`) ; suppression origin = action GitHub humaine | ✅ FAIT |
| `chore/p6-w1-reevaluation-cleanup` (local + origin) | **Mergée** (PR #36, main @ `025b90b2`) | **Clôturée localement le 20/09** (`git branch -d`, était @ `7f7bce2e`) ; suppression origin = action GitHub humaine | ✅ FAIT |
| `chore/p6-coverage-plan` (local + origin, 2 commits hors main : `b5960bef` + `b0375c75`) | **Ouverte, non mergée** — contient l'analyse exhaustive des manques de couverture (67/78 fichiers) + versionnement de `scripts/coverage_gap_analysis.rb` (**absent de main**) | **Tranche CTO 20/09** : absorber dans P1 **uniquement si** l'audit P1 confirme que le script sert au mécanisme de détection testé — sinon fermeture. **Ne pas supprimer avant cette vérification** | ⏳ TODO (audit P1 requis) |
| `main` | `025b90b2`, synchronisée origin, arbre propre (rspec.xml artefact non tracké) | — | ✅ OK |

Note : les suppressions de branches distantes nécessitent une authentification GitHub (action humaine ou commande `git push origin --delete` non exécutable côté agent sans accès authentifié) ; les branches locales mergées sont supprimables sur GO.

## 3. Cartographie des renames — `docs/technical/` (148 documents)

**Inventaire source :** find_path complet (3 pages) + dates : nom de fichier (86 docs déjà datés) / `git --follow --diff-filter=A` (62 docs) / date de session ([DONE]_2026_09_20_p6_wave2_tracker, non commité). Script reproductible : `tmp/doc_creation_dates.rb` (+ variante remediation).

**Exécution 20/09 (C1+C2+C3 GO) : E1 + E2 appliqués à l'ensemble — 148 docs migrés + 1 déjà conforme ; les statuts TODO ci-dessous sont historiques (état de planification), le journal §5 fait foi.**

### 3.1 `changes/` (42) — règle par défaut : `[DONE]` (historique de travail livré, suites vertes documentées à l'époque)

| Document | Date | [DONE] | Suivi |
|---|---|---|---|
| 2025-12-18-CI_Fix_Resolution | 2025-12-18 | ✅ | ⏳ TODO |
| 2025-12-18-GoogleOauthService_Fix_Resolution | 2025-12-18 | ✅ (supersédé 21/12) | ⏳ TODO |
| 2025-12-18-OAuthTokenService_Comment_Fix | 2025-12-18 | ✅ | ⏳ TODO |
| 2025-12-19-* (8 : Authenticatable_Cleanup, Authentication_Concerns_Fix, CI_Security_Fixes_Secrets_PostgreSQL, JWT_Robustness_Improvements_Complete, OAuth_Architecture_Fix, Rswag_OAuth_Specs_Feature_Contract, Security_CI_Complete_Fix, Zeitwerk_OAuth_Services_Rename) | 2025-12-19 | ✅ | ⏳ TODO |
| 2025-12-20-* (9 : Authenticatable_Concern_Refactoring, Autoload_Cleanup, Bootsnap_Reactivation, Brakeman_Ignore_Config_Fix, Debug_Logging_Cleanup, Migrations_Consolidation, Rails_Migration_Task_Planning, Security_Gems_Update, UUID_Migration) | 2025-12-20 | ✅ (migration Rails exécutée 26/12) | ⏳ TODO |
| 2025-12-21-GoogleOAuth2Service_Removal_Resolution, 2025-12-21-PGCrypto_Compatibility_Fix | 2025-12-21 | ✅ | ⏳ TODO |
| 2025-12-22-Datadog_APM_Standardization_Resolution | 2025-12-22 | ✅ | ⏳ TODO |
| 2025-12-23-* (5 : APM_Service_Tests_Fix, CI_Rubocop_Standards, Docker_Build_Health_Check, OAuth_Services_Elegant_Solution, OmniAuth_Session_Middleware_Fix) | 2025-12-23 | ✅ | ⏳ TODO |
| 2025-12-24-Production_Errors_500_Fix | 2025-12-24 | ✅ | ⏳ TODO |
| 2025-12-25-Rails_8_1_1_Migration_Plan | 2025-12-25 | ✅ | ⏳ TODO |
| 2025-12-26-E2E_Revocation_Script, 2025-12-26-Rails_8_1_1_Migration_Complete | 2025-12-26 | ✅ | ⏳ TODO |
| 2025-12-28-FC05_Rate_Limiting_PR_Description | 2025-12-28 | ✅ (PR FC-05 mergée) | ⏳ TODO |
| 2025-12-31-FC06_Missions_Implementation | 2025-12-31 | ✅ (PR #12) | ⏳ TODO |
| 2026-01-03-Concerns_Architecture_Refactoring, 2026-01-03-FC07_CRA_Implementation | 2026-01-03 | ✅ | ⏳ TODO |
| 2026-01-07-FC07_Mini-FC-02_CSV_Export | 2026-01-07 | ✅ | ⏳ TODO |
| 2026-01-07-Legacy_Cleanup_Plan | 2026-01-07 | ✅ (exécuté P6.1-bis PR #34 + Wave 1) | ⏳ TODO |
| 2026-09-14-FC08_Companies_PR_Description | 2026-09-14 | ✅ (PR #24) | ⏳ TODO |
| 2026-09-16-D1-D11_Debt_Verification_Report, 2026-09-16-D2_SimpleCov_Chiffrage, 2026-09-16-D4_PR_Description | 2026-09-16 | ✅ (PR #25-#29) | ⏳ TODO |
| 2026-09-17-D12_LEDGER_PATH_Chiffrage | 2026-09-17 | ❌ **D-12 ouverte** (E2E shell CI — registre) | ⏳ TODO |
| 2026-09-17-P61_Coverage_Lock_PR_Description | 2026-09-17 | ✅ (PR #34) | ⏳ TODO |
| 2026-09-19-P6_Wave1_PR_Description | 2026-09-19 | ✅ (PR #35) | ⏳ TODO |
| README.md | 2025-12-18 (git) | ❌ (index vivant) | ⏳ TODO |

Base de vérification `[DONE]` changes/ : statut de complétion porté par chaque doc + jalons suites vertes documentés (BRIEFING, trackers) + continuité prouvée par l'état actuel : **suite 977/0 sur main (20/09), CI 6/6 PR #36**.

### 3.2 `corrections/` (22) — règle par défaut : `[DONE]`

| Document | Date | [DONE] | Suivi |
|---|---|---|---|
| 2025-12-19-CI_Configuration_Fix_Resolution, 2025-12-19-pgcrypto_elimination_solution, 2025-12-26-CI_Fix_Rails_8_1_1_Migration, 2025-12-29-Feature-Contract-05-RSpec-Tests-Fix | 2025-12 | ✅ | ⏳ TODO |
| 2026-01-03-FC07_Concerns_Namespace_Fix, 2026-01-03-FC07_Redis_Connection_Fix, 2026-01-04-FC07_TDD_PLATINUM_CraEntry_Lifecycle, 2026-01-11-FC07_Architecture_Services_Unified_Migration | 2026-01 | ✅ | ⏳ TODO |
| 2026-01-27-DDD_Audit_CRA_Tests_Migration, 2026-01-28-README_API_Structure_Refactoring_Completion, 2026-01-28-README_Refactoring_Plan_Historical_Reference, 2026-01-29-CTO_Feedback | 2026-01 | ✅ (migration DDD/RDD clôturée 28-29/01) | ⏳ TODO |
| 2026-02-03-API_Missions_Stabilization_Plan, 2026-02-12-Swagger_RSwagSpecs_Completion_Plan, 2026-02-15-DDD_Relation-Driven_Migration_Plan, 2026-02-18-DDD_Relation-Driven_Final_State, 2026-02-18-RSwag_Completion_Status ×2 | 2026-02 | ✅ (Swagger 402 specs / DDD finalisé) | ⏳ TODO |
| TECH-DEBT-dry-monads-missing | 2026-01-05 (git) | ❌ **dette ouverte** (dry-monads absent du Gemfile vérifié 20/09) | ⏳ TODO |

### 3.3 Audits, analyses, déploiement, validation, migrations

| Document | Date | [DONE] | Suivi |
|---|---|---|---|
| audits/2026-01-06-FC06-FC07-Conformity-Audit | 2026-01-06 | ✅ | ⏳ TODO |
| audits/2026-07-22-Architecture_Debt_Audit_and_Plan | 2026-07-22 | ✅ (D-1→D-11 fermées — rapport 2026-09-16, PR #24-#29) | ⏳ TODO |
| audits/2026-08-18-PR23_Review_Action_Plan | 2026-08-18 | ✅ (PR #23 mergée) | ⏳ TODO |
| audits/ANALYSE_TECHNIQUE_FORESY, audits/CHANGELOG_REFACTORISATION | 2025-12-17 (git) | ❌ (référence/historique) | ⏳ TODO |
| analysis/concerns_analysis_report | 2026-01-05 (git) | ✅ (refactoring concerns exécuté 03/01 + Wave 1) | ⏳ TODO |
| analysis/csrf_security_analysis_same_site_none | 2025-12-19 (git) | ✅ (sessions/cookies supprimés 22/12) | ⏳ TODO |
| analysis/docker_configuration_problems_solution | 2025-12-23 (git) | ✅ (fix livré 23/12) | ⏳ TODO |
| analysis/google_oauth_service_mock_solution | 2025-12-19 (git) | ✅ (supersédé — GoogleOAuth2Service supprimé 21/12) | ⏳ TODO |
| analysis/jsonwebtoken_exceptions_improvement | 2025-12-19 (git) | ✅ (JWT_Robustness_Complete 19/12) | ⏳ TODO |
| analysis/oauth_caching_strategy | 2025-12-24 (git) | ❌ (checklist « implémentation future » — non réalisée) | ⏳ TODO |
| analysis/omniauth_oauth_configuration_solution | 2025-12-19 (git) | ✅ (OAuth_Services_Elegant_Solution 23/12) | ⏳ TODO |
| analysis/pgcrypto_alternatives_analysis | 2025-12-19 (git) | ✅ (pgcrypto éliminé 19-21/12) | ⏳ TODO |
| deployment/2025-12-26-Progressive_Deployment_Plan | 2025-12-26 | ✅ (Render live, BRIEFING 20/12) | ⏳ TODO |
| deployment/2025-12-26-Rollback_Plan | 2025-12-26 | ❌ (runbook vivant) | ⏳ TODO |
| deployment/docker_operations_maintenance | 2025-12-23 (git) | ❌ (guide vivant) | ⏳ TODO |
| migrations/2025-12-26-PR8_Technical_Justification | 2025-12-26 | ✅ (PR #8 mergée) | ⏳ TODO |
| validation/2025-12-26-Native_Dependencies_Validation_Report | 2025-12-26 | ✅ (script validate_native_dependencies.sh sur main) | ⏳ TODO |
| validation/2026-01-29-CRA_Tests_Final_Validation | 2026-01-29 | ✅ (498 tests verts 29/01, domaine CRA certifié) | ⏳ TODO |

### 3.4 Registres et trackers racine

| Document | Date | [DONE] | Suivi |
|---|---|---|---|
| d1_d11_corrective_actions_tracker | 2026-09-16 (git) | ✅ (D-1→D-11 100 % fermées, rapport vérification 16/09) | ⏳ TODO |
| d2_simplecov_implementation_tracker | 2026-09-16 (git) | ✅ (SimpleCov opérationnel — Cobertura CI + rapports, PR #24-#36) | ⏳ TODO |
| fc08_implementation_tracker | 2026-08-31 (git) | ✅ (FC-08 terminé, PR #24) | ⏳ TODO |
| fc08_debt_register | 2026-09-14 (git) | ❌ **ACTIF** (D-12 ouverte, D3-3 reportée) | ⏳ TODO |

### 3.5 `guides/` (8) — règle par défaut : vivant, pas de [DONE]

| Document | Date (git) | [DONE] | Suivi |
|---|---|---|---|
| error_contract | 2026-08-18 | ❌ (vivant — mis à jour 19/09) | ⏳ TODO |
| git_ledger_operations | 2026-08-18 | ❌ (vivant) | ⏳ TODO |
| github-workflows-monitor-improvements | 2026-02-02 | ❌ (statut à vérifier à l'exécution) | ⏳ TODO |
| implementation_methodology | 2026-01-06 | ❌ (vivant) | ⏳ TODO |
| migration_strategy | 2026-08-18 | ❌ (statut à vérifier à l'exécution) | ⏳ TODO |
| oauth_flow_documentation | 2025-12-24 | ❌ (vivant — référence Wave 2) | ⏳ TODO |
| tests_organization | 2025-12-17 | ❌ (vivant) | ⏳ TODO |
| token_revocation_strategy | 2025-12-24 | ❌ (vivant) | ⏳ TODO |

### 3.6 `testing/`

| Document | Date | [DONE] | Suivi |
|---|---|---|---|
| 2025-12-19-pgcrypto_migration_test_strategy | 2025-12-19 | ✅ (pgcrypto éliminé) | ⏳ TODO |
| [DONE]_2026_09_17_coverage_campaign_p6 | 2026-09-17 (git) | ❌ **ACTIF** (Wave 2 en cours, D3-3 reporté) | ⏳ TODO |
| e2e_staging_tests_guide | 2025-12-24 (git) | ✅ (infra E2E livrée — bin/e2e, 23 tests verts prod, BRIEFING Sprint 3) | ⏳ TODO |
| fc08_coverage_report | 2026-09-14 (git) | ✅ (rapport livré avec PR #24) | ⏳ TODO |
| line_coverage | 2026-09-16 (git) | ❌ (guide méthodologie vivant) | ⏳ TODO |
| p6_wave1_tracker | 2026-09-18 (git) | ✅ **(Wave 1 clôturée — PR #35 + PR #36, CI 6/6, validation CTO 19/09)** | ⏳ TODO |
| [DONE]_2026_09_20_p6_wave2_tracker | 2026-09-20 (session) | ❌ **ACTIF** (W2-D2 GO le 20/09) | ⏳ TODO |
| test_database_isolation | 2026-09-15 (git) | ❌ (statut à vérifier à l'exécution) | ⏳ TODO |

### 3.7 `fc06/` (16) — règle par défaut : `[DONE]` (FC-06 terminé, PR #12 mergée 01/01/2026)

| Groupe | Date (git) | [DONE] | Suivi |
|---|---|---|---|
| README, development/* (3), implementation/* (2), methodology/* (2), phases/* (4), testing/* (3) | 2026-01-04 | ✅ | ⏳ TODO |
| corrections/2025-12-31-FC06_Architecture_DDD_Standards, corrections/2026-01-01-FC06_Missions_Implementation_Complete, corrections/2026-01-04-FC06_DDD_PLATINUM_Standards_Established | 2025-12-31 → 2026-01-04 | ✅ | ⏳ TODO |

### 3.8 `fc07/` (17) — règle par défaut : `[DONE]` (FC-07 100 % terminé 07/01/2026, tag `fc-07-complete`)

| Groupe | Date (git) | [DONE] | Suivi |
|---|---|---|---|
| README, development/fc07_changelog, methodology/fc07_methodology_tracker, phases/* (8), testing/fc07_progress_tracking, PR-13-DESCRIPTION, corrections/2026-01-06 | 2026-01-05/06 | ✅ | ⏳ TODO |
| enhancements/MINI-FC-01-CRA-Filtering, enhancements/MINI-FC-02-CRA-Export | 2026-01-06 | ✅ (livrés avec FC-07) | ⏳ TODO |
| enhancements/FC07-Future-Enhancements | 2026-01-06 | ❌ (items v0.3 non réalisés : versioning avancé, PDF) | ⏳ TODO |

### 3.9 `[DONE]_remediation/` (8) — marqueur déjà posé, normalisation proposée

| Document | Date (git) | [DONE] | Suivi |
|---|---|---|---|
| README + phase-0 → phase-6 (8 fichiers) | 2026-07-22 | ✅ (v0.1.0 remédiation livrée — 25/25 tâches, PR mergées) | ⏳ TODO — dir → `[DONE]_remediation/` si C1+C2 validés |

## 4. Plan d'exécution (phases — GO CTO requis par phase)

| Phase | Contenu | Suivi |
|---|---|---|
| E1 | Renames mécaniques en masse (script `tmp/rename_technical_docs.rb`, `git mv` — mapping C1/C2) — **148 migrés + 1 déjà conforme, 0 erreur résiduelle** | ✅ FAIT (20/09) |
| E2 | Mise à jour des références croisées (script single-pass `tmp/update_doc_references.rb`) — **109 fichiers, 665 remplacements** (README, index.md, BRIEFING, registres, specs, commentaires code) + 7 doubles préfixes réparés | ✅ FAIT (20/09) |
| E3 | Vérification : G1 doubles préfixes **= 0** · G2 ancien format daté = 2 refs pré-existantes dangling (consignées) · G3 anciens noms **= 0** · suite RSpec **977/0** (`foresy_test`, 2 min 27) · SimpleCov **77,18 % lignes (2815/3647) inchangé** · branches 47,87 % (756/1579) | ✅ FAIT (20/09) |
| E4 | Journal de ce tracker à jour + cross-références trackers wave1/wave2 + commits sur `chore/docs-hygiene` (base `main` @ `025b90b2`) → PR | ⏳ EN COURS |

## 5. Journal de suivi

### 2026-09-20 (bis) — Validation navigation documentaire (revue CTO PR #37) — liens vérifiés cible par cible

- **Vérificateur exhaustif (`tmp/check_doc_links.rb`) :** 621 cibles distinctes (liens markdown + refs backticks `docs/…`) vérifiées — existence du chemin résolu **ET casse exacte composant par composant** (macOS insensible à la casse, CI Linux sensible — le piège `[Done]`/`[DONE]` impose ce contrôle).
- **Liens cassés par le rename : 1 détecté → 0 restant** — 3 self-links `./README.md` vers les README renommés (fc06 self, fc07 PR-13, fc07 enhancements) corrigés ; + 1 double préfixe `[DONE]_[DONE]_` dans README (famille passe-2 E2, échappé à la gate G1 qui ne contrôlait que les dates doublées) corrigé.
- **README + docs/index.md : 100 % des liens pointent désormais vers des fichiers existants** — corrigés : 3 templates `.env*.example` (`../` — fichiers à la racine, erreur pré-existante), `tests_organization` → `guides/`, `docker_operations_maintenance` → `deployment/` (répertoires réels, pré-existant), lien FC-06 (extension `.md` manquante, pré-existant), `fc07_technical_implementation.md` (cible inexistante → README fc07).
- **2 refs du tracker wave2 corrigées (notres) :** citations de sources RAG écrites sans préfixe `docs/` (ambiguïté) → préfixées.
- **Résidu quantifié — pré-existant et indépendant du rename (~115 cibles) :** liens à profondeur relative erronée dans fc06/fc07 (`../../app/…`, `../../FeatureContract/…` sans `.md`, `../../swagger/…`, `../../spec/…`, `../corrections/…`) — cassés par la réorganisation du 2026-01-04/05 (fichiers déplacés de la racine `docs/technical/` vers les sous-répertoires sans correction des liens ; les chemins visés n'ont jamais existé, l'E2 n'a changé que des noms de fichiers à l'intérieur de chemins déjà faux) + 2 wildcards de prose (`*.md` dans du texte) + 3 danglings documentés (D12 → `chore/p6-coverage-plan` non mergée ; `docs/adr/` inexistant). **Recommandation : chore séparé de réparation des profondeurs — hors périmètre PR #37.**
- **Gates inchangées :** suite 977/0 (`foresy_test`) · SimpleCov 77,18 % (2815/3647) · grep anciens noms = 0 · doubles préfixes (dates ET `[DONE]`) = 0.

### 2026-09-20 — C1+C2+C3 GO — exécution E1→E3 complète, gates verts, E4 en cours

- **GO CTO consigné :** C1 `YYYY_MM_DD_` (migration unique et complète, références corrigées dans le même cycle) · C2 `[DONE]_` partout + normalisation `[Done]_remediation/` · C3 suppression locale des 3 branches mergées. `chore/p6-coverage-plan` : non tranché — absorption dans P1 conditionnée à l'audit P1.
- **C3 exécuté :** `feat/p6-wave1` (@ `b51347f9`), `chore/p61-coverage-lock` (@ `4c7dce6b`), `chore/p6-w1-reevaluation-cleanup` (@ `7f7bce2e`) supprimées localement (`-d`, mergées — zéro perte) ; suppression origin = action GitHub humaine. Branche de travail `chore/docs-hygiene` créée sur `025b90b2`.
- **E1 exécuté :** 148 docs migrés (147 `git mv` + 1 `move_path` pour le tracker wave2 non encore commité) ; 1 déjà conforme (ce tracker). Incident : répertoire `[Done]_remediation` non renommé sur disque (FS macOS insensible à la casse — l'index git portait déjà `[DONE]_remediation`) → renommage disque forcé via `mv` en 2 étapes.
- **E2 exécuté :** script **single-pass** (`Regexp.union`, plus long motif d'abord — évite le re-scan des noms déjà remplacés) sur `.md`/`.rb`/`.yml`/`.sh` : **109 fichiers, 665 remplacements** — README (8), docs/index.md (155), BRIEFING (13), RELEASE_NOTES (10), registres/trackers, guides croisés, commentaires `@see` du code (`user_cra.rb`, `user_mission.rb`, `feature_flags.rb`, `cras_controller.rb` — **commentaires uniquement, aucune modification fonctionnelle**) et ~25 specs (commentaires).
- **Incidents E2 corrigés (transparents) :** (a) README.md traité 2× (doublon de globs `README.md` + `*.md`) → 7 doubles préfixes (`2026_08_18_2026_08_18_…`) réparés ; (b) les candidats « bare » des 2 trackers déjà conformes (hygiène, wave2) étaient inclus à tort dans le mapping → 2 doubles réparés (référence croisée + exemple C1). Gate G1 (doubles préfixes) = **0**.
- **Gates E3 :** G2 (ancien format daté) = **2 refs pré-existantes dangling**, hors périmètre du rename — consignées : `changes/[DONE]_2026_09_17_D12_LEDGER_PATH_Chiffrage.md` → pointe vers `2026-09-17-P6_Coverage_Gap_Analysis.md` + `p6_coverage_implementation_tracker.md` (docs vivant sur `chore/p6-coverage-plan`, non mergée) ; `corrections/[DONE]_2026_01_11_FC07_Architecture_Services_Unified_Migration.md` → `docs/adr/…` (répertoire inexistant). G3 (anciens noms non datés non préfixés) = **0**. Références `memory/…` (hub RAG) : hors périmètre.
- **E3 suite :** première exécution = **22 échecs — piège D-10 identifié et documenté** (la `DATABASE_URL` du conteneur écrase `database.yml` → la suite tournait contre `foresy_development`, polluée par les données E2E). Procédure du guide `2026_09_15_test_database_isolation.md` appliquée : `db:prepare` sur `foresy_test` + suite contre la base test + TRUNCATE dev (données 100 % jetables, 20 users/15 companies/8 cras purgés). Re-exécution : **977 exemples, 0 échec** (2 min 27) — **fausse alerte de régression confirmée, aucun changement fonctionnel**.
- **E3 couverture :** SimpleCov **77,18 % lignes (2815/3647) — inchangé** vs PR #36 · branches **47,87 % (756/1579)** · corpus 3647 lignes = −46 vs 3870 (cohérent avec le retrait des lignes mortes de la réévaluation Wave 1).
- **Corrections de compte au §3 (relevées à l'exécution, script faisant foi) :** `changes/` **46** (et non 42) · `corrections/` **18** (et non 22) · `fc06/` **18** (et non 16) · `analysis/` **10** (ajout `2026-01-29-CRA_Permissions_Deep_Analysis`, daté, [DONE] — caractérisation CRA exécutée Wave 1) — total 148 + ce tracker = 149.
- **Note :** scripts `tmp/` (dates, renames, références) — `tmp/` est gitigné ; méthode décrite au journal pour reproductibilité.
- **W2-D2 : débloqué** — prochaines specs de caractérisation `OAuthCodeExchangeService` (tracker wave2 §4).

### 2026-09-20 — Création du tracker (pré-travail demandé avant implémentation W2-D2)

- **Audit branches effectué (git) :** 5 locales + miroirs — 3 mergées (feat/p6-wave1, chore/p61-coverage-lock, chore/p6-w1-reevaluation-cleanup) = candidats clôture ; 1 ouverte non mergée (chore/p6-coverage-plan — analyse coverage + script `coverage_gap_analysis.rb` absent de main) = arbitrage CTO ; main synchronisée.
- **Inventaire complet :** 148 documents sous `docs/technical/` (13 répertoires) — 86 déjà datés (format `YYYY-MM-DD-`), 62 non datés (dates récupérées par `git log --follow --diff-filter=A`), 1 créé en session ([DONE]_2026_09_20_p6_wave2_tracker).
- **Découverte d'un précédent :** répertoire `[DONE]_remediation/` — la convention `[Done]_` existe déjà (casse différente de l'instruction `[DONE]` du 20/09) → normalisation proposée (C2).
- **Divergence conventionnelle relevée :** standard maison documenté (`YYYY-MM-DD-…`, BRIEFING §Documentation Maintenance + docs/index.md) vs format demandé (`YYYY_MM_DD`) — arbitrage C1 requis avant le rename de masse (86 fichiers déjà au format hyphène).
- **Classification [DONE] :** base de preuve par défaut = statut de complétion porté par le document + jalons suites vertes documentés + état actuel vérifié : **suite 977/0 sur main (20/09), CI 6/6 sur PR #36**. Les docs au statut incertain sont marqués « à vérifier à l'exécution » (pas de [DONE] inféré sans preuve).
- **W2-D2 : GO acquis le 20/09 — exécution gated sur ce pré-travail** (arbitrages C1/C2 + clôture branches).

## 6. Références

- Tracker Wave 2 (gated par ce pré-travail) : `docs/technical/testing/[DONE]_2026_09_20_p6_wave2_tracker.md`
- Tracker Wave 1 (précédent de méthode) : `docs/technical/testing/[DONE]_2026_09_18_p6_wave1_tracker.md`
- Standard de nommage historique : `docs/BRIEFING.md` (§ Documentation Maintenance) · `docs/index.md` (§ Standards de Documentation)
- Scripts de dates : `tmp/doc_creation_dates.rb`, `tmp/doc_creation_dates_remediation.rb` (reproductibles)