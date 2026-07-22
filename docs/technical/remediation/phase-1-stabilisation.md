# Phase 1 — Stabilisation Runtime

**Phase :** P1 — Stabilisation Runtime
**Priorité :** 🔴 Critique
**Statut phase :** ✅ Terminée
**Date de début :** —
**Date de fin prévue :** —
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

### 🔴 RED — YYYY-MM-DD — [Tâche PX.Y]

- **Test ajouté :**
- **Invariant visé :**
- **Raison de l'échec :**
- **Commit :** `test: ...`

### 🟢 GREEN — YYYY-MM-DD — [Tâche PX.Y]

- **Implémentation minimale :**
- **Fichiers modifiés :**
- **Test passe ✅ :**
- **Commit :** `fix: ...`

### 🔵 REFACTOR — YYYY-MM-DD — [Tâche PX.Y] (optionnel)

- **Amélioration :**
- **Tests toujours verts ✅ :**
- **Commit :** `refactor: ...`

### 🎯 Merge — YYYY-MM-DD

- **PR :** #
- **Validation Platinum :**
- **Notes :**

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