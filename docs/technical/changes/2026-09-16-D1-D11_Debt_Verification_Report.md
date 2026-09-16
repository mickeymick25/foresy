# Vérification d'implémentation — Dette technique D-1 → D-11 (niveau platinium)

**Date :** 16 septembre 2026
**Périmètre :** toute la dette du registre `docs/technical/fc08_debt_register.md`, depuis D-1 (D-4 incluse)
**Branche vérifiée :** `chore/d4-e2e-scripts-repair` (HEAD `1de4d154`, poussée sur origin)
**Standard attendu :** platinium — méthodologie maison (TDD/DDD si applicable, RAG d'abord, gates qualité, traçabilité)
**Statut :** 🟢 fond conforme — 4 anomalies documentées, 2 réserves de process

---

## 1. Méthode et sources (discipline de provenance)

- **Lectures locales** : contrat FC-08 v3.2.3, registre de dette, tracker FC-08 (journal), code Ruby (modèles, services, contrôleurs, concerns, specs), scripts shell E2E, workflows CI
- **Exécutions réelles** (conteneur Docker, base `foresy_test`) : suite RSpec complète, specs ciblées par dette, RuboCop, Brakeman, bundle-audit
- **Exécutions HTTP réel** (serveur dev `:3000`) : `e2e_cra_lifecycle.sh` ×2, `e2e_auth_flow.sh` ×2, `smoke_test.sh`
- **Requêtes hub RAG** : `foresy__knowledge` (registre, journal, guides) et `foresy__memories` (fc08::001/003/004/006) — exécutées via le proxy MCP documenté (`/mcp` Streamable HTTP, conteneur temporaire sur `chroma-net`, pattern de `e2e_mcp_test.py`), les outils `chroma_*` n'étant pas attachés à la session agent (réactivation côté Zed effectuée le 16/09)
- **API GitHub** : état des PR de la branche
- Annexe (hub) : `e2e_mcp_test.py` du hub échoue tel quel avec l'anyio de l'image actuelle — `anyio.run(main())` doit être `anyio.run(main)`

## 2. Verdict par dette

| Dette | Implémentation vérifiée | Verdict |
|---|---|---|
| **D-1** INV-01/02 par inspection | Spec d'architecture `spec/models/fc08_architecture_invariants_spec.rb` **7/0 exécutée** — INV-01/02/03/04/06 épinglés (colonnes + associations), INV-15 justifié en en-tête (aucun code de simulation dans `app/`) — 21/22 invariants testés | ✅ Conforme, platinium |
| **D-2** SimpleCov | Absente du `Gemfile`, `coverage/` vide — ouverte, documentée « à chiffrer » | ✅ Conforme à sa déclaration |
| **D-3** PR #24 | Mergée le 15/09 (tag `v0.1.1`, commit `c080f909`) ; conditions post-merge CTO (staging E2E, monitoring prod) documentées au registre | ✅ Conforme |
| **D-4** Scripts E2E hérités | 4 corrections structurelles vérifiées dans le code : `run_request`/`HTTP_CODE`/`HTTP_BODY` (codes > 255 tronqués : 422→166, 500→244, 409→153), `%-m` (mois JSON valide), `float_eq` awk (décimaux), code mort nettoyé ; **rejeux indépendants ×2 PASSED** (cra — lock Git Ledger + protections 409 inclus — et auth) | ✅ Code conforme — ⚠️ process incomplet (A2, A3) |
| **D-5** GitLedger/Brakeman | Garde `SAFE_ID_PATTERN` (`/\A[A-Za-z0-9_-]{1,64}\z/`) en amont des deux `--grep`, refus silencieux `false`/`nil` sans invoquer Git ; specs exécutées : `git_ledger_integration` **13/0**, `p6_1` **10/0** (contrat renforcé couvert : ID malveillant → 0 invocation Git ; ID valide → argv array, ID dans un seul argument `--grep`, + 5 contrôles statiques) ; `brakeman.ignore` : 3 entrées justifiées, entrée obsolète supprimée ; **Brakeman 0 warning vérifié** | 🟡 Fond conforme — **gate RuboCop cassée** (A1) |
| **D-6** Cosmétique scope | `user_company.rb` L52 : scope `[:user_id, :company_id, :role]` inchangé (redondance `user_id`) — ouverte, sans impact | ✅ Conforme à sa déclaration |
| **D-7** Dépréciations Rack | Warnings `:unprocessable_entity` toujours présents dans les runs — ouverte | ✅ Conforme à sa déclaration |
| **D-8** Signup 400 | Fix vérifié : `StandardError` déclaré **en premier** dans `StandardizedError` (mécanisme `rescuable.rb` commenté dans le code) ; spec contractuelle présente dans `users_spec.rb` (`signup {}` → 400 `MISSING_PARAMETER`, forme plate, renvoi au contrat `error_contract.md`) — TDD RED→GREEN documenté ; contrat p1_2 (générique → 500) préservé ; **smoke 15/15 exécuté** ; discipline « RAG d'abord » tracée au journal | ✅ Conforme, platinium |
| **D-9** rubyzip CVE | `Gemfile.lock` : rubyzip 3.6.0 ; **`bundler-audit check --update` : 0 vulnérabilité** (advisory DB 2026-09-13) | ✅ Conforme |
| **D-10** Isolement bases | Guide `docs/technical/testing/test_database_isolation.md` (piège `DATABASE_URL`, procédure conteneur, validation) ; suite exécutée sur `foresy_test` via la config compose | ✅ Conforme, platinium |
| **D-11** Node 24 actions | `.github/workflows/ci.yml` : `checkout@v4` / `upload-artifact@v4` toujours en place — ouverte, documentée opportuniste | ✅ Conforme à sa déclaration |

## 3. Gates qualité exécutées (16/09, HEAD `1de4d154`)

| Gate | Résultat | Standard |
|---|---|---|
| Suite RSpec (`foresy_test`) | **957 exemples, 0 échec** | ✅ |
| Brakeman | **0 warning** (3 ignorés justifiés) | ✅ |
| bundle-audit | **0 vulnérabilité** | ✅ |
| Smoke test | **15/15** | ✅ |
| E2E cra + auth | **PASSED ×2 chacun** (déterminisme, rejouabilité) | ✅ |
| **RuboCop** | **2 offenses, 235 fichiers** | ❌ gate cassée (A1) |

## 4. Vérifications ciblées par specs

| Spec | Réel (exécuté) | Claim journal | Écart |
|---|---|---|---|
| `fc08_architecture_invariants_spec.rb` (D-1) | 7/0 | 7/7 | ✅ |
| `git_ledger_integration_spec.rb` (D-5) | 13/0 | 13/0 | ✅ |
| `p6_1_git_ledger_security_spec.rb` (D-5) | **10/0** | « 23/0 » | ⚠️ 23 = somme des deux specs D-5 (13+10), attribuée à tort à p6_1 seul |
| `users_spec.rb` (D-8) | 4/0 | — | ✅ (spec contractuelle D-8 confirmée) |

## 5. Anomalies détectées (aucune n'était documentée)

- **A1 — RuboCop cassé par D-5 (le seul défaut de gate)** : le commit `47e9de01` introduit 2 offenses dans `git_ledger_repository.rb` L92 — `Lint/UselessConstantScoping` (le `private` ne s'applique pas aux constantes) et `Style/RedundantFreeze` (`.freeze` sur regexp, gelée par défaut). Le journal D-5 ne mentionne pas RuboCop et le « 6/6 CI verts » datait d'avant ce commit → non détecté. **Impact : la CI RuboCop échoue sur main et sur toute PR issue de la branche.** Correctif : déplacer la constante au-dessus du `private` + retirer `.freeze` (commit étiqueté `style(d5)`).
- **A2 — Process D-4 inachevé** : branche poussée mais **aucune PR ouverte** (API GitHub : `[]`), alors que le journal revendique « branche dédiée + PR, fin des pushes directs sur main ». À noter : D-10/D-5 ont été poussés directement sur main avant la déclaration de cette discipline.
- **A3 — Commentaire obsolète** : `e2e_cra_lifecycle.sh` L23-24 mentionne encore `make_request` « returns the HTTP code as its exit status » — précisément le bug que D-4 corrige ; raté par l'« audit intégral ligne à ligne ».
- **A4 — Journal D-5 inexact** : « p6_1 — 23/0 » alors que p6_1 compte 10 exemples (23 = somme 13+10 des deux specs D-5).
- **A5 — Workflow mémoire en attente** : `fc08::006` amendée in-repo (D-4 résolue) mais le hub indexe encore la version pré-D-4 (« Reste : D-4 ») — memory-indexer à relancer après validation humaine.
- **A6 — Traçabilité Git (observation systémique)** : 179 commits signés `foresy-ledger <ledger@foresy.internal>` (identité du conteneur, cf. `GitLedgerRepository.configure_identity`) contre 170 au nom humain — le workflow mémoire exige que Git trace la validation humaine ; les commits faits depuis le conteneur l'effacent. Recommandation : identité Git explicite dans le conteneur ou commits depuis le host.
- **Annexe hub** : `e2e_mcp_test.py` — `anyio.run(main())` doit être `anyio.run(main)` (coroutine non appelable avec l'anyio de l'image actuelle).

## 6. Appréciation méthodologique

Points exemplaires : TDD RED→GREEN réel pour D-8 (spec contractuelle + mécanisme Rails sourcé), discipline « RAG d'abord » tracée au journal, spec d'architecture D-1 au niveau contrat (INV-15 justifié), guide D-10 de référence, rejeux multiplicateurs prouvant le déterminisme, `brakeman.ignore` avec justifications renvoyant vers les specs de couverture.

Les manquements sont des **écarts de reporting et de gate** (A1–A4), pas des défauts de conception : aucune dette résolue n'est faussement revendiquée sur le fond — seuls RuboCop (A1) et l'état process de D-4 (A2) demandent une action.

## 7. Actions correctives proposées (sur accord CTO, correctifs étiquetés)

1. `style(d5)` : corriger les 2 offenses RuboCop — restaure la gate 0-offense
2. `docs(d4)` : corriger le commentaire obsolète L23-24 + rectifier le journal D-5 (p6_1 = 10/0)
3. Ouvrir la **PR D-4** (`chore/d4-e2e-scripts-repair` → main, description au format maison)
4. Valider `fc08::007` (proposition du 16/09) puis relancer `memory-indexer` (synchronise aussi `fc08::006`)
5. Réindexer la connaissance : `index-project.sh /Users/michaelboitin/Documents/02_Dev/Foresy`
6. Hygiène : configurer l'identité Git du conteneur

## 8. Références

- Registre de dette : `docs/technical/fc08_debt_register.md` (§4-7)
- Journal : `docs/technical/fc08_implementation_tracker.md` (entrées Gate CTO, CI Gate, D-4, D-5, D-8, D-9, D-10)
- Mémoires : `memory/2026-09-14-fc08-implementation.md` (fc08::001–007)
- Contrat FC-08 v3.2.3 : `docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]`