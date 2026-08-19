# Foresy API

🚀 **Production Live:** https://foresy-api.onrender.com  
🔒 **Security:** Stateless JWT, no token logging, no cookies  
⚡ **Stack:** Ruby 3.4.8 + Rails 8.1.3.1  
🗄️ **Database:** PostgreSQL (Supabase)  

Foresy est une application Ruby on Rails API-only qui fournit une API RESTful robuste pour la gestion des utilisateurs, des missions professionnelles et des Comptes Rendus d'Activité (CRA), avec authentification JWT et support OAuth (Google & GitHub). Conçue pour les travailleurs indépendants.

## 🚀 Vue d'Ensemble

### 🎯 État Actuel (Août 2026)
- **v0.1.0** : ✅ Remédiation Architecture complète (25/25 tâches TDD/DDD/Platinum)
- **Feature Contract 01 (OAuth)** : ✅ Google & GitHub authentication
- **Feature Contract 02 (Auth Email/Password)** : ✅ JWT stateless + refresh tokens
- **Feature Contract 03 (Rails Upgrade)** : ✅ Rails 7.1.5.1 → 8.1.3.1 + Ruby 3.4.8
- **Feature Contract 04 (Token Revocation)** : ✅ Revoke + revoke_all endpoints
- **Feature Contract 05 (Rate Limiting)** : ✅ Login/Signup/Refresh/Missions/CRAs
- **Feature Contract 06 (Missions)** : ✅ CRUD complet + lifecycle
- **Feature Contract 07 (CRA)** : ✅ 100% TERMINÉ — TDD PLATINUM + Filtering + CSV Export
- **Architecture** : ✅ DDD/RDD finalisée — relations via tables pivot, plus de FK directes
- **Tests** : 863 exemples RSpec verts (0 failures, 0 pending)
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

### 🏆 Certifications & Standards
- **TDD PLATINUM** : Domaine CRA auto-défensif, cycle RED → GREEN → REFACTOR par tâche
- **DDD/RDD Architecture** : Migration complète — tables pivot, plus de FK directes, scopes explicites
- **Code Quality** : RuboCop 225 files 0 offenses, Brakeman 0 warnings, Bundle audit 0 vulnérabilités
- **CI/CD** : 6/6 jobs verts (Tests, RuboCop, Security, Contracts, E2E, Quality Gate)

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
- 📖 [Documentation complète](docs/technical/guides/error_contract.md)

### Documentation & Qualité
- **Swagger/OpenAPI** : 248 specs RSwag, audit 25/25 routes documentées
- **Tests complets** : 863 exemples RSpec (0 failures, 0 pending)
- **Code quality** : RuboCop 225 files, 0 offenses
- **Security audit** : Brakeman 0 warnings, Bundle audit 0 vulnérabilités
- **Collection Postman** : 28 endpoints avec scripts de test automatisés

## 🏗️ Architecture

### Stack Technology
- **Ruby** : 3.4.8
- **Ruby on Rails** : 8.1.3.1 (API-only)
- **Base de données** : PostgreSQL (Supabase — permanent, free tier)
- **Cache** : Redis pour les sessions et performances
- **Authentification** : JWT avec tokens stateless
- **OAuth** : OmniAuth pour Google et GitHub
- **Documentation** : Swagger via rswag (248 specs)
- **Module Rails** : `Foresy` (renommé depuis `App`)
- **config.load_defaults** : 8.1

### Architecture DDD/RDD (Domain-Driven / Relation-Driven Design)
- ❌ **Aucune FK directe** entre entités métier
- ✅ **Tables pivot explicites** : UserCompany, MissionCompany, UserMission, UserCra, CraMission, CraEntryCra, CraEntryMission
- ✅ **Services applicatifs** : `CraServices::*`, `MissionServices::*`, `CraEntryServices::*` retournent `ApplicationResult`
- ✅ **Thin controllers** : Tous les contrôleurs héritent de `Api::V1::BaseController`
- ✅ **Scopes explicites** : `active`, `with_deleted`, `only_deleted` (remplacement `default_scope`)
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
└── health                # Health check
```

## 🧪 Tests & Qualité

### Statistiques Actuelles (Août 2026)
- **Tests RSpec** : ✅ **863 examples, 0 failures, 0 pending**
- **Tests Rswag** : ✅ **248 examples** — audit 25/25 routes
- **RuboCop** : ✅ **225 files, 0 offenses**
- **Brakeman** : ✅ **0 Security Warnings**
- **Bundle audit** : ✅ **0 vulnerabilities** (Rails 8.1.3.1, puma 8.0.2)
- **Smoke tests E2E** : ✅ **15/15 passed**
- **GitLedger integration** : ✅ **13 tests** (init, commit, verify, injection shell, cleanup)

### 📈 Évolution des Métriques de Tests
| Version | Date | Tests RSpec | Événements |
|---------|------|-------------|------------|
| v0.0.1 | Déc 2025 | 97 | OAuth + E2E + token revocation |
| v0.0.2 | 26 Déc 2025 | 221 | Rails 8.1.1 migration |
| v0.0.3 | 29 Déc 2025 | 290 | FC-05 Rate Limiting + FC-06 Missions |
| v0.1.0-fc07 | 7 Jan 2026 | 449 | FC-07 CRA + Mini-FC |
| **v0.1.0** | **18 Août 2026** | **863** | **Remédiation Architecture (25 tâches)** |

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

📖 [Stratégie de migration DB](docs/technical/guides/migration_strategy.md)

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
| [Contrat d'erreur](docs/technical/guides/error_contract.md) | Format unifié, tous les codes, migration clients |
| [Stratégie migration DB](docs/technical/guides/migration_strategy.md) | Squash, commandes, réversibilité |
| [Git Ledger](docs/technical/guides/git_ledger_operations.md) | Permissions, sécurité, checklist staging |
| [Plan de remédiation](docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md) | Audit 25 points + 25 tâches (100% terminé) |
| [Release notes v0.1.0](docs/RELEASE_NOTES_v0.1.0.md) | Breaking changes, nouveautés, déploiement |
| [Collection Postman](docs/postman/Foresy_API.postman_collection.json) | 28 endpoints avec scripts de test |
| [BACKLOG](docs/BACKLOG.md) | Roadmap produit et tâches restantes |
| [Index documentation](docs/index.md) | Navigation centrale |

## 📊 Monitoring & Observabilité

### Health Checks
- `GET /health` : Health check de l'application
- `GET /up` : Health check Rails
- `GET /api-docs` : Documentation Swagger interactive

## 📝 Changelog

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

**Foresy API** — API Rails moderne, sécurisée et entièrement testée. Architecture DDD/RDD, 863 tests verts, 0 vulnérabilités. Prête pour la production.