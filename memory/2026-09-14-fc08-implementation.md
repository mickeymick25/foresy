<!-- category: foresy -->

# FC-08 v3.2.3 — Company & User-Company Relationships

## fc08::001
<!-- created: 2026-09-14 -->
<!-- updated: 2026-09-15 -->
FC-08 v3.2.3 implémenté et **MERGÉ** sur main le 15/09/2026 (PR #24, CI 6/6 verts, suite 956/0). Contrat gelé v3.2.3, statut Implementation-Ready respecté. Post-merge CTO : tag version, déploiement staging E2E, monitoring prod 24-48h.

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
<!-- updated: 2026-09-15 -->
Gate CTO pre-merge (PR #24) : invariants 21/22 testés (spec architecture 7/7 ; INV-15 justifié — aucun code de simulation). CI : RuboCop corrigé ; 2 jobs débloqués le 15/09 : D-8 signup 400 (StandardError déclaré en premier dans StandardizedError — dernier déclaré gagne, cf. rescuable.rb) et D-9 rubyzip 3.6.0 (CVE-2026-85396). Suite 956/0, smoke 15/15, contrat p1_2 préservé. Merge PR #24 le 15/09 (tag v0.1.1). Dette : D-5 résolue (durcissement GitLedger SAFE_ID_PATTERN + ignore Brakeman régénéré → 0 warning), D-10 résolue (foresy_test + guide isolation), D-4 résolue (scripts E2E hérités réparés — run_request/HTTP_CODE, JSON month %m → %-m, flottants awk ; branche `chore/d4-e2e-scripts-repair`). Reste : D-2 (SimpleCov), D-11 (Node 24 actions).

## fc08::007
<!-- created: 2026-09-16 -->
<!-- updated: 2026-09-16 -->
Vérification dette D-1→D-11 le 16/09 (branche `chore/d4-e2e-scripts-repair`, rapport `docs/technical/changes/2026-09-16-D1-D11_Debt_Verification_Report.md`) : fond conforme — suite 957/0, Brakeman 0, bundle-audit 0, smoke 15/15, E2E cra/auth rejoués ×2 ; anomalies à traiter : D-5 casse RuboCop (2 offenses `SAFE_ID_PATTERN` L92, correctif `style(d5)`), PR D-4 à ouvrir, journal D-5 surévalué (p6_1 = 10/0), memory-indexer en attente (hub fc08::006 périmée).