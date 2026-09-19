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
| `app/controllers/concerns/api/v1/cras/access_validation.rb` | 94 / 77 | 18,09 % — **supprimé en W1-D1 (18/09)** |
| `app/controllers/concerns/api/v1/cras/error_handler.rb` | 76 / 49 | 35,53 % |
| `app/controllers/concerns/api/v1/cra_entries/error_handler.rb` | 73 / 46 | 36,99 % |
| `app/controllers/concerns/common/error_handler.rb` | 36 / 17 | 52,78 % |
| `app/controllers/concerns/standardized_error.rb` | 84 / 26 | 69,05 % |

## 3. Séquence validée

### W1-D1 — Suppression du concern mort `Api::V1::Cras::AccessValidation` — ✅ FAIT (18/09)

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

### W1-D2 — Caractérisation de la sécurité vivante — ✅ FAIT (18/09) · W1-D2-BUG complet (CRA + Mission) — clôture définitive D2 avec le GO CTO W1-D3

**Périmètre :** ce qui tourne réellement — `Cra.accessible_to` (scope pivot RDD), `CrasController#validate_cra_access!`, et le **chemin via-missions** (FC06 : CRA d'un autre créateur accessible par les missions liées aux sociétés de l'utilisateur — le seul chemin de sécurité vivant non caractérisé).

**Méthode :** specs de caractérisation sur comportement existant ; si le chemin via-missions se comporte de façon non documentée/incorrecte → cycle RED explicite (décision CTO avant correction).

**Gates :** suite verte (compte documenté au journal si évolution justifiée), RuboCop 0, Brakeman 0, mesure SimpleCov.

**Commit :** `test(p6): characterize CRA access control`

### W1-D2-BUG — Soft-delete propagation dans l autorisation CRA — ✅ CYCLE TERMINÉ (arbitrage CTO 18/09)

**Arbitrage :** les deux observations de frontière de W1-D2 sont des **bugs** (mission soft-deletée → accès persistant ; user_company révoqué FC-08 → accès persistant). Le scope nu (CRA soft-deleté) est **confirmé non exposé** (appelants chaînent `.active`) — sans correction. `Mission.accessible_to` : détermination par caractérisation requise, **pas de correction préventive spéculative**.

