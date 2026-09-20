# 📚 Documentation Centrale - Projet Foresy
Historique / état au 2025-12-31


**Version :** 3.1  
**Dernière mise à jour :** 31 décembre 2025  
**Stack :** Ruby 3.4.8 + Rails 8.1.1  
**Objectif :** Point d'entrée centralisé pour toute la documentation du projet Foresy API  
**Production :** https://foresy-api.onrender.com  
**Sécurité :** Stateless JWT, token revocation, no token logging, session minimale pour OmniAuth uniquement  
**Feature actuelle :** FC-06 Missions — TERMINÉ ✅

---

## 🎯 Vue d'Ensemble

Cette documentation centralisée regroupe toutes les informations techniques, historiques et de référence du projet Foresy. Elle a été réorganisée le 18 décembre 2025 pour rassembler les documents dispersés dans plusieurs endroits du projet.

### 📁 Structure de la Documentation

```
Foresy/
├── render.yaml                  # 🚀 Render deployment blueprint
├── Dockerfile                   # Multi-stage Docker build
├── entrypoint.sh               # Container entrypoint script
└── docs/
    ├── index.md                 # Documentation centrale (ce fichier)
    ├── BRIEFING.md              # Contexte projet pour IA
    ├── BACKLOG.md               # Backlog produit et roadmap
    ├── VISION.md                # Vision produit et principes architecture
    ├── FeatureContract/         # Contrats de fonctionnalités
    │   ├── 01_...OAuth          # Feature Contract OAuth
    │   ├── 02_...Auth           # Authentication email/password
    │   ├── 03_...Rails_Upgrade  # Migration Rails 8.1.1
    │   ├── 04_...Revocation     # Token revocation E2E
    │   ├── 05_...Rate_Limiting  # Rate limiting
    │   └── 06_...Missions       # ✅ Mission management (TERMINÉ)
    └── technical/               # Documentation technique centralisée
        ├── guides/              # 📖 Guides d'intégration
        │   ├── 2025_12_24_oauth_flow_documentation.md      # 🔐 Guide complet OAuth
        │   └── 2025_12_24_token_revocation_strategy.md     # 🔒 Stratégie de revocation des tokens
        ├── analysis/            # Analyses techniques approfondies (Déc 2025)
        │   ├── [DONE]_2025_12_19_pgcrypto_alternatives_analysis.md
        │   ├── [DONE]_2025_12_19_google_oauth_service_mock_solution.md
        │   ├── [DONE]_2025_12_19_omniauth_oauth_configuration_solution.md
        │   └── [DONE]_2025_12_19_csrf_security_analysis_same_site_none.md
        ├── changes/             # Journal chronologique des modifications
        │   ├── [DONE]_2025_12_31_FC06_Missions_Implementation.md  # ✅ FC-06 Missions
        │   ├── [DONE]_2025_12_26_Rails_8_1_1_Migration_Complete.md
        │   ├── [DONE]_2025_12_19_Security_CI_Complete_Fix.md
        │   └── ...
        ├── audits/              # Rapports d'audit technique
        │   ├── 2025_12_17_ANALYSE_TECHNIQUE_FORESY.md
        │   └── 2025_12_17_CHANGELOG_REFACTORISATION.md
        └── corrections/         # Corrections techniques historiques
            ├── [DONE]_2025_12_19_pgcrypto_elimination_solution.md  # ✅ pgcrypto éliminé
            └── [DONE]_2025_12_19_CI_Configuration_Fix_Resolution.md
```

---

## 📋 Navigation Rapide

