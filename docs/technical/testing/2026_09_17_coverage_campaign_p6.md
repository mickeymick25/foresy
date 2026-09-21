# P6 — Campagne de couverture (SimpleCov)

**Date :** 17 septembre 2026
**Décision CTO :** GO P6.1 (checkpoint post-D-12) — verrou initial + trajectoire 95 %
**Outillage :** PR #29 (D-2) — `simplecov` 1.3.0 + `simplecov-cobertura`, guide `docs/technical/testing/2026_09_16_line_coverage.md`
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

## 3. P6.1 — Verrou initial (état : 🔒 LOCKED / TEMPORARY BASELINE)

| Étape | Résultat |
|---|---|
| Nettoyage environnement | `foresy_test` polluée (SIREN en dur + session `authrepro`) → TRUNCATE → 962/0 |
| **Mesure baseline ×2** | **73,21 % lignes / 45,07 % branches** — identiques ×2 (seeds différents) → déterminisme confirmé. Écart vs baseline du 16/09 (72,78 %) : code évolué depuis (D-5, D-12) |
| Verrou | `minimum_coverage` dans `.simplecov` — **armé uniquement sur les runs de la suite complète** (P6.1-bis, cf. journal) : un subset (gate DDD, acceptance E2E, fichier ciblé) mesure la couverture et régénère les rapports, sans échec au seuil. **Seuil transitoire 72,0** (décision CTO 18/09 — cf. ligne « Recalibration » ci-dessous) |
| Vérification | Suite avec verrou : **962/0** ✅ |
| **Recalibration (18/09, incident CI 17→18/09 — cf. journal P6.1-bis)** | Corpus d'enforcement CI (eager load, `ENV['CI']`) ≠ corpus conteneur (lazy) : 67,27 % vs 73,21 % → cleanup legacy exécuté (9 fichiers morts, plan 07/01) → corpus CI post-cleanup **72,34 %**. **Baseline documenté de référence : 72,34 % corpus CI** · seuil **72,0 transitoire** (marge +0,34 pt) · retour à **72,5 rattaché à la couverture de `OAuthCodeExchangeService` en Wave 2** · aucune exclusion SimpleCov pour ce fichier · 72,0 ≠ baseline qualitatif · **trajectoire 95 % inchangée · seuil restauré à 72,5 le 20/09 (Wave 2 livrée — GO CTO)** |

## 4. Séquence des vagues

