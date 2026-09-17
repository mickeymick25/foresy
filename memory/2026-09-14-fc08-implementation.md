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
<!-- validated: 2026-09-16 (co-CTO, GREEN FOR MERGE PR #25) -->
Vérification dette D-1→D-11 le 16/09 (branche `chore/d4-e2e-scripts-repair`, rapport `docs/technical/changes/2026-09-16-D1-D11_Debt_Verification_Report.md`) : fond conforme — suite 957/0, Brakeman 0, bundle-audit 0, smoke 15/15, E2E cra/auth rejoués ×2. Résolution (**PR #25 mergée le 16/09**, merge commit `8d6c9918`, GREEN FOR MERGE) : A1 style(d5) `650d80c1` (RuboCop 0-offense restaurée), A3/A4 docs(d4) `4caa50ec` (commentaire e2e_cra + journal p6_1 = 10/0), A7 ci(a7) `11432c68` (détectée en revue conjointe — CI ignore-config → `config/brakeman.ignore`) ; A5 périmée (hub synchronisé), A6 racine corrigée (`.git/config` → identité humaine). Restes (⚠️ état historique du 16/09 — depuis traités par fc08::008/fc08::009 : A6 conteneur → PR #27 `8d19bce8` ; D-2 → PR #29 `1c7999aa` ; D-11 → PR #28 `689a4b15`) : A6 conteneur (PR séparée), D-2 SimpleCov (chiffrage), D-11 Node 24 (opportuniste). Suivi : `docs/technical/d1_d11_corrective_actions_tracker.md`.

## fc08::008
<!-- created: 2026-09-17 -->
<!-- updated: 2026-09-17 -->
Vague corrective D-1→D-11 + A1-A7 **terminée, toutes PR mergées** (vérifications par annotations CI + API GitHub). PR #25 (`8d6c9918`) : D-4 réparée (scripts E2E rejouables — codes HTTP >255 tronqués, JSON month, flottants awk) + A1/A3/A4/A7 corrigées (RuboCop 0-offense, commentaire, journal p6_1 = 10/0, CI brakeman.ignore). PR #26 (`dbf90121`) : bookkeeping + `fc08::007` validée humain. PR #27 (`8d19bce8`) : **A6 close** — `.git/config` corrigé (181 commits `foresy-ledger` expliqués), conteneur auto-réparant (compose web self-heal, surcharge `GIT_USER_NAME/GIT_USER_EMAIL`), ledger scopé par design (`run_git` avec `chdir LEDGER_PATH`). PR #28 (`689a4b15`) : **D-11 résolue** — `checkout@v5` (Node 24 natif) + `upload-artifact@v7` (v5 ciblait encore Node 20, détecté par annotations CI), 0 warning vérifié ; D-2 chiffrée. **D-12 créée** (E2E shell hors CI — `LEDGER_PATH` `/app/cra-ledger` codé en dur, vérifié au code L13 ; specs isolées en tmpdir). A5 périmée. CI : 6/6 verts + 0 annotation à chaque PR. Suivi : `docs/technical/d1_d11_corrective_actions_tracker.md`.

## fc08::009
<!-- created: 2026-09-17 -->
<!-- updated: 2026-09-17 -->
**D-2 SimpleCov résolue** (PR #29, `1c7999aa`, GREEN FOR MERGE après durcissement CI) : `simplecov` 1.3.0 + `simplecov-cobertura` 4.0.0, boot dédié `spec/coverage_boot.rb` (SimpleCov AVANT config/environment — `.rspec` charge l'app au boot, require tardif = couverture vide), **baseline mesurée : 72.78 % lignes (2879/3956) / 44.82 % branches (744/1660)** — Models 84.8 %, Services 80.5 %, Controllers 61.2 %, Autres 64.9 % ; top sous-couverts : concerns API (access_validation 18.1 %, error_handlers ~35-37 %, parameter_extractors ~36-42 %), `CraServices::List` 24.6 %, `OAuthConcern` 32.7 %, `GitLedgerService` 44.7 %. Décisions actées (co-CTO) : D-2.1 baseline sans échec, D-2.2 Cobertura XML, D-2.3 sprint maintenant ; **seuil 95 % = P6, à statuer post-mesure**. Durcissement CI (revue co-CTO, P0/P1) : **E2E bloquant dans la Quality Gate** (success ou skipped hors PR), **Brakeman strict** (retrait `--no-exit-on-warn` — tout warning non ignoré échoue), assertion bloquante `coverage/coverage.xml`, gate DDD explicite (🏛️ invariants FC-08 + p4_6). CI 6/6 verts + 0 annotation (head `1fbf298d`) ; artefact test-results inclut coverage/ (HTML + XML). Guide : `docs/technical/testing/line_coverage.md`. Suivi : `docs/technical/d2_simplecov_implementation_tracker.md`.
## fc08::010
<!-- created: 2026-09-17 -->
P6.1 fait (branche `chore/p61-coverage-lock`) : `foresy_test` nettoyée (pollution SIREN en dur + session authrepro → TRUNCATE, incident tracé), baseline mesurée ×2 **73,21 % lignes / 45,07 % branches** (déterminisme confirmé — seeds différents ; écart vs 16/09 = code évolué D-5/D-12), verrou `minimum_coverage line: 72.5` posé dans `.simplecov` (suite 962/0 avec verrou). Décisions CTO : trajectoire 95 % avec palier décisionnel 90 % (P6.6), zone morte = couverture comportementale, branch coverage P6.6. Plan de campagne : `docs/technical/testing/coverage_campaign_p6.md`. Prochaine étape : Wave 1 (access_validation, error_handlers, standardized_error).
