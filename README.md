# Foresy API

🚀 **Production Live:** https://foresy-api.onrender.com  
🔒 **Security:** Stateless JWT, no token logging, no cookies  
⚡ **Stack:** Ruby 3.4.8 + Rails 8.1.1

Foresy est une application Ruby on Rails API-only qui fournit une API RESTful robuste pour la gestion des utilisateurs, des missions professionnelles, avec authentification JWT et support OAuth (Google & GitHub). Conçue pour les travailleurs indépendants.

## 🚀 Vue d'Ensemble

### 🎯 État Actuel (Janvier 2026)
- **Feature Contract 07 (CRA)** : ✅ 100% TERMINÉ - 449 tests GREEN, TDD PLATINUM
- **Feature Contract 06 (Missions)** : ✅ Opérationnel avec CRUD complet
- **Feature Contract 05 (Rate Limiting)** : ✅ OPÉRATIONNEL
- **Architecture** : ✅ DDD/RDD certifiée Platinium
- **Tests** : 449 exemples RSpec verts (97 → 449 evolution complète)
- **Sécurité** : ✅ JWT stateless, OAuth Google/GitHub, CSRF protection

### 📈 Historique des Accomplissements
| Version | Date | Tests | Événements Majeurs |
|---------|------|-------|-------------------|
| 1.3.0 | 19 Déc 2025 | 97 | Corrections sécurité |
| 2.0.0 | 26 Déc 2025 | 221 | Rails 8.1.1 migration |
| 2.1.0 | 31 Déc 2025 | 290 | FC-06 Missions complet |
| 2.3.0 | 7 Jan 2026 | 449 | FC-07 CRA + Mini-FC |

### 🏆 Certifications & Standards
- **TDD PLATINUM** : Domaine CRA auto-défensif
- **DDD/RDD Architecture** : Migration volontaire complète
- **Code Quality** : RuboCop 100%, Brakeman sans vulnérabilités critiques
- **Test Coverage** : Tests d'acceptation OAuth (9/9), intégration (8/10)

## ⚡ Fonctionnalités

### Sécurité & Authentification

#### JWT (JSON Web Tokens)
- **Authentification stateless** : Sans sessions serveur, tokens dans headers Authorization
- **Token Refresh** : Système automatique de rafraîchissement avec `refresh_token`
- **Sécurité renforcée** : Aucun logging de tokens (même tronqués), masquage IP

