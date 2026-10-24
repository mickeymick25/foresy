# FC-07 Development Changelog

**Feature Contract** : FC-07 - CRA (Compte Rendu d'Activité) Management  
**Status** : ✅ **100% TERMINÉ - TDD PLATINUM**  
**Période** : 3 janvier 2026 → 6 janvier 2026

---

## 📅 Historique Complet

### 6 Janvier 2026 - Phase 3C TERMINÉE - FC-07 COMPLET 🏆

#### ✅ Phase 3C : Recalcul Automatique des Totaux

**Objectif** : Tester le recalcul automatique de `total_days` et `total_amount`

**Tests créés** : 24 tests
- CreateService : 5 tests (création entrée, multiples, transaction, locked, duplicate)
- UpdateService : 6 tests (quantity, unit_price, both, sequence, transaction, locked)
- DestroyService : 6 tests (only entry, multiple, sequence, transaction, submitted, already deleted)
- Edge cases : 3 tests (decimals, large quantities, many entries)

**Corrections appliquées** :

1. **Lazy Evaluation Fix** (UpdateService + DestroyService)
   ```ruby
   # Avant (ÉCHEC) - entry pas créé avant le reload
   before { cra.reload }
   
   # Après (SUCCÈS)
   before do
     entry  # Force lazy evaluation
     cra.reload
   end
   ```

2. **Financial Calculation Fix**
   ```ruby
   # Avant (ÉCHEC)
   expect(cra.total_amount).to eq(1_250_00)   # Mauvais nombre de zéros
   
   # Après (SUCCÈS)
   expect(cra.total_amount).to eq(1_250_000)  # 50 × 0.5 × 500_00 cents
   ```

3. **Variable Reference Fix** (sequence destroy test)
   - Remplacement de la boucle anonyme par des créations explicites
   - Stockage des références `@second_entry` et `@third_entry`

**Décision architecturale confirmée** :
- ❌ Callbacks ActiveRecord → Rejeté
- ✅ Services Applicatifs → Adopté

**Résultat** : 24/24 tests ✅

---

### 5 Janvier 2026 - Phases 3A + 3B TERMINÉES

#### ✅ Phase 3A : Legacy Tests Alignment

**Objectif** : Aligner les tests legacy avec l'architecture services

**Tests validés** : 9 tests
- `cra_entry_lifecycle_spec.rb` : 6 tests ✅
- `cra_entry_uniqueness_spec.rb` : 3 tests ✅

**Action** : Purge des specs legacy obsolètes (~60 tests)

#### ✅ Phase 3B.1 : Pagination ListService

**Tests créés** : 9 tests
- Pagination standard
- Filtrage par mission
- Tri par date
- Gestion pages vides

**Résultat** : 9/9 tests ✅

#### ✅ Phase 3B.2 : Unlink Mission DestroyService

**Tests créés** : 8 tests
- Suppression avec unlink mission
- Gestion des erreurs
- Validation permissions

**Résultat** : 8/8 tests ✅

---

### 4 Janvier 2026 - Phases 1 + 2 TERMINÉES

#### ✅ Phase 1 : CraEntry Lifecycle + CraMissionLinker

**Objectif** : Établir les invariants métier du lifecycle CRA

**Tests créés** : 6 tests
- create sur CRA draft : ✅ autorisé
- create sur CRA submitted : ❌ CraSubmittedError
- create sur CRA locked : ❌ CraLockedError
- discard sur CRA draft : ✅ autorisé
- discard sur CRA submitted : ❌ CraSubmittedError
- discard sur CRA locked : ❌ CraLockedError

**Implémentation** :
- Guards lifecycle dans `CraEntry` model
- Exceptions métier : `CraErrors::CraSubmittedError`, `CraErrors::CraLockedError`

**Résultat** : 6/6 tests ✅ - TDD PLATINUM

#### ✅ Phase 2 : Unicité Métier

**Objectif** : Un seul `CraEntry` par tuple `(cra, mission, date)`

**Tests créés** : 3 tests
- Création première entrée : ✅
- Création duplicate : ❌ DuplicateEntryError
- Création avec mission différente : ✅

**Implémentation** :
- Validation dans `CreateService`
- Exception : `CraErrors::DuplicateEntryError`

**Résultat** : 3/3 tests ✅ - TDD PLATINUM

---

### 3 Janvier 2026 - Corrections Techniques

#### 🔧 Corrections Namespace

**Problème** : Concerns non trouvés par Zeitwerk
**Solution** : Namespace complet `Api::V1::Cras::*`

**Fichiers modifiés** :
- `app/controllers/concerns/api/v1/cras/error_handler.rb`
- `app/controllers/concerns/api/v1/cras/response_formatter.rb`

#### 🔧 Corrections CraErrors

**Problème** : Module non autoloadé
**Solution** : Déplacement vers `lib/cra_errors.rb`

#### 🔧 Corrections Redis

**Problème** : `NoMethodError: undefined method 'current' for class Redis`
**Solution** : Connection Redis environment-aware

```ruby
# Avant
Redis.current

# Après
@redis = ENV['REDIS_URL'] ? Redis.new(url: ENV['REDIS_URL']) : Redis.new
```

---

## 📊 Métriques Finales

| Métrique | Valeur |
|----------|--------|
| Durée totale | 4 jours |
| Tests services créés | 41 |
| Tests legacy validés | 9 |
| Total tests FC-07 | 50 |
| Couverture | 100% TDD Platinum |
| Bugs corrigés | 6 |
| Specs legacy purgées | ~60 |

---

## 🎓 Leçons Apprises

### 1. Services > Callbacks

La logique métier complexe appartient aux services applicatifs, pas aux callbacks ActiveRecord.

**Avantages** :
- Testabilité
- Prévisibilité
- Contrôle transactionnel explicite

### 2. RSpec Lazy Evaluation

Les `let` blocks sont lazy-evaluated. Toujours forcer l'évaluation avant `reload`.

```ruby
before do
  entry  # ← Critical !
  cra.reload
end
```

### 3. Montants Financiers

- Toujours en centimes (integer)
- Jamais en float
- Documenter l'unité dans les tests

### 4. Purge des Tests Obsolètes

> "On ne garde pas des tests qui testent une architecture obsolète"

Supprimer les tests qui ne reflètent pas l'architecture actuelle évite la confusion et la dette technique.

---

## 🔗 Références

- [FC-07 README](../README.md)
- [Phase 3C Report](../phases/[DONE]_2026_01_05_FC07-Phase3C-Completion-Report.md)
- [Progress Tracking](../testing/[DONE]_2026_01_05_fc07_progress_tracking.md)

---

*Document créé : 6 janvier 2026*  
*Status : ✅ COMPLET*