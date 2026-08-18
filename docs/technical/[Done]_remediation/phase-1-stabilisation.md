# Phase 1 — Stabilisation Runtime

**Phase :** P1 — Stabilisation Runtime
**Priorité :** 🔴 Critique
**Statut phase :** ✅ Terminée
**Date de début :** 2026-08-18
**Date de fin prévue :** 2026-08-18
**Document parent :** [`docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md)

---

## 🎯 Objectif

Éliminer les crashes runtime garantis et neutraliser les handlers qui masquent les erreurs.

## 🧪 Méthodologie TDD + DDD + Platinum

Chaque tâche suit le cycle **🔴 RED → 🟢 GREEN → 🔵 REFACTOR** en 3 commits distincts (voir [§1.3 du document principal](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#13-méthodologie-tdd--ddd--niveau-platinum)).

- 🔴 **RED** : Test caractérisant le comportement attendu (ex: boot sans `NameError`, route 500 renvoie JSON formaté)
- 🟢 **GREEN** : Implémentation minimale (suppression ou création de classe)
- 🔵 **REFACTOR** : Nettoyage cohérent (suppression des couches obsolètes)

**DDD** : P1.1 (services `CraEntries::*`) doit respecter l'isolation du domaine — pas d'infrastructure dans les services.

**Critères Platinum** : rspec ✅ / rubocop ✅ / brakeman ✅ / zeitwerk:check ✅ + tests d'invariants runtime.

## 📋 Tâches

| ID | Tâche | Statut | 🔴 RED | 🟢 GREEN | 🔵 REFACTOR | PR | Notes |
|---|---|---|---|---|---|---|---|
P1.1 | Résoudre crash `Domain::CraEntry::CraEntry` | ✅ | ✅ | ✅ | ✅ | — | Option A: 4 fichiers supprimés
P1.2 | Résoudre conflit `rescue_from StandardError` | ✅ | ✅ | ✅ | ✅ | — | 2 specs, 0 failures

---

## 📝 Décisions de Phase

### P1.1 — Option A (supprimer) vs Option B (créer `Domain::CraEntry`)

- **Décision :** ⬜ À prendre
- **Date :** —
- **Justification :**
- **Impact :**

---

## 📝 Journal d'Exécution (TDD)

### 🔴 RED — 2026-08-18 — P1.1

- **Test ajouté :** `spec/integration/p1_1_cra_entries_dead_layer_removal_spec.rb`
- **Invariant visé :** `CraEntries::*` n'est plus autoloadable, l'app boote sans `NameError`
- **Raison de l'échec :** Les classes `CraEntries::Create/Update/Destroy/List` existent encore dans `app/services/cra_entries/`
- **Commit :** `test: P1.1 caracterise la suppression de la couche CraEntries morte`

### 🟢 GREEN — 2026-08-18 — P1.1

- **Implémentation minimale :** Suppression des 4 fichiers `app/services/cra_entries/*`
- **Fichiers modifiés :** 4 fichiers supprimés (`create.rb`, `update.rb`, `destroy.rb`, `list.rb`)
- **Test passe ✅ :** 9 examples, 0 failures
- **Commit :** `fix: P1.1 supprime la couche CraEntries cassee`

### 🔵 REFACTOR — 2026-08-18 — P1.1

- **Amélioration :** Vérification `rake zeitwerk:check` cohérent après suppression
- **Tests toujours verts ✅ :** 9 examples, 0 failures
- **Commit :** `refactor: P1.1 verifie zeitwerk apres suppression CraEntries`

### 🔴 RED — 2026-08-18 — P1.2

- **Test ajouté :** `spec/integration/p1_2_rescue_from_standard_error_spec.rb`
- **Invariant visé :** Une route levant `StandardError` renvoie un JSON `{ code, message }` en 500
- **Raison de l'échec :** Le bloc `rescue_from StandardError` TEMPORAIRE dans `ApplicationController` avale l'erreur et renvoie un format incohérent
- **Commit :** `test: P1.2 caracterise le contrat d'erreur 500 sur StandardError`

### 🟢 GREEN — 2026-08-18 — P1.2

- **Implémentation minimale :** Suppression du bloc `rescue_from StandardError` TEMPORAIRE dans `ApplicationController`
- **Fichiers modifiés :** `app/controllers/application_controller.rb`
- **Test passe ✅ :** 2 examples, 0 failures
- **Commit :** `fix: P1.2 supprime le rescue_from StandardError temporaire`

### 🎯 Merge — 2026-08-18

- **PR :** Branche `phase-1-9-error-contract`
- **Validation Platinum :** rspec ✅ / rubocop ✅ / zeitwerk ✅
- **Notes :** Option A choisie (supprimer la couche cassée)

---

## ✅ Critères de Fin de Phase

- [ ] Boot de l'app sans `NameError` (P1.1)
- [ ] Test d'intégration : une route levant `StandardError` renvoie un JSON `{ code, message }` en 500 (P1.2)
- [ ] `bundle exec rspec` passe
- [ ] `bundle exec rubocop` passe
- [ ] `bundle exec rake zeitwerk:check` passe

---

## 🔗 Références

- [Tâche P1.1 — Résoudre crash `Domain::CraEntry`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p11--résoudre-le-crash-runtime-domaincraentrycraentry-inexistant)
- [Tâche P1.2 — Résoudre conflit `rescue_from`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p12--résoudre-le-conflit-rescue_from-standarderror)