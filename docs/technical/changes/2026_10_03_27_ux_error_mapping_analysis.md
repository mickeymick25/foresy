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
| **C-1** | `POST /missions` avec `client_company_id` inconnu → `MissionCompany.create!` → **ForeignKeyViolation** → rescue service → `internal_error` → **500 :internal_error** (données intègres) | ✅ (param accepté par strong params L192, consommé par le service L354-360) | Correction : **validation préalable dans le service** → `422 :invalid_client_company` (avant transaction) |
| **C-2** | `PUT/DELETE /cra_entries` sur CRA **non-draft** → `CraEntryServices::Update/Destroy` émettent **`ApplicationResult.conflict(:invalid_transition)`** (update L55-58, destroy L54-57) — mais `CraEntriesController#handle_service_error` mappe sur `result.error` **sans connaître `:invalid_transition`** → `else` → `error_internal('An unexpected error occurred')` → **500 + message générique écrasé** | ✅ (L292-310 : la liste `when` couvre `:invalid_cra_state` mais pas `:invalid_transition`) | Correction : `when :invalid_transition → error_conflict` (**409 + message service**) |
| **C-3** | RuntimeError défensif « No independent company found » (missions L347) → 500 | 🟡 théorique — `check_user_permissions` garantit l'existence (`exists?` même requête) ; atteignable seulement par suppression concurrente (aucun chemin applicatif) | **Pas de correction** — statu quo documenté (constat, pas défaut) |

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

### 2.3 C-3 — RuntimeError défensif

- `raise 'No independent company found…'` (L347) — **non-rescué** → rollback sain → 500.
- `check_user_permissions` (L248-264) garantit l'existence par la même requête (`exists?`) → atteignable
  seulement par suppression concurrente (aucun chemin applicatif — cf. #19 reachability). **Constat, pas
  défaut ; correction non proposée.**

---

## 3. Mappings proposés (décisions → arbitrage)

| # | Décision demandée | Proposition |
|---|---|---|
| **Q-1** | C-1 : statut/code pour `client_company_id` inconnu | Validation dans le service **avant** toute écriture : `client_id.present? && !Company.find_by(id: client_id)` ⇒ `ApplicationResult.unprocessable_entity(error: :invalid_client_company, message: …)` → **422** (famille invalid_payload du contrat). RED d'abord (spec : 500 aujourd'hui). |
| **Q-2** | C-2 : mapping `:invalid_transition` dans `handle_service_error` | `when :invalid_transition → error_conflict(result.message)` → **409 + message service** (aligné avec émission conflict du service). RED d'abord (spec : 500 aujourd'hui). |
| **Q-3** | C-3 : RuntimeError défensif | **Statu quo documenté** — pas de correction (chemin mort en pratique) ; retrait du `raise` non demandé. |

**Discipline d'implémentation si GO** : RED mesurés d'abord (2 specs : 500 aujourd'hui → échec), correction
minimale (2 fichiers : `mission_services/create.rb` + `cra_entries_controller.rb`), GREEN, suite complète,
`[DONE]_`, BACKLOG close. Le vocabulaire `:invalid_cra_state`/`:invalid_transition` (fragmentation S-4) reste
**hors périmètre** (sujet étude #19 — ne pas fusionner).

---

## 4. Suivi d'avancement (T1-T8) — traité / non traité

| # | Étape | Statut | Où |
|---|---|---|---|
| T1 | Analyse #27 écrite (preuves code, reachability, mappings proposés) | ✅ fait (2026-10-03) | ce doc · BACKLOG #27 |
| T2 | **Arbitrage CTO : Q-1 / Q-2 / Q-3** (mapping + GO correction) | ⬜ en attente | arbitrage CTO |
| T3 | **RED mesurés** (2 specs : 500 constatés → assertions 422/409 en échec) | ⬜ après T2 | specs dédiées |
| T4 | Patch minimal (service validation + mapping contrôleur) | ⬜ après T3 | code |
| T5 | GREEN + suite complète + Zeitzeitwerk/RuboCop 0 | ⬜ après T4 | gates |
| T6 | BACKLOG #27 close + row « livrés » · `[DONE]_` sur ce doc | ⬜ après T5 | BACKLOG/doc |
| T7 | Merge + réindexation hub | ⬜ post-merge | hub RAG |
| T8 | Mémoire fc08::019 proposée | ⬜ proposition | hub après validation |

**Hors périmètre (constats sans correction)** : C-3 (RuntimeError défensif) · fragmentation du vocabulaire
d'erreurs (S-4, étude #19) · convention `.status` vs `.error` entre contrôleurs (à arbitrer séparément).

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
*Préfixe `[DONE]_` à appliquer à l'issue de l'arbitrage (Q-1/Q-2/Q-3) + correction.*