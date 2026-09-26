# Foresy API

🚀 **Production Live:** https://foresy-api.onrender.com  
🔒 **Security:** Stateless JWT, no token logging, no cookies  
⚡ **Stack:** Ruby 3.4.8 + Rails 8.1.3.1  
🗄️ **Database:** PostgreSQL (Supabase)  

Foresy est une application Ruby on Rails API-only qui fournit une API RESTful robuste pour la gestion des utilisateurs, des missions professionnelles et des Comptes Rendus d'Activité (CRA), avec authentification JWT et support OAuth (Google & GitHub). Conçue pour les travailleurs indépendants.

## 🚀 Vue d'Ensemble

### 🎯 État Actuel (Septembre 2026)
- **v0.1.4** : ✅ FC-05 Rate Limiting — remediation contractuelle (contrat → RED mesurés → GREEN → R-4, PR #56) — 429 uniquement sur dépassement réel, backend distribué Redis
- **v0.1.3** : ✅ P7 System Specs API CLOSED — contrat système (3ᵉ contrat) établi, bug de composition mission_id corrigé (PR #42)
- **v0.1.2** : ✅ Campagne P6 Waves 1-4 + hygiène documentaire + P6.6 CLOSED (PR #35-#41)
- **v0.1.1** : ✅ FC-08 Companies + vague dette D-1→D-11 fermée + SimpleCov (PR #24-#29)
- **v0.1.0** : ✅ Remédiation Architecture complète (25/25 tâches TDD/DDD/Platinum)
- **Feature Contract 01 (OAuth)** : ✅ Google & GitHub authentication
- **Feature Contract 02 (Auth Email/Password)** : ✅ JWT stateless + refresh tokens
- **Feature Contract 03 (Rails Upgrade)** : ✅ Rails 7.1.5.1 → 8.1.3.1 + Ruby 3.4.8
- **Feature Contract 04 (Token Revocation)** : ✅ Revoke + revoke_all endpoints
- **Feature Contract 05 (Rate Limiting)** : ✅ Login/Signup/Refresh/Missions/CRAs
- **Feature Contract 06 (Missions)** : ✅ CRUD complet + lifecycle
- **Feature Contract 07 (CRA)** : ✅ 100% TERMINÉ — TDD PLATINUM + Filtering + CSV Export
- **Feature Contract 08 (Companies & User-Company)** : ✅ TERMINÉ — CRUD, onboarding atomique, SIREN obligatoire, soft delete (PR #24)
- **Architecture** : ✅ DDD/RDD finalisée — relations via tables pivot, plus de FK directes
- **Dette D-1→D-11** : ✅ **100 % fermée** (vague corrective PR #25-#29) — A6 close, D-11 résolue, D-12 (E2E shell CI) tracée au registre
- **Couverture** : 📊 SimpleCov **85.36 % lignes / 60.23 % branches** (3091/3621 · 918/1524) — suite 1166 verts, verrou 72,5 armé dans le processus RSpec réel, rapport HTML + Cobertura XML
- **Sécurité** : ✅ JWT stateless, OAuth Google/GitHub, 0 vulnérabilité bundle audit
- **Contrat d'erreur** : ✅ Format unifié `{ code, message, details }` sur tous les endpoints

### 📈 Historique des Accomplissements
| Version | Date | Tests | Événements Majeurs |
|---------|------|-------|-------------------|
| v0.0.1 | Déc 2025 | 97 | OAuth + E2E + token revocation (FC-01, FC-02, FC-04) |
| v0.0.2 | 26 Déc 2025 | 221 | Rails 8.1.1 migration (FC-03) |
| v0.0.3 | 29 Déc 2025 | 290 | Rate Limiting Platinum (FC-05) + FC-06 Missions |
| v0.1.0-fc07 | 7 Jan 2026 | 449 | FC-07 CRA complet + Mini-FC (TDD Platinum) |
| **v0.1.0** | **18 Août 2026** | **863** | **Remédiation Architecture (25 tâches) + DDD finalisé + Supabase** |
| **v0.1.1** | **16-17 Sept 2026** | **957** | **FC-08 Companies + vague dette D-1→D-11 + SimpleCov + durcissement CI (PR #24-#29)** |
| **v0.1.2** | **19-21 Sept 2026** | **1150** | **Campagne P6 : Waves 1-4 + hygiène documentaire + P6.6 CLOSED — 2 bugs prod corrigés, 144 specs (PR #35-#41)** |
| **v0.1.3** | **21-22 Sept 2026** | **1154** | **P7 System Specs API CLOSED — contrat système, bug de composition mission_id corrigé (PR #42)** |
| **v0.1.4** | **26 Sept 2026** | **1166** | **FC-05 Rate Limiting remediation — contrat → RED mesurés (10) → GREEN → R-4 (limiter parallèle supprimé, backend distribué) (PR #56)** |

### 🏆 Certifications & Standards
- **TDD PLATINUM** : Domaine CRA auto-défensif, cycle RED → GREEN → REFACTOR par tâche
- **DDD/RDD Architecture** : Migration complète — tables pivot, plus de FK directes, scopes explicites
- **Code Quality** : RuboCop 246 files 0 offenses, Brakeman 0 warnings (mode strict en CI), Bundle audit 0 vulnérabilités
- **CI/CD** : 6/6 jobs verts + 0 annotation — E2E bloquant dans la Quality Gate, Brakeman strict, gate DDD explicite, assertion Cobertura, actions Node 24

## ⚡ Fonctionnalités

### Sécurité & Authentification

#### JWT (JSON Web Tokens)
- **Authentification stateless** : Sans sessions serveur, tokens dans headers Authorization
- **Token Refresh** : Système automatique de rafraîchissement avec `refresh_token`
- **Sécurité renforcée** : Aucun logging de tokens, masquage IP
- **Revocation** : `DELETE /revoke` et `DELETE /revoke_all` pour invalidation

#### OAuth 2.0 (Google & GitHub)
- **Intégration complète** : Google OAuth2 + GitHub
- **Tests validés** : 31 tests d'acceptance + intégration
- **Gestion d'erreurs** : Format standardisé `{ code, message, details }`

#### Architecture Stateless & CSRF
- **100% stateless** : Suppression middlewares Cookie/Session
- **Protection CSRF** : Session store désactivé
- **Routes E2E verrouillées** : `__test_support__` inaccessible en production (défense en profondeur)

#### Rate Limiting
- **Login** : 5 requêtes/minute
- **Signup** : 3 requêtes/minute
- **Token Refresh** : 10 requêtes/minute
- **Missions/CRAs** : Protection contre attaques par force brute

### Gestion des Utilisateurs
- **Inscription/Connexion** : API REST pour l'authentification utilisateur
- **Multi-provider** : Support Google et GitHub unifié
- **Validation robuste** : Contraintes d'unicité et validations métier

### Gestion des Missions (Feature Contract 06)
- **CRUD Missions** : Création, lecture, modification, archivage
- **Types de mission** : Time-based (TJM) et Fixed-price (forfait)
- **Lifecycle** : lead → pending → won → in_progress → completed
- **Architecture DDD** : Relations via tables dédiées (MissionCompany, UserMission)
- **Thin controller** : Logique métier déléguée à `MissionServices::*` (pattern `ApplicationResult`)

### Gestion des CRA (Feature Contract 07) 🏆 TDD PLATINUM
- **CRUD CRA** : Création, lecture, modification, archivage
- **CRUD CRA Entries** : Gestion des entrées d'activité par mission et date
- **Lifecycle strict** : draft → submitted → locked (immutable)
- **Git Ledger** : Versioning Git pour l'immutabilité légale (Open3.capture3, anti-injection shell)
- **Calculs serveur** : total_days, total_amount calculés côté serveur uniquement
- **Montants en centimes** : Précision financière (Integer, pas de Float)
- **Soft delete** : Avec règles métier (impossible si CRA submitted/locked)
- **Export CSV** : `GET /api/v1/cras/:id/export` avec option `include_entries`
- **Filtrage** : Par year, month, status

### Contrat d'Erreur Standardisé
- **Format unifié** : `{ code, message, details }` sur tous les endpoints
- **Codes standardisés** : BAD_REQUEST, UNAUTHORIZED, FORBIDDEN, NOT_FOUND, CONFLICT, UNPROCESSABLE_ENTITY, TOO_MANY_REQUESTS, INVALID_PAYLOAD, INTERNAL_SERVER_ERROR
- **Masquage production** : `error_internal` masque les détails en prod, les expose en dev/test
- 📖 [Documentation complète](docs/technical/guides/2026_08_18_error_contract.md)

### Documentation & Qualité
- **Swagger/OpenAPI** : 402 specs RSwag, audit 35/35 routes documentées
- **Tests complets** : 1166 exemples RSpec (0 failures, 0 pending)
- **Couverture** : 📊 SimpleCov **85.36 % lignes / 60.23 % branches** (rapport HTML + Cobertura XML)
- **Code quality** : RuboCop 245 files, 0 offenses
- **Security audit** : Brakeman 0 warnings (mode strict), Bundle audit 0 vulnérabilités
- **Collection Postman** : 28 endpoints avec scripts de test automatisés

## 🏗️ Architecture

### Stack Technology
- **Ruby** : 3.4.8
- **Ruby on Rails** : 8.1.3.1 (API-only)
- **Base de données** : PostgreSQL (Supabase — permanent, free tier)
- **Cache** : Redis pour les sessions et performances
- **Authentification** : JWT avec tokens stateless
- **OAuth** : OmniAuth pour Google et GitHub
- **Documentation** : Swagger via rswag (402 specs)
- **Module Rails** : `Foresy` (renommé depuis `App`)
- **config.load_defaults** : 8.1

### Architecture DDD/RDD (Domain-Driven / Relation-Driven Design)
- ❌ **Aucune FK directe** entre entités métier
- ✅ **Tables pivot explicites** : UserCompany, MissionCompany, UserMission, UserCra, CraMission, CraEntryCra, CraEntryMission
- ✅ **Services applicatifs** : `CraServices::*`, `MissionServices::*`, `CraEntryServices::*` retournent `ApplicationResult`
- ✅ **Thin controllers** : Tous les contrôleurs héritent de `Api::V1::BaseController`
- ✅ **Scopes explicites** : `active` / `deleted` / `with_deleted` (Company, UserCompany — convention FC-08) ; `only_deleted` conservé sur CRA (FC-07) — remplacement `default_scope`
- ✅ **Créateur via pivot** : `creator_user_id` lit via `user_cras`/`user_missions` (role: 'creator')

### Structure API
```
/api/v1/
├── auth/
│   ├── login             # Authentification JWT
│   ├── logout            # Déconnexion
│   ├── refresh           # Rafraîchissement token
│   ├── revoke            # Révocation token courant
│   ├── revoke_all        # Révocation tous les tokens
│   ├── failure           # Gestion échecs OAuth
│   └── :provider/callback # OAuth (google_oauth2, github)
├── signup                # Inscription utilisateur
├── missions/             # CRUD missions (5 endpoints)
├── cras/                 # CRUD + submit + lock + export (8 endpoints)
│   └── :cra_id/entries/  # CRUD entries (5 endpoints)
├── companies/            # CRUD + onboarding atomique FC-08 (5 endpoints)
├── user_companies/       # Relations user↔company, rôles, soft delete (5 endpoints)
└── health                # Health check
```

## 🧪 Tests & Qualité

### Statistiques Actuelles (Septembre 2026)
- **Tests RSpec** : ✅ **1166 examples, 0 failures, 0 pending**
- **Tests Rswag** : ✅ **429 examples** — audit 35/35 routes
- **RuboCop** : ✅ **246 files, 0 offenses**
- **Brakeman** : ✅ **0 Security Warnings** (mode strict — tout warning non ignoré échoue)
- **Bundle audit** : ✅ **0 vulnerabilities** (Rails 8.1.3.1, puma 8.0.2)
- **Smoke tests E2E** : ✅ **15/15 passed**
- **GitLedger integration** : ✅ **23 tests** (intégration 13 + sécurité injection 10, env isolé)
- **Couverture (SimpleCov)** : 📊 **85.36 % lignes (3091/3621) / 60.23 % branches (918/1524)** — rapport HTML + Cobertura XML
- **CI/CD** : ✅ **6/6 jobs verts, 0 annotation** — E2E bloquant dans la Quality Gate, Brakeman strict, gate DDD explicite

### 📈 Évolution des Métriques de Tests
| Version | Date | Tests RSpec | Événements |
|---------|------|-------------|------------|
| v0.0.1 | Déc 2025 | 97 | OAuth + E2E + token revocation |
| v0.0.2 | 26 Déc 2025 | 221 | Rails 8.1.1 migration |
| v0.0.3 | 29 Déc 2025 | 290 | FC-05 Rate Limiting + FC-06 Missions |
| v0.1.0-fc07 | 7 Jan 2026 | 449 | FC-07 CRA + Mini-FC |
| **v0.1.0** | **18 Août 2026** | **863** | **Remédiation Architecture (25 tâches)** |
| **v0.1.1** | **16-17 Sept 2026** | **957** | **FC-08 Companies + vague dette D-1→D-11 + SimpleCov baseline** |
| **v0.1.2** | **19-21 Sept 2026** | **1150** | **Campagne P6 : Waves 1-4 + hygiène documentaire + P6.6 CLOSED — 2 bugs prod corrigés, 144 specs (PR #35-#41)** |
| **v0.1.3** | **21-22 Sept 2026** | **1154** | **P7 System Specs API CLOSED — contrat système, bug de composition mission_id corrigé (PR #42)** |
| **v0.1.4** | **26 Sept 2026** | **1166** | **FC-05 remediation : RED contractuels (10) → GREEN + R-4 (limiter parallèle supprimé, distribué Redis) (PR #56)** |

## 🚀 Déploiement & Configuration

### Prérequis
- Docker & Docker Compose
- Ruby 3.4.8 + Rails 8.1.3.1

### Installation

1. **Cloner le repository**
   ```bash
   git clone <repository-url>
   cd Foresy
   ```

2. **Lancer l'application**
   ```bash
   docker-compose up -d
   ```

3. **Initialiser la base de données**
   ```bash
   docker compose exec web bundle exec rails db:setup
   ```

4. **Vérifier le statut**
   ```bash
   docker compose exec web curl -s localhost:3000/health
   ```

### Tests

```bash
# Suite complète RSpec
docker compose exec web bundle exec rspec

# Qualité du code
docker compose exec web bundle exec rubocop

# Audit de sécurité
docker compose exec web bundle exec brakeman
docker compose exec web bundle exec bundle audit check --update

# Smoke tests
docker compose exec web ./bin/e2e/smoke_test.sh

# Test GitLedger (environnement isolé)
docker compose exec web bundle exec rails runner scripts/test_git_ledger.rb
```

### Base de données — Supabase

L'API utilise **Supabase** (PostgreSQL managed) en production pour éviter l'expiration du free tier Render (90 jours).

📖 [Stratégie de migration DB](docs/technical/guides/[DONE]_2026_08_18_migration_strategy.md)

### Configuration OAuth

**Variables d'environnement requises :**
```bash
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
LOCAL_GITHUB_CLIENT_ID=your_github_client_id
LOCAL_GITHUB_CLIENT_SECRET=your_github_client_secret
JWT_SECRET=your_jwt_secret_key
```

📖 [Configuration GitHub Secrets (CI/CD)](docs/index.md)

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [Contrat d'erreur](docs/technical/guides/2026_08_18_error_contract.md) | Format unifié, tous les codes, migration clients |
| [Stratégie migration DB](docs/technical/guides/[DONE]_2026_08_18_migration_strategy.md) | Squash, commandes, réversibilité |
| [Git Ledger](docs/technical/guides/2026_08_18_git_ledger_operations.md) | Permissions, sécurité, checklist staging |
| [Plan de remédiation](docs/technical/audits/[DONE]_2026_07_22_Architecture_Debt_Audit_and_Plan.md) | Audit 25 points + 25 tâches (100% terminé) |
| [Release notes v0.1.0](docs/RELEASE_NOTES_v0.1.0.md) | Breaking changes, nouveautés, déploiement |
| [Collection Postman](docs/postman/Foresy_API.postman_collection.json) | 28 endpoints avec scripts de test |
| [BACKLOG](docs/BACKLOG.md) | Backlog transverse et tâches restantes |
| [Index documentation](docs/index.md) | Navigation centrale |

## 📊 Monitoring & Observabilité

### Health Checks
- `GET /health` : Health check de l'application
- `GET /up` : Health check Rails
- `GET /api-docs` : Documentation Swagger interactive

## 📝 Changelog

### v0.1.4 (26 Septembre 2026) — FC-05 Rate Limiting : Remediation contractuelle 🏆
- 📜 **Contrat FC-05 v1** (`docs/technical/guides/[DONE]_2026_09_25_fc05_rate_limiting_contract.md`) : arbitrages A1-A9 (CTO) — 6 états de sélection · fallback Memory + warning · 429 uniquement sur dépassement réel · seuils contractuels missions/cras/entries
- 🔍 **Investigation #20** : 3 causes démontrées + runtime (audit `[DONE]_2026_09_25_fc05_rate_limiting_audit.md`) — sélecteur inconditionnel · increment! orphelin · LIMITS['missions'] absent
- 🔴→🟢 **RED mesurés (12 exemples, 10 échecs documentés) → GREEN (12/12)** — la preuve fonctionnelle est la chaîne RED → GREEN, pas la couverture
- 🔁 **R-4** : limiter parallèle `RedisRateLimiter` (compteur orphelin) supprimé, contrôleurs unifiés sur `RateLimitService` (clé user_id) — net −227 lignes
- 🛡️ **Production vérifiée** : REDIS_URL injectée · deploy live `3f974dc` (Event 12:18) · sondage 401×5 → 429 RATE_LIMIT_EXCEEDED (payload contrat) · 0 RedisConfigurationError · plan free = 1 instance
- 📊 **85.36 % lignes (3091/3621) / 60.23 % branches (918/1524)** — verrou 72,5 ✓ · RuboCop 0 · 1166/0
- CI PR : 6/6 verts (runs 36233661450 et 375) · incident Setup database run 373 = transitoire (clos)

### v0.1.3 (21-22 Septembre 2026) — P7 System Specs API CLOSED : Contrat Système établi 🏆
- 🧪 **4 system specs** ajoutées (`spec/system/`) : CRA lifecycle complet avec **Git Ledger réel** (UC-4) · échec infra → rollback complet → récupération (UC-9) · garde duplicate cross-pivots 409 (UC-5) · compensation mission inexistante (UC-5)
- 🐛 **1 bug de composition corrigé** : `POST /entries` avec `mission_id` → 201 sans pivot `CraEntryMission` (champ extrait mais perdu avant le service) + `.to_i` corrompant les UUID en 0 — défaut invisible des couches Unit/Services/Request, démontré par le premier system spec (RED → fix minimal +3/−3 → GREEN)
- 🔁 **UC-3 (Company onboarding)** : 0 nouvelle spec — propriétés déjà garanties par les request specs avec assertions DB (scénarios 2/3/8/9/11/12) ; échec étape 2 de la transaction naturellement injoignable
- 📊 **84.37 % lignes (3121/3699) / 57.74 % branches (902/1562)** — verrou 72,5 inchangé · RuboCop 0 · Brakeman 0
- 📋 **Règles P7** : zéro mock/stub métier · Ledger réel (D-12) · échecs par infrastructure/configuration · State, pas implementation · arrêt sur valeur de composition (D3 non justifié)
- 🏷️ **Hygiène** : préfixes `[DONE]_` appliqués aux docs fermés de la campagne P6/P7 (7 documents testing/)
- CI PR : 6/6 verts (PR #42)

### v0.1.2 (19-21 Septembre 2026) — Campagne P6 : Waves 1-4 + Hygiène documentaire + P6.6 CLOSED 🏆
- 📊 **136+8 specs** ajoutées : CraServices::List (24,62→96,92 %), Git Ledger (100 %), services/lib, contrôleurs, concerns, modèles/pivots
- 🐛 **2 bugs production corrigés** : GET /api/v1/cras = 500 (ApplicationResult sans data:), Company#country_name NameError (ISO3166 jamais déclaré)
- 🧹 **Nettoyage OAuth** : 7 méthodes mortes supprimées (zéro appelant — corpus −28 lignes)
- 📋 **Hygiène documentaire** : 148 docs migrés vers YYYY_MM_DD_ + [DONE]_/[Obsolete]_ · BACKLOG transverse relancé · ROADMAP aligné · hub RAG réindexé
- 📏 **P6.6 CLOSED** : 84,21 % lignes (3115/3699) · 57,41 % branches (898/1564) · verrou 72,5 armé dans le processus réel
- 📋 **Dettes tracées** : BACKLOG #13 (branch protection) · #14 (arbre mergé) · #15 (RSwag 'name') · #16 (validate_uniqueness) · D3-3 (reporté) · P1 (recommandé) · link-rot
- CI PR : 6/6 verts (runs 35611220178 et 35646923309)

### v0.1.1 (16-17 Septembre 2026) — FC-08 Companies + Fermeture de la dette technique 🏆
- 🏢 **FC-08 v3.2.3** : Companies & User-Company Relationships — CRUD, onboarding atomique
  (Company + UserCompany en une transaction, INV-16/17), SIREN obligatoire/unique, soft delete,
  Swagger 10 schémas (PR #24)
- 🛠️ **Vague dette D-1→D-11 fermée** (PR #25-#28) : scripts E2E réparés et rejouables (D-4),
  RuboCop 0-offense restauré (A1), journal exact (A4), identité Git humaine + conteneur
  auto-réparant (A6), Node 24 — checkout@v5 + upload-artifact@v7 (D-11), chiffrage SimpleCov,
  D-12 tracée (E2E shell hors CI)
- 📊 **SimpleCov** (D-2, PR #29) : lignes + branches, baseline **72.78 % lignes / 44.82 % branches**,
  rapport HTML + Cobertura XML, guide 2026_09_16_line_coverage.md
- 🛡️ **CI durcie** (revue co-CTO) : E2E bloquant dans la Quality Gate, Brakeman strict,
  gate DDD explicite 🏛️, assertion bloquante coverage.xml — **6/6 verts + 0 annotation**
- ✅ **957 tests**, 0 failures — registre de dette à jour (`docs/technical/2026_09_14_fc08_debt_register.md`)

### v0.1.0 (18 Août 2026) — Remédiation Architecture + DDD Finalisé 🏆
- 🏗️ **25/25 tâches** de remédiation architecture (P0-P6) en TDD strict
- 🔒 **Sécurité** : Routes E2E verrouillées, puts JWT supprimés, GitLedger Open3 (anti-injection)
- 📐 **Unification erreurs** : 3 formats → 1 format `{ code, message, details }`
- 🗑️ **Nettoyage** : ~3162 lignes de code mort supprimées
- 🏗️ **DDD finalisé** : `default_scope` supprimé, `created_by_user_id` → tables pivot
- 🗄️ **DB** : UUID natif PostgreSQL, enum PG, migration squashed (16 → 1)
- ⚙️ **Config** : Module `App` → `Foresy`, `load_defaults` 8.1
- 📦 **Gems** : Rails 8.1.3.1, puma 8.0.2 — 0 vulnérabilités
- 🗄️ **Supabase** : Migration DB Render → Supabase (permanent)
- ✅ **863 tests**, 0 failures, RuboCop 0 offenses, CI 6/6 verts

### v0.1.0-fc07 (7 Janvier 2026) — Feature Contract 07: CRA 100% TERMINÉ
- 🎉 FC-07 complet : CRUD CRA + Entries + Filtering + CSV Export
- 🏆 TDD PLATINUM certifié, 449 tests GREEN
- 📤 Mini-FC-02 CSV Export avec UTF-8 BOM
- 🔍 Mini-FC-01 Filtering par year, month, status

### v0.0.3 (29 Décembre 2025) — FC-05 Rate Limiting + FC-06 Missions
- 🛡️ Rate Limiting Platinum (FC-05)
- 🎯 Missions CRUD complet (FC-06), lifecycle, access control
- ✅ 290 tests, PR #12 merged

### v0.0.2 (26 Décembre 2025) — Rails 8.1.1 Migration (FC-03)
- 🚀 Rails 7.1.5.1 → 8.1.1, Ruby 3.3.0 → 3.4.8
- 🐳 Docker optimisé multi-stage
- ✅ 221 tests

### v0.0.1 (Décembre 2025) — OAuth + E2E + Token Revocation (FC-01, FC-02, FC-04)
- 🔐 OAuth Google & GitHub (FC-01)
- 🔑 Auth email/password + JWT (FC-02)
- 🚫 Token revocation E2E (FC-04)
- ✅ 97 tests, CI/CD opérationnel

## 🤝 Contribution

1. **Fork** le repository
2. **Créer** une feature branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** les changements (`git commit -m 'Add AmazingFeature'`)
4. **Push** vers la branch (`git push origin feature/AmazingFeature`)
5. **Ouvrir** une Pull Request

### Standards de Contribution
- ✅ Tests requis (TDD : RED → GREEN → REFACTOR)
- ✅ RuboCop compliance (0 violation)
- ✅ Documentation mise à jour
- ✅ PR description claire avec context et tests

## 📄 License

Ce projet est sous license MIT. Voir le fichier `LICENSE` pour plus de détails.

---

**Foresy API** — API Rails moderne, sécurisée et validée par les gates Platinium actuelles (1166 tests verts, CI 6/6 bloquante incl. E2E). Architecture DDD/RDD, couverture mesurée (85,36 % lignes / 60,23 % branches, verrou 72,5 armé), contrat système établi (P7), FC-05 rate limiting certifié (PR #56), dettes résiduelles explicitement tracées (D-12, BACKLOG transverse).