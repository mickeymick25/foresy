# FC-07 Phase 3C - Corrections Techniques

**Date** : 6 janvier 2026  
**Phase** : 3C - Recalcul Automatique des Totaux CRA  
**Impact** : Tests RSpec  
**Résultat** : 24/24 tests ✅

---

## 🎯 Contexte

Lors de l'implémentation des tests Phase 3C pour le recalcul automatique des totaux CRA (`total_days`, `total_amount`), plusieurs corrections techniques ont été nécessaires pour faire passer tous les tests.

---

## 🐛 Correction 1 : Lazy Evaluation RSpec

### Problème

Les blocs `before` dans les tests `UpdateService` et `DestroyService` vérifiaient les totaux du CRA avant que l'entrée (`entry`) ne soit créée.

En RSpec, les `let` blocks sont **lazy-evaluated** : ils ne s'exécutent que lorsqu'ils sont explicitement appelés.

### Symptôme

```
Failure/Error: expect(cra.total_days).to eq(1.0)
  expected: 1.0
       got: 0.0
```

### Code Avant (ÉCHEC)

```ruby
describe 'CraEntries::UpdateService' do
  let(:entry) do
    result = Api::V1::CraEntries::CreateService.call(...)
    result.entry
  end

  before do
    cra.reload
    expect(cra.total_days).to eq(1.0)  # ÉCHEC : entry pas encore créé !
  end
end
```

### Code Après (SUCCÈS)

```ruby
describe 'CraEntries::UpdateService' do
  let(:entry) do
    result = Api::V1::CraEntries::CreateService.call(...)
    result.entry
  end

  before do
    entry  # Force lazy evaluation - CRITIQUE !
    cra.reload
    expect(cra.total_days).to eq(1.0)
  end
end
```

### Fichiers Modifiés

- `spec/services/cra_entries/total_recalculation_service_spec.rb`
  - Ligne 281 : Ajout de `entry` dans le before block (UpdateService)
  - Ligne 468 : Ajout de `entry` dans le before block (DestroyService)

---

## 🐛 Correction 2 : Calcul Financier (Centimes)

### Problème

Erreur de frappe dans le nombre de zéros du montant attendu.

### Symptôme

```
Failure/Error: expect(cra.total_amount).to eq(1_250_00)
  expected: 125000
       got: 1250000
```

### Analyse

- 50 entrées × 0.5 jours × 500_00 centimes = 1_250_000 centimes
- Le test avait `1_250_00` (125,000) au lieu de `1_250_000` (1,250,000)

### Code Avant (ÉCHEC)

```ruby
expect(cra.total_amount).to eq(1_250_00)  # 125,000 centimes = 1,250 EUR
```

### Code Après (SUCCÈS)

```ruby
expect(cra.total_amount).to eq(1_250_000)  # 1,250,000 centimes = 12,500 EUR
```

### Fichier Modifié

- `spec/services/cra_entries/total_recalculation_service_spec.rb`
  - Ligne 820 : Correction `1_250_00` → `1_250_000`

---

## 🐛 Correction 3 : Variable de Référence Manquante

### Problème

Le test "destroying entries in sequence" utilisait `@second_entry` qui n'était jamais défini dans le contexte.

### Symptôme

```
CraErrors::EntryNotFoundError:
  CRA entry not found
```

### Cause

La boucle de création d'entrées ne stockait pas les références :

```ruby
# Boucle anonyme - pas de référence stockée
2.times do |i|
  result = Api::V1::CraEntries::CreateService.call(...)
end
# @second_entry n'existe pas !
```

### Code Avant (ÉCHEC)

```ruby
before do
  2.times do |i|
    result = Api::V1::CraEntries::CreateService.call(
      cra: cra,
      entry_params: { date: "2024-03-#{16 + i}", ... },
      ...
    )
  end
  cra.reload
end

it 'maintains accurate totals as entries are destroyed' do
  Api::V1::CraEntries::DestroyService.call(entry: @second_entry, ...)  # ÉCHEC !
end
```

### Code Après (SUCCÈS)

```ruby
before do
  # Création explicite avec références stockées
  result = Api::V1::CraEntries::CreateService.call(
    cra: cra,
    entry_params: { date: '2024-03-16', ... },
    ...
  )
  @second_entry = result.entry

  result = Api::V1::CraEntries::CreateService.call(
    cra: cra,
    entry_params: { date: '2024-03-17', ... },
    ...
  )
  @third_entry = result.entry
  cra.reload
end

it 'maintains accurate totals as entries are destroyed' do
  Api::V1::CraEntries::DestroyService.call(entry: @second_entry, ...)  # SUCCÈS !
end
```

### Fichier Modifié

- `spec/services/cra_entries/total_recalculation_service_spec.rb`
  - Lignes 530-575 : Remplacement de la boucle par des créations explicites

---

## ✅ Résultat Final

```bash
docker compose exec web bundle exec rspec spec/services/cra_entries/total_recalculation_service_spec.rb --format progress

# Avant corrections : 13 failures
# Après corrections : 0 failures

# 24 examples, 0 failures
```

---

## 📚 Leçons Apprises

### 1. RSpec Lazy `let` 

**Règle** : Si un `before` block dépend d'un `let`, toujours appeler le `let` explicitement.

```ruby
# ✅ Pattern correct
before do
  entry  # Force l'évaluation
  cra.reload
end
```

### 2. Montants Financiers

**Règle** : Toujours vérifier le nombre de zéros dans les calculs en centimes.

```ruby
# Calcul : 50 × 0.5 × 500_00
# = 25 × 500_00
# = 1_250_000 centimes
# = 12,500.00 EUR
```

### 3. Variables d'Instance dans les Tests

**Règle** : Préférer les créations explicites aux boucles anonymes quand les références sont nécessaires.

```ruby
# ❌ Boucle anonyme
3.times { |i| create_entry(i) }

# ✅ Créations explicites
@first = create_entry(0)
@second = create_entry(1)
@third = create_entry(2)
```

---

## 🔗 Références

- [Phase 3C Completion Report](../phases/FC07-Phase3C-Completion-Report.md)
- [FC-07 Progress Tracking](../testing/fc07_progress_tracking.md)
- [FC-07 Changelog](../development/fc07_changelog.md)

---

*Document créé : 6 janvier 2026*  
*Auteur : Session TDD avec CTO*  
*Status : ✅ RÉSOLU*