# P6.1 — Verrou de couverture `minimum_coverage line: 72.5` — Description de PR

**Date :** 17 septembre 2026
**Décision CTO :** GO P6.1 (checkpoint post-D-12) — verrou initial + trajectoire 95 %
**Branche :** `chore/p61-coverage-lock` → `main`
**Plan de campagne :** `docs/technical/testing/coverage_campaign_p6.md`

---

## 1. Résumé

P6.1 pose le **verrou initial de couverture** décidé par le CTO : `minimum_coverage line: 72.5`
dans `.simplecov`, appuyé sur une baseline **mesurée deux fois de façon identique** (déterminisme
confirmé). Aucun travail Wave 1 dans ce PR — uniquement le verrou + le plan de campagne + le
nettoyage environnement documenté.

## 2. Preuves (environnements)

| Étape | Résultat |
|---|---|
| Nettoyage `foresy_test` | Polluée (SIREN en dur `123456789` + session `authrepro`) → TRUNCATE → 962/0 |
| **Mesure baseline #1** | **73,21 % lignes / 45,07 % branches** (962 exemples, 0 échec) |
| **Mesure baseline #2** (seed différent) | **73,21 % lignes / 45,07 % branches** — identique → déterminisme confirmé |
| Verrou posé | `minimum_coverage line: 72.5` — suite avec verrou : **962/0** |

Écart vs baseline du 16/09 (72,78 % / 44,82 %) : le code a évolué (D-5 durcissement GitLedger,
D-12 `LEDGER_PATH` + specs). Documenté tel quel — aucune retouche pour aligner les chiffres.

## 3. Fichiers modifiés

| Fichier | Changement |
|---|---|
| `.simplecov` | `minimum_coverage line: 72.5` + commentaire P6.1 (baseline, marge 0,71 pt, trajectoire) |
| `docs/technical/testing/coverage_campaign_p6.md` | Nouveau — décisions CTO (72,5 / 95 palier 90 / zone morte comportementale / branch P6.6), règle TDD P6.0, séquence vagues 1→4, environnement de mesure, incident `foresy_test` |
| `docs/technical/fc08_implementation_tracker.md` | Journal P6.1 |
| `memory/2026-09-14-fc08-implementation.md` | Mémoire durable `fc08::010` |

## 4. Décisions CTO actées (checkpoint 17/09)

- Verrou initial : **72,5 % line** (empêche la régression dès P6.1, sans objectif artificiel)
- Trajectoire : **95 % avec palier décisionnel à 90 %** (décision finale P6.6 sur mesure réelle)
- Zone morte : couverture **comportementale** + exclusions documentées (pas de tests artificiels)
- Branch coverage : **différée à P6.6**

## 5. Incident environnemental documenté (2e)

`foresy_test` a été re-polluée entre les campagnes (SIREN en dur de l'ancienne version du script
E2E + une session `authrepro`) → 21 faux échecs, couverture effondrée à 56,12 %. Remède D-10
appliqué (TRUNCATE + procédure d'isolement `docs/technical/testing/test_database_isolation.md`)
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

---
*Description générée le 17/09/2026 — campagne P6, branche `chore/p61-coverage-lock`*