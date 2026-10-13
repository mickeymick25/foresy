# 📐 Analyse #27 — Mapping erreurs contrôleur ↔ contrat : anomalies UX atteignables (500 → 422/409)

**Date :** 2026-10-03 (horodatage git-clock hôte)
**Chantier :** BACKLOG **#27** — « Mapping contrôleur — anomalies UX atteignables (à qualifier) »
**Statut :** ✅ Analyse terminée (lecture seule, falsifiable — preuves code) — **3 décisions de mapping
soumises à arbitrage CTO avant toute implémentation** · suivi d'avancement : §4
**Discipline :** Investigation → preuve → arbitrage → modification — ce document est l'étape « preuve ».

---

## 1. Conclusion en une page

| # | Anomalie | Constat | Atteignable ? | Correction proposée |
|---|---|---|---|---|
| **C-1** | `POST /missions` avec `client_company_id` inconnu → **ANOMALIE RÉELLE ≠ analyse initiale : 201 + param client silencieusement jeté** — `mission.mission_companies.create!` lève `RecordInvalid ('Company must exist')` (validation belongs_to, AVANT l'INSERT — pas de FK violation) et le `rescue ActiveRecord::RecordInvalid` **DANS le bloc transaction** de `save_mission` (L250) **jette le résultat** : `success` renvoyé inconditionnellement → **mission committée sans lien client** (meilleur écho du même anti-pattern C-1/C-2) | ✅ PROUVÉ par runs (201, seed 47973) | **CORRIGÉ (Q-1)** : validation AVANT toute écriture → `422 :invalid_client_company` |
| **C-2** | `PUT/DELETE /cra_entries` sur CRA non-draft — **PAS de RED via points d'entrée publics** : `before_action validate_entry_modifiable!` (L23/L166-173) sert **déjà le 409** `CONFLICT` (+ message métier) AVANT l'appel au service — le 500 `handle_service_error` n'est **pas atteignable via l'API** (le code-level claim C-4/analyse initiale corrigé) | ✅ démontré par spec (PATCH+DELETE = 409, verts d'emblée) | **Mapping NON ajouté** — règle : pas de code défensif sans anomalie atteignable (précédent Q-3) |
| **C-3** | RuntimeError défensif « No independent company found » → 500 | 🟡 theorique — `check_user_permissions` garantit l'existence (`exists?` même requête) ; atteignable seulement par suppression concurrente (aucun chemin applicatif) | **Pas de correction** — statu quo documenté (constat, pas défaut) |

**Qualification proposée** : anomalies **UX contractuelles** (contrat d'erreur standardisé) — pas de risque
données (déjà démontré #19), pas de P0. Les corrections sont **optionnelles / hygiène de contrat**.

---

## 2. Phase 1 — Faits (preuves code)

### 2.1 C-1 — missions / client_company_id inconnu

- `MissionsController#mission_params` (L181-194) : **`client_company_id` est permitté** (L192) et documenté
  « consumed by MissionServices::Create to build the client relation ».
- `MissionServices::Create#create_mission_company_relations!` (L354-360) : `client_id.present?` ⇒
  `mission.mission_companies.create!(company_id: client_id, role: 'client')` — **aucune validation** ni
  existence-check avant l'INSERT.
- FK `mission_companies.companies` (schema L229, sans cascade) ⇒ `client_id` inconnu → **ForeignKeyViolation**
  (StandardError, non-rescuée par les rescues RecordInvalid/RecordNotFound) → échappe du bloc transaction →
  `.call rescue StandardError` (L68-73) → `ApplicationResult.internal_error(:internal_error, 'An unexpected
  error occurred while creating the mission')` → `render_result_error` → **500** (message générique, pas de
  fuite `e.message` — contrôlé).
- **Données intègres** : rollback complet (mission + pivots) — démontré #19 (audit `[DONE]_…reachability…` §4).
- **CORRECTION POST-RED (empirique — points falsifiés ci-dessus)** : FK réellement présente
  (`fk_rails_5e6e367100 — FOREIGN KEY (company_id) REFERENCES companies(id)`, probe manuel §4-doc) MAIS
  **la validation belongs_to échoue AVANT l'INSERT** (`RecordInvalid : 'Company must exist'`, probe manuel)
  et le `rescue ActiveRecord::RecordInvalid` **DANS le bloc transaction** de `save_mission` **jette le
  résultat** (`success` renvoyé inconditionnellement — anti-pattern C-1/C-2) → comportement réel :
  **201 + param client silencieusement jeté** (mission committée sans lien client) — RED mesuré `got: 201`
  (seed 47973, fix stashé, requête JSON bien formée). Fix Q-1 remède correct (validation avant écriture → 422).

### 2.2 C-2 — cra_entries / :invalid_transition non mappé

- Émission : `CraEntryServices::Update` (L55-58) et `Destroy` (L54-57) — `ApplicationResult.conflict(error:
  :invalid_transition, message: 'Cannot update/delete entries of a CRA that is not in draft')`.
- Contrôleur : `handle_service_error` (L291-310+) mappe sur **`result.error`** ; la liste couvre
  `:invalid_cra_state` (→409) mais **pas `:invalid_transition`** → `else error_internal('An unexpected error
  occurred')` → **HTTP 500 + message générique écrasé** (le message service et le statut conflict du résultat
  perdus).
- **Trois conventions coexistantes autour du même invariant** (observation factuelle) : résultat `conflict`
  (services) vs mapping contrôleur incomplet (500) vs `rescue_from CraErrors::InvalidTransitionError` → 422
  (L29-33, L199-203 — voie exception). En cohérence avec l'étude S-4 (vocabulaire fragmenté) — hors #27.
- Contexte C-4 : l'étude 24/09 qualifiait déjà ce mapping — le C-2 ci-dessus est la confirmation au code
  d'aujourd'hui (l'inertie observée au §6 de l'étude est le même constat).
- **CORRECTION POST-RED (empirique)** : le before_action `validate_entry_modifiable!` (L23/L166-173) sert
  **déjà le 409 CONFLICT** via les points d'entrée publics (spec PATCH+DELETE : 409 + code CONFLICT + message
  métier — vertes d'emblée) — le 500 `handle_service_error` n'est **pas atteignable via l'API pour ce cas**
  (claim C-4/analyse initiale corrigé) ; conformément à la règle « pas de code défensif sans anomalie
  atteignable », le mapping `:invalid_transition` **n'est pas ajouté** ; la spec publique épine le 409
  comme régression permanente.

### 2.3 C-3 — RuntimeError défensif

- `raise 'No independent company found…'` (L347) — **non-rescué** → rollback sain → 500.
- `check_user_permissions` (L248-264) garantit l'existence par la même requête (`exists?`) → atteignable
  seulement par suppression concurrente (aucun chemin applicatif — cf. #19 reachability). **Constat, pas
  défaut ; correction non proposée.**

---

## 3. Mappings proposés (décisions → arbitrage)

| # | Décision demandée | Proposition |
|---|---|---|
| **Q-1** | C-1 : statut/code pour `client_company_id` inconnu | **IMPLEMENTÉ** : validation dans le service **avant** toute écriture (UUID malformé inconnu ⇒ `ApplicationResult.unprocessable_entity(error: :invalid_client_company…)` → **422**, HTTP code contractuel UNPROCESSABLE_ENTITY — le symbole vit côté ApplicationResult). **RED mesuré** avec requête JSON bien formée : `got: 201` (seed 47973, fix stashé) → **GREEN ×2** |
| **Q-2** | C-2 : mapping `:invalid_transition` dans `handle_service_error` | **PAS DE RED ATTEIGNABLE** (409 déjà servi par `validate_entry_modifiable!` via points d'entrée publics — spec verte d'emblée) : conformément à la règle « pas de code défensif sans anomalie atteignable » (précédent Q-3), **mapping non ajouté** ; la spec publique épine le 409 comme régression permanente |
| **Q-3** | C-3 : RuntimeError défensif | **Statu quo acté** — pas de correction (chemin mort en pratique) ; preuve de garde documentée (§2.3) |

**Discipline d'implémentation si GO** : RED mesurés d'abord (2 specs : 500 aujourd'hui → échec), correction
minimale (2 fichiers : `mission_services/create.rb` + `cra_entries_controller.rb`), GREEN, suite complète,
`[DONE]_`, BACKLOG close. Le vocabulaire `:invalid_cra_state`/`:invalid_transition` (fragmentation S-4) reste
**hors périmètre** (sujet étude #19 — ne pas fusionner).

---

## 4. Suivi d'avancement (T1-T8) — traité / non traité

| # | Étape | Statut | Où |
|---|---|---|---|
| T1 | Analyse #27 écrite (preuves code, reachability, mappings proposés) — **corrigée post-RED** : C-1 réel = 201 + param client jeté (pas 500/FK) · C-2 = pas de RED via points d'entrée publics (before_action) | ✅ fait + corrigé (2026-10-03) | ce doc · BACKLOG #27 |
| T2 | **Arbitrage CTO : Q-1 GO · Q-2 GO (sous réserve RED via points d'entrée publics) · Q-3 NO-GO** | ✅ fait (2026-10-03) | arbitrage CTO |
| T3 | **RED** : Q-1 — 1ʳᵉ mesure invalide (ParseError spec : `as: :json` manquant — artefact de test, corrigé) ; **RED final : got 201** (seed 47973, fix stashé, requête JSON bien formée) · **Q-2 : PAS DE RED** (409 déjà servi par `validate_entry_modifiable!` — specs PATCH+DELETE vertes d'emblée) | ✅ mesuré (2026-10-03) | specs dédiées (+ sorties session) |
| T4 | Patch minimal : **Q-1 uniquement** (validation UUID+existence du client AVANT toute écriture → `422 :invalid_client_company`) · **Q-2 mapping NON ajouté** (pas de RED — règle : pas de code défensif sans anomalie atteignable) | ✅ fait | `mission_services/create.rb`, spec de contrat Q-2 conservée |
| T5 | GREEN ×2 + suite complète **1136/0** (seed 26173 — 86,30/61,16 · verrou 72,5) + RuboCop **246 files / 0** · Brakeman 0 · Zeitwerk OK | ✅ fait | gates |
| T6 | BACKLOG #27 close + row « livrés » · `[DONE]_` sur ce doc | ✅ fait | BACKLOG/doc |
| T7 | Merge + réindexation hub | ⬜ post-merge | hub RAG |
| T8 | Mémoire fc08::019 **proposée** (à valider; non enregistrée avant vérification) | ⬜ proposition | hub après validation |

**Corrections d'analyse post-RED (honnête de traçabilité)** : l'analyse initiale affirmait (a) C-1 = FK
violation → 500 et (b) C-2 500 atteignable via l'API. Les RED via points d'entrée publics ont réfuté les deux :
(a) le comportement réel est **201 + param client silencieusement jeté** — le `create!` client lève
`RecordInvalid ('Company must exist')` (validation belongs_to, avant l'INSERT) et le `rescue ActiveRecord::RecordInvalid`
**DANS le bloc transaction** de `save_mission` **jette le résultat** (`success` inconditionnel — anti-pattern
C-1/C-2) ; la FK `fk_rails_5e6e367100` existe mais n'est jamais atteinte ; (b) le before_action sert déjà le 409.
Le fix Q-1 est le remède correct — **plus fort que l'analyse initiale** : l'anomalie incluait une persistance
sans son client (201), pas un simple mauvais statut.

**Hors périmètre (constats sans correction)** : C-3 (RuntimeError défensif) · fragmentation du vocabulaire
d'erreurs (S-4) · convention `.status` vs `.error` entre contrôleurs · prévention ledger (#28).

---

## 5. Références

- `app/controllers/api/v1/missions_controller.rb` L49-59 (create), L126-142 (`render_result_error` sur
  `.status`), L179-194 (`mission_params` avec `:client_company_id`)
- `app/services/mission_services/create.rb` L344-361 (relations), L347 (RuntimeError défensif), L68-73
  (rescue → internal_error)
- `app/controllers/api/v1/cra_entries_controller.rb` L291-310 (`handle_service_error` sur `.error`,
  `else → error_internal`), L29-33/L199-203 (voie exception → 422)
- `app/services/cra_entry_services/{update,destroy}.rb` L55-58/L54-57 (émission `conflict(:invalid_transition)`)
- `app/lib/application_result.rb` (vocabulaire 400/401/403/404/409/422/500)
- `docker-compose.yml` L229-230 (`mission_companies` FK sans cascade) · étude services 24/09 (C-4) ·
  audit `[DONE]_2026_09_26_19_p0_reachability_investigation.md` · BACKLOG **#27**

---

**Document créé le :** 2026-10-03
**Propriétaire :** Équipe technique Foresy
**Certification (2026-10-03)** : Q-1 implémenté (RED got 201 → GREEN ×2 · suite 1136/0 · RuboCop 246/0 ·
Brakeman 0 · Zeitwerk OK) · Q-2 mapping non ajouté (pas de RED — before_action) · Q-3 statu quo acté ·
analyse corrigée post-RED (§2.1/§2.2/§4) · préfixe `[DONE]_` appliqué · **#27 CLOSED** (prévention ledger =
#28, hors périmètre).