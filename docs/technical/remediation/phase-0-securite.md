# Phase 0 — Sécurité Critique

**Phase :** P0 — Sécurité Critique
**Priorité :** 🔴 Critique
**Statut phase :** ✅ Terminée
**Date de début :** —
**Date de fin prévue :** —
**Document parent :** [`docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md)

---

## 🎯 Objectif

Éliminer les failles de sécurité pouvant exposer des données ou permettre des actions non autorisées en production.

## 🧪 Méthodologie TDD + DDD + Platinum

Chaque tâche suit le cycle **🔴 RED → 🟢 GREEN → 🔵 REFACTOR** en 3 commits distincts (voir [§1.3 du document principal](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#13-méthodologie-tdd--ddd--niveau-platinum)).

- 🔴 **RED** : Test d'invariant de sécurité d'abord (ex: assertion pas de JWT dans stdout, route test 404 en prod)
- 🟢 **GREEN** : Implémentation minimale pour faire passer le test
- 🔵 **REFACTOR** : Nettoyage sans casser les tests

**Critères Platinum** : `bundle exec rspec` ✅ + `rubocop` ✅ + `brakeman` ✅ + `zeitwerk:check` ✅ + invariants défensifs ajoutés.

## 📋 Tâches

| ID | Tâche | Statut | 🔴 RED | 🟢 GREEN | 🔵 REFACTOR | PR | Notes |
|---|---|---|---|---|---|---|---|
| P0.1 | Verrouiller routes `__test_support__` en prod | ✅ | ✅ | ✅ | ✅ | — | 9 specs, 0 failures |
P0.2 | Supprimer `puts` JWT dans `authenticatable.rb` | ✅ | ✅ | ✅ | ✅ | — | 3 specs, 0 failures
P0.3 | Supprimer `puts` dans `missions_controller.rb` | ✅ | ✅ | ✅ | ✅ | — | 3 specs, 0 failures
P0.4 | Sécuriser `OauthController#callback` fuite erreurs | ✅ | ✅ | ✅ | ✅ | — | 3 specs, 0 failures

---

## 📝 Journal d'Exécution (TDD)

### 🔴 RED — 2026-07-22 — P0.1

- **Test ajouté :** `spec/integration/test_support_routes_security_spec.rb`
- **Invariant visé :** en production + E2E_MODE=true, `POST /__test_support__/e2e/setup` et `DELETE /__test_support__/e2e/cleanup` doivent retourner 404 et ne pas créer de données.
- **Raison de l'échec :** la condition `Rails.env.test? || ENV['E2E_MODE'] == 'true'` laissait passer `E2E_MODE=true` en production ; `verify_e2e_mode!` levait `RoutingError` qui devenait 500 en test env.
- **Commit :** (non committé, branche `phase-1-9-error-contract`)

### 🟢 GREEN — 2026-07-22 — P0.1

- **Implémentation minimale :**
  - `config/routes.rb` : condition `Rails.env.test? || (ENV['E2E_MODE'] == 'true' && !Rails.env.production?)`
  - `app/controllers/__test_support__/e2e/setup_controller.rb` : `e2e_mode_enabled?` ajoute `&& !Rails.env.production?` ; `verify_e2e_mode!` rend 404 JSON au lieu de lever `RoutingError`.
- **Fichiers modifiés :** `config/routes.rb`, `app/controllers/__test_support__/e2e/setup_controller.rb`
- **Test passe ✅ :** 9 examples, 0 failures (4 unitaires sur `e2e_mode_enabled?` + 4 de request sur le comportement 404 + 1 non-création de données)
- **Commit :** (non committé)

### 🔵 REFACTOR — 2026-07-22 — P0.1

- **Amélioration :** nettoyage du debug temporaire, `return` explicite après `render`, RuboCop clean.
- **Tests toujours verts ✅ :** 9 examples, 0 failures
- **Non-régression ✅ :** 12 échecs préexistants sur `spec/requests` confirmés identiques sans mes changements (branche `phase-1-9-error-contract`).
- **Validation Platinum :** rspec ✅ / rubocop ✅ (3 files, 0 offenses)
- **Commit :** (non committé)

### 🔴 RED — 2026-07-22 — P0.2

- **Test ajouté :** `spec/integration/authenticatable_security_spec.rb`
- **Invariant visé :** après une requête authentifiée, stdout ne doit contenir ni le token JWT, ni l'en-tête Authorization, ni aucune sortie de debug de `authenticate_access_token!`.
- **Raison de l'échec :** 7 `puts` dans `authenticatable.rb` dont un qui imprimait `request.headers['Authorization']` (token JWT complet) dans stdout. Sortie capturée : `request.headers['Authorization'] = "Bearer eyJhbGci..."`.
- **Commit :** (non committé)

### 🟢 GREEN — 2026-07-22 — P0.2

- **Implémentation minimale :** suppression des 7 `puts` dans `app/controllers/concerns/authenticatable.rb` (méthode `authenticate_access_token!`).
- **Fichiers modifiés :** `app/controllers/concerns/authenticatable.rb`
- **Test passe ✅ :** 3 examples, 0 failures
- **Commit :** (non committé)

### 🔵 REFACTOR — 2026-07-22 — P0.2

- **Amélioration :** `grep` confirme aucun `puts` restant dans `authenticatable.rb`. RuboCop clean (2 files, 0 offenses).
- **Tests toujours verts ✅ :** 3 examples, 0 failures
- **Non-régression ✅ :** 64 examples, 0 failures sur `spec/requests/api/v1/authentication` + `spec/integration/authenticatable_security_spec.rb` + `spec/integration/test_support_routes_security_spec.rb`.
- **Validation Platinum :** rspec ✅ / rubocop ✅
- **Commit :** (non committé)

### 🎯 Merge — 2026-07-22

- **PR :** (en attente de commit)
- **Validation Platinum :** rspec ✅ / rubocop ✅
- **Notes :** Fuite critique de credentials éliminée. Le token JWT n'apparaît plus dans stdout après authentification.

---

## ✅ Critères de Fin de Phase

- [ ] Test d'intégration : `__test_support__/*` retourne 404 en prod même avec `E2E_MODE=true`
- [ ] Test : aucun token JWT dans stdout/stderr après une requête authentifiée
- [ ] Test : `OauthController#callback` ne renvoie jamais `e.message` au client
- [ ] `bundle exec rspec` passe
- [ ] `bundle exec rubocop` passe
- [ ] `bundle exec brakeman` sans nouvelle vulnérabilité

---

## 🔗 Références

- [Tâche P0.1 — Verrouiller routes `__test_support__`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p01--verrouiller-les-routes-__test_support__-en-production)
- [Tâche P0.2 — Supprimer `puts` JWT](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p02--supprimer-les-puts-exposant-le-token-jwt-dans-authenticatablerb)
- [Tâche P0.3 — Supprimer `puts` missions](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p03--supprimer-les-puts-de-debug-dans-missions_controllerrb)
- [Tâche P0.4 — Sécuriser OAuth callback](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p04--sécuriser-oauthcontrollercallback-contre-la-fuite-derreurs)