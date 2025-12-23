# 📚 Documentation Centrale - Projet Foresy

**Version :** 1.8  
**Dernière mise à jour :** 23 décembre 2025  
**Objectif :** Point d'entrée centralisé pour toute la documentation du projet Foresy API  
**Production :** https://foresy-api.onrender.com  
**Sécurité :** Stateless JWT, no token logging, no cookies

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
    ├── index.md                 # Index principal (ce fichier)
    ├── BRIEFING.md              # Contexte projet pour IA
    └── technical/               # Documentation technique centralisée
        ├── analysis/            # Analyses techniques approfondies (Déc 2025)
        │   ├── pgcrypto_alternatives_analysis.md
        │   ├── google_oauth_service_mock_solution.md
        │   ├── omniauth_oauth_configuration_solution.md
        │   └── csrf_security_analysis_same_site_none.md
        ├── changes/             # Journal chronologique des modifications
        │   ├── 2025-12-18-CI_Fix_Resolution.md
        │   ├── 2025-12-18-GoogleOauthService_Fix_Resolution.md
        │   ├── 2025-12-18-OAuthTokenService_Comment_Fix.md
        │   ├── 2025-12-19-Security_CI_Complete_Fix.md
        │   ├── 2025-12-19-Zeitwerk_OAuth_Services_Rename.md
        │   └── 2025-12-19-Rswag_OAuth_Specs_Feature_Contract.md
        ├── audits/              # Rapports d'audit technique
        │   ├── ANALYSE_TECHNIQUE_FORESY.md
        │   └── CHANGELOG_REFACTORISATION.md
        └── corrections/         # Corrections techniques historiques
            ├── 2025-12-19-pgcrypto_elimination_solution.md  # ✅ pgcrypto éliminé
            └── CORRECTIONS_JANVIER_2025.md
