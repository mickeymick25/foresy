# Plan de Nettoyage des Legacy Services - Foresy

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

**Statut** : 🟡 EN ATTENTE DE VALIDATION
**Priorité** : HAUTE (Architecture)
**Impact** : POSITIF (Nettoyage architectural)