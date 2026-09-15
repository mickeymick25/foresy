<!-- category: foresy -->

# FC-08 v3.2.3 — Company & User-Company Relationships

## fc08::001
<!-- created: 2026-09-14 -->
<!-- updated: 2026-09-14 -->
FC-08 v3.2.3 implémenté sur `feature/fc-08-companies`, phases 1-9 complètes (16/19 tâches). Contrat gelé, statut Implementation-Ready / TDD-Ready. **PR #24 ouverte : https://github.com/mickeymick25/foresy/pull/24** — en attente de merge.

## fc08::002
<!-- created: 2026-09-14 -->
Migration `20260914000001` : `companies.siren` NOT NULL + UNIQUE, `siret` nullable (unique conservé), `vat_regime` string nullable, `user_companies.deleted_at`, enum `user_company_role_enum` conservé. Garde-fou données §47.1 + down complet.

## fc08::003
<!-- created: 2026-09-14 -->
Qualité FC-08 : RSpec 948/948, RuboCop 0 offense, swaggerize 402/402, audit routes↔swagger 35/35, Brakeman 0 warning FC-08, E2E rejouable 19/19 ×2 (SIREN/SIRET dérivés du RUN_ID).

## fc08::004
<!-- created: 2026-09-14 -->
Dette transverse tracée dans `docs/technical/fc08_debt_register.md` : D-2 couverture de lignes (SimpleCov), D-4 scripts E2E hérités à réparer, D-5 warnings Brakeman préexistants `GitLedgerRepository`. Détails : `docs/technical/testing/fc08_coverage_report.md` (19/22 invariants couverts).

## fc08::005
<!-- created: 2026-09-14 -->
Erreurs API standardisées en format plat `{code, message, details}` (concern `StandardizedError`, contrat §44) — le helper de test `ErrorResponseHelper` attend un format imbriqué et n'est pas aligné.

## fc08::006
<!-- created: 2026-09-15 -->
Gate CTO pre-merge (PR #24) : invariants 21/22 testés (spec architecture 7/7 ; INV-15 justifié — aucun code de simulation). CI : RuboCop corrigé ; 2 jobs bloqués par dette PRÉEXISTANTE : D-8 signup 500 (ParameterMissing rendu en 500, fix → 400 requis pour le job E2E) et D-9 CVE rubyzip ≥ 3.4.0 (requis pour Security Audit). Base dev polluée par les runs E2E → nettoyée (13 users e2e-*, 10 companies), suite 955/955 vert ; D-10 = isolement bases test/dev à créer. Plan d'action CI Gate : registre de dette §5.