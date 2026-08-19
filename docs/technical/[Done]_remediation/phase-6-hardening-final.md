# Phase 6 — Hardening Final

**Phase :** P6 — Hardening Final
**Priorité :** 🟢 Moyenne
**Statut phase :** ✅ Terminée
**Date de début :** 2026-08-18
**Date de fin prévue :** 2026-08-18
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

| ID | Tâche | Statut | 🔴 RED | 🟢 GREEN | 🔵 REFACTOR | PR | Notes |
|---|---|---|---|---|---|---|---|
| P6.1 | Sécuriser `GitLedgerRepository` shell | ✅ | ✅ | ✅ | ✅ | — | Open3.capture3, 9 specs injection |
| P6.2 | Nettoyer `CraEntry` callbacks + `attr_writer` | ✅ | ✅ | ✅ | ✅ | — | Commentaires + attr_writer supprimés |
| P6.3 | Évaluer migration `users` PK → UUID | ✅ | ✅ | ✅ | ✅ | — | Documenté comme choix architectural |

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

### 🔴 RED — 2026-08-18 — P6.1

- **Test ajouté :** `spec/integration/p6_1_git_ledger_shell_injection_spec.rb` (9 specs : aucun backtick utilisé + tests d'injection shell sur `GitLedgerRepository`)
- **Invariant visé :** `GitLedgerRepository` n'utilise ni backticks ni `system()` ; les tentatives d'injection shell sont neutralisées
- **Raison de l'échec :** `GitLedgerRepository` utilise des backticks et `system()` avec interpolation de chaînes
- **Commit :** `test: P6.1 caracterise la securisation de GitLedgerRepository contre l'injection shell`

### 🟢 GREEN — 2026-08-18 — P6.1

- **Implémentation minimale :** Remplacement des backticks/`system()` par `Open3.capture3` + `Shellwords.escape` + `chdir:`
- **Fichiers modifiés :** `app/.../git_ledger_repository.rb`
- **Test passe ✅ :** 9 examples, 0 failures
- **Commit :** `fix: P6.1 securise GitLedgerRepository via Open3.capture3`

### 🔴 RED — 2026-08-18 — P6.2

- **Test ajouté :** `spec/integration/p6_2_cra_entry_callbacks_cleanup_spec.rb`
- **Invariant visé :** `CraEntry` ne contient aucun callback commenté ni `attr_writer :cra, :mission`
- **Raison de l'échec :** Le modèle contient un bloc commenté "NE PLUS UTILISER" et un `attr_writer :cra, :mission`
- **Commit :** `test: P6.2 caracterise l'absence de callbacks commentes et d'attr_writer sur CraEntry`

### 🟢 GREEN — 2026-08-18 — P6.2

- **Implémentation minimale :** Suppression du bloc "NE PLUS UTILISER" commenté + suppression de `attr_writer :cra, :mission`
- **Fichiers modifiés :** `app/models/cra_entry.rb`
- **Test passe ✅ :** 3 examples, 0 failures
- **Commit :** `fix: P6.2 supprime le bloc commente et attr_writer de CraEntry`

### 🟣 DÉCISION — 2026-08-18 — P6.3

- **Décision :** Option A — Documenter comme choix architectural (recommandé)
- **Justification :** `users` conserve une PK `bigint` pour les performances des joins ; une colonne `uuid` séparée sert à l'identification publique
- **Impact :** Aucun changement DB ; décision tracée dans le document d'audit
- **Commit :** `docs: P6.3 documente le choix architectural PK bigint + colonne uuid publique`

### 🎯 Merge — 2026-08-18

- **PR :** Branche `phase-6-hardening-final`
- **Validation Platinum :** rspec ✅ / rubocop ✅ / brakeman ✅ / zeitwerk ✅ + tests d'injection shell ✅
- **Notes :** P6.3 clos sans migration (Option A) — `users` reste bigint PK + colonne uuid publique

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