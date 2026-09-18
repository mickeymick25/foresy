# Plan d'implémentation & Suivi — P6 Wave 1

**Date :** 18 septembre 2026
**Décision CTO :** GO Wave 1 (W1-D1 → W1-D4), séquence validée le 18/09
**Campagne :** `docs/technical/testing/coverage_campaign_p6.md` (§4 — Wave 1 : sécurité et erreurs critiques)
**Branche :** `feat/p6-wave1` — base : `chore/p61-coverage-lock` @ `547c8d8a` (P6.1 LOCKED / TEMPORARY BASELINE, PR #34)
**Règle de campagne :** traverser les chemins d'échec et de sécurité non exercés — **pas monter un pourcentage**

---

## 1. Règles de la vague (P6.0, inchangées)

| Règle | Énoncé |
|---|---|
| Pas de tests artificiels | Caractérisation du comportement **existant** ; RED uniquement si un comportement **attendu et documenté** manque ; jamais de contournement pour préserver la baseline |
| Bug découvert | Devient un vrai cycle RED → correction → GREEN, traité explicitement dans le journal |
| Stabilité des specs | Le nombre d'exemples reste **inchangé** sauf découverte d'une référence fonctionnelle réelle (règle Platinum) |
| fc08::005 | Le helper `ErrorResponseHelper` n'est modifié **que si la caractérisation démontre** son incompatibilité avec le contrat réel — RED → GREEN minimal, pas de refactoring opportuniste |
| Mesures | Les projections ne sont **pas contractuelles** — la valeur de référence est celle produite par SimpleCov à chaque étape |
| Hors périmètre | `OAuthCodeExchangeService` — réservé à **Wave 2** (retour du verrou à 72,5) |

## 2. Cibles et état mesuré (corpus conteneur, suite 962/0 du 18/09)

| Cible | Lignes utiles / non couvertes | Taux |
|---|---|---|
| `app/controllers/concerns/api/v1/cras/access_validation.rb` | 94 / 77 | 18,09 % |
| `app/controllers/concerns/api/v1/cras/error_handler.rb` | 76 / 49 | 35,53 % |
| `app/controllers/concerns/api/v1/cra_entries/error_handler.rb` | 73 / 46 | 36,99 % |
| `app/controllers/concerns/common/error_handler.rb` | 36 / 17 | 52,78 % |
| `app/controllers/concerns/standardized_error.rb` | 84 / 26 | 69,05 % |

## 3. Séquence validée

### W1-D1 — Suppression du concern mort `Api::V1::Cras::AccessValidation` — ⬜ à faire

**Décision CTO (GO 18/09) :** dette legacy démontrée — mêmes critères que le cleanup P6.1-bis. **On ne le caractérise pas pour augmenter SimpleCov.**

**Preuves établies (reconnaissance 18/09 — coverage ligne à ligne + greps exhaustifs) :**

| Élément | Preuve |
|---|---|
| `validate_cra_access!` éclipsée | `CrasController` L201-206 définit la sienne (scope RDD `Cra.accessible_to`) — la classe gagne la résolution |
| `validate_mission_access!` éclipsée | `MissionsController` L155 définit la sienne (scope `Mission.accessible_to`) |
| Méthodes à paramètres inappellables | Le `before_action :validate_*!` invoque **sans argument** — `validate_user_authentication!`, `validate_user_company_role!`, `validate_cra_modification_allowed!`, `validate_cra_lifecycle_transition!`, `validate_cra_creation_params!`, `validate_cra_entry_params!` : zéro appelant dans `app/` |
| `get_accessible_cra_ids` / `get_accessible_mission_ids` | Zéro appelant — implémentation JOINs manuels = l'ancien scope pré-RDD documenté dans `docs/technical/changes/2026-01-03-FC07_CRA_Implementation.md` §4 |
| `parse_date_param` | Corps à 0 hits — dupliquée en 4 exemplaires identiques (concern, `Cras::ParameterExtractor`, `CraEntries::ParameterExtractor`, local `CraEntriesController`) |
| Sécurité vivante testée | `permissions_spec.rb` (403) exerce contrôleur + `Cra.accessible_to` — vert alors que le concern est mort |

**Gates avant commit (séquence CTO) :** retrait de l'`include` (CrasController L26) → grep exhaustif des références → RSpec complet **962/0 inchangé** → RuboCop 0 → Brakeman 0 → **mesure SimpleCov réelle enregistrée au journal**.

**Commit :** `chore(p6): remove dead AccessValidation concern`

### W1-D2 — Caractérisation de la sécurité vivante — ⬜ à faire

**Périmètre :** ce qui tourne réellement — `Cra.accessible_to` (scope pivot RDD), `CrasController#validate_cra_access!`, et le **chemin via-missions** (FC06 : CRA d'un autre créateur accessible par les missions liées aux sociétés de l'utilisateur — le seul chemin de sécurité vivant non caractérisé).

**Méthode :** specs de caractérisation sur comportement existant ; si le chemin via-missions se comporte de façon non documentée/incorrecte → cycle RED explicite (décision CTO avant correction).

**Gates :** suite verte (compte documenté au journal si évolution justifiée), RuboCop 0, Brakeman 0, mesure SimpleCov.

**Commit :** `test(p6): characterize CRA access control`

### W1-D3 — Caractérisation des error_handlers — ⬜ à faire

**Périmètre :** traverser chaque handler non exercé des 3 fichiers, avec assertion du contrat `{ code, message, details }` (référence : `docs/technical/guides/error_contract.md`) — notamment : `handle_cra_locked_error`, `handle_cra_submitted_error`, `handle_duplicate_cra_error`, `handle_invalid_transition_error`, `handle_rate_limit_exceeded`, `handle_internal_error`, `handle_cra_month/year/currency_error`, `handle_no_independent_company_error`, et les équivalents `cra_entries` + `common`.

**Gates :** idem + aucune modification du format de sortie (caractérisation pure — toute divergence détectée = journal + décision CTO).

**Commit :** `test(p6): characterize API error handlers`

### W1-D4 — `standardized_error` : branches restantes + fc08::005 — ⬜ à faire

**Périmètre :** branches non traversées (`error_invalid_enum`, `error_malformed_json`, `error_missing_parameter`, `error_unauthorized`, `handle_unpermitted_parameters`, `handle_parameter_missing`, helpers `validate_required_params`/`validate_enum`/`validate_json`) ; puis règle fc08::005 : **si** la caractérisation démontre l'incompatibilité du helper (`{error: {code}}` imbriqué vs contrat plat) → RED → correction **minimale** du helper.

**Gates :** idem + journal W1-D4 explicitant la démonstration d'incompatibilité (ou son absence).

**Commit :** `fix(p6): align standardized error contract`

## 4. Journal de suivi

### 2026-09-18 — GO Wave 1 + reconnaissance pré-D1

- **GO CTO :** branche `feat/p6-wave1`, séquence W1-D1→D4, messages de commits validés, règle fc08::005 conditionnelle, projections non contractuelles.
- **Reconnaissance (contrat de routage respecté) :** requêtes hub `foresy__knowledge`/`foresy__memories` (campagne, contrat d'erreur, fc08::005) ; lecture des 5 cibles + `CrasController`/`MissionsController` + `permissions_spec.rb` ; extraction coverage ligne à ligne (Cobertura) ; greps exhaustifs.
- **Découverte W1-D1 :** le concern `Api::V1::Cras::AccessValidation` est **mort/éclipsé à 100 %** (preuves §3) — la cible n°1 affichée de la campagne est une dette legacy, pas un trou de couverture à caractériser. Renvoyé au CTO → GO suppression.
- **Note CI :** la branche `feat/p6-wave1` ne déclenche pas de run CI au push (workflow : push main / PR main) — l'arbitrage CI interviendra à l'ouverture de la PR Wave 1, après merge de la PR #34.

## 5. Critères de sortie de vague

- [ ] W1-D1 → W1-D4 : chaque étape validée (suite verte, RuboCop 0, Brakeman 0, mesure réelle au journal)
- [ ] Compte de specs : 962 inchangé, ou toute évolution justifiée au journal
- [ ] fc08::005 : traitée selon la règle conditionnelle
- [ ] Journal complet + docs de campagne à jour (`coverage_campaign_p6.md`)
- [ ] PR Wave 1 ouverte au format maison après merge PR #34 — CI 6/6 = clôture de la vague

## 6. Références

- Plan de campagne : `docs/technical/testing/coverage_campaign_p6.md`
- Contrat d'erreur : `docs/technical/guides/error_contract.md`
- Guide couverture : `docs/technical/testing/line_coverage.md`
- Mémoire : `fc08::010` (P6.1-bis clos, dette OAuth → Wave 2)
- Historique migration FC-07 : `docs/technical/changes/2026-01-03-FC07_CRA_Implementation.md` §4 (ancien scope pré-RDD)