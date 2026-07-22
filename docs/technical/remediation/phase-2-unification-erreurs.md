# Phase 2 — Unification des Erreurs

**Phase :** P2 — Unification des Erreurs
**Priorité :** 🟡 Haute
**Statut phase :** ✅ Terminée
**Date de début :** —
**Date de fin prévue :** —
**Document parent :** [`docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md)

---

## 🎯 Objectif

Converger vers UN seul format d'erreur JSON pour toute l'API.

## 🧪 Méthodologie TDD + DDD + Platinum

Chaque tâche suit le cycle **🔴 RED → 🟢 GREEN → 🔵 REFACTOR** en 3 commits distincts (voir [§1.3 du document principal](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#13-méthodologie-tdd--ddd--niveau-platinum)).

- 🔴 **RED** : Test de contrat d'erreur (schéma JSON unique attendu) d'abord
- 🟢 **GREEN** : Unification minimale (suppression/migration des formats concurrents)
- 🔵 **REFACTOR** : Nettoyage des handlers redondants

**DDD** : Les erreurs métier restent typées (`CraErrors::*`). Le format JSON est une responsabilité d'API (controller), pas du domaine.

**Critères Platinum** : rspec ✅ / rubocop ✅ / brakeman ✅ / zeitwerk:check ✅ + tests de contrat RSwag mis à jour + document `error_contract.md` créé.

## 📋 Tâches

| ID | Tâche | Statut | 🔴 RED | 🟢 GREEN | 🔵 REFACTOR | PR | Notes |
|---|---|---|---|---|---|---|---|
P2.1 | Évaluer et merger la Phase 1.9 | ✅ | ✅ | ✅ | ✅ | — | Déjà présente sur la branche
P2.2 | Supprimer le concern orphelin `ErrorRenderable` | ✅ | ✅ | ✅ | ✅ | — | 2 specs, 0 failures
P2.3 | Migrer `render_fc07_error` vers le format unifié | ✅ | ✅ | ✅ | ✅ | — | 3 specs + 18 non-régression

---

## 📝 Format d'Erreur Cible

> À documenter une fois la décision prise en P2.1.

**Schéma JSON cible :**
```json
{
  "code": "ERROR_CODE",
  "message": "Description lisible",
  "details": { }
}
```

**Source de vérité :** `Foresy/app/controllers/concerns/standardized_error.rb` (à confirmer en P2.1)

**Document de référence :** `Foresy/docs/technical/guides/error_contract.md` (à créer)

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

- [ ] Test : tous les endpoints d'erreur retournent le même schéma JSON
- [ ] `grep -r "render_fc07_error" app/` retourne 0 résultat
- [ ] `grep -r "ErrorRenderable" app/` retourne 0 résultat
- [ ] Document `docs/technical/guides/error_contract.md` créé
- [ ] Tests RSwag mis à jour et passent
- [ ] `bundle exec rspec` passe

---

## 🔗 Références

- [Tâche P2.1 — Évaluer et merger Phase 1.9](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p21--évaluer-et-merger-la-phase-19-standardized-error-contract)
- [Tâche P2.2 — Supprimer `ErrorRenderable`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p22--supprimer-le-concern-orphelin-errorrenderable)
- [Tâche P2.3 — Migrer `render_fc07_error`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p23--migrer-render_fc07_error-vers-le-format-unifié)