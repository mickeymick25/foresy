# 📚 Documentation Centrale - Projet Foresy

**Version :** 1.3  
**Dernière mise à jour :** 19 décembre 2025
**Objectif :** Point d'entrée centralisé pour toute la documentation du projet Foresy API

---

## 🎯 Vue d'Ensemble

Cette documentation centralisée regroupe toutes les informations techniques, historiques et de référence du projet Foresy. Elle a été réorganisée le 18 décembre 2025 pour rassembler les documents dispersés dans plusieurs endroits du projet.

### 📁 Structure de la Documentation

```
docs/
├── index.md                     # Index principal (ce fichier)
├── BRIEFING.md                  # Contexte projet pour IA
└── technical/                   # Documentation technique centralisée
    ├── changes/                # Journal chronologique des modifications
    │   ├── 2025-12-18-CI_Fix_Resolution.md
    │   ├── 2025-12-18-GoogleOauthService_Fix_Resolution.md
    │   ├── 2025-12-18-OAuthTokenService_Comment_Fix.md
    │   ├── 2025-12-19-Security_CI_Complete_Fix.md
    │   ├── 2025-12-19-Zeitwerk_OAuth_Services_Rename.md
    │   └── 2025-12-19-Rswag_OAuth_Specs_Feature_Contract.md  # 📋 SWAGGER AUTO
    ├── audits/                 # Rapports d'audit technique
    │   ├── ANALYSE_TECHNIQUE_FORESY.md
    │   └── CHANGELOG_REFACTORISATION.md
    └── corrections/            # Corrections techniques historiques
        └── CORRECTIONS_JANVIER_2025.md
```

---

## 📋 Navigation Rapide

### 🎯 Pour Commencer
1. **[README.md](../README.md)** - Vue d'ensemble du projet, installation, utilisation
2. **[Rswag OAuth Specs 19/12/2025](./technical/changes/2025-12-19-Rswag_OAuth_Specs_Feature_Contract.md)** - 📋 **DERNIÈRE INTERVENTION** - Swagger auto-généré

### 🔧 **Pour le Développement**
1. **[Analyse Technique](./technical/audits/ANALYSE_TECHNIQUE_FORESY.md)** - Architecture et analyse technique complète
2. **[Corrections Janvier 2025](./technical/corrections/CORRECTIONS_JANVIER_2025.md)** - Résolution problèmes CI historiques

### 📊 **Pour les Modifications Récentes**
1. **[📋 Rswag OAuth Specs 19/12/2025](./technical/changes/2025-12-19-Rswag_OAuth_Specs_Feature_Contract.md)** - **MAJEUR** - Specs rswag + Swagger auto-généré
2. **[🔧 Zeitwerk OAuth 19/12/2025](./technical/changes/2025-12-19-Zeitwerk_OAuth_Services_Rename.md)** - **CRITIQUE** - Renommage services OAuth pour Zeitwerk
3. **[🔒 Sécurité & Secrets 19/12/2025](./technical/changes/2025-12-19-Security_CI_Complete_Fix.md)** - **CRITIQUE** - Sécurisation secrets CI/CD
4. **[Correction CI 18/12/2025](./technical/changes/2025-12-18-CI_Fix_Resolution.md)** - Intervention majeure CI
5. **[Correction GoogleOauthService 18/12/2025](./technical/changes/2025-12-18-GoogleOauthService_Fix_Resolution.md)** - Résolution erreur Zeitwerk

### 🔧 **Pour les Corrections Critiques**
1. **[🔧 Zeitwerk OAuth 19/12/2025](./technical/changes/2025-12-19-Zeitwerk_OAuth_Services_Rename.md)** - Erreur `uninitialized constant OauthTokenService`
2. **[🔒 Sécurité Secrets 19/12/2025](./technical/changes/2025-12-19-Security_CI_Complete_Fix.md)** - Secrets exposés → GitHub Secrets
3. **[GoogleOauthService 18/12/2025](./technical/changes/2025-12-18-GoogleOauthService_Fix_Resolution.md)** - Erreur `uninitialized constant GoogleOauthService`
4. **[CI GitHub 18/12/2025](./technical/changes/2025-12-18-CI_Fix_Resolution.md)** - Pipeline CI cassée

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
| [📋 2025-12-19-Rswag_OAuth_Specs_Feature_Contract.md](./technical/changes/2025-12-19-Rswag_OAuth_Specs_Feature_Contract.md) | 19/12/2025 | Specs rswag OAuth conformes au Feature Contract | **MAJEUR** - Swagger auto-généré |
| [🔧 2025-12-19-Zeitwerk_OAuth_Services_Rename.md](./technical/changes/2025-12-19-Zeitwerk_OAuth_Services_Rename.md) | 19/12/2025 | Renommage fichiers OAuth pour Zeitwerk | **CRITIQUE** - CI fonctionnelle |
| [🔒 2025-12-19-Security_CI_Complete_Fix.md](./technical/changes/2025-12-19-Security_CI_Complete_Fix.md) | 19/12/2025 | Sécurisation secrets + Configuration GitHub Secrets | **CRITIQUE** - Sécurité renforcée |
| [2025-12-18-OAuthTokenService_Comment_Fix.md](./technical/changes/2025-12-18-OAuthTokenService_Comment_Fix.md) | 18/12/2025 | Correction commentaires OAuthTokenService | **MINEUR** - Qualité code |
| [2025-12-18-CI_Fix_Resolution.md](./technical/changes/2025-12-18-CI_Fix_Resolution.md) | 18/12/2025 | Résolution problèmes CI GitHub | **CRITIQUE** - CI fonctionnelle |
| [2025-12-18-GoogleOauthService_Fix_Resolution.md](./technical/changes/2025-12-18-GoogleOauthService_Fix_Resolution.md) | 18/12/2025 | Résolution erreur Zeitwerk GoogleOauthService | **CRITIQUE** - 87 tests, 0 échec |

### 🔍 **Rapports d'Audit** (`docs/technical/audits/`)
Analyses techniques et historiques des modifications.

| Fichier | Type | Description |
|---------|------|-------------|
| [ANALYSE_TECHNIQUE_FORESY.md](./technical/audits/ANALYSE_TECHNIQUE_FORESY.md) | Analyse | Architecture technique et bonnes pratiques |
| [CHANGELOG_REFACTORISATION.md](./technical/audits/CHANGELOG_REFACTORISATION.md) | Historique | Chronologie des refactorisations et améliorations |

### 🛠️ **Corrections Techniques** (`docs/technical/corrections/`)
Résolutions de problèmes critiques et interventions majeures.

| Fichier | Date | Problème Résolu | Impact |
|---------|------|-----------------|--------|
| [CORRECTIONS_JANVIER_2025.md](./technical/corrections/CORRECTIONS_JANVIER_2025.md) | 01/2025 | CI complètement cassée (0 tests) | **MAJEUR** - Pipeline fonctionnel |

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
**Dernière révision :** 19 décembre 2025  
**Version :** 1.3  
**Statut :** ✅ Actif et maintenu