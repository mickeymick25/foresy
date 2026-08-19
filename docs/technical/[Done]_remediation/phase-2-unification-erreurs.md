# Phase 2 — Unification des Erreurs

**Phase :** P2 — Unification des Erreurs
**Priorité :** 🟡 Haute
**Statut phase :** ✅ Terminée
**Date de début :** 2026-08-18
**Date de fin prévue :** 2026-08-18
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

### 🔵 ÉVALUATION — 2026-08-18 — P2.1

- **Constat :** La Phase 1.9 est déjà présente sur la branche, `StandardizedError` déjà introduit
- **Action :** Aucune migration nécessaire — conserver l'existant comme source de vérité du contrat d'erreur
- **Test :** Vérification que `concerns/standardized_error.rb` est autoloadable
- **Commit :** `chore: P2.1 valide StandardizedError deja present (Phase 1.9)`

### 🔴 RED — 2026-08-18 — P2.2

- **Test ajouté :** `spec/integration/p2_2_error_renderable_removal_spec.rb`
- **Invariant visé :** `ErrorRenderable` n'est plus autoloadable, aucune référence dans `app/`
- **Raison de l'échec :** Le concern `ErrorRenderable` existe encore dans `app/controllers/concerns/`
- **Commit :** `test: P2.2 caracterise la suppression du concern orphelin ErrorRenderable`

### 🟢 GREEN — 2026-08-18 — P2.2

- **Implémentation minimale :** Suppression du fichier `app/controllers/concerns/error_renderable.rb`
- **Fichiers modifiés :** 1 fichier supprimé
- **Test passe ✅ :** 2 examples, 0 failures
- **Commit :** `fix: P2.2 supprime le concern orphelin ErrorRenderable`

### 🔴 RED — 2026-08-18 — P2.3

- **Test ajouté :** `spec/integration/p2_3_unified_error_format_spec.rb` (+ 18 specs de non-régression)
- **Invariant visé :** Les erreurs CRA entries utilisent le format unifié `{ code, message, details }` via les helpers `error_*`
- **Raison de l'échec :** Les contrôleurs utilisent encore `render_fc07_error` (format legacy FC07)
- **Commit :** `test: P2.3 caracterise le format d'erreur unifie pour les CRA entries`

### 🟢 GREEN — 2026-08-18 — P2.3

- **Implémentation minimale :** Migration des 20+ appels `render_fc07_error` vers les helpers `error_*` (`StandardizedError`)
- **Fichiers modifiés :** Contrôleurs CRA entries et dépendants
- **Test passe ✅ :** 3 specs + 18 non-régression, 0 failures
- **Commit :** `fix: P2.3 migre render_fc07_error vers error_* unifie`

### 🎯 Merge — 2026-08-18

- **PR :** Branche `phase-2-error-unification`
- **Validation Platinum :** rspec ✅ / rubocop ✅ / brakeman ✅ / zeitwerk ✅ + tests RSwag à jour + `error_contract.md` créé
- **Notes :** `grep -r "render_fc07_error" app/` retourne 0 résultat ; `grep -r "ErrorRenderable" app/` retourne 0 résultat

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