**Cycle exécuté :** RED (bascule des 2 attentes en négatives métier) → **2 échecs exactement, pour la raison attendue** (l'accès persiste) → cause racine : la sous-requête via-missions de `relation_accessible_to` ne filtre ni `missions.deleted_at` ni `user_companies.deleted_at` (pivots `cra_missions`/`mission_companies` : hard delete, aucun filtre requis) → **GREEN : correction minimale (2 lignes** — conditions `deleted_at: nil` sur `missions` et `user_companies` dans la sous-requête ; aucun refactor du mécanisme) → ciblé 9/0 (7 CRA + 2 Mission).

**Détermination `Mission.accessible_to` (vigilance CTO) :** `spec/models/mission_access_spec.rb` — témoin positif via-companies ✓ + défaut **démontré** : une adhésion révoquée (user_company soft-deleté) continuait d octroyer l accès mission (`via_companies` sans filtre). **Corrigé dans le même cycle par arbitrage CTO** (journal W1-D2-BUG suite) — `MissionsController#validate_mission_access!` l appelle en production.

**Régression :** FC06 positif via-missions reste **200** en requête (incluse dans la suite) · suite **972/0** (970 + 2 détermination Mission) · RuboCop **0** (230 files) · Brakeman **0** · SimpleCov réel : **74,70 % lignes (2891/3870) · 46,66 % branches (755/1618)** — inchangé vs D2 (la correction ajoute 2 lignes au corpus du scope déjà couvert).

**Commit :** `fix(p6): l'autorisation CRA filtre missions et user_companies soft-deletées (W1-D2-BUG)`

### W1-D3 — Caractérisation des error_handlers — ⏸ bloquée (arbitrage CTO post-D2-BUG)

**Périmètre :** traverser chaque handler non exercé des 3 fichiers, avec assertion du contrat `{ code, message, details }` (référence : `docs/technical/guides/error_contract.md`) — notamment : `handle_cra_locked_error`, `handle_cra_submitted_error`, `handle_duplicate_cra_error`, `handle_invalid_transition_error`, `handle_rate_limit_exceeded`, `handle_internal_error`, `handle_cra_month/year/currency_error`, `handle_no_independent_company_error`, et les équivalents `cra_entries` + `common`.

**Gates :** idem + aucune modification du format de sortie (caractérisation pure — toute divergence détectée = journal + décision CTO).

**Commit :** `test(p6): characterize API error handlers`

### W1-D4 — `standardized_error` : branches restantes + fc08::005 — ⬜ à faire

**Périmètre :** branches non traversées (`error_invalid_enum`, `error_malformed_json`, `error_missing_parameter`, `error_unauthorized`, `handle_unpermitted_parameters`, `handle_parameter_missing`, helpers `validate_required_params`/`validate_enum`/`validate_json`) ; puis règle fc08::005 : **si** la caractérisation démontre l'incompatibilité du helper (`{error: {code}}` imbriqué vs contrat plat) → RED → correction **minimale** du helper.

**Gates :** idem + journal W1-D4 explicitant la démonstration d'incompatibilité (ou son absence).

**Commit :** `fix(p6): align standardized error contract`

## 4. Journal de suivi

### 2026-09-18 — W1-D2-BUG (suite) — RED → GREEN : propagation du soft-delete dans l autorisation Mission

- **Arbitrage CTO :** défaut **démontré en production** (via_companies sans filtre + `MissionsController#validate_mission_access!` sur show/update/destroy) — même violation de sémantique que CRA, **correction dans le même cycle, dette non reportée** (cohérence d autorisation entre les deux agrégats sur la même notion de relation active)
- **RED :** bascule de l observation en attente métier négative — **exactement 1 échec** (exit 1, l accès persiste après révocation), témoin positif via-companies vert
- **Cause racine :** `Mission.relation_accessible_to` — la sous-requête via_companies ne filtre pas `user_companies.deleted_at`
- **Correction minimale (symétrique du fix CRA) :** 1 ligne — `user_companies: { …, deleted_at: nil }` dans via_companies. Pivot `mission_companies` : hard delete — aucun filtre requis. **Rien d autre modifié** (cra_missions, mission_companies, structure du mécanisme, autres chemins, soft-delete de Mission lui-même)
- **GREEN :** ciblé **9/0** (2 Mission — dont le **témoin positif toujours accessible** — + 7 CRA revérifiées)
- **Régression :** suite **972/0** — compte exact effectivement obtenu (l exemple basculé remplace l observation) ✓ · RuboCop **0** (230 files) ✓ · Brakeman **0** ✓
- **Mesure SimpleCov réelle :** **74,70 % lignes (2891/3870) · 46,66 % branches (755/1618)** — identique (le filtre s applique à des lignes déjà couvertes)
- **Commit :** `fix(p6): l'autorisation Mission filtre user_companies soft-deletées (W1-D2-BUG suite)`
- **État de vague :** W1-D1 ✅ · W1-D2 ✅ (caractérisation) + W1-D2-BUG ✅ complet (CRA + Mission) · W1-D3 ⏸ · W1-D4 ⏸ — **GO W1-D3 attendu du CTO**

### 2026-09-18 — W1-D2-BUG clôturé — RED → GREEN : propagation du soft-delete dans l autorisation CRA

- **Observation initiale (W1-D2) :** mission soft-deletée ⇒ accès persistant ; user_company soft-deleté (FC-08 : révocation) ⇒ accès persistant. Arbitrage CTO : **bugs — cycle RED → GREEN requis** ; scope nu CRA : non exposé, sans correction ; `Mission.accessible_to` : caractériser pour déterminer, aucune correction préventive
- **RED démontré :** bascule des 2 observations en attentes négatives métier — **exactement 2 échecs** (exit 1), pour la raison attendue : `Cra.accessible_to(member)` inclut encore le CRA après soft-delete. Les 5 autres caractérisations restent vertes
- **Cause racine :** `Cra.relation_accessible_to` — la sous-requête via-missions joint `missions` et `user_companies` sans condition `deleted_at` : une relation supprimée reste une voie d autorisation active
- **Correction minimale :** 2 lignes dans la sous-requête — `.where(user_companies: { …, deleted_at: nil })` + `.where(missions: { deleted_at: nil })`. Pivots `cra_missions`/`mission_companies` : hard delete (schéma) — aucun filtre requis. **Aucun refactor du mécanisme d autorisation**
- **GREEN :** ciblé **9/0** (7 CRA — dont les 2 négatives basculées + le témoin FC06 + l observation scope nu conservée — et 2 Mission) ; FC06 positif en requête reste **200**
- **Détermination `Mission.accessible_to` :** même défaut **démontré** par observation (`via_companies` sans filtre `user_companies.deleted_at` — la révocation d adhésion n invalide pas l accès mission). **Non corrigé** — décision CTO (dette ouverte, même chaîne d autorisation que CRA)
- **Gates :** suite **972/0** (970 + 2) ✓ · RuboCop **0** (230 files — 3 offenses de layout dans mes specs, corrigées avant commit) ✓ · Brakeman **0** ✓
- **Mesure SimpleCov réelle :** **74,70 % lignes (2891/3870) · 46,66 % branches (755/1618)** — identique à la clôture D2 (la correction ne fait pas varier le corpus mesuré)
- **Commit :** `fix(p6): l'autorisation CRA filtre missions et user_companies soft-deletées (W1-D2-BUG)`
- **État de vague :** W1-D1 ✅ · W1-D2 ✅ (caractérisation) + W1-D2-BUG ✅ · W1-D3 ⏸ · W1-D4 ⏸ — **clôture définitive D2 + GO D3 : réévaluation CTO**

### 2026-09-18 — W1-D2 clôturée — caractérisation de la sécurité vivante (via-missions)

- **Specs ajoutées (8, suite 962 → 970) :** `spec/models/cra_access_spec.rb` (nouveau, 7 exemples — voie via-missions FC06, rôles pivots, séparation société/mission, 3 observations soft-delete) + 1 contexte requête dans `spec/requests/api/v1/cras/permissions_spec.rb` (via-missions → GET show 200)
- **Ce que démontre le scénario via-missions :** le chemin de sécurité vivant **fonctionne de bout en bout** — `Cra.accessible_to` inclut le CRA d'un autre créateur lorsque l'utilisateur est lié (user_company, rôle independent **ou client**) à une société elle-même liée à une mission du CRA (pivot cra_missions) ; la requête réelle renvoie 200 avec le payload complet. **Caractérisation pure — aucun cycle RED requis pour ce chemin.**
- **Observations aux frontières (démontrées vertes telles quelles — relevées pour décision CTO) :**
  1. **Mission soft-deletée ⇒ l'accès via-missions persiste** — le scope ne filtre pas `missions.deleted_at`
  2. **User_company soft-deleté (FC-08) ⇒ l'accès via-missions persiste** — le scope ne filtre pas `user_companies.deleted_at` : une révocation d'adhésion ne se propage PAS à l'autorisation CRA
  3. CRA soft-deleté retourné par le scope nu — **sans impact API** (tous les appelants chaînent `.active`), documenté tel quel
  → Les points 1 et 2 sont des candidats cycles RED → GREEN (correction du scope) — **décision CTO attendue avant tout basculement d'attente**
- **Gates :** RSpec **970/0** ✓ · RuboCop **0 offense** (229 files) ✓ · Brakeman **0 warning** ✓
- **Mesure SimpleCov réelle :** **74,70 % lignes (2891/3870) · 46,66 % branches (755/1618)** — vs 74,54 % post-W1-D1 : **+0,16 pt lignes** (conséquence de la caractérisation réelle, pas d'un objectif)
- **Commit :** `test(p6): characterize CRA access control`
- **Suivant :** W1-D3 (error_handlers) — non démarré

### 2026-09-18 — W1-D1 clôturée — suppression du concern mort

- **Gates (séquence CTO) :** retrait de l'`include` (CrasController L26) ✓ → grep exhaustif post-suppression (`app/`, `config/`, `lib/`, `bin/`, `spec/` — `.rb`/`.rake`) : **zéro référence de code** ✓ → RSpec **962/0 — compte inchangé** ✓ → RuboCop **0 offense** (228 files) ✓ → Brakeman **0 warning** ✓
- **Mesure SimpleCov réelle (conteneur, `foresy_test` propre) :** **74,54 % lignes (2885/3870) · 46,35 % branches (750/1618)** — vs 73,21 % / 45,07 % avant suppression : **+1,33 pt lignes, +1,28 pt branches**, sans un test artificiel (l'univers est réduit du code mort, le comportement est inchangé — 962 exemples identiques)
- **Base de branche vérifiée (contrôle CTO pré-lancement) :** `547c8d8a` = tête de `chore/p61-coverage-lock` (descendant de `f1f42652` par les commits docs-only `37a1aedd` + `547c8d8a`, tous CI verts) — référence du tracker confirmée exacte
- **Commit :** `chore(p6): remove dead AccessValidation concern`
- **Suivant :** W1-D2 (caractérisation sécurité vivante) — non démarré, conformément à la règle de clôture

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