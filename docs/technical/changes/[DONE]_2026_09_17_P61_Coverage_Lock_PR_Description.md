# P6.1/P6.1-bis — Verrou de couverture temporaire 72,0 % (initial 72,5) + cleanup legacy — Description de PR

**Date :** 17 septembre 2026 (résumé aligné sur le head final le 19/09 — revue co-CTO)
**Décision CTO :** GO P6.1 (checkpoint post-D-12) — verrou initial + trajectoire 95 % ;
recalibration temporaire bornée 72,0 (18/09, cf. §9) ; clôture P6.1-bis (CI verte `f1f42652`)
**Branche :** `chore/p61-coverage-lock` → `main`
**Plan de campagne :** `docs/technical/testing/2026_09_17_coverage_campaign_p6.md`

---

## 1. Résumé (aligné sur le head final `547c8d8a`)

Cette PR pose le **verrou de couverture P6.1** et le **stabilise** (P6.1-bis). Verrou initial
proposé : **72,5 %** — **seuil effectif final : 72,0 % temporaire** (recalibration bornée,
décision CTO 18/09, cf. §9). La PR contient également :

- le **cleanup de 9 fichiers legacy morts** (plan du 07/01 enfin exécuté : 6 services
  `Api::V1::Cras::*` + `Api::V1::CraEntries::ListService` + `app/lib/http_status_map.rb` +
  `app/lib/mission_errors.rb`, zéro référence active) — révélés par la divergence de corpus
  lazy/eager (67,27 % CI vs 73,21 % conteneur) ; le corpus CI passe à **72,34 %** post-cleanup ;
