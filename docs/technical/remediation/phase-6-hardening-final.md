# Phase 6 — Hardening Final

**Phase :** P6 — Hardening Final
**Priorité :** 🟢 Moyenne
**Statut phase :** ⬜ Non commencée
**Date de début :** —
**Date de fin prévue :** —
**Document parent :** [`docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md)

---

## 🎯 Objectif

Sécuriser le Git Ledger, terminer le nettoyage des modèles, finaliser l'API de tests.

## 🧪 Méthodologie TDD + DDD + Platinum

Chaque tâche suit le cycle **🔴 RED → 🟢 GREEN → 🔵 REFACTOR** en 3 commits distincts (voir [§1.3 du document principal](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#13-méthodologie-tdd--ddd--niveau-platinum)).

- 🔴 **RED** : Test d'invariant de sécurité/d'intégrité d'abord (ex: test injection shell sur `GitLedgerRepository`)
- 🟢 **GREEN** : Implémentation sécurisée minimale (`Open3.capture3`, suppression du code commenté)
- 🔵 REFACTOR : Nettoyage cohérent

**DDD** : P6.1 (GitLedger) — l'infrastructure Git doit être isolée dans l'adapter `GitLedgerRepository`, pas dans le domaine. Le domaine ne doit pas connaître `Open3`.

**Critères Platinum** : rspec ✅ / rubocop ✅ / brakeman ✅ / zeitwerk:check ✅ + tests d'invariants défensifs (sécurité, intégrité).

## 📋 Tâches

| ID | Tâche | Statut | PR | Notes |
|---|---|---|---|---|
| P6.1 | Sécuriser `GitLedgerRepository` shell | ⬜ | — | Open3 |
| P6.2 | Nettoyer `CraEntry` callbacks + `attr_writer` | ⬜ | — | |
| P6.3 | Évaluer migration `users` PK → UUID | ⬜ | — | Décision: migrer ou documenter |

---

## 📝 Design : Refactor `GitLedgerRepository` (P6.1)

> Migrer les backticks et `system()` vers `Open3.capture3` avec gestion du exit status.

**Pattern cible :**

```ruby
require 'open3'

def git_log_for_cra(cra_id)
  sanitized_id = Shellwords.escape(cra_id)
  cmd = ['git', 'log', "--grep=CRA locked.*#{sanitized_id}", '--oneline']

  stdout, stderr, status = Open3.capture3(*cmd, chdir: ledger_path)

  unless status.success?
    Rails.logger.error("GitLedger git log failed: #{stderr}")
    return []
  end

  stdout.lines.map(&:strip).reject(&:empty?)
end
```

**Bénéfices :**
- Pas de shell intermédiaire (pas d'injection)
- Gestion explicite du exit status
- Stderr capturé et loggué au lieu d'être supprimé par `2>/dev/null`
- `chdir:` au lieu de `cd ... && git` dans une string shell

**Points d'attention :**
- Conserver la cohérence avec `GitLedgerService.commit_cra_lock!` (transaction DB)
- Tester que les CRA locked existants restent retrouvables via le ledger

---

## 📝 Décision P6.3 — Migrer `users` PK → UUID ou documenter

- **Décision :** ⬜ À prendre
- **Date :** —
- **Options :**
  - **A — Documenter comme décision architecturale** (recommandé, 15min) : Justifier que `users` reste en bigint pour des raisons de performance (joins plus rapides sur bigint que sur UUID) ou de compatibilité OAuth. Fermer le point.
  - **B — Migrer** (4-8h, risque élevé) : Migration en 3 étapes avec backfill des FK.
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

- [ ] Tests d'injection shell sur `GitLedgerRepository` passent (P6.1)
- [ ] `CraEntry` ne contient aucun code commenté (P6.2)
- [ ] `attr_writer :cra, :mission` supprimé ou justifié (P6.2)
- [ ] Décision P6.3 documentée ou migration effectuée
- [ ] `bundle exec rspec` passe
- [ ] `bundle exec brakeman` sans nouvelle vulnérabilité

---

## 🔗 Références

- [Tâche P6.1 — Sécuriser `GitLedgerRepository`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p61--sécuriser-gitledgerrepository-contre-les-injections-shell)
- [Tâche P6.2 — Nettoyer `CraEntry`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p62--nettoyer-craentry--callbacks-commentés--attr_writer-tdd)
- [Tâche P6.3 — Évaluer migration `users` PK](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p63--évaluer-la-migration-users-pk-bigint--uuid-long-terme)