#### OAuth 2.0 (Google & GitHub)
- **Intégration complète** : [Documentation API OAuth](#oauth-endpoints) avec configuration et troubleshooting
- **Tests validés** : 9/9 tests d'acceptation passent ✅, 8/10 tests d'intégration ✅
- **Architecture robuste** : Approche simple avec stubbing direct `extract_oauth_data`
- **Gestion d'erreurs** : 
  - `:oauth_failed` → `render_unauthorized('oauth_failed')` (401)
  - `:invalid_payload` → `render_unprocessable_entity('invalid_payload')` (422)
- **Configuration** : Templates .env complets, application démarre même sans variables OAuth

#### Architecture Stateless & CSRF
- **100% stateless** : Suppression middlewares Cookie/Session 
- **Protection CSRF** : Session store désactivé, risque CSRF complètement éliminé
- **Privacy** : User IDs utilisés au lieu des emails dans les logs

#### Rate Limiting
- **Login** : 5 requêtes/minute
- **Signup** : 3 requêtes/minute  
- **Token Refresh** : 10 requêtes/minute
- **Missions/CRAs** : Protection contre attaques par force brute

#### Session Management
- **Gestion complète** : Création, expiration, invalidation automatique
- **Multi-provider** : Support Google et GitHub unifié
- **Contrôles** : Validation robuste avec contraintes d'unicité

### Gestion des Utilisateurs
- **Inscription/Connexion** : API REST pour l'authentification utilisateur
- **Profil utilisateur** : Gestion des données utilisateur via API
- **Multi-provider** : [Support Google et GitHub](#oauth-endpoints) - Voir documentation OAuth
- **Validation robuste** : Contraintes d'unicité et validations métier

### Gestion des Missions (Feature Contract 06)
- **CRUD Missions** : Création, lecture, modification, archivage de missions
- **Types de mission** : Time-based (TJM) et Fixed-price (forfait)
- **Lifecycle** : lead → pending → won → in_progress → completed
- **Architecture Domain-Driven** : Relations via tables dédiées (MissionCompany)
- **Contrôle d'accès** : Basé sur les rôles (independent/client)
- **Soft delete** : Archivage avec protection si CRA liés

### Gestion des CRA (Feature Contract 07) 🏆 TDD PLATINUM - 100% TERMINÉ
- **CRUD CRA** : Création, lecture, modification, archivage de Comptes Rendus d'Activité
- **CRUD CRA Entries** : Gestion des entrées d'activité par mission et date
- **Lifecycle strict** : draft → submitted → locked (immutable)
- **Git Ledger** : Versioning Git pour l'immutabilité légale des CRA verrouillés
- **Calculs serveur** : total_days, total_amount calculés côté serveur uniquement
- **Montants en centimes** : Précision financière (Integer, pas de Float)
- **Soft delete** : Avec règles métier (impossible si CRA submitted/locked)
- **Export CSV** : `GET /api/v1/cras/:id/export` avec option `include_entries` ✅ NEW
- ✅ **Domaine auto-défensif** : Lifecycle invariants contractuellement garantis
- ✅ **Tests de modèle 100% verts** : 6/6 exemples CraEntry lifecycle passent
- ✅ **Exceptions métier différenciées** : CraSubmittedError vs CraLockedError
- ✅ **Architecture DDD renforcée** : Relations explicites avec writers transitoires
- ✅ **Single source of truth** : validate_cra_lifecycle! centralisé
- ✅ **Mini-FC-01 Filtering** : Filtrage par year, month, status ✅ TERMINÉ
- ✅ **Mini-FC-02 CSV Export** : Export CSV avec UTF-8 BOM ✅ TERMINÉ (7 Jan 2026)
- 🎯 **État actuel** : FC-07 100% TERMINÉ — 449 tests GREEN, taggé `fc-07-complete`
- 📋 **Documentation complète** : [Documentation Centrale FC-07](docs/technical/fc07/README.md) - Vue d'ensemble et navigation vers méthodologie TDD/DDD, implémentation technique, suivi de progression

### Documentation & Qualité
- **Swagger/OpenAPI** : Documentation API interactive et à jour
- **Tests complets** : Couverture RSpec exhaustive
- **Code quality** : Conformité RuboCop 100%
- **Security audit** : Validation Brakeman sans vulnérabilités critiques
- **Docker Operations** : Guide complet de maintenance et troubleshooting Docker

## 🏗️ Architecture

### Stack Technology
- **Ruby** : 3.4.8
- **Ruby on Rails** : 8.1.1 (API-only)
- **Base de données** : PostgreSQL
- **Cache** : Redis pour les sessions et performances
- **Authentification** : JWT avec tokens stateless
- **OAuth** : OmniAuth pour Google et GitHub
- **Documentation** : Swagger via rswag
- **Bundler** : 4.0.3

### Structure API
```
/api/v1/
├── auth/
│   ├── login          # Authentification JWT
│   ├── logout         # Déconnexion utilisateur
│   ├── refresh        # Rafraîchissement token
│   ├── revoke         # Révocation token courant
│   ├── revoke_all     # Révocation tous les tokens
│   ├── failure        # Gestion des échecs d'authentification
│   └── :provider/
│       └── callback   # OAuth callbacks (Google, GitHub)
├── signup             # Inscription utilisateur
├── missions/
│   ├── index          # Liste des missions accessibles
│   ├── show           # Détail d'une mission
│   ├── create         # Création de mission
│   ├── update         # Modification de mission
│   └── destroy        # Archivage de mission
├── cras/
│   ├── index          # Liste des CRAs accessibles
│   ├── show           # Détail d'un CRA avec entries
│   ├── create         # Création de CRA
│   ├── update         # Modification de CRA
│   ├── destroy        # Archivage de CRA
│   ├── submit         # Soumission (draft → submitted)
│   ├── lock           # Verrouillage avec Git Ledger
│   └── export         # Export des données CRA
│   └── :cra_id/entries/
│       ├── index      # Liste des entries d'un CRA
│       ├── show       # Détail d'une entry
│       ├── create     # Création d'entry
│       ├── update     # Modification d'entry
│       └── destroy    # Suppression d'entry
└── health             # Health check endpoint
```

## 🧪 Tests & Qualité

### Statistiques Actuelles (Janvier 2026) — Validé le 29 janvier 2026
**🏆 Migration DDD/RDD Architecture Complétée (27-28 Janvier 2026)**
- **Tests RSpec** : ✅ **498 examples, 0 failures**
- **Tests Rswag** : ✅ **128 examples, 0 failures** — `swagger.yaml` généré
- **RuboCop** : ✅ **147 files inspected, no offenses detected**
- **Brakeman** : ✅ **0 Security Warnings** (3 ignored warnings)
- **Tests Missions (FC-06)** : ✅ 30/30 passent
- **Tests CRA (FC-07)** : ✅ **Architecture DDD/RDD Pure**
  - CraServices::Create (24 tests verts - Pattern 3-barrières)
  - CraServices::Export (26 tests verts)
  - Services Domain 100% fonctionnels
  - Legacy Api::V1:: eliminated
- **Tests d'acceptation OAuth** : ✅ 15/15 passent
- **Architecture DDD/RDD** : ✅ Migration complète, domaine CRA certifié Platinum DDD
  - 🏆 **Validation finale 29/01/2026** : 498 tests verts, 0 failures
  - 🗑️ **Legacy API nettoyé** : 2 tests API obsolètes supprimés
  - ✅ **Template validé** : Pattern 3-barrières pour FC-08
- **Pattern Réplicable** : ✅ Template méthodologique pour autres bounded contexts

### Couverture de Tests

### 📈 Évolution des Métriques de Tests (Historique)

**Progression chronologique des tests pour contextualiser l'évolution :**

| Version | Date | Tests RSpec | Événements |
|---------|------|-------------|------------|
| 1.3.0 | 19 Déc 2025 | 97 examples | Corrections sécurité, pgcrypto éliminé |
| 2.0.0 | 26 Déc 2025 | 221 tests | Rails 8.1.1 migration + 124 nouveaux tests |
| 2.1.0 | 31 Déc 2025 | 290 tests | Feature Contract 06 (Missions) + 69 nouveaux tests |
| 2.2.0 | 3 Jan 2026 | 400+ tests | Feature Contract 07 (CRA) implémenté |
| 2.3.0 | 7 Jan 2026 | 449 tests | Mini-FC-01 (Filtering) + Mini-FC-02 (CSV Export) |
| 2.3.1 | 28 Jan 2026 | 449 tests | Migration DDD/RDD Architecture (refactoring) |

**Note :** L'augmentation de 97 → 221 → 290 → 449 tests reflète l'ajout progressif des Feature Contracts :
- **+124 tests** : Migration Rails + infrastructure de tests
- **+69 tests** : Feature Contract 06 (Missions CRUD)
- **+150+ tests** : Feature Contract 07 (CRA complet)
- **+10 tests** : Mini-features (Filtering + Export CSV)

### Couverture de Tests
- **Authentication** : Login, logout, token refresh, revocation ✅
- **Rate Limiting** : Login (5/min), Signup (3/min), Refresh (10/min), Missions, CRAs ✅
- **OAuth Integration** : Google OAuth2, GitHub ✅
- **Session Management** : Création, expiration, invalidation ✅
- **Missions (FC-06)** : CRUD complet, lifecycle, access control ✅
- **CRA (FC-07) Modèle** : ✅ Tests de modèle 100% verts (Phases 1-3C TDD PLATINUM)
- **CRA (FC-07) Services** : ✅ Create, Update, Destroy, List, Export (17+16 tests)
- **CRA (FC-07) Filtering** : ✅ Mini-FC-01 - Filtrage year/month/status (16 tests)
- **CRA (FC-07) Export** : ✅ Mini-FC-02 - CSV export avec include_entries (17+9 tests)
- **CRA (FC-07) API** : ✅ 100% opérationnel - 449 tests GREEN
- **API Endpoints** : Tous les endpoints testés ✅
- **Models** : User, Session, Mission, Company, Cra, CraEntry, relations ✅
- **Error Handling** : Gestion d'erreurs robuste testée ✅

## 📖 Documentation API

### OAuth Endpoints

#### POST /api/v1/auth/:provider/callback
OAuth callback pour l'authentification avec Google ou GitHub

**Parameters :**
- `:provider` : `google_oauth2` | `github`
- Body JSON : 
  ```json
  {
    "code": "oauth_authorization_code",
    "redirect_uri": "https://client.app/callback"
  }
  ```

**Responses :**
- **200 OK** : JWT token et données utilisateur
  ```json
  {
    "token": "jwt_token_here",
    "user": {
      "id": "uuid",
      "email": "user@email.com",
      "provider": "google_oauth2",
      "provider_uid": "123456789"
    }
  }
  ```
- **400 Bad Request** : Provider non supporté
- **401 Unauthorized** : Échec OAuth
- **422 Unprocessable Entity** : Données invalides ou incomplètes
- **500 Internal Server Error** : Erreur serveur

### Authentication Endpoints

#### POST /api/v1/auth/login
Authentification JWT classique

#### POST /api/v1/auth/refresh  
Rafraîchissement de token JWT

#### DELETE /api/v1/auth/logout
Déconnexion et invalidation de session

#### GET /api/v1/auth/failure
Endpoint d'échec OAuth (optionnel)

### Missions Endpoints (Feature Contract 06)

#### POST /api/v1/missions
Crée une nouvelle mission

**Headers :** `Authorization: Bearer <jwt_token>`

**Body JSON :**
```json
{
  "name": "Mission Data Platform",
  "description": "Backend architecture",
  "mission_type": "time_based",
  "status": "lead",
  "start_date": "2025-01-01",
  "daily_rate": 60000,
  "currency": "EUR",
  "client_company_id": "uuid (optional)"
}
```

**Responses :**
- **201 Created** : Mission créée avec succès
- **401 Unauthorized** : JWT invalide
- **403 Forbidden** : User sans company independent
- **422 Unprocessable Entity** : Validation métier échouée

#### GET /api/v1/missions
Liste les missions accessibles à l'utilisateur

**Headers :** `Authorization: Bearer <jwt_token>`

**Responses :**
- **200 OK** : Liste des missions avec meta.total

#### GET /api/v1/missions/:id
Détail d'une mission

**Responses :**
- **200 OK** : Mission avec companies associées
- **404 Not Found** : Mission inaccessible

#### PATCH /api/v1/missions/:id
Modifie une mission (creator only)

**Responses :**
- **200 OK** : Mission mise à jour
- **403 Forbidden** : Non-creator
- **422 Unprocessable Entity** : Transition de statut invalide

#### DELETE /api/v1/missions/:id
Archive une mission (soft delete)

**Responses :**
- **200 OK** : Mission archivée
- **409 Conflict** : Mission liée à un CRA

### Règles Métier Missions (FC-06)

#### Lifecycle (Transitions de Statut)
```
lead → pending → won → in_progress → completed
```
- ⚠️ Pas de retour arrière autorisé
- ⚠️ Transitions invalides → 422 `invalid_transition`

#### Protection CRA
- Une mission liée à un CRA ne peut pas être supprimée
- Tentative de suppression → 409 `mission_in_use`
- Note : FC-07 (CRA) implémentera la liaison effective

#### Notifications Post-WON (Prévu)
Une notification sera envoyée après modification d'une mission en statut `won` uniquement si :
- Une Company client est liée à la mission
- Un représentant client existe
- Un email client est présent

Sinon : comportement silencieux (pas d'erreur).

> 📌 Cette fonctionnalité sera implémentée dans un Feature Contract futur.

## 🚀 Déploiement & Configuration

### Prérequis
- Docker & Docker Compose
- Stack technique complète : Voir section [🏗️ Architecture Technique](#️-architecture-technique) → [Stack Technology](#stack-technology)

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

3. **Vérifier le statut**
   ```bash
   docker-compose logs -f web
   ```

### Tests

```bash
# Tous les tests RSpec
docker-compose run --rm web bundle exec rspec

# Tests OAuth uniquement
docker-compose run --rm web bundle exec rspec spec/acceptance/oauth_feature_contract_spec.rb
docker-compose run --rm web bundle exec rspec spec/integration/oauth/oauth_callback_spec.rb

# Qualité du code
docker-compose run --rm web bundle exec rubocop

# Audit de sécurité
docker-compose run --rm web bundle exec brakeman
```

### Configuration OAuth

**Templates de configuration disponibles :**
- `.env.example` - Template complet pour le développement local
- `.env.test.example` - Template pour les tests automatisés
- `.env.production.example` - Template pour la production avec instructions sécurité

**Variables d'environnement requises :**

```bash
# Google OAuth2 Configuration
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# GitHub OAuth Configuration (Note: LOCAL_ prefix requis)
LOCAL_GITHUB_CLIENT_ID=your_github_client_id
LOCAL_GITHUB_CLIENT_SECRET=your_github_client_secret

# JWT Configuration (Requis)
JWT_SECRET=your_jwt_secret_key
```

**Configuration rapide :**
```bash
# 1. Copier le template
cp .env.example .env

# 2. Remplir les vraies valeurs OAuth
# 3. Générer les secrets JWT
openssl rand -hex 64  # Pour JWT_SECRET
```

### 🔒 Configuration GitHub Secrets (CI/CD)

Pour que la CI/CD fonctionne correctement, les secrets suivants doivent être configurés dans **GitHub Repository Settings > Secrets and variables > Actions** :

| Secret | Description | Génération |
|--------|-------------|------------|
| `SECRET_KEY_BASE` | Clé secrète Rails | `rails secret` |
| `JWT_SECRET` | Clé de signature JWT | `openssl rand -hex 64` |
| `GOOGLE_CLIENT_ID` | Client ID Google OAuth | Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | Client Secret Google OAuth | Google Cloud Console |
| `LOCAL_GITHUB_CLIENT_ID` | Client ID GitHub OAuth | GitHub Developer Settings |
| `LOCAL_GITHUB_CLIENT_SECRET` | Client Secret GitHub OAuth | GitHub Developer Settings |

> ⚠️ **SÉCURITÉ** : Ne jamais committer de secrets en clair dans le repository. Utiliser GitHub Secrets pour la CI/CD.

## 📊 Monitoring & Observabilité

### Health Checks
- `GET /up` : Health check de l'application
- `GET /api-docs` : Documentation Swagger interactive

### Logs
- **Application logs** : `/app/log/` (development, test, production)
- **Structured logging** : JSON format pour l'analyse
- **OAuth tracking** : Logs spécifiques pour les événements OAuth

## 🛠️ Développement

### Standards de Code
- **RuboCop** : 0 violation tolérance
- **Rspec** : Tests obligatoires pour toutes les fonctionnalités
- **Git Flow** : Feature branches avec PR reviews
- **Documentation** : Code autodocumenté avec comments appropriés

### Structure des Tests
```
spec/
├── acceptance/          # Tests d'acceptation (API contracts)
├── integration/         # Tests d'intégration (OAuth, workflows)
├── requests/           # Tests de requêtes API
├── unit/              # Tests unitaires (modèles, services)
├── factories/         # Factories pour les données de test
└── support/           # Helpers et configurations de test

bin/e2e/
├── e2e_auth_flow.sh     # Tests E2E authentification
├── e2e_missions.sh      # Tests E2E missions (FC-06)
├── e2e_revocation.sh    # Tests E2E révocation tokens
└── smoke_test.sh        # Tests smoke basiques
```

### Tests E2E

Les tests E2E valident les flux critiques end-to-end en conditions réelles.

**Usage :**
```bash
# Local (RAILS_ENV=test)
./bin/e2e/e2e_missions.sh

# Staging/CI (nécessite E2E_MODE=true)
STAGING_URL=https://api.example.com E2E_MODE=true ./bin/e2e/e2e_missions.sh
```

**Endpoints de support E2E :**

⚠️ **Ces endpoints n'existent qu'en environnement test/CI. Toute exposition en production est une faille critique.**

| Endpoint | Description |
|----------|-------------|
| `POST /__test_support__/e2e/setup` | Crée un contexte de test (User + Company + relation) |
| `DELETE /__test_support__/e2e/cleanup` | Nettoie les données de test E2E |

**Sécurité :**
- Routes montées uniquement si `RAILS_ENV=test` ou `E2E_MODE=true`
- Double vérification dans le contrôleur (defense in depth)
- En production, les routes n'existent pas

## 📈 Performance

### Optimisations Implémentées
- **Redis Cache** : Cache distribué pour les sessions
- **Database Indexing** : Index optimisés pour les requêtes fréquentes
- **API Pagination** : Pagination pour les listes importantes
- **JWT Efficiency** : Tokens stateless pour performance optimale

### Métriques de Performance
- **Response Time** : < 100ms pour les endpoints authentifiés
- **Database Queries** : Optimisation N+1 et index appropriés
- **Memory Usage** : Monitoring et optimisation continue

## 📝 Changelog

### Version 2.3.0 (7 Janvier 2026) - Feature Contract 07: 100% TERMINÉ 🏆
- 🎉 **FC-07 COMPLETE** : Tag `fc-07-complete` créé, 449 tests GREEN
- 📤 **Mini-FC-02 CSV Export** : `GET /api/v1/cras/:id/export` endpoint
  - ExportService avec UTF-8 BOM pour compatibilité Excel
  - Option `include_entries` (true/false)
  - 17 tests service + 9 tests request
- 🔍 **Mini-FC-01 Filtering** : Filtrage CRAs par year, month, status (16 tests)
- 📦 **Gem csv ajoutée** : Requise pour Ruby 3.4+ (plus dans default gems)
- 📖 **Documentation** : Mini-FC-02 documentation complète mise à jour

### Version 2.3.1 (28 Janvier 2026) - Migration DDD/RDD Architecture ✅
- 🏗️ **Architecture DDD/RDD Pure** : Migration volontaire vers architecture DDD/RDD pure
- 🔧 **Services Refactorisés** : Api::V1::CraEntries::* legacy eliminés
- 🧪 **CraServices::Create** : Pattern 3-barrières implémenté (24 tests verts)
- 📊 **ApplicationResult Pattern** : Normalisé dans tout le domaine CRA
- 🎯 **Template Établi** : Méthodologie reproductible pour autres bounded contexts
- ✅ **Qualité Maintenue** : 449 tests verts, 0 régression
- 🏆 **Certification Platinium** : Domaine CRA certifié DDD/RDD (27-28 Jan 2026)

### Version 2.2.2 (11 Janvier 2026) - Feature Contract 07: CRA Phase 3A ✅ ACCOMPLIE
- 🏗️ **Tests de services directs créés** : 4 specs complètes (Create, Update, Destroy, ListService)
- ✅ **Fonctionnalités manquantes implémentées** : Recalcul des totaux CRA dans Create/Update/Destroy
- 🧪 **Approche TDD pragmatique appliquée** : Tests orientés cœur métier, autorisations stubbées
- 📊 **Métriques d'accomplissement** : 63 exemples de tests, 80% couverture services
- 🎯 **Architecture préservée** : Services sophistiqués conservés et validés
- 🔄 **Phase 3B planifiée** : Pagination ListService (priorité haute, démarrage immédiat)
- 📖 **Documentation** : docs/technical/fc07/phases/FC07-Phase3A-Accomplishment-Report.md

### Version 2.2.1 (4 Janvier 2026) - Feature Contract 07: CRA 🏆 TDD PLATINUM - DOMAINE ÉTABLI
- 🎯 **Domaine auto-défensif** : Lifecycle invariants contractuellement garantis
- 🧪 **Tests de modèle 100% verts** : 6/6 exemples CraEntry lifecycle passent
- 🔒 **Lifecycle strict** : draft → submitted → locked (immutable après lock)
- 🚫 **Exceptions métier différenciées** : CraSubmittedError vs CraLockedError
- 🏗️ **Architecture DDD renforcée** : Relations explicites avec writers transitoires
- 💰 **Montants en centimes** : Précision financière Integer (pas de Float)
- 🧮 **Calculs serveur** : total_days, total_amount calculés côté serveur uniquement
- 🗑️ **Soft delete FC-07** : Impossible si CRA submitted ou locked
- ✅ **Implémentation TDD PLATINUM** :
  - Guards lifecycle centraux (`validate_cra_lifecycle!`)
  - Single source of truth pour create/update/destroy callbacks
  - Writers transitoires pour compatibilité TDD (DDD préservé)
  - Exceptions métier explicites et hiérarchisées
  - Soft delete testé correctement (`discard` vs `destroy`)
- ✅ **Contrat métier validé** :
  - Draft CRA → toutes opérations autorisées
  - Submitted CRA → création interdite (CraSubmittedError)
  - Locked CRA → modification interdite (CraLockedError)
- 🎯 **Phase suivante** : Phase 3A - Tests de Services CraEntries (Tests directs créés avec succès)
- 📖 **Documentation** : docs/technical/fc07/README.md - Documentation centrale complète avec méthodologie TDD/DDD, implémentation technique et suivi de progression

### Version 2.2.0 (3 Janvier 2026) - Feature Contract 07: CRA ✅ CORRECTIONS MAJEURES
- 🎯 **CRA CRUD** : Gestion complète des Comptes Rendus d'Activité
- 📝 **CRA Entries** : Entrées d'activité par mission et date avec unicité
- 🔒 **Lifecycle strict** : draft → submitted → locked (immutable après lock)
- 📚 **Git Ledger** : Versioning Git pour l'immutabilité légale des CRA verrouillés
- 💰 **Montants en centimes** : Précision financière Integer (pas de Float)
- 🧮 **Calculs serveur** : total_days, total_amount calculés côté serveur uniquement
- 🗑️ **Soft delete FC-07** : Impossible si CRA submitted ou locked
- ✅ **Corrections critiques appliquées** :
  - Namespacing Zeitwerk (`Api::V1::Cras::*`)
  - CraErrors autoload (`lib/cra_errors.rb`)
  - `cra_params` ajouté au controller
  - Chemins complets services (`Api::V1::Cras::CreateService`)
  - `git_version` retiré (décision CTO - pas en DB)
  - ResponseFormatter aligné FC-06 (objet direct)
  - ErrorRenderable expose exceptions en test
- ✅ **Redis connection fix** : Erreurs 500 résolues, tous les tests passent
- 🎯 **Prochaine étape** : Phase 3A - Tests de Services CraEntries (planifiée)
- 📖 **Documentation** : docs/technical/corrections/2026-01-03-FC07_Redis_Connection_Fix.md

### Version 2.1.0 (31 Décembre 2025) - Feature Contract 06: Missions ✅ PR #12 MERGED
- 🎯 **Missions CRUD** : Création, lecture, modification, archivage de missions professionnelles
- 🏗️ **Architecture Domain-Driven** : Relations via tables dédiées (MissionCompany, UserCompany)
- 📊 **Types de mission** : Time-based (TJM) et Fixed-price (forfait)
- 🔄 **Lifecycle** : lead → pending → won → in_progress → completed
- 🔐 **Contrôle d'accès** : Basé sur les rôles (independent/client) via Company
- 🗑️ **Soft delete** : Archivage avec protection si CRA liés
- ✅ **290 Tests** : +69 nouveaux tests, 0 échec
- ✅ **RuboCop** : 93 fichiers, 0 offense
- ✅ **Brakeman** : 0 vulnérabilité
- ✅ **Swagger** : 119 specs générées
- ✅ **PR #12** : Approuvée CTO, mergée le 1 janvier 2026

### Version 2.0.0 (26 Décembre 2025) - Rails 8.1.1 Migration
- 🚀 **Rails Upgrade** : Migration majeure de Rails 7.1.5.1 → 8.1.1
- 💎 **Ruby Upgrade** : Migration de Ruby 3.3.0 → 3.4.8
- 📦 **Bundler Upgrade** : Migration vers Bundler 4.0.3
- 🐳 **Docker Optimisé** : Multi-stage build avec bundle_cache volume
- ✅ **221 Tests** : Tous les tests passent sans régression
- ✅ **Rubocop** : 82 fichiers, 0 offense
- ✅ **Brakeman** : 0 vulnérabilité critique
- ✅ **Zeitwerk** : Autoloading validé

### Version 1.5.0 (22 Décembre 2025) - Corrections Sécurité PR
- 🔒 **Token Logging** : Suppression de tout logging de tokens (PR Point 2)
- 🔒 **CSRF Protection** : Suppression Cookie/Session middlewares (PR Point 1)
- 🔒 **Privacy** : Masquage IP et utilisation user IDs dans logs
- 📦 **Postman Collection** : Ajout collection avec URLs OAuth

### Version 1.4.1 (20 Décembre 2025 - soir) - Fix Signup Session
- 🔧 **Signup Session** : Signup crée maintenant une session comme login
- ✅ **Logout après Signup** : Fonctionne immédiatement après inscription

### Version 1.4.0 (20 Décembre 2025) - Déploiement Production
- 🚀 **Render Deployment** : API live sur https://foresy-api.onrender.com
- 🐳 **Dockerfile optimisé** : Multi-stage build pour production
- ✅ **pgcrypto éliminé** : Migration complète vers IDs bigint + UUID Ruby
- 🔧 **CI/CD complet** : GitHub Actions (CI) + Render (CD)

### Version 1.3.0 (19 Décembre 2025) - Analyses Techniques & Sécurité
- ✅ **pgcrypto Elimination** : Migration complète vers IDs bigint + UUID Ruby (pgcrypto totalement éliminé)
- 🛠️ **GoogleOAuth2Service Mock** : Suppression service mock mal placé dans app/services
- 🔐 **OmniAuth Configuration** : Initializer robuste + templates .env complets
- 🛡️ **CSRF Security Analysis** : Élimination risque CSRF via désactivation session store
- 📋 **Templates Configuration** : .env.example, .env.test.example, .env.production.example
- 🏗️ **Architecture Clarifiée** : JWT stateless confirmé, session store désactivé
- 📖 **Documentation Étendue** : 4 nouvelles analyses techniques détaillées
- ✅ **Tests Maintenus** : 97 examples, 0 failures (toutes corrections validées)

### Version 1.2.3 (19 Décembre 2025)
- 📋 **Rswag OAuth Specs** : Specs rswag conformes au Feature Contract
- ✅ **Swagger auto-généré** : Documentation générée automatiquement depuis les tests
- ✅ **Couverture complète** : Google, GitHub, tous codes d'erreur (400, 401, 422, 500)
- ✅ **97 tests passent** : +4 tests rswag OAuth

### Version 1.2.2 (19 Décembre 2025)
- 🔧 **Zeitwerk Fix** : Renommage fichiers services OAuth pour compatibilité autoloading
- ✅ **Fichiers renommés** : `oauth_*_service.rb` → `o_auth_*_service.rb`
- ✅ **Convention Rails** : Alignement avec convention Zeitwerk pour acronymes
- ✅ **CI fonctionnelle** : 87 tests passent, 0 échec

### Version 1.2.1 (19 Décembre 2025)
- 🔒 **Security Fix** : Suppression secrets exposés dans le repository
- ✅ **GitHub Secrets** : Configuration sécurisée des variables CI/CD
- ✅ **OAuth Variables** : Alignement avec restrictions GitHub (`LOCAL_GITHUB_*`)
- ✅ **Documentation** : Guide complet de configuration des secrets

### Version 1.2.0 (18 Décembre 2025)
- ✅ **Feature OAuth** : Implémentation complète Google & GitHub
- ✅ **Tests Quality** : 87 tests RSpec, 0 violation RuboCop
- ✅ **Regression Fix** : Correction problème tests d'acceptation OAuth
- ✅ **Code Architecture** : Contrôleur OAuth optimisé et maintanable
- ✅ **CI/CD Ready** : Pipeline GitHub Actions entièrement fonctionnel

### Version 1.1.0 (Octobre 2025)
- ✅ **Refactorisation** : AuthenticationController optimisé
- ✅ **Tests Coverage** : Augmentation significative de la couverture
- ✅ **Documentation** : Swagger complet et à jour

## 🤝 Contribution

1. **Fork** le repository
2. **Créer** une feature branch (`git checkout -b feature/AmazingFeature`)
3. **Commit** les changements (`git commit -m 'Add AmazingFeature'`)
4. **Push** vers la branch (`git push origin feature/AmazingFeature`)
5. **Ouvrir** une Pull Request

### Standards de Contribution
- ✅ Tests requis pour toute nouvelle fonctionnalité
- ✅ RuboCop compliance (0 violation)
- ✅ Documentation mise à jour
- ✅ PR description claire avec context et tests

## 📞 Support

- **Issues** : GitHub Issues pour les bugs et feature requests
- **Documentation** : Swagger UI disponible sur `/api-docs`
- **Tests** : Documentation complète dans `/spec/README.md`

## 📄 License

Ce projet est sous license MIT. Voir le fichier `LICENSE` pour plus de détails.

---

**Foresy API** - Une API Rails moderne, sécurisée et entièrement testée pour la gestion d'utilisateurs avec OAuth et JWT. Développée avec les meilleures pratiques et prête pour la production.