```

---

## 📋 Navigation Rapide

### 🎯 Pour Commencer
1. **[🚀 Production Live](https://foresy-api.onrender.com)** - API déployée sur Render
2. **[README.md](../README.md)** - Vue d'ensemble du projet, installation, utilisation
3. **[📮 Postman Collection](./postman/Foresy_API.postman_collection.json)** - Collection pour tester les endpoints
4. **[🚨 Migration Rails Planifiée](./technical/changes/2025-12-20-Rails_Migration_Task_Planning.md)** - Migration Rails 7.1.5.1 → 7.2+ (EOL octobre 2025)

### 🔧 **Pour le Développement**
1. **[Analyse Technique](./technical/audits/ANALYSE_TECHNIQUE_FORESY.md)** - Architecture et analyse technique complète
2. **[Corrections Janvier 2025](./technical/corrections/CORRECTIONS_JANVIER_2025.md)** - Résolution problèmes CI historiques

### 🔍 **Analyses Techniques Récentes (Décembre 2025)**
1. **[🔧 pgcrypto UUID Alternatives](./technical/analysis/pgcrypto_alternatives_analysis.md)** - **CRITIQUE** - Migration UUID sans pgcrypto
2. **[🚫 GoogleOAuth2Service Mock Removal](./technical/analysis/google_oauth_service_mock_solution.md)** - **CRITIQUE** - Suppression service mock mal placé
3. **[🔐 OmniAuth OAuth Configuration](./technical/analysis/omniauth_oauth_configuration_solution.md)** - **CRITIQUE** - Configuration robuste secrets OAuth
4. **[🛡️ CSRF Security Analysis](./technical/analysis/csrf_security_analysis_same_site_none.md)** - **CRITIQUE** - Analyse risque CSRF et sécurisation

### 📊 **Pour les Modifications Récentes**
1. **[🔧 OAuth Services Elegant Solution 23/12/2025](./technical/changes/2025-12-23-OAuth_Services_Elegant_Solution.md)** - **MAJEUR** - Solution élégante élimination require_relative, conventions Zeitwerk respectées (23/12/2025)
2. **[🐳 Docker Build Health Check 23/12/2025](./technical/changes/2025-12-23-Docker_Build_Health_Check_Resolution.md)** - **RÉSOLU** - Conteneurs Docker healthy, health endpoints fonctionnels (23/12/2025)
3. **[📊 Standardisation APM Datadog 22/12/2025](./technical/changes/2025-12-22-Datadog_APM_Standardization_Resolution.md)** - **RÉSOLU** - Standardisation API Datadog multi-versions (22/12/2025)
3. **[🚨 Migration Rails Planifiée 20/12/2025](./technical/changes/2025-12-20-Rails_Migration_Task_Planning.md)** - **CRITIQUE** - Planification migration Rails 7.1.5.1 → 7.2+ (EOL)
4. **[🔧 Refactoring Authenticatable 20/12/2025](./technical/changes/2025-12-20-Authenticatable_Concern_Refactoring.md)** - **MAJEUR** - Séparation responsabilités auth
5. **[🔑 Migration UUID 20/12/2025](./technical/changes/2025-12-20-UUID_Migration.md)** - **MAJEUR** - Migration identifiants sécurisés
6. **[🔧 PGCrypto Compatibility Fix 21/12/2025](./technical/changes/2025-12-21-PGCrypto_Compatibility_Fix.md)** - **CRITIQUE** - Résolution compatibilité environnements managés
7. **[✅ GoogleOAuth2Service Removal 21/12/2025](./technical/changes/2025-12-21-GoogleOAuth2Service_Removal_Resolution.md)** - **RÉSOLU** - Point 2 PR fermé (suppression service mock)
8. **[🔒 Sécurité Gems 20/12/2025](./technical/changes/2025-12-20-Security_Gems_Update.md)** - **CRITIQUE** - 20+ vulnérabilités corrigées
9. **[⚡ Réactivation Bootsnap 20/12/2025](./technical/changes/2025-12-20-Bootsnap_Reactivation.md)** - **MAJEUR** - Performance boot Rails
10. **[🏗️ Consolidations Migrations 20/12/2025](./technical/changes/2025-12-20-Migrations_Consolidation.md)** - **MAJEUR** - Nettoyage migrations UUID
11. **[JWT Robustesse 19/12/2025](./technical/changes/2025-12-19-JWT_Robustness_Improvements_Complete.md)** - **MAJEUR** - Amélioration robustesse JWT
12. **[🏗️ Corrections Architecture OAuth 19/12/2025](./technical/changes/2025-12-19-OAuth_Architecture_Fix.md)** - **CRITIQUE** - Nommage OAuth + RequireRelative
13. **[🔒 Corrections CI Sécurité 19/12/2025](./technical/changes/2025-12-19-CI_Security_Fixes_Secrets_PostgreSQL.md)** - **CRITIQUE** - Sécurité CI + Compatibilité runners
14. **[🔧 Zeitwerk OAuth 19/12/2025](./technical/changes/2025-12-19-Zeitwerk_OAuth_Services_Rename.md)** - **CRITIQUE** - Renommage services OAuth pour Zeitwerk
15. **[🔒 Sécurité & Secrets 19/12/2025](./technical/changes/2025-12-19-Security_CI_Complete_Fix.md)** - **CRITIQUE** - Sécurisation secrets CI/CD
16. **[Correction CI 18/12/2025](./technical/changes/2025-12-18-CI_Fix_Resolution.md)** - Intervention majeure CI
17. **[Correction GoogleOauthService 18/12/2025](./technical/changes/2025-12-18-GoogleOauthService_Fix_Resolution.md)** - Résolution erreur Zeitwerk

### 🔍 **Analyses Techniques Problèmes PR (Décembre 2025)**
1. **[🔧 pgcrypto UUID Alternatives](./technical/analysis/pgcrypto_alternatives_analysis.md)** - ✅ **RÉSOLU** - Compatibilité environnements managés (21/12/2025)
2. **[🚫 GoogleOAuth2Service Mock Removal](./technical/analysis/google_oauth_service_mock_solution.md)** - ✅ **RÉSOLU** - Service mock supprimé (21/12/2025)
3. **[🔐 OmniAuth OAuth Configuration](./technical/analysis/omniauth_oauth_configuration_solution.md)** - Configuration secrets fragile
4. **[🛡️ CSRF Security Analysis](./technical/analysis/csrf_security_analysis_same_site_none.md)** - Risque CSRF avec same_site: :none
5. **[📊 Standardisation APM Datadog](./technical/changes/2025-12-22-Datadog_APM_Standardization_Resolution.md)** - ✅ **RÉSOLU** - Standardisation API Datadog multi-versions (22/12/2025)

### 🔧 **Pour les Corrections Critiques**
1. **[🏗️ Corrections Architecture OAuth 19/12/2025](./technical/changes/2025-12-19-OAuth_Architecture_Fix.md)** - Fuite secrets + Dépendance pg_isready + Incohérences nommage OAuth
2. **[🔒 Sécurité Secrets 19/12/2025](./technical/changes/2025-12-19-Security_CI_Complete_Fix.md)** - Secrets exposés → GitHub Secrets
3. **[GoogleOauthService 18/12/2025](./technical/changes/2025-12-18-GoogleOauthService_Fix_Resolution.md)** - Erreur `uninitialized constant GoogleOauthService`
4. **[✅ GoogleOAuth2Service Resolution 21/12/2025](./technical/changes/2025-12-21-GoogleOAuth2Service_Removal_Resolution.md)** - ✅ **RÉSOLU** - Point 2 PR fermé (suppression service mock)
5. **[CI GitHub 18/12/2025](./technical/changes/2025-12-18-CI_Fix_Resolution.md)** - Pipeline CI cassée

### 📈 Pour l'Historique
1. **[Changelog Refactorisation](./technical/audits/CHANGELOG_REFACTORISATION.md)** - Historique des refactorisations

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
| [✅ 2025-12-23-CI_Rubocop_Standards_Configuration_Fix.md](./technical/changes/2025-12-23-CI_Rubocop_Standards_Configuration_Fix.md) | 23/12/2025 | Corrections CI, standards Rubocop et configuration Rails | **CRITIQUE** - CI débloquée, 0 offense |
| [🧹 2025-12-19-Authenticatable_Cleanup.md](./technical/changes/2025-12-19-Authenticatable_Cleanup.md) | 19/12/2025 | Unification payload_valid?/valid_payload? + tests unitaires | **MOYEN** - 149 tests OK |
| [🔧 2025-12-19-Authentication_Concerns_Fix.md](./technical/changes/2025-12-19-Authentication_Concerns_Fix.md) | 19/12/2025 | Correction concerns authentification (class_methods + Zeitwerk) | **CRITIQUE** - 120 tests OK |
| [🔧 2025-12-20-Authenticatable_Concern_Refactoring.md](./technical/changes/2025-12-20-Authenticatable_Concern_Refactoring.md) | 20/12/2025 | Refactoring concern Authenticatable (séparation responsabilités) | **MAJEUR** - Architecture clean |
| [🔧 2025-12-20-Autoload_Cleanup.md](./technical/changes/2025-12-20-Autoload_Cleanup.md) | 20/12/2025 | Nettoyage require_relative et optimisation autoload | **MINEUR** - Performance |
| [⚡ 2025-12-20-Bootsnap_Reactivation.md](./technical/changes/2025-12-20-Bootsnap_Reactivation.md) | 20/12/2025 | Réactivation Bootsnap pour optimisation boot Rails | **MAJEUR** - Performance |
| [🛡️ 2025-12-20-Brakeman_Ignore_Config_Fix.md](./technical/changes/2025-12-20-Brakeman_Ignore_Config_Fix.md) | 20/12/2025 | Configuration patterns ignore Brakeman | **MINEUR** - Configuration |
| [🧹 2025-12-20-Debug_Logging_Cleanup.md](./technical/changes/2025-12-20-Debug_Logging_Cleanup.md) | 20/12/2025 | Suppression logs debug Rails.logger | **MINEUR** - Propreté code |
| [🏗️ 2025-12-20-Migrations_Consolidation.md](./technical/changes/2025-12-20-Migrations_Consolidation.md) | 20/12/2025 | Consolidation migrations users/sessions UUID | **MAJEUR** - Schema clean |
| [🔒 2025-12-20-Security_Gems_Update.md](./technical/changes/2025-12-20-Security_Gems_Update.md) | 20/12/2025 | Mise à jour sécurité gems (20+ vulnérabilités) | **CRITIQUE** - Sécurité |
| [🔑 2025-12-20-UUID_Migration.md](./technical/changes/2025-12-20-UUID_Migration.md) | 20/12/2025 | Migration identifiants users/sessions vers UUID | **MAJEUR** - Sécurité |
| [🔑 2025-12-19-JWT_Robustness_Improvements_Complete.md](./technical/changes/2025-12-19-JWT_Robustness_Improvements_Complete.md) | 19/12/2025 | Amélioration robustesse validation JWT | **MAJEUR** - Authentification |
| [🏗️ 2025-12-19-OAuth_Architecture_Fix.md](./technical/changes/2025-12-19-OAuth_Architecture_Fix.md) | 19/12/2025 | Corrections architecturales (nommage OAuth + require_relative) | **CRITIQUE** - Architecture robuste |
| [🔒 2025-12-19-CI_Security_Fixes_Secrets_PostgreSQL.md](./technical/changes/2025-12-19-CI_Security_Fixes_Secrets_PostgreSQL.md) | 19/12/2025 | Corrections sécurité CI (fuite secrets + pg_isready) | **CRITIQUE** - CI sécurisée |
| [📋 2025-12-19-Rswag_OAuth_Specs_Feature_Contract.md](./technical/changes/2025-12-19-Rswag_OAuth_Specs_Feature_Contract.md) | 19/12/2025 | Specs rswag OAuth conformes au Feature Contract | **MAJEUR** - Swagger auto-généré |
| [🔧 2025-12-19-Zeitwerk_OAuth_Services_Rename.md](./technical/changes/2025-12-19-Zeitwerk_OAuth_Services_Rename.md) | 19/12/2025 | Renommage fichiers OAuth pour Zeitwerk | **CRITIQUE** - CI fonctionnelle |
| [🔒 2025-12-19-Security_CI_Complete_Fix.md](./technical/changes/2025-12-19-Security_CI_Complete_Fix.md) | 19/12/2025 | Sécurisation secrets + Configuration GitHub Secrets | **CRITIQUE** - Sécurité renforcée |
| [2025-12-18-OAuthTokenService_Comment_Fix.md](./technical/changes/2025-12-18-OAuthTokenService_Comment_Fix.md) | 18/12/2025 | Correction commentaires OAuthTokenService | **MINEUR** - Qualité code |
| [2025-12-18-CI_Fix_Resolution.md](./technical/changes/2025-12-18-CI_Fix_Resolution.md) | 18/12/2025 | Résolution problèmes CI GitHub | **CRITIQUE** - CI fonctionnelle |
| [2025-12-18-GoogleOauthService_Fix_Resolution.md](./technical/changes/2025-12-18-GoogleOauthService_Fix_Resolution.md) | 18/12/2025 | Résolution erreur Zeitwerk GoogleOauthService | **CRITIQUE** - 87 tests, 0 échec |

### 🔍 **Analyses Techniques** (`docs/technical/analysis/`)
Analyses approfondies des problèmes techniques identifiés et solutions proposées.

| Fichier | Date | Problème | Impact | Solution |
|---------|------|----------|--------|----------|
| [pgcrypto_alternatives_analysis.md](./technical/analysis/pgcrypto_alternatives_analysis.md) | 19/12/2025 | pgcrypto échoue en production | **CRITIQUE** | UUID Ruby |
| [google_oauth_service_mock_solution.md](./technical/analysis/google_oauth_service_mock_solution.md) | 19/12/2025 | Service mock en production | **CRITIQUE** | Suppression |
| [omniauth_oauth_configuration_solution.md](./technical/analysis/omniauth_oauth_configuration_solution.md) | 19/12/2025 | Configuration secrets fragile | **CRITIQUE** | Templates + robustesse |
| [csrf_security_analysis_same_site_none.md](./technical/analysis/csrf_security_analysis_same_site_none.md) | 19/12/2025 | Risque CSRF cookies | **CRITIQUE** | Session store désactivé |

### 📊 **Rapports d'Audit** (`docs/technical/audits/`)
Analyses techniques et historiques des modifications.

| Fichier | Type | Description |
|---------|------|-------------|
| [ANALYSE_TECHNIQUE_FORESY.md](./technical/audits/ANALYSE_TECHNIQUE_FORESY.md) | Analyse | Architecture technique et bonnes pratiques |
| [CHANGELOG_REFACTORISATION.md](./technical/audits/CHANGELOG_REFACTORISATION.md) | Historique | Chronologie des refactorisations et améliorations |

### 🛠️ **Corrections Techniques** (`docs/technical/corrections/`)
Résolutions de problèmes critiques et interventions majeures.

| Fichier | Date | Problème Résolu | Impact |
|---------|------|-----------------|--------|
| [2025-12-19-pgcrypto_elimination_solution.md](./technical/corrections/2025-12-19-pgcrypto_elimination_solution.md) | 19/12/2025 | **CRITIQUE** - Dépendance pgcrypto bloquant déploiement production | **CRITIQUE** - Compatibilité totale environnements managés |
| [CORRECTIONS_JANVIER_2025.md](./technical/corrections/CORRECTIONS_JANVIER_2025.md) | 01/2025 | CI complètement cassée (0 tests) | **MAJEUR** - Pipeline fonctionnel |

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
| [docker_operations_maintenance.md](./technical/docker_operations_maintenance.md) | **GUIDE COMPLET** - Commandes Docker, health checks, troubleshooting, bonnes pratiques | **23/12/2025** - Post-restart web service |

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
- `CORRECTIONS_JANVIER_2025.md` (racine du projet)
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
CORRECTIONS_JANVIER_2025.md → docs/technical/corrections/

# Rapports d'audit
audit_report/ANALYSE_TECHNIQUE_FORESY.md → docs/technical/audits/
audit_report/CHANGELOG_REFACTORISATION.md → docs/technical/audits/

# Journal chronologique
docs/changes/ → docs/technical/changes/

# Documentation GitHub
README.md reste à la racine pour compatibilité GitHub
```