### 🎯 Pour Commencer
1. **[🚀 Production Live](https://foresy-api.onrender.com)** - API déployée sur Render
2. **[README.md](../README.md)** - Vue d'ensemble du projet, installation, utilisation
3. **[🔐 Guide OAuth](./technical/guides/2025_12_24_oauth_flow_documentation.md)** - Documentation complète du flux OAuth (state, scopes, JWT, exemples frontend)
4. **[🔒 Token Revocation](./technical/guides/2025_12_24_token_revocation_strategy.md)** - Stratégie de revocation des tokens (sécurité)
5. **[📮 Postman Collection](./postman/Foresy_API.postman_collection.json)** - Collection pour tester les endpoints

### 🎯 **Feature Contract 07 — CRA (7/01/2026)** 🏆 **100% TERMINÉ - TDD PLATINUM**
1. **[📋 Documentation Centrale FC-07](./technical/fc07/[DONE]_2026_01_05_README.md)** - Vue d'ensemble et navigation complète
2. **[📚 Méthodologie TDD/DDD](./technical/fc07/methodology/[DONE]_2026_01_05_fc07_methodology_tracker.md)** - Suivi méthodologique
3. **[🔧 Implémentation Technique](./technical/fc07/implementation/fc07_technical_implementation.md)** - Documentation technique
4. **[🏗️ Phases Complétées](./technical/fc07/phases/)** - Toutes phases terminées
5. **[📤 Mini-FC-02 CRA Export](./technical/fc07/enhancements/[DONE]_2026_01_06_MINI-FC-02-CRA-Export.md)** - Export CSV ✨ NEW
6. **[🔍 Mini-FC-01 Filtering](./technical/fc07/enhancements/[DONE]_2026_01_06_MINI-FC-01-CRA-Filtering.md)** - Filtrage CRAs

**✅ FC-07 100% TERMINÉ** (Tag: `fc-07-complete`)

| Outil | Résultat | Status |
|-------|----------|--------|
| **RSpec** | 449 examples, 0 failures | ✅ |
| **Rswag** | 128 examples, 0 failures | ✅ |
| **RuboCop** | 147 files, no offenses | ✅ |
| **Brakeman** | 0 Security Warnings | ✅ |

| Phase | Description | Tests | Status |
|-------|-------------|-------|--------|
| Phase 1 | CraEntry Lifecycle + CraMissionLinker | 6/6 ✅ | TDD PLATINUM |
| Phase 2 | Unicité Métier (cra, mission, date) | 3/3 ✅ | TDD PLATINUM |
| Phase 3A | Legacy Tests Alignment | 9/9 ✅ | TDD PLATINUM |
| Phase 3B.1 | Pagination ListService | 9/9 ✅ | TDD PLATINUM |
| Phase 3B.2 | Unlink Mission DestroyService | 8/8 ✅ | TDD PLATINUM |
| Phase 3C | Recalcul Totaux (Create/Update/Destroy) | 24/24 ✅ | TDD PLATINUM |
| **Mini-FC-01** | **Filtrage CRAs (year/month/status)** | **16/16 ✅** | **TDD PLATINUM** |
| **Mini-FC-02** | **Export CSV avec include_entries** | **26/26 ✅** | **TDD PLATINUM** |

**Décision Architecturale Clé (Phase 3C)** :
- ❌ **Callbacks ActiveRecord** → Rejeté
- ✅ **Services Applicatifs** → Adopté

La logique de recalcul (`total_days`, `total_amount`) est dans les services, pas dans les callbacks.

**Leçons Apprises** :
1. **Services > Callbacks** pour la logique métier complexe
2. **RSpec lazy `let`** : toujours forcer l'évaluation avant `reload`
3. **Montants financiers** : toujours en centimes (integer)

**Contrat Métier Validé** :
| Action | CRA draft | CRA submitted | CRA locked |
|--------|-----------|---------------|------------|
| create | ✅ autorisé | ❌ CraSubmittedError | ❌ CraLockedError |
| update | ✅ autorisé | ❌ (implicitement) | ❌ CraLockedError |
| discard | ✅ autorisé | ❌ CraSubmittedError | ❌ CraLockedError |

**Commande de Validation** :
```bash
docker compose exec web bundle exec rspec spec/services/cra_entries/ spec/models/cra_entry_lifecycle_spec.rb spec/models/cra_entry_uniqueness_spec.rb --format progress
# Résultat : 50 examples, 0 failures
```

**Mini-FCs Terminés (7 Jan 2026)** :
| Mini-FC | Fonctionnalité | Tests | Status |
|---------|----------------|-------|--------|
| Mini-FC-01 | Filtrage CRAs (year, month, status) | 16 ✅ | TERMINÉ |
| Mini-FC-02 | Export CSV (`GET /cras/:id/export`) | 17+9 ✅ | TERMINÉ |

**Endpoint Export CSV** :
```
GET /api/v1/cras/:id/export?export_format=csv&include_entries=true
```

**Commandes de Validation (résultats du 7 janvier 2026)** :
```bash
# RSpec
docker compose exec web bundle exec rspec --format progress
# → 449 examples, 0 failures

# Rswag
docker compose exec web bundle exec rake rswag:specs:swaggerize
# → 128 examples, 0 failures

# RuboCop
docker compose exec web bundle exec rubocop --format simple
# → 147 files inspected, no offenses detected

# Brakeman
docker compose exec web bundle exec brakeman -q
# → 0 Security Warnings
```

> ✅ **FC-07 TERMINÉ — 449 tests GREEN, taggé `fc-07-complete`, prêt pour production.**

### 🎯 **Feature Contract 06 — Missions (31/12/2025)** ✅ PR #12 MERGED (1 Jan 2026)
1. **[📋 Feature Contract 06](./FeatureContract/06_Feature%20Contract%20—%20Missions)** - Contrat source de vérité
2. **[📝 Changelog FC-06](./technical/changes/[DONE]_2025_12_31_FC06_Missions_Implementation.md)** - Documentation technique complète de l'implémentation
3. **[📊 BACKLOG.md](./BACKLOG.md)** - Roadmap mise à jour avec FC-06 mergé
4. **[🧪 Script E2E Missions](../bin/e2e/e2e_missions.sh)** - 6 tests E2E (tous passent)

### 🧪 **Tests E2E Infrastructure**
**Endpoints de support** (uniquement en `RAILS_ENV=test` ou `E2E_MODE=true`) :
| Endpoint | Description |
|----------|-------------|
| `POST /__test_support__/e2e/setup` | Crée contexte test (User + Company + relation) |
| `DELETE /__test_support__/e2e/cleanup` | Nettoie les données E2E |

⚠️ **Sécurité** : Ces endpoints n'existent PAS en production. Toute exposition serait une faille critique.

**Scripts disponibles** :
- `bin/e2e/e2e_missions.sh` - Tests missions (6 tests)
- `bin/e2e/e2e_auth_flow.sh` - Tests authentification
- `bin/e2e/e2e_revocation.sh` - Tests révocation tokens
- `bin/e2e/smoke_test.sh` - Tests smoke basiques

### 🔧 **Pour le Développement**
1. **[Analyse Technique](./technical/audits/2025_12_17_ANALYSE_TECHNIQUE_FORESY.md)** - Architecture et analyse technique complète
2. **[✅ Migration Rails 8.1.1 Complétée](./technical/changes/[DONE]_2025_12_26_Rails_8_1_1_Migration_Complete.md)** - Migration Rails 7.1.5.1 → 8.1.1 + Ruby 3.4.8 (26/12/2025)
3. **[🧪 Organisation des Tests](./technical/2025_12_17_tests_organization.md)** - Guide complet de l'organisation des tests RSpec (Acceptance, Integration, Unit, API)
4. **[Corrections 19 Décembre 2025](./technical/corrections/[DONE]_2025_12_19_CI_Configuration_Fix_Resolution.md)** - Résolution problèmes CI historiques

### 🏗️ **Plan de Remédiation Architecture (22/07/2026)**
1. **[📋 Audit & Plan Principal](./technical/audits/[DONE]_2026_07_22_Architecture_Debt_Audit_and_Plan.md)** - Audit complet (25 points) + plan d'implémentation (23 tâches en 6 phases) + tableau de bord de suivi
2. **[📁 Suivi par Phase](./technical/[DONE]_remediation/[DONE]_2026_07_22_README.md)** - Navigation vers les 7 sous-documents de suivi détaillé (P0 à P6)
3. **[🔴 Phase 0 — Sécurité Critique](./technical/[DONE]_remediation/[DONE]_2026_07_22_phase-0-securite.md)** - Routes test, `puts` JWT, fuite erreurs OAuth
4. **[🔴 Phase 1 — Stabilisation Runtime](./technical/[DONE]_remediation/[DONE]_2026_07_22_phase-1-stabilisation.md)** - Crash `Domain::CraEntry`, conflit `rescue_from`
5. **[🟡 Phase 2 — Unification Erreurs](./technical/[DONE]_remediation/[DONE]_2026_07_22_phase-2-unification-erreurs.md)** - Phase 1.9 + suppression `ErrorRenderable` + `render_fc07_error`
6. **[🟡 Phase 3 — Nettoyage Code Mort](./technical/[DONE]_remediation/[DONE]_2026_07_22_phase-3-nettoyage-code-mort.md)** - ~2700 lignes `app/lib` + concerns orphelins
7. **[🟡 Phase 4 — Cohérence Architecturale](./technical/[DONE]_remediation/[DONE]_2026_07_22_phase-4-coherence-architecturale.md)** - Héritage contrôleurs, IP rate limit, services missions
8. **[🟢 Phase 5 — DB & Config](./technical/[DONE]_remediation/[DONE]_2026_07_22_phase-5-db-config.md)** - UUID natif, enum PG, module `Foresy`, `load_defaults`
9. **[🟢 Phase 6 — Hardening Final](./technical/[DONE]_remediation/[DONE]_2026_07_22_phase-6-hardening-final.md)** - GitLedger shell, `CraEntry` nettoyage, `users` PK

### 🔍 **Analyses Techniques Récentes (Décembre 2025)**
1. **[🔧 pgcrypto UUID Alternatives](./technical/analysis/[DONE]_2025_12_19_pgcrypto_alternatives_analysis.md)** - **CRITIQUE** - Migration UUID sans pgcrypto
2. **[🚫 GoogleOAuth2Service Mock Removal](./technical/analysis/[DONE]_2025_12_19_google_oauth_service_mock_solution.md)** - **CRITIQUE** - Suppression service mock mal placé
3. **[🔐 OmniAuth OAuth Configuration](./technical/analysis/[DONE]_2025_12_19_omniauth_oauth_configuration_solution.md)** - **CRITIQUE** - Configuration robuste secrets OAuth
4. **[🛡️ CSRF Security Analysis](./technical/analysis/[DONE]_2025_12_19_csrf_security_analysis_same_site_none.md)** - **CRITIQUE** - Analyse risque CSRF et sécurisation

### 📊 **Pour les Modifications Récentes**
1. **[🔴 FC-07 CRA 03/01/2026](./technical/corrections/[DONE]_2026_01_03_FC07_Concerns_Namespace_Fix.md)** - **✅ TERMINÉ** - FC-07 CRA 100% terminé (TDD Platinum, 449 tests)
2. **[🎯 FC-06 Missions 31/12/2025](./technical/changes/[DONE]_2025_12_31_FC06_Missions_Implementation.md)** - **MAJEUR** - Feature Contract 06 Missions complet, 290 tests OK, 0 vulnérabilités (31/12/2025)
2. **[🚀 Migration Rails 8.1.1 26/12/2025](./technical/changes/[DONE]_2025_12_26_Rails_8_1_1_Migration_Complete.md)** - **MAJEUR** - Upgrade complet Ruby 3.4.8 + Rails 8.1.1 (26/12/2025)
3. **[🔒 Token Revocation Endpoints 24/12/2025](./technical/guides/2025_12_24_token_revocation_strategy.md)** - Endpoints DELETE /revoke et /revoke_all pour invalidation des tokens (24/12/2025)
4. **[🧪 Tests E2E Staging Infrastructure 24/12/2025](./technical/testing/[DONE]_2025_12_24_e2e_staging_tests_guide.md)** - Scripts E2E pour staging: smoke_test.sh (15 tests) et e2e_auth_flow.sh (8 tests) (24/12/2025)
5. **[🚨 Résolution Erreurs 500 Production 24/12/2025](./technical/changes/[DONE]_2025_12_24_Production_Errors_500_Fix.md)** - Migration des tables users/sessions appliquée en production (24/12/2025)
6. **[🔧 OmniAuth Session Middleware Fix 23/12/2025](./technical/changes/[DONE]_2025_12_23_OmniAuth_Session_Middleware_Fix.md)** - **CRITIQUE** - Résolution erreur OmniAuth::NoSessionError bloquant tous les endpoints (23/12/2025)
3. **[🔧 OAuth Services Elegant Solution 23/12/2025](./technical/changes/[DONE]_2025_12_23_OAuth_Services_Elegant_Solution.md)** - **MAJEUR** - Solution élégante élimination require_relative, conventions Zeitwerk respectées (23/12/2025)
4. **[🐳 Docker Build Health Check 23/12/2025](./technical/changes/[DONE]_2025_12_23_Docker_Build_Health_Check_Resolution.md)** - **RÉSOLU** - Conteneurs Docker healthy, health endpoints fonctionnels (23/12/2025)
3. **[📊 Standardisation APM Datadog 22/12/2025](./technical/changes/[DONE]_2025_12_22_Datadog_APM_Standardization_Resolution.md)** - **RÉSOLU** - Standardisation API Datadog multi-versions (22/12/2025)
3. **[🚨 Migration Rails Planifiée 20/12/2025](./technical/changes/[DONE]_2025_12_20_Rails_Migration_Task_Planning.md)** - **CRITIQUE** - Planification migration Rails 7.1.5.1 → 7.2+ (EOL)
4. **[🔧 Refactoring Authenticatable 20/12/2025](./technical/changes/[DONE]_2025_12_20_Authenticatable_Concern_Refactoring.md)** - **MAJEUR** - Séparation responsabilités auth
5. **[🔑 Migration UUID 20/12/2025](./technical/changes/[DONE]_2025_12_20_UUID_Migration.md)** - **MAJEUR** - Migration identifiants sécurisés
6. **[🔧 PGCrypto Compatibility Fix 21/12/2025](./technical/changes/[DONE]_2025_12_21_PGCrypto_Compatibility_Fix.md)** - **CRITIQUE** - Résolution compatibilité environnements managés
7. **[✅ GoogleOAuth2Service Removal 21/12/2025](./technical/changes/[DONE]_2025_12_21_GoogleOAuth2Service_Removal_Resolution.md)** - **RÉSOLU** - Point 2 PR fermé (suppression service mock)
8. **[🔒 Sécurité Gems 20/12/2025](./technical/changes/[DONE]_2025_12_20_Security_Gems_Update.md)** - **CRITIQUE** - 20+ vulnérabilités corrigées
9. **[⚡ Réactivation Bootsnap 20/12/2025](./technical/changes/[DONE]_2025_12_20_Bootsnap_Reactivation.md)** - **MAJEUR** - Performance boot Rails
10. **[🏗️ Consolidations Migrations 20/12/2025](./technical/changes/[DONE]_2025_12_20_Migrations_Consolidation.md)** - **MAJEUR** - Nettoyage migrations UUID
11. **[JWT Robustesse 19/12/2025](./technical/changes/[DONE]_2025_12_19_JWT_Robustness_Improvements_Complete.md)** - **MAJEUR** - Amélioration robustesse JWT
12. **[🏗️ Corrections Architecture OAuth 19/12/2025](./technical/changes/[DONE]_2025_12_19_OAuth_Architecture_Fix.md)** - **CRITIQUE** - Nommage OAuth + RequireRelative
13. **[🔒 Corrections CI Sécurité 19/12/2025](./technical/changes/[DONE]_2025_12_19_CI_Security_Fixes_Secrets_PostgreSQL.md)** - **CRITIQUE** - Sécurité CI + Compatibilité runners
14. **[🔧 Zeitwerk OAuth 19/12/2025](./technical/changes/[DONE]_2025_12_19_Zeitwerk_OAuth_Services_Rename.md)** - **CRITIQUE** - Renommage services OAuth pour Zeitwerk
15. **[🔒 Sécurité & Secrets 19/12/2025](./technical/changes/[DONE]_2025_12_19_Security_CI_Complete_Fix.md)** - **CRITIQUE** - Sécurisation secrets CI/CD
16. **[Correction CI 18/12/2025](./technical/changes/[DONE]_2025_12_18_CI_Fix_Resolution.md)** - Intervention majeure CI
17. **[Correction GoogleOauthService 18/12/2025](./technical/changes/[DONE]_2025_12_18_GoogleOauthService_Fix_Resolution.md)** - Résolution erreur Zeitwerk
18. **[🔒 Feature Contract 05 - Rate Limiting 28/12/2025](./FeatureContract/05_Feature Contract — Rate Limiting)** - ✅ **COMPLÉTÉ** - Rate limiting opérationnel avec before_action filters + RateLimitService Redis (28/12/2025)

### 🔍 **Analyses Techniques Problèmes PR (Décembre 2025)**
1. **[🔧 pgcrypto UUID Alternatives](./technical/analysis/[DONE]_2025_12_19_pgcrypto_alternatives_analysis.md)** - ✅ **RÉSOLU** - Compatibilité environnements managés (21/12/2025)
2. **[🚫 GoogleOAuth2Service Mock Removal](./technical/analysis/[DONE]_2025_12_19_google_oauth_service_mock_solution.md)** - ✅ **RÉSOLU** - Service mock supprimé (21/12/2025)
3. **[🔐 OmniAuth OAuth Configuration](./technical/analysis/[DONE]_2025_12_19_omniauth_oauth_configuration_solution.md)** - Configuration secrets fragile
4. **[🛡️ CSRF Security Analysis](./technical/analysis/[DONE]_2025_12_19_csrf_security_analysis_same_site_none.md)** - Risque CSRF avec same_site: :none
5. **[📊 Standardisation APM Datadog](./technical/changes/[DONE]_2025_12_22_Datadog_APM_Standardization_Resolution.md)** - ✅ **RÉSOLU** - Standardisation API Datadog multi-versions (22/12/2025)

### 🔧 **Pour les Corrections Critiques**
1. **[🏗️ Corrections Architecture OAuth 19/12/2025](./technical/changes/[DONE]_2025_12_19_OAuth_Architecture_Fix.md)** - Fuite secrets + Dépendance pg_isready + Incohérences nommage OAuth
2. **[🔒 Sécurité Secrets 19/12/2025](./technical/changes/[DONE]_2025_12_19_Security_CI_Complete_Fix.md)** - Secrets exposés → GitHub Secrets
3. **[GoogleOauthService 18/12/2025](./technical/changes/[DONE]_2025_12_18_GoogleOauthService_Fix_Resolution.md)** - Erreur `uninitialized constant GoogleOauthService`
4. **[✅ GoogleOAuth2Service Resolution 21/12/2025](./technical/changes/[DONE]_2025_12_21_GoogleOAuth2Service_Removal_Resolution.md)** - ✅ **RÉSOLU** - Point 2 PR fermé (suppression service mock)
5. **[CI GitHub 18/12/2025](./technical/changes/[DONE]_2025_12_18_CI_Fix_Resolution.md)** - Pipeline CI cassée

### 📈 Pour l'Historique
1. **[Changelog Refactorisation](./technical/audits/2025_12_17_CHANGELOG_REFACTORISATION.md)** - Historique des refactorisations

---

## 📖 Guide par Catégorie

### 📖 **Documentation Projet** (`README.md racine`)
Informations générales et d'utilisation du projet (compatible GitHub).

| Fichier | Description |
|---------|-------------|
| [README.md](../README.md) | Documentation principale, installation, utilisation, architecture |

### 🔧 **Journal des Changements** (`docs/technical/changes/`)
Documentation chronologique de toutes les modifications significatives du projet.

| Fichier | Date | Description | Impact |
|---------|------|-------------|--------|
| [✅ [DONE]_2025_12_23_CI_Rubocop_Standards_Configuration_Fix.md](./technical/changes/[DONE]_2025_12_23_CI_Rubocop_Standards_Configuration_Fix.md) | 23/12/2025 | Corrections CI, standards Rubocop et configuration Rails | **CRITIQUE** - CI débloquée, 0 offense |
| [🧹 [DONE]_2025_12_19_Authenticatable_Cleanup.md](./technical/changes/[DONE]_2025_12_19_Authenticatable_Cleanup.md) | 19/12/2025 | Unification payload_valid?/valid_payload? + tests unitaires | **MOYEN** - 149 tests OK |
| [🔧 [DONE]_2025_12_19_Authentication_Concerns_Fix.md](./technical/changes/[DONE]_2025_12_19_Authentication_Concerns_Fix.md) | 19/12/2025 | Correction concerns authentification (class_methods + Zeitwerk) | **CRITIQUE** - 120 tests OK |
| [🔧 [DONE]_2025_12_20_Authenticatable_Concern_Refactoring.md](./technical/changes/[DONE]_2025_12_20_Authenticatable_Concern_Refactoring.md) | 20/12/2025 | Refactoring concern Authenticatable (séparation responsabilités) | **MAJEUR** - Architecture clean |
| [🔧 [DONE]_2025_12_20_Autoload_Cleanup.md](./technical/changes/[DONE]_2025_12_20_Autoload_Cleanup.md) | 20/12/2025 | Nettoyage require_relative et optimisation autoload | **MINEUR** - Performance |
| [⚡ [DONE]_2025_12_20_Bootsnap_Reactivation.md](./technical/changes/[DONE]_2025_12_20_Bootsnap_Reactivation.md) | 20/12/2025 | Réactivation Bootsnap pour optimisation boot Rails | **MAJEUR** - Performance |
| [🛡️ [DONE]_2025_12_20_Brakeman_Ignore_Config_Fix.md](./technical/changes/[DONE]_2025_12_20_Brakeman_Ignore_Config_Fix.md) | 20/12/2025 | Configuration patterns ignore Brakeman | **MINEUR** - Configuration |
| [🧹 [DONE]_2025_12_20_Debug_Logging_Cleanup.md](./technical/changes/[DONE]_2025_12_20_Debug_Logging_Cleanup.md) | 20/12/2025 | Suppression logs debug Rails.logger | **MINEUR** - Propreté code |
| [🏗️ [DONE]_2025_12_20_Migrations_Consolidation.md](./technical/changes/[DONE]_2025_12_20_Migrations_Consolidation.md) | 20/12/2025 | Consolidation migrations users/sessions UUID | **MAJEUR** - Schema clean |
| [🔒 [DONE]_2025_12_20_Security_Gems_Update.md](./technical/changes/[DONE]_2025_12_20_Security_Gems_Update.md) | 20/12/2025 | Mise à jour sécurité gems (20+ vulnérabilités) | **CRITIQUE** - Sécurité |
| [🔑 [DONE]_2025_12_20_UUID_Migration.md](./technical/changes/[DONE]_2025_12_20_UUID_Migration.md) | 20/12/2025 | Migration identifiants users/sessions vers UUID | **MAJEUR** - Sécurité |
| [🔑 [DONE]_2025_12_19_JWT_Robustness_Improvements_Complete.md](./technical/changes/[DONE]_2025_12_19_JWT_Robustness_Improvements_Complete.md) | 19/12/2025 | Amélioration robustesse validation JWT | **MAJEUR** - Authentification |
| [🏗️ [DONE]_2025_12_19_OAuth_Architecture_Fix.md](./technical/changes/[DONE]_2025_12_19_OAuth_Architecture_Fix.md) | 19/12/2025 | Corrections architecturales (nommage OAuth + require_relative) | **CRITIQUE** - Architecture robuste |
| [🔒 [DONE]_2025_12_19_CI_Security_Fixes_Secrets_PostgreSQL.md](./technical/changes/[DONE]_2025_12_19_CI_Security_Fixes_Secrets_PostgreSQL.md) | 19/12/2025 | Corrections sécurité CI (fuite secrets + pg_isready) | **CRITIQUE** - CI sécurisée |
| [📋 [DONE]_2025_12_19_Rswag_OAuth_Specs_Feature_Contract.md](./technical/changes/[DONE]_2025_12_19_Rswag_OAuth_Specs_Feature_Contract.md) | 19/12/2025 | Specs rswag OAuth conformes au Feature Contract | **MAJEUR** - Swagger auto-généré |
| [🔧 [DONE]_2025_12_19_Zeitwerk_OAuth_Services_Rename.md](./technical/changes/[DONE]_2025_12_19_Zeitwerk_OAuth_Services_Rename.md) | 19/12/2025 | Renommage fichiers OAuth pour Zeitwerk | **CRITIQUE** - CI fonctionnelle |
| [🔒 [DONE]_2025_12_19_Security_CI_Complete_Fix.md](./technical/changes/[DONE]_2025_12_19_Security_CI_Complete_Fix.md) | 19/12/2025 | Sécurisation secrets + Configuration GitHub Secrets | **CRITIQUE** - Sécurité renforcée |
| [[DONE]_2025_12_18_OAuthTokenService_Comment_Fix.md](./technical/changes/[DONE]_2025_12_18_OAuthTokenService_Comment_Fix.md) | 18/12/2025 | Correction commentaires OAuthTokenService | **MINEUR** - Qualité code |
| [[DONE]_2025_12_18_CI_Fix_Resolution.md](./technical/changes/[DONE]_2025_12_18_CI_Fix_Resolution.md) | 18/12/2025 | Résolution problèmes CI GitHub | **CRITIQUE** - CI fonctionnelle |
| [[DONE]_2025_12_18_GoogleOauthService_Fix_Resolution.md](./technical/changes/[DONE]_2025_12_18_GoogleOauthService_Fix_Resolution.md) | 18/12/2025 | Résolution erreur Zeitwerk GoogleOauthService | **CRITIQUE** - 87 tests, 0 échec |

### 🔍 **Analyses Techniques** (`docs/technical/analysis/`)
Analyses approfondies des problèmes techniques identifiés et solutions proposées.

| Fichier | Date | Problème | Impact | Solution |
|---------|------|----------|--------|----------|
| [[DONE]_2025_12_19_pgcrypto_alternatives_analysis.md](./technical/analysis/[DONE]_2025_12_19_pgcrypto_alternatives_analysis.md) | 19/12/2025 | pgcrypto échoue en production | **CRITIQUE** | UUID Ruby |
| [[DONE]_2025_12_19_google_oauth_service_mock_solution.md](./technical/analysis/[DONE]_2025_12_19_google_oauth_service_mock_solution.md) | 19/12/2025 | Service mock en production | **CRITIQUE** | Suppression |
| [[DONE]_2025_12_19_omniauth_oauth_configuration_solution.md](./technical/analysis/[DONE]_2025_12_19_omniauth_oauth_configuration_solution.md) | 19/12/2025 | Configuration secrets fragile | **CRITIQUE** | Templates + robustesse |
| [[DONE]_2025_12_19_csrf_security_analysis_same_site_none.md](./technical/analysis/[DONE]_2025_12_19_csrf_security_analysis_same_site_none.md) | 19/12/2025 | Risque CSRF cookies | **CRITIQUE** | Session store désactivé |

### 📊 **Rapports d'Audit** (`docs/technical/audits/`)
Analyses techniques et historiques des modifications.

| Fichier | Type | Description |
|---------|------|-------------|
| [2025_12_17_ANALYSE_TECHNIQUE_FORESY.md](./technical/audits/2025_12_17_ANALYSE_TECHNIQUE_FORESY.md) | Analyse | Architecture technique et bonnes pratiques |
| [2025_12_17_CHANGELOG_REFACTORISATION.md](./technical/audits/2025_12_17_CHANGELOG_REFACTORISATION.md) | Historique | Chronologie des refactorisations et améliorations |

### 🛠️ **Corrections Techniques** (`docs/technical/corrections/`)
Résolutions de problèmes critiques et interventions majeures.

| Fichier | Date | Problème Résolu | Impact |
|---------|------|-----------------|--------|
| [[DONE]_2025_12_29_Feature-Contract-05-RSpec-Tests-Fix.md](./technical/corrections/[DONE]_2025_12_29_Feature-Contract-05-RSpec-Tests-Fix.md) | 29/12/2025 | **CRITIQUE** - Tests RSpec échouants pour FC-05 Rate Limiting (23/25 → 20/20) | **CRITIQUE** - 100% réussite tests feature sécurité |
| [[DONE]_2025_12_19_pgcrypto_elimination_solution.md](./technical/corrections/[DONE]_2025_12_19_pgcrypto_elimination_solution.md) | 19/12/2025 | **CRITIQUE** - Dépendance pgcrypto bloquant déploiement production | **CRITIQUE** - Compatibilité totale environnements managés |
| [[DONE]_2025_12_19_CI_Configuration_Fix_Resolution.md](./technical/corrections/[DONE]_2025_12_19_CI_Configuration_Fix_Resolution.md) | 19/12/2025 | CI complètement cassée (0 tests) | **MAJEUR** - Pipeline fonctionnel |

### 📋 **Templates de Configuration** (Racine)
Nouveaux templates de configuration OAuth ajoutés en décembre 2025.

| Fichier | Description | Environnement |
|---------|-------------|---------------|
| [.env.example](./.env.example) | Template configuration développement | **Développement** |
| [.env.test.example](./.env.test.example) | Template configuration tests | **Tests** |
| [.env.production.example](./.env.production.example) | Template configuration production | **Production** |

### 🐳 **Docker Operations** (`docs/technical/`)
Documentation complète pour la maintenance et les opérations Docker du projet Foresy.

| Fichier | Description | Dernière Mise à Jour |
|---------|-------------|---------------------|
| [2025_12_23_docker_operations_maintenance.md](./technical/2025_12_23_docker_operations_maintenance.md) | **GUIDE COMPLET** - Commandes Docker, health checks, troubleshooting, bonnes pratiques | **23/12/2025** - Post-restart web service |

**Services Docker Compose :**
- **web** : Rails API (port 3000) avec endpoints de santé
- **db** : PostgreSQL 15+ (port 5432) avec health check pg_isready
- **test** : Service de tests RSpec automatisés

**Health Endpoints Opérationnels :**
- **`GET /health`** : Health check de base
- **`GET /up`** : Service up status  
- **`GET /health/detailed`** : Informations système complètes

**Commandes Fréquentes :**
```bash
# Restart service web (le plus utilisé)
docker-compose restart web

# Lancer les tests
docker-compose up test

# Monitoring
docker-compose ps
docker-compose logs -f web

# Health check application
curl -f http://localhost:3000/health

# Health check base de données
docker-compose exec db pg_isready -U postgres
```

---

---

## 🔄 Réorganisation 18 Décembre 2025

### Problème Initial
La documentation était dispersée dans plusieurs endroits :
- `[DONE]_2025_12_19_CI_Configuration_Fix_Resolution.md` (anciennement à la racine du projet)
- `audit_report/` (dossier séparé)
- `docs/changes/` (nouveau journal chronologique)

### Solution Appliquée
Création d'une structure centralisée et logique sous `docs/` :
- **Centralisation** : Toute la documentation technique au même endroit
- **Organisation** : Séparation par type (projet, chronologique, audit, corrections)
- **Navigation** : Index principal avec liens vers tous les documents
- **Évolutivité** : Structure facilement extensible

### Fichiers Déplacés
```
# Corrections techniques
[DONE]_2025_12_19_CI_Configuration_Fix_Resolution.md → docs/technical/corrections/

# Rapports d'audit
audit_report/2025_12_17_ANALYSE_TECHNIQUE_FORESY.md → docs/technical/audits/
audit_report/2025_12_17_CHANGELOG_REFACTORISATION.md → docs/technical/audits/

# Journal chronologique
docs/changes/ → docs/technical/changes/

# Documentation GitHub
README.md reste à la racine pour compatibilité GitHub
```

### Ajouts 18 Décembre 2025 - Soir
Ajout du document de résolution GoogleOauthService :
```
# Nouveau document de correction
docs/technical/changes/[DONE]_2025_12_18_GoogleOauthService_Fix_Resolution.md
```

---

## 🎯 Utilisation de la Documentation

### 👨‍💻 **Pour les Développeurs**
1. **Commencer par** : [README.md racine](../README.md)
2. **Pour l'état actuel** : [Corrections GoogleOauthService 18/12/2025](./technical/changes/[DONE]_2025_12_18_GoogleOauthService_Fix_Resolution.md)
3. **Pour l'architecture** : [Analyse Technique](./technical/audits/2025_12_17_ANALYSE_TECHNIQUE_FORESY.md)

### 🔧 **Pour les Corrections**
1. **Problème actuel** : [GoogleOauthService 18/12/2025](./technical/changes/[DONE]_2025_12_18_GoogleOauthService_Fix_Resolution.md) - **RÉSOLU**
2. **Journal chronologique** : [Correction CI 18/12/2025](./technical/changes/[DONE]_2025_12_18_CI_Fix_Resolution.md)
3. **Problèmes précédents** : [Corrections 19 Décembre 2025](./technical/corrections/[DONE]_2025_12_19_CI_Configuration_Fix_Resolution.md)
4. **Continuer le travail** : Ajouter un nouveau fichier daté dans `technical/changes/`

### 📊 **Pour la Maintenance**
1. **Métriques actuelles** : Voir [Correction CI 18/12/2025](./technical/changes/[DONE]_2025_12_18_CI_Fix_Resolution.md)
2. **Historique des problèmes** : [Changelog Refactorisation](./technical/audits/2025_12_17_CHANGELOG_REFACTORISATION.md)
3. **Standards du projet** : [Analyse Technique](./technical/audits/2025_12_17_ANALYSE_TECHNIQUE_FORESY.md)

---

## 📋 Standards de Documentation

### 🎯 **Conventions de Nommage**
- **Corrections** : `YYYY-MM-DD-Titre_Descriptif.md`
- **Analyses** : `TYPE_Projet.md`
- **Historiques** : `Changelog_Description.md`
- **Guides** : `README.md` ou `Guide_Nom.md`

### 📝 **Standards de Qualité**
- **Tests obligatoires** : RSpec + Rubocop + Brakeman
- **Reproductibilité** : Commandes Docker et scripts inclus
- **Traçabilité** : Dates, versions, responsables documentés
- **Continuité** : Liens vers documents précédents

### 🔧 **Processus de Documentation**
1. **Avant** : Identifier le type de modification
2. **Pendant** : Documenter avec exemples et commandes
3. **Après** : Mettre à jour ce index si nécessaire
4. **Révision** : Valider avec tests de qualité

---

## 🏷️ Tags et Catégories

### 🔧 **Types de Documents**
- **🔧 FIX** : Corrections de bugs et problèmes critiques
- **🚀 FEATURE** : Nouvelles fonctionnalités
- **📚 DOC** : Documentation et guides
- **⚡ PERF** : Optimisations de performance
- **🔒 SECURITY** : Modifications de sécurité
- **🧪 TEST** : Amélioration des tests
- **⚙️ CONFIG** : Changements de configuration

### 📊 **Niveaux d'Impact**
- **CRITIQUE** : Problèmes bloquants, CI cassée
- **MAJEUR** : Fonctionnalités importantes, refactorisations
- **MINEUR** : Améliorations, optimisations
- **INFO** : Documentation, guides

---

## 🎯 Prochaines Étapes

### 📝 **Ajout de Nouvelle Documentation**
1. **Déterminer la catégorie** (changes, audits, corrections)
2. **Créer le fichier** avec la convention de nommage appropriée
3. **Documenter** selon les standards établis
4. **Mettre à jour** ce index si nécessaire

### 🔄 **Maintenance Continue**
1. **Révision périodique** de la pertinence des documents
2. **Mise à jour** des liens et références
3. **Archivage** des documents obsolètes
4. **Validation** de la cohérence de la structure

---

## 📞 Support et Contact

Pour toute question sur la documentation :
1. **Vérifier** ce index pour la navigation
2. **Consulter** le document le plus récent dans la catégorie appropriée
3. **Utiliser** les liens de navigation fournis
4. **Ajouter** une note dans le journal chronologique si nécessaire

---

## 🔒 Sécurité des Secrets (19 Décembre 2025)

### Configuration GitHub Secrets Requise
Pour que la CI fonctionne, les secrets suivants doivent être configurés dans **GitHub Repository Settings > Secrets and variables > Actions** :

| Secret | Description | Génération |
|--------|-------------|------------|
| `SECRET_KEY_BASE` | Clé Rails pour environnement test | `rails secret` |
| `JWT_SECRET` | Clé JWT pour authentification | `openssl rand -hex 64` |
| `GOOGLE_CLIENT_ID` | Client ID Google OAuth | Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | Client Secret Google OAuth | Google Cloud Console |
| `LOCAL_GITHUB_CLIENT_ID` | Client ID GitHub OAuth | GitHub Developer Settings |
| `LOCAL_GITHUB_CLIENT_SECRET` | Client Secret GitHub OAuth | GitHub Developer Settings |

> ⚠️ **IMPORTANT** : Ne jamais committer de secrets en clair dans le repository. Voir [[DONE]_2025_12_19_Security_CI_Complete_Fix.md](./technical/changes/[DONE]_2025_12_19_Security_CI_Complete_Fix.md) pour les détails.

---

**Index maintenu par :** Équipe Foresy  
**Dernière révision :** 20 décembre 2025  
**Version :** 1.5
**Statut :** ✅ Actif et maintenu