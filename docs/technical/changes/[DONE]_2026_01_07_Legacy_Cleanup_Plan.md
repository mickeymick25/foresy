# Plan de Nettoyage des Legacy Services - Foresy

> **✅ PHASE 1 EXÉCUTÉE le 18 septembre 2026** (PR P6.1-bis, branche
> `chore/p61-coverage-lock`) — relevé d'exécution en fin de document.
> Le verrou de couverture P6.1 a révélé en CI que le corpus eager-load
> mesurait encore ces services morts : 67,27 % CI vs 73,21 % conteneur.
> Chaîne causale complète : journal P6.1-bis
> (`docs/technical/[DONE]_2026_08_31_fc08_implementation_tracker.md`).
>
> **Régularisé le 18/09/2026** : déplacé depuis la racine du dépôt vers
> `docs/technical/changes/` (convention du dépôt + indexation RAG).
> Historique : artifact de session agent du 27/01 (commit `589f98d4`,
> auteur `foresy-ledger` — identité conteneur pré-A6), posé hors de
> l'arborescence documentaire et non référencé par `docs/index.md` —
> d'où son oubli pendant 8 mois (jamais exécuté jusqu'à P6.1-bis).

## 🎯 Objectif
Nettoyer complètement les services legacy Api::V1::* et leurs tests non utilisés pour finaliser la migration DDD.

## 📊 État Actuel (7 Janvier 2026)

### ✅ Services Domain (DDD) - CONSERVER
- `Services::CraEntries::Create` - ✅ Fonctionnel
- `Services::CraEntries::Update` - ✅ Fonctionnel  
- `Services::CraEntries::Destroy` - ✅ Fonctionnel
- `Services::CraEntries::List` - ✅ Fonctionnel
- `CraEntryServices::Create` - ✅ Fonctionnel
- `CraEntryServices::Update` - ✅ Fonctionnel
- `CraEntryServices::Destroy` - ✅ Fonctionnel

### ❌ Services API Legacy - À SUPPRIMER
- `Api::V1::CraEntries::DestroyService` - ❌ Jamais utilisé, tests échouent
- `Api::V1::CraEntries::CreateService` - ❌ Jamais utilisé
- `Api::V1::CraEntries::UpdateService` - ❌ Jamais utilisé
- `Api::V1::CraEntries::ListService` - ❌ Jamais utilisé

### 🧪 Tests Legacy - À SUPPRIMER
- `spec/services/cra_entries/destroy_service_unlink_spec.rb` - ❌ Teste service jamais utilisé
- `spec/services/api/v1/cra_entries/*_spec.rb` - ❌ Tests pour services API jamais utilisés

## 🗑️ Plan de Suppression

### Phase 1 : Services API Legacy (Priorité HAUTE)

#### 1.1 Supprimer Api::V1::CraEntries::DestroyService
**Fichiers à supprimer :**
- `app/services/api/v1/cra_entries/destroy_service.rb`
- `spec/services/cra_entries/destroy_service_unlink_spec.rb`

**Raison :**
- Service jamais utilisé dans l'application (controller utilise Services::CraEntries::Destroy)
- Tests échouent à cause de problèmes de permissions API
- Logique métier déjà couverte par CraEntryServices::Destroy (tests passent)

#### 1.2 Supprimer Autres Services API Legacy
**Fichiers à supprimer :**
- `app/services/api/v1/cra_entries/create_service.rb`
- `app/services/api/v1/cra_entries/update_service.rb` 
- `app/services/api/v1/cra_entries/list_service.rb`

**Raison :**
- Controller utilise maintenant Services::CraEntries::* directement
- Ces services ne sont jamais appelée dans l'application
- Redondants avec les services Domain

#### 1.3 Supprimer Tests API Legacy
**Fichiers à supprimer :**
- `spec/services/api/v1/cra_entries/*_spec.rb` (si existants)

**Raison :**
- Tests pour services jamais utilisés
- Créent de la confusion architecturale
- Maintenance inutile

### Phase 2 : Nettoyage Architecture

#### 2.1 Vérifier Références Mortes
**Actions :**
- Rechercher toutes références à `Api::V1::CraEntries::*` dans le codebase
- Vérifier routes, tests, documentation
- Supprimer ou remplacer les références trouvées

#### 2.2 Mettre à Jour Documentation
**Actions :**
- Supprimer références aux services API legacy dans README
- Mettre à jour documentation Swagger/RDoc
- Clarifier architecture DDD dans documentation