### Ajouts 18 Décembre 2025 - Soir
Ajout du document de résolution GoogleOauthService :
```
# Nouveau document de correction
docs/technical/changes/2025-12-18-GoogleOauthService_Fix_Resolution.md
```

---

## 🎯 Utilisation de la Documentation

### 👨‍💻 **Pour les Développeurs**
1. **Commencer par** : [README.md racine](../README.md)
2. **Pour l'état actuel** : [Corrections GoogleOauthService 18/12/2025](./technical/changes/2025-12-18-GoogleOauthService_Fix_Resolution.md)
3. **Pour l'architecture** : [Analyse Technique](./technical/audits/ANALYSE_TECHNIQUE_FORESY.md)

### 🔧 **Pour les Corrections**
1. **Problème actuel** : [GoogleOauthService 18/12/2025](./technical/changes/2025-12-18-GoogleOauthService_Fix_Resolution.md) - **RÉSOLU**
2. **Journal chronologique** : [Correction CI 18/12/2025](./technical/changes/2025-12-18-CI_Fix_Resolution.md)
3. **Problèmes précédents** : [Corrections Janvier 2025](./technical/corrections/CORRECTIONS_JANVIER_2025.md)
4. **Continuer le travail** : Ajouter un nouveau fichier daté dans `technical/changes/`

### 📊 **Pour la Maintenance**
1. **Métriques actuelles** : Voir [Correction CI 18/12/2025](./technical/changes/2025-12-18-CI_Fix_Resolution.md)
2. **Historique des problèmes** : [Changelog Refactorisation](./technical/audits/CHANGELOG_REFACTORISATION.md)
3. **Standards du projet** : [Analyse Technique](./technical/audits/ANALYSE_TECHNIQUE_FORESY.md)

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

> ⚠️ **IMPORTANT** : Ne jamais committer de secrets en clair dans le repository. Voir [2025-12-19-Security_CI_Complete_Fix.md](./technical/changes/2025-12-19-Security_CI_Complete_Fix.md) pour les détails.

---

**Index maintenu par :** Équipe Foresy  
**Dernière révision :** 20 décembre 2025  
**Version :** 1.5
**Statut :** ✅ Actif et maintenu