- la **correction du cas rswag `--pattern`** (le `RakeTask` invoque rspec sans argument de
  fichier — le verrou s'armait à tort sur un subset, cf. §10) ;
- le **retrait du `|| true`** du step CI principal (le verrou est bloquant sur la suite complète) ;
- le plan de campagne P6, la description des 4 incidents CI (§7-10), la mémoire `fc08::010`
  amendée (validation CTO, post-CI-verte) et la régularisation du plan legacy cleanup dans
  `docs/technical/changes/`.

**Pourquoi 72,0 et non 72,5 :** le corpus d'enforcement CI (eager load, `ENV['CI']`) post-cleanup
mesure **72,34 %** (baseline officielle, mesurée ×2) contre 73,21 % en corpus conteneur lazy —
l'écart résiduel est `OAuthCodeExchangeService`, **code de production actif non testé**, transféré
à **Wave 2**. **Retour à 72,5 % : explicitement rattaché à la couverture de ce fichier en Wave 2.**
Trajectoire 95 % inchangée (palier décisionnel 90 % à P6.6). Aucune exclusion SimpleCov.

Périmètre final : P6.1 verrou + P6.1-bis stabilisation (4 incidents CI résolus) + cleanup legacy
+ recalibration CI temporaire + documentation de campagne.

## 2. Preuves (environnements)

| Étape | Résultat |
|---|---|
| Nettoyage `foresy_test` | Polluée (SIREN en dur `123456789` + session `authrepro`) → TRUNCATE → 962/0 |
| **Mesure baseline #1** | **73,21 % lignes / 45,07 % branches** (962 exemples, 0 échec) |
| **Mesure baseline #2** (seed différent) | **73,21 % lignes / 45,07 % branches** — identique → déterminisme confirmé |
| Verrou posé | `minimum_coverage line: 72.5` — suite avec verrou : **962/0** |

Écart vs baseline du 16/09 (72,78 % / 44,82 %) : le code a évolué (D-5 durcissement GitLedger,
D-12 `LEDGER_PATH` + specs). Documenté tel quel — aucune retouche pour aligner les chiffres.

## 3. Fichiers modifiés (18 au total — head final `547c8d8a`)

| Fichier | Changement |
|---|---|
| `.simplecov` | Verrou P6.1 : armé dans un `at_exit` uniquement sur la **suite complète** (détecteurs : files_or_directories, `-e`/`-t`, `--pattern`, exclude_pattern — fail-closed) ; **seuil 72,0 temporaire** (décision 18/09) |
| `Gemfile` | `simplecov` + `simplecov-cobertura` `require: false` (fix incident #1 — chargement uniquement via `spec/coverage_boot`) |
| `.github/workflows/ci.yml` | `|| true` retiré (verrou bloquant) ; step diagnostic P6.1 (`if: always()`) ; YAML corrigé |
| **9 fichiers supprimés** | `app/services/api/v1/cras/{create,update,list,lifecycle,export,destroy}_service.rb`, `app/services/api/v1/cra_entries/list_service.rb`, `app/lib/http_status_map.rb`, `app/lib/mission_errors.rb` — plan 07/01 exécuté (§9) |
| `legacy_cleanup_plan.md` → `docs/technical/changes/[DONE]_2026_01_07_Legacy_Cleanup_Plan.md` | Régularisé dans l'arborescence documentaire (convention + indexation RAG), marqué « Phase 1 exécutée » avec relevé |
| `docs/technical/testing/2026_09_17_coverage_campaign_p6.md` | Nouveau — décisions CTO, règle TDD P6.0, séquence des vagues, recalibration 72,0 (§3) |
| `docs/technical/testing/2026_09_16_line_coverage.md` | Guide : périmètre du verrou, politique de seuils, phase 2 transitoire |
| `docs/technical/[DONE]_2026_08_31_fc08_implementation_tracker.md` | Journal P6.1 + P6.1-bis + incidents + clôture |
| `docs/technical/changes/[DONE]_2026_09_17_P61_Coverage_Lock_PR_Description.md` | Cette description (§7-10 : les 4 incidents) |
| `memory/2026-09-14-fc08-implementation.md` | Mémoire `fc08::010` amendée (P6.1-bis complet — validation CTO post-CI-verte) |

Historique du 17/09 (inchangé, cf. §2) : verrou initial 72,5 posé, plan de campagne, journal, mémoire — la recalibration 72,0 est documentée §9.

## 4. Décisions CTO actées (checkpoint 17/09)

- Verrou initial : **72,5 % line** (empêche la régression dès P6.1, sans objectif artificiel)
- Trajectoire : **95 % avec palier décisionnel à 90 %** (décision finale P6.6 sur mesure réelle)
- Zone morte : couverture **comportementale** + exclusions documentées (pas de tests artificiels)
- Branch coverage : **différée à P6.6**

## 5. Incident environnemental documenté (2e)

`foresy_test` a été re-polluée entre les campagnes (SIREN en dur de l'ancienne version du script
E2E + une session `authrepro`) → 21 faux échecs, couverture effondrée à 56,12 %. Remède D-10
appliqué (TRUNCATE + procédure d'isolement `docs/technical/testing/2026_09_15_test_database_isolation.md`)
avant toute mesure — l'incident est tracé dans le plan P6 §5 et le guide.

## 6. Hors périmètre (prochaines étapes)

- **Wave 1** : `access_validation` (77 lignes / 0 sur 46 branches), `error_handlers`,
  `standardized_error` + intégration associée — TDD de caractérisation
- Wave 2 (extraction, rate limiting, OAuth) → Wave 3 → Wave 4 → **P6.6** (mesure finale,
  décision 90/95, branch coverage, exclusions)

## 7. Incident CI corrigé dans ce PR (post-revue co-CTO 17/09)

**Constat :** run PR #34 rouge — job « Tests & Coverage » échoue à « Setup database » (exit 2).
**Cause racine :** les gems SimpleCov étaient **auto-requirées par Bundler** en environnement
test → SimpleCov démarrait pendant `rails db:drop db:create db:schema:load` (via l'auto-load de
`.simplecov`), mesurait le boot minimal (~12,6 %) et le verrou P6.1 faisait échouer le process
(exit 2) — le verrou s'appliquait alors à toutes les invocations `rails`, pas seulement rspec.
**Fix (`6812b9b8`) :** `gem 'simplecov', require: false` + `simplecov-cobertura, require: false`
— SimpleCov ne se charge que via `spec/coverage_boot` (conforme au design D-2). Revalidation :
db tasks sans SimpleCov, suite 962/0, couverture 73,21 %, verrou tenu.

## 8. Incident CI corrigé dans ce PR (2e, résiduel — qualifié le 18/09)

**Constat :** après le fix `6812b9b8`, le run PR restait rouge — chronologie : « Setup database »
exit 2 (corrigé §7) → « Run RSpec » exit 2 (`|| true` posé en diagnostic, `1c6cafc1`) →
« 🏛️ DDD Invariants » exit 2 (état `d3a08877`) alors que les 27 invariants passent (0 échec).

**Cause racine :** le verrou `minimum_coverage line: 72.5` posé dans le bloc `start` de
`.simplecov` s'appliquait à **tout run rspec** (auto-chargé par `.rspec → spec/coverage_boot`).
Le gate DDD (2 fichiers → 62,85 %) puis l'acceptance du job E2E (subset) couvrent
mécaniquement moins que la suite → SimpleCov exit 2 (`ExitCodes::MINIMUM_COVERAGE`) avec
des specs vertes. Par ailleurs le `|| true` avalait échecs de specs ET violation du verrou :
le verrou n'avait plus aucune mordance en CI.

**Fix (P6.1-bis) :** verrou armé au dernier moment dans un `at_exit` de `.simplecov`
(enregistré après celui de SimpleCov → LIFO → s'exécute avant ; SimpleCov relit le seuil
via `build_coverage_limits`). Condition « suite complète » : `@files_or_directories_to_run
== [default_path]` (ivar rspec-core 3.13 — le getter n'est plus exposé) ET pas de filtre
`-e`/`-t`. Fail-closed : si la détection dérive, le verrou s'arme. `|| true` retiré du step
principal CI — suite et verrou échouent à nouveau le job (steps `if: always()` préservés).

**Validation (conteneur, `foresy_test` propre, miroir CI) :**

| Run | Verrou | Résultat | Exit |
|---|---|---|---|
| Suite complète (formateurs CI) | armé, tenu | 962/0 — 73,21 % / 45,07 % | 0 |
| Suite complète, seuil temporaire 99,9 | armé → violation | 73,21 % < 99,9 | **2** (dents prouvées) |
| Gate DDD (2 fichiers, comme CI) | désarmé | 27/0 | 0 |
| Acceptance (job E2E, `E2E_MODE`) | désarmé | 31/0 | 0 |
| Filtre `-e` (résout `[spec]` mais partiel) | désarmé | 0 exécutable | 0 |

## 9. Incident CI #3 — corpus eager-load, cleanup legacy exécuté, recalibration 72,0 transitoire (GO CTO 18/09)

**Constat (run `b097c87c`) :** exit 2 au step principal — **962/0 specs vertes**, couverture
CI **67,27 %** (3113/4627) vs 73,21 % (2903/3965) en conteneur. Reproduction locale exacte
(`CI=1` dans le conteneur : mêmes chiffres à la décimale près).

**Cause racine :** `config.eager_load = ENV['CI'].present?` (`config/environments/test.rb:20`)
→ le runner CI charge tous les fichiers autoloadés ; le conteneur (lazy) ne charge que les
référencés. Delta : **662 lignes pertinentes / 9 fichiers morts** — 7 services legacy
`Api::V1::*` (le plan du 07/01 — jamais exécuté, régularisé le 18/09 dans
`docs/technical/changes/[DONE]_2026_01_07_Legacy_Cleanup_Plan.md` — les listait comme
« jamais utilisés » depuis la migration FC-07) + `app/lib/http_status_map.rb` +
`app/lib/mission_errors.rb` (zéro référence active).

**Fix (cleanup exécuté, GO CTO) :** suppression des 9 fichiers — le plan 07/01 est marqué
« Phase 1 exécutée » avec relevé exact. Validation : **962/0 inchangé** (zéro impact
fonctionnel), RuboCop **0**, Brakeman **0**, grep résiduel = commentaires de migration
uniquement. Corpus CI-sim : 67,27 % → **72,34 %** (2932/4053) ; lazy inchangé 73,21 %.

**Écart résiduel (+88 lignes corpus CI) :** 8 lignes scaffolding Rails (100 %) +
**80 lignes `o_auth_code_exchange_service.rb` à 26,25 %** — code de **production** actif
(flow OAuth #2 code-exchange, appelé par `OAuthValidationService.extract_oauth_data`)
jamais exercé par les specs (les 31 tests OAuth ne couvrent que le flow OmniAuth).
Pas du code mort → ni supprimé, ni exclu du verrou.

**Recalibration temporaire bornée (décision CTO 18/09, option 1/3) — quatre conditions :**

1. **72,0 est un seuil temporaire**, pas le nouveau baseline qualitatif de Foresy
2. **Baseline documenté de référence : 72,34 %** sur le corpus CI eager-load post-cleanup
3. **Retour à 72,5 explicitement rattaché à la couverture de `OAuthCodeExchangeService`
   dans Wave 2** (premier travail de Wave 2)
4. **Aucune exclusion SimpleCov** pour ce fichier — le gap doit rester visible

L'objectif 95 % reste inchangé. Options rejetées par le CTO : couvrir le fichier dans cette
PR (Wave 2 entrerait dans une PR « verrou ») et l'exclure du verrou (ce n'est pas de
l'infrastructure pure).

**État P6 :** P6.1 — **LOCKED / TEMPORARY BASELINE** · P6.1-bis — **CLOSED après
validation CI verte** · dette couverture OAuth → **Wave 2**.

## 10. Incident CI #4 — job « Contracts » : subset `--pattern` du RakeTask rswag (run `175818e9`)

**Constat :** `tests` ✅ (verrou 72,0 tenu — première CI verte du job) · `security` ✅ ·
`lint` ✅ · **`contracts` ❌ exit 2** à `rake rswag:specs:swaggerize` — **404 exemples
verts, couverture 47,94 %** (257/536). Premier run du job depuis l'introduction du
verrou (toujours *skipped* : `needs: tests` jamais satisfait avant).

**Cause racine :** angle mort de la détection « suite complète » (P6.1-bis) — le
`RSpec::Core::RakeTask` de rswag (attribut `t.pattern`) invoque rspec avec
`--pattern 'spec/requests/**/*, spec/api/**/*, spec/integration/**/*'` **sans argument
de fichier** : `files_or_directories` vaut alors `[default_path]` et les filtres sont
vides → le verrou s'armait sur un subset. Reproduit en conteneur à l'identique.

**Fix :** la garde intègre `pattern`/`exclude_pattern`, comparés à l'at_exit aux
défauts d'une **instance fraîche** de `RSpec::Core::Configuration` — rspec applique
`--pattern` avant de charger les `--require` (constaté : un snapshot au boot capture
le pattern déjà surchargé) ; l'instance fraîche reste drift-proof et fail-closed.

**Validation :**

| Run | Verrou | Résultat | Exit |
|---|---|---|---|
| `rake rswag:specs:swaggerize` (subset `--pattern`) | désarmé | 404/0 — 47,94 % | 0 |
| Suite complète lazy @ 72,0 | armé, tenu | 962/0 — 73,21 % | 0 |
| Suite complète CI-sim @ 72,0 | armé, tenu | 962/0 — 72,34 % | 0 |
| Négatif CI-sim @ seuil 72,9 | armé → violation | 72,34 % < 72,9 | **2** (dents prouvées) |

---
*Description générée le 17/09/2026 — campagne P6, branche `chore/p61-coverage-lock`*