## 🚀 Avantages de la Suppression

### Architecturaux
- ✅ Architecture DDD pure
- ✅ Séparation claire des responsabilités
- ✅ Réduction de la complexité cognitive
- ✅ Élimination des chemins morts

### Maintenance
- ✅ Moins de code à maintenir
- ✅ Tests plus ciblés et efficaces
- ✅ Configuration plus simple
- ✅ Déploiement plus rapide

### Qualité
- ✅ Élimination des tests rassurants sur du code mort
- ✅ Couverture de tests plus précise
- ✅ Meilleure traçabilité des bugs
- ✅ Architecture plus prédictible

## ⚠️ Précautions

### Avant Suppression
1. ✅ Vérifier que le controller fonctionne avec les services Domain
2. ✅ Tester toutes les routes API CRA
3. ✅ Valider que les tests Domain couvrent les cas d'usage
4. ✅ Sauvegarder le code avant suppression

### Après Suppression  
1. ✅ Lancer la suite de tests complète
2. ✅ Vérifier les routes API
3. ✅ Tester les fonctionnalités utilisateur
4. ✅ Mettre à jour la documentation

## 📋 Checklist de Validation

### Tests Pré-Suppression
- [ ] Controller `cra_entries_controller.rb` fonctionne
- [ ] Services Domain `Services::CraEntries::*` couvrent les cas d'usage
- [ ] Tests Domain `CraEntryServices::*` passent
- [ ] Routes API CRA fonctionnelles

### Tests Post-Suppression
- [ ] Suite de tests RSpec passe (449 exemples)
- [ ] Tests Swagger passent (128 exemples)
- [ ] Pas d'erreurs RuboCop (147 fichiers)
- [ ] Pas de warnings Brakeman (3 ignorés)

## 🎯 Résultats Attendus

### Avant Suppression
- **Tests totaux** : ~449 exemples (avec tests legacy)
- **Architecture** : Mix DDD + API Legacy
- **Services CRA** : 8 services (4 DDD + 4 API)
- **Complexité** : Élevée (chemins morts)

### Après Suppression
- **Tests totaux** : ~441 exemples (sans tests legacy)
- **Architecture** : DDD pur
- **Services CRA** : 4 services (4 DDD)
- **Complexité** : Réduite (architecture claire)

## 📞 Actions Immédiates

1. **Vérifier** que le controller corrigé fonctionne en production
2. **Supprimer** `Api::V1::CraEntries::DestroyService` et ses tests
3. **Tester** que tout fonctionne sans les services legacy
4. **Répéter** pour les autres services API

---

**Statut** : ✅ PHASE 1 EXÉCUTÉE (18 septembre 2026)
**Priorité** : HAUTE (Architecture)
**Impact** : POSITIF (Nettoyage architectural)

## 📝 Relevé d'exécution (18 septembre 2026)

**Fichiers supprimés (9)** — `app/services/api/` entier, plus l'extension vérifiée `app/lib` :

- `app/services/api/v1/cras/{create,update,list,lifecycle,export,destroy}_service.rb` (6)
- `app/services/api/v1/cra_entries/list_service.rb` — seul rescapé de la liste du plan ;
  les autres `cra_entries` legacy (`destroy/create/update`) avaient déjà disparu du dépôt
- Extension vérifiée (GO CTO 18/09) : `app/lib/http_status_map.rb`, `app/lib/mission_errors.rb`
  — zéro référence active (grep exhaustif app/config/lib/spec/bin), jamais chargés en lazy

**Tests legacy (§1.3 du plan)** : déjà absents du dépôt — rien à supprimer.

**Vérification §2.1 (références mortes)** : grep exhaustif — seuls subsistent des commentaires
`# Migrated from Api::V1::Cras::* to CraServices namespace` (documentation des nouveaux
services, volontaires).

**Validation** : suite 962/0 inchangée (zéro impact fonctionnel — les fichiers étaient
morts) · RuboCop 0 · Brakeman 0 · corpus CI-sim 67,27 % → **72,34 %**.

**Hors périmètre** : `app/services/o_auth_code_exchange_service.rb` (chargé par l'eager
load CI, 26,25 %) — NON supprimé : code de production actif (flow OAuth code-exchange,
appelé par `OAuthValidationService`). Dette de couverture transférée à P6 Wave 2.