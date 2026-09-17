# P6 — Campagne de couverture (SimpleCov)

**Date :** 17 septembre 2026
**Décision CTO :** GO P6.1 (checkpoint post-D-12) — verrou initial + trajectoire 95 %
**Outillage :** PR #29 (D-2) — `simplecov` 1.3.0 + `simplecov-cobertura`, guide `docs/technical/testing/line_coverage.md`
**Branche P6.1 :** `chore/p61-coverage-lock`

---

## 1. Décisions CTO (checkpoint du 17/09)

| Décision | Choix | Justification |
|---|---|---|
| Verrou initial | **72,5 % line** | Suffisant pour empêcher une régression dès P6.1 sans transformer le verrou en objectif artificiel immédiat |
| Trajectoire | **95 % avec palier décisionnel à 90 %** | Objectif Platinum conservé ; la pertinence du dernier ~5 % se décide à P6.6 sur mesure réelle |
| Zone morte | Couverture **comportementale** + exclusions documentées pour l'infrastructure pure | Pas de tests artificiels uniquement pour monter SimpleCov ; `apm_service`/infrastructure examinés individuellement avant exclusion |
| Branch coverage | **Différée à P6.6** | D'abord augmenter la couverture line honnêtement et caractériser les branches critiques |

## 2. Règle TDD pour P6 (principe P6.0 maintenu)

Pas de tests artificiels pour SimpleCov. Pour chaque zone :
**comportement existant → caractérisation → RED si un comportement attendu manque → GREEN → refactor si nécessaire.**
Si la couverture révèle un bug existant, il devient un vrai cycle RED → correction → GREEN, traité explicitement — jamais contourné pour préserver la baseline.

## 3. P6.1 — Verrou initial (état : ✅ fait)

| Étape | Résultat |
|---|---|
| Nettoyage environnement | `foresy_test` polluée (SIREN en dur + session `authrepro`) → TRUNCATE → 962/0 |
| **Mesure baseline ×2** | **73,21 % lignes / 45,07 % branches** — identiques ×2 (seeds différents) → déterminisme confirmé. Écart vs baseline du 16/09 (72,78 %) : code évolué depuis (D-5, D-12) |
| Verrou | `minimum_coverage line: 72.5` dans `.simplecov` (marge 0,71 pt) |
| Vérification | Suite avec verrou : **962/0** ✅ |

## 4. Séquence des vagues

```
P6.1 ✅
 └─ verrou minimum_coverage line: 72.5 (ce PR)
Wave 1 → sécurité et erreurs critiques
 ├─ access_validation (77 lignes / 0 sur 46 branches)
 ├─ error_handlers
 ├─ standardized_error
 └─ intégration associée
Wave 2
 ├─ extraction
 ├─ rate limiting
 └─ OAuth
Wave 3
 ├─ services/lib
 ├─ List / filtres
 ├─ git ledger
 └─ modèles
Wave 4
 └─ ~40 fichiers résiduels
P6.6
 ├─ mesure finale
 ├─ décision 90 / 95
 ├─ décision branch coverage
 └─ qualification finale des exclusions
```

Objectif Wave 1 : **traverser les chemins d'échec et de sécurité non exercés** — pas monter un pourcentage.

## 5. Environnement de mesure

- Base : `foresy_test` — **propre obligatoire** (cf. `docs/technical/testing/test_database_isolation.md`)
- Incident 15→17/09 : `foresy_test` polluée par un run E2E (SIREN en dur) + une session `authrepro` → 21 faux échecs, couverture effondrée (56,12 %) — remède D-10 appliqué avant toute mesure
- Commande de mesure :
  ```bash
  docker compose exec -T web sh -c "DATABASE_URL=postgres://postgres:password@db:5432/foresy_test RAILS_ENV=test bundle exec rspec"
  # lecture : coverage/.last_run.json -> result.line / result.branch
  ```

## 6. Références

- Chiffrage D-2 : `docs/technical/changes/2026-09-16-D2_SimpleCov_Chiffrage.md`
- Guide couverture : `docs/technical/testing/line_coverage.md`
- Isolement bases : `docs/technical/testing/test_database_isolation.md`
- Registre : `docs/technical/fc08_debt_register.md` (D-2, P6)