```
P6.1 ✅
 └─ verrou minimum_coverage line: 72.5 (ce PR)
Wave 1 ✅ CLÔTURÉE (19/09, validation CTO)
 ├─ W1-D1 : suppression du concern mort `Api::V1::Cras::AccessValidation`
 │  (éclipsé à 100 % — dette legacy démontrée, GO CTO 18/09 ; ne se caractérise pas,
 │  mêmes critères que le cleanup P6.1-bis)
 ├─ W1-D2 : caractérisation sécurité vivante (`Cra.accessible_to` + via-missions)
 ├─ W1-D2-BUG : 2 bugs soft-delete corrigés (RED → GREEN arbitré — CRA + Mission)
 ├─ W1-D3 : concerns d'erreur — 2 chemins rate-limit vivants caractérisés (A),
 │  divergence 429 documentée sans breaking change, 3 concerns morts supprimés (B)
 ├─ W1-D4 : standardized_error caractérisé + fc08::005 tranchée (helper mort)
 └─ Suivi d'implémentation : `docs/technical/testing/[DONE]_2026_09_18_p6_wave1_tracker.md`
     PR : `docs/technical/changes/[DONE]_2026_09_19_P6_Wave1_PR_Description.md`
     Bilan mesuré : 76,49 % lignes / 47,60 % branches, 977 exemples, 0 test artificiel
     Verrou 72,0 INCHANGÉ (retour 72,5 = Wave 2, arbitrage CTO 19/09)
Wave 2 ✅ CLÔTURÉE (20/09, validation CTO)
 ├─ W2-D1 : reconnaissance + cartographie du flow code-exchange (9 chemins,
 │  service 0 % confirmé par grep exhaustif — dette tracée fc08::010)
 ├─ W2-D2 : caractérisation unitaire `OAuthCodeExchangeService` — 10 specs,
 │  stub Net::HTTP uniquement ; service **0 % → 69,44 % lignes (125/180) / 13/29 branches** ;
 │  asymétries documentées (uid Google Integer vs GitHub to_s ; Google token via
 │  post_form vs perform_https_request — timeouts 10 s caractérisés)
 ├─ W2-D3 : flow callback end-to-end — 7 specs requête vertes d'emblée (caractérisation
 │  pure) : utilisateurs réellement créés, JWT réellement générés/décodés
 │  ({user_id, provider, exp}), 400/401/422×3 — chaîne validate_oauth_data réelle
 ├─ Divergence doc↔réel documentée (caractérisation, sans correction produit dans
 │  cette vague) : `format_success_response` inclut `name` — absent du schéma RSwag
 └─ Suivi d'implémentation : `docs/technical/testing/2026_09_20_p6_wave2_tracker.md`
     Bilan mesuré : **77,83 % lignes (2901/3727) / 48,42 % branches (771/1592)**,
     **994 exemples, 0 failure** — 17 specs OAuth caractérisées
     **Verrou restauré : 72,5** (GO CTO 20/09 — marge +5,33 pts ; trajectoire 95 % inchangée)
Wave 3 ✅ CLÔTURÉE (20/09, validation CTO)
 ├─ W3-D1 : `CraServices::List` + filtres — **RED démontré : bug production
 │  `GET /api/v1/cras` = 500** (`ApplicationResult.success` sans `data:` — L77/L119)
 │  corrigé (2 lignes) — list **24,62 → 96,92 % (63/65)** · divergence Mini-FC-01
 │  per_page 25↔20 arbitrée (doc alignée sur le code) · 19 specs
 ├─ W3-D2 : Git Ledger — **16 specs** (délégations, double lock idempotent,
 │  gardes validate_cra!, fail-closed history_rewritten?, payload canonique) :
 │  service 77,78 → **100 %**, repository 76,29 → **95,88 %**, payload → **100 %**
 ├─ W3-D3 : services/lib + façades — **36 specs chemins vivants** (RedisBackend
 │  ZSET réel, Backend contrat abstrait, race/link/RecordInvalid OAuth,
 │  taxonomie CraErrors, missing_cra) + **nettoyage OAuth ciblé**
 │  (7 méthodes mortes supprimées — zéro appelant ; façades et
 │  ApplicationResult conservés + documentés)
 └─ W3-D4 : modèles — **64 specs** (cra lifecycle/transitions/atomicité lock
 │  GitLedger, mission exclusivité financière par type, company normalisations,
 │  pivots rôles/gardes d'unicité)
     Suivi d'implémentation : `docs/technical/testing/2026_09_20_p6_wave3_tracker.md`
     Bilan mesuré : **83,07 % lignes (3073/3699) / 54,78 % branches (858/1566)**,
     **1129 exemples, 0 failure** — corpus −28 lignes (code mort OAuth supprimé)
     **Verrou 72,5 INCHANGÉ pendant la vague (marge +10,57 pts à la clôture)**
     Découvertes : 2 bugs production corrigés (GET /cras 500 ; specs disparues
     Mini-FC-01 révélées par la caractérisation) ; contract drift per_page aligné
Wave 4
 └─ ~40 fichiers résiduels
P6.6
 ├─ mesure finale
 ├─ décision 90 / 95
 ├─ décision branch coverage
 └─ qualification finale des exclusions
```

Objectif Wave 1 : **traverser les chemins d'échec et de sécurité non exercés** — pas monter un pourcentage.

### Dettes identifiées pendant Wave 1 — reportées à la réévaluation de fin de campagne (arbitrage CTO 19/09)

- `spec/support/error_response_helper.rb` (fc08::005) : helper mort (zéro usage — aucune incompatibilité démontrable par exécution) — **maintenu temporairement, dette distincte**
- 6 helpers `standardized_error` sans appelant + 4 latents `rate_limitable` : suppression/conservation à arbitrer par groupe
- `handle_unpermitted_parameters` / `handle_record_not_found` : injoignables (config), documentés
- D3-3 : couches d'erreur vivantes des contrôleurs — réévaluation séparée

## 5. Environnement de mesure

- Base : `foresy_test` — **propre obligatoire** (cf. `docs/technical/testing/2026_09_15_test_database_isolation.md`)
- Incident 15→17/09 : `foresy_test` polluée par un run E2E (SIREN en dur) + une session `authrepro` → 21 faux échecs, couverture effondrée (56,12 %) — remède D-10 appliqué avant toute mesure
- Commande de mesure :
  ```bash
  docker compose exec -T web sh -c "DATABASE_URL=postgres://postgres:password@db:5432/foresy_test RAILS_ENV=test bundle exec rspec"
  # lecture : coverage/.last_run.json -> result.line / result.branch
  ```

## 6. Références

- Chiffrage D-2 : `docs/technical/changes/[DONE]_2026_09_16_D2_SimpleCov_Chiffrage.md`
- Guide couverture : `docs/technical/testing/2026_09_16_line_coverage.md`
- Isolement bases : `docs/technical/testing/2026_09_15_test_database_isolation.md`
- Registre : `docs/technical/2026_09_14_fc08_debt_register.md` (D-2, P6)