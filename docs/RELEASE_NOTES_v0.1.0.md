# 📝 Release Notes — v0.1.0

**Date :** 18 août 2026
**PR :** [#23 — Remédiation Architecture + Phase 1.9](https://github.com/mickeymick25/foresy/pull/23)
**Tag suggéré :** `v0.1.0`

---

## ⚠️ Breaking Changes

### Format d'erreur API unifié

Le format de toutes les réponses d'erreur change :

**Avant :**
```json
{ "error": "invalid_payload", "message": "Description", "timestamp": "2026-..." }
```

**Après :**
```json
{ "code": "INVALID_PAYLOAD", "message": "Description", "details": {} }
```

📖 Documentation complète : [`docs/technical/guides/error_contract.md`](technical/guides/error_contract.md)

### Colonnes DB supprimées

- `cras.created_by_user_id` — remplacé par table pivot `user_cras` (DDD)
- `missions.created_by_user_id` — remplacé par table pivot `user_missions` (DDD)

### Module Rails renommé

- `module App` → `module Foresy` dans `config/application.rb`

### `default_scope` supprimé

Sur 4 modèles (Company, Cra, CraEntry, Mission). Utiliser `.active` explicitement.

---

## ✅ Nouveautés

### Architecture

- **Contrat d'erreur standardisé** : un seul format `{ code, message, details }` via `StandardizedError`
- **DDD finalisé** : toutes les relations via tables pivot, plus de FK directes entre entités métier
- **Thin controllers** : `MissionsController` délègue à `MissionServices::*` (pattern `CraServices::*`)
- **Scopes explicites** : `active`, `with_deleted`, `only_deleted` (remplacement `default_scope`)
- **Migration unique** : 16 migrations squashées en `InitialSchema` (schéma final propre)

### Sécurité

- Routes `__test_support__` verrouillées en production (défense en profondeur)
- `puts` de debug supprimés (dont un qui exposait le token JWT en stdout)
- `OauthController#callback` ne fuit plus `e.message` au client
- `GitLedgerRepository` sécurisé : `Open3.capture3` au lieu de backticks (anti-injection shell)
- Bug GitLedger corrigé : `git add -f` pour bypass `.gitignore` sur fichiers payload

### Qualité

- Gems mis à jour : Rails 8.1.3.1, puma 8.0.2, etc. — **0 vulnérabilités** bundle audit
- ~3162 lignes de code mort supprimées (`app/lib/*`, concerns orphelins)
- `config.load_defaults` 8.1 (aligné sur Rails 8.1.3.1)
- `users.uuid` + `sessions.uuid` : VARCHAR → UUID natif PostgreSQL
- `user_missions.role` + `user_cras.role` : string → enum PostgreSQL

---

## 📊 Métriques

| Métrique | Avant | Après |
|---|---|---|
| Tests RSpec | 742 (12 failures) | **863 (0 failures)** |
| RuboCop | offenses | **225 files, 0 offenses** |
| Bundle audit | 9+ CVE | **0 vulnerabilities** |
| Formats d'erreur | 3 cohabitants | **1 unifié** |
| Code mort | ~3162 lignes | **0** |
| Migrations | 16 (contradictoires) | **1 (propre)** |

---

## 📖 Documentation

| Document | Description |
|---|---|
| [`error_contract.md`](technical/guides/error_contract.md) | Format d'erreur, tous les codes, exemples, migration clients |
| [`migration_strategy.md`](technical/guides/migration_strategy.md) | Squash DB, commandes, réversibilité |
| [`git_ledger_operations.md`](technical/guides/git_ledger_operations.md) | Permissions, sécurité, checklist staging |
| [`[Done]_remediation/`](technical/[Done]_remediation/) | Suivi complet 25/25 tâches (P0-P6) |

---

## 🚀 Déploiement

### Étapes

1. Merger la PR #23 vers `main`
2. Déployer sur staging
3. Exécuter `bundle exec rails db:setup` (nouvelle base — schéma complet)
4. Lancer smoke tests : `docker compose exec web bundle exec rails runner scripts/test_git_ledger.rb`
5. Lancer API smoke tests : `./bin/e2e/smoke_test.sh`
6. Monitorer les logs pendant 1h

### Rollback

```bash
# Revert le merge
git revert <merge-commit>
# Redéployer l'image précédente
```

---

**Auteur :** Zed Agent
**Date :** 18 août 2026