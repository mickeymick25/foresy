# 📐 Étude — Homogénéité & Uniformisation Méthodologique de la Couche Services

**Date :** 24 septembre 2026
**Auteur :** Zed Agent (étude automatisée sur demande CTO)
**Statut :** ✅ Étude terminée — **plan d'uniformisation proposé (§9), RIEN exécuté** (étude uniquement)
**Périmètre :** `app/services/**` (26 fichiers) + `spec/services/**` + `app/lib/application_result.rb`
**Méthodes :** requêtes RAG `foresy__knowledge` (historique FC-06/FC-07, migration 11/01/2026, Wave 3) ·
4 analyses de périmètre lecture seule (CRA / Mission+Company / CRAEntry+Linker / Infra+OAuth) ·
**re-vérification directe des constats critiques** (lignes de code citées) · `wc -l` / `grep` réels.
**Autorité :** ce document est la source de vérité de l'étude ; entrée BACKLOG associée (#19).

---

## 1. Synthèse exécutive

| Axe | Verdict Platinum | Détail |
|---|---|---|
| **Contrat de surface** (`.call` + ApplicationResult) | 🟢 Uniforme | 100 % des services métier namespacés (14/14) : `.call` kwargs, `ApplicationResult` exclusif, rescue final `StandardError` → `internal_error`, headers CONTRACT |
| **Discipline transactionnelle** | 🔴 Non uniforme — **2 bugs P0** | rescues **dans** le bloc `transaction` = rollback inhibé (`CraServices::Create`, `MissionServices::Create`) ; `CraEntryServices::Create` **sans transaction** (compensation manuelle) ; `CraEntryServices::Update` header mensonger |
| **Vocabulaire d'erreurs** | 🟠 Fragmenté | 3 vocables pour le même invariant (`:invalid_cra_state` / `:invalid_transition` ; `:insufficient_permissions` / `:forbidden` ; `bad_request` / `unprocessable_entity`) ; 1 mapping contrôleur incomplet → **500 au lieu de 409** |
| **Autorisation** | 🟠 Hétérogène | 3 modèles coexistants (rôle `independent` / `modifiable_by?` / `creator_user_id` inline) ; `CraEntryServices::List` **sans autorisation** (current_user ignoré) |
| **Dead code / règle métier** | 🔴 2 services orphelins | `CraMissionLinker` **0 call-site** (règle FC-07 de liaison auto CRA↔Mission **plus implémentée nulle part**) ; `ApmService` **0 call-site** (254 LOC + TestHelpers embarqués en prod) |
| **Specs unitaires** | 🟠 Trous | `CraServices::Update` (318 LOC) et `Destroy` (169 LOC) : **0 spec unitaire** ; `CompanyServices` : **0 spec** ; `CraEntryServices::Update` sans test doublon ; 122 examples unitaires côté infra |
| **Doc ↔ code** | 🟠 Rot | doc dit `CraServices::CreateService` (suffixe `Service`) — le réel est `Create` (le stub `cra_services.rb` est correct) ; « 45 tests CraEntryServices » → 46 réels ; headers mensongers (Update/List) |
| **Infra (OAuth/GitLedger/APM/RateLimit/JWT)** | 🟠 6 conventions de retour coexistantes | légitime pour l'infra, mais : backend Redis **jamais branché** (rate limiting par-processus en prod), APM ×3 implémentations parallèles toutes inertes |

**Verdict Platinum** : la couche a une **coquille homogène** et le socle du pattern est bon
(`ApplicationResult` façade unique bien conçue), mais l'**intériorité diverge** : transaction,
vocabulaire d'erreurs, autorisation, payload — et **2 bugs structurels P0** contredisent les
invariants relation-driven documentés (audit M3 : « la table pivot est l'unique lien créateur »).

---

## 2. Inventaire réel (vérifié au code)

### 2.1 Services métier namespacés (14 fichiers, pattern ApplicationResult)

| Famille | Fichiers | LOC | Pattern |
|---|---|---|---|
| `CraServices::*` | create 314 · list 200 · update 318 · destroy 169 · lifecycle 199 · export 162 + stub 36 | 1 398 | `.call` kwargs · ApplicationResult · transactions (4/6) |
| `CraEntryServices::*` | create 265 · update 82 · destroy 85 · list 48 | 627 | `.call` kwargs · ApplicationResult · transaction (1/4 !) |
| `MissionServices::*` | create 395 · update 245 · delete 115 | 755 | `.call` kwargs · ApplicationResult · transaction (1/3) |
| `CompanyServices::*` | create 99 | 99 | `.call` kwargs · ApplicationResult · transaction ✓ (mais 0 spec) |
| `CraMissionLinker` | 147 (top-level) | 147 | **`class << self`, exceptions, ApplicationResult absent, 0 appelant** |

### 2.2 Services infra (14 fichiers, 1 836 LOC — patterns propres)

`OAuthCodeExchangeService` (204) · `OAuthTokenService` (44) · `OAuthUserService` (108) ·
`OAuthValidationService` (158) · `GitLedgerService` (116) · `GitLedgerRepository` (module, 197) ·
`GitLedgerPayload` (module, 54) · `AuthenticationService` (89 + 3 concerns 186 LOC) ·
`JsonWebToken` (167) · `ApmService` (254, **mort**) · `RateLimitService` (249, hybride class+instance) ·
`RateLimit::Backend` (43) / `MemoryBackend` (85) / `RedisBackend` (68).

**Lecture de l'étude** : la divergence infra est **partiellement légitime** (JWT retourne une string,
GitLedger committe, RateLimit retourne un tuple) — le problème n'est pas leur hétérogénéité en
soi mais (a) l'absence de convention *documentée et assumée* par famille, (b) les faux headers,
(c) le code mort inerté.

---

## 3. Le contrat de référence — `app/lib/application_result.rb`

Façade unique (17/12/2025, "Solution Platinum") : constructeurs sémantiques
(`success/created/no_content` · `fail` + `bad_request/unauthorized/forbidden/not_found/conflict/unprocessable_entity/internal_error`)
+ fabriques compatibilité (`success_entry/entries/cra/cras`) + helpers lecteurs
(`item/items/cra/total_count/pagination/totals`).

**Constats d'usage divergent** :
- 5 services Cra utilisent les constructeurs sémantiques ; `CraServices::Export` seul utilise `.fail(error:, status:, message:)` brut.
- Fabriques compatibilité (`success_cra`, etc.) utilisées de façon inégale ; helpers lecteurs (`item`, `cra`, `pagination`) consommés par CraServices mais **pas par CraEntryServices** (clés `:cra_entry`/`:cra_entries` sans helper) ni `MissionServices` (`:mission`) ni `CompanyServices` (`:company`) — chaque contrôleur pioche `result.data[:clé]` à la main.
- Formes de `data` : hash simple / hash paginé / **string CSV brute** (Export) — 3 conventions.

---

## 4. Constats critiques — re-vérifiés directement au code

| ID | Constat | Preuve | Impact |
|---|---|---|---|
| **C-1** 🔴 | **Rollback inhibé — `CraServices::Create#save_cra`** : `rescue ActiveRecord::RecordInvalid/RecordNotFound` **à l'intérieur** du bloc `transaction` (L243-276). Si le pivot `UserCra` échoue **après** `cra.save!` réussi : exception avalée dans le bloc → transaction **commitée** (pas de rollback) → CRA persisté **sans pivot créateur** + le contrôleur reçoit un failure alors que la donnée existe en base. | lecture directe L243-276 ; contraste `lifecycle.rb` L146/L173 (rescue **hors** bloc, pattern correct) et `CompanyServices::Create` (rescue au niveau méthode) | 🔴 invariant relation-driven cassé silencieusement + divergence API/DB |
| **C-2** 🔴 | **Même anti-pattern — `MissionServices::Create#save_mission`** (L305-327) : mission + MissionCompany commités si UserMission échoue. Le `raise 'No independent company found…'` (RuntimeError) s'échappe correctement (rollback) mais le chemin RecordInvalid ne rollback pas. | lecture directe L305-336 | 🔴 idem |
| **C-3** 🔴 | **Règle métier FC-07 morte** : liaison automatique CRA↔Mission à la première entry — `CraMissionLinker` n'a **aucun appelant en production** (grep exhaustif : commentaires uniquement, dont un commentaire mensonger du contrôleur cra_entries L15). Les call-sites vivaient dans les services legacy `Api::V1::CraEntries::*`, supprimés en 01/2026 sans report. En plus : `Destroy` ne fait **aucun unlink** (feature documentée "Phase 3B" jamais reportée). | grep `CraMissionLinker` sur app/ | 🔴 fonctionnalité fantôme documentée comme vivante |
| **C-4** 🟠 | **Mapping contrôleur incomplet** : `CraEntriesController#handle_service_error` bascule sur `result.error` et **ne connaît pas `:invalid_transition`** (émis par CraEntryServices::Update/Destroy sur CRA non-draft) → fallback `error_internal` → **HTTP 500 au lieu de 409**. Deux conventions de contrat coexistent : mapper sur `.error` (CraEntries) vs `.status` (Cras/Missions/Companies). | lecture directe L268-292 | 🟠 contractuel |
| **C-5** 🟠 | **Rate limiting par-processus en production** : le commentaire de `RateLimitService.backend` et le header FC-05 affirment « RedisBackend in production », mais **aucune affectation de backend n'existe** (grep config/+app/) — vérifié empiriquement dans le conteneur : backend = `MemoryBackend`. Le fail-closed Redis est un chemin mort ; le throttling est inefficace derrière plusieurs instances. | grep + exécution rails runner (lecture) | 🟠 opérationnel |
| **C-6** 🟠 | **`ApmService` est du code mort** : 0 call-site (seules occurrences = son propre fichier + sa spec 34 examples), 254 LOC dont `ApmService::TestHelpers` (57 LOC de support RSpec) embarquées en code de production. Trois pipelines APM parallèles inerts : ApmService (morte), `JsonWebToken.add_datadog_tags`, `AuthenticationMetricsConcern` (NewRelic) — ni gem `datadog` ni `newrelic` présentes. | grep exhaustif ; exécution : `defined?(NewRelic/Datadog)` = nil, `ApmService.enabled?` = false | 🟠 dette P6 (examen avant exclusion déjà prévu) |
| **C-7** 🟠 | **CraEntryServices::Create sans transaction** : rollback manuel par compensation (`new_entry.destroy`, `cra_entry_cra.destroy`) — et le recalcul des totaux appelé via **wrapper silencieux** (échec → log seul, success quand même). Update : header « Transactions atomiques » **faux** (aucune transaction) ; recalcul nu sans rescue. | lecture des 4 fichiers | 🟠 intégrité |
| **C-8** 🟢 | `CraEntryServices::Destroy` fait un **hard delete** (`destroy!`) alors que le modèle documente un soft delete (`deleted_at`, `discard` neutralisé) — contradictoire, perte d'auditabilité. | lecture | 🟢→🟠 à arbitrer |

---

## 5. Divergences méthodologiques transverses (le cœur de l'étude)

### 5.1 Nomenclature
- **Doc vs code** : la migration 11/01/2026 (et les headers des fichiers eux-mêmes, « Migrated from Api::V1::Cras::*Service ») annoncent `CreateService/ListService/…` ; le réel est `CraServices::Create` **sans suffixe**. Le stub `cra_services.rb` est exact (`%w[Create List Update Destroy Lifecycle Export]`). FC-06 : les classes plates `MissionCreationService` etc. ont été migrées en `MissionServices::{Create,Update,Delete}` — le code a bougé, une partie de la doc non.
- **Stub de namespace inégaux** : `mission_services.rb` annonce `service_available?` = `%w[Create]` (périmé : Update/Delete existent) et mentionne le flag mort `USE_USER_RELATIONS` (0 usage) ; `company_services.rb` est correct et cite le house pattern ; `cra_services.rb` est exact.
- **Fusion non documentée** : Submit/Lock annoncés séparément en 01/2026 → réellement fusionnés dans `CraServices::Lifecycle` via kwarg `action:` (magic strings `'submit'`/`'lock'`).

### 5.2 Vocabulaire et mapping d'erreurs (divergence la plus systémique)
| Cas | Vocables concurrents |
|---|---|
| CRA non-modifiable (lifecycle) | `:invalid_cra_state` (CraEntry::Create) vs `:invalid_transition` (Update/Destroy) |
| Permission refusée | `:insufficient_permissions` (Mission::Create) vs `:forbidden` (Update/Delete) |
| Params manquants | `bad_request` 400 (Cra::Create/Destroy/Lifecycle) vs `unprocessable_entity` 422 (Cra::Update) |
| Doublon | `:cra_already_exists` (Cra) / `:duplicate_entry` (CraEntry) / `:duplicate_relationship` (Company) |
| Fuite d'erreur | CraServices : messages génériques en 500 ✓ / CraEntryServices + Mission (`:build_failed`) : **interpolation `e.message`** vers le client |
| Détection fragile | doublon CRA détecté par **parsing de messages** (`'already exists'`, `'duplicate'`…) ; doublon CraMission par magic string copiée depuis le validateur |

### 5.3 Autorisation — 3 modèles coexistants
| Modèle | Où |
|---|---|
| Rôle `independent` via `user_companies` | CraServices::Create, MissionServices::Create |
| `modifiable_by?` (créateur) | Cra Update/Destroy/Lifecycle/Export, Mission Update/Delete |
| `creator_user_id == current_user.id` inline | CraEntryServices ×3 (+ Destroy Cra redondant : créateur **puis** rôle, règles contradictoires) |
| ❌ aucune | CraEntryServices::List (`current_user` accepté, jamais utilisé) · CraMissionLinker · CraEntryServices::Create côté `cra.creator_user_id` ✓ en fait |
+ double couche contrôleur (`validate_cra_access!` via `Cra.accessible_to`) **et** service avec sémantiques différentes.

### 5.4 Discipline transactionnelle (matrice)
| Service | Transaction | Rescue placement | Constat |
|---|---|---|---|
| CraServices::Create | ✓ | ❌ **dans** le bloc | 🔴 C-1 |
| CraServices::Lifecycle (×2 blocs) | ✓ | ✓ hors bloc | pattern correct |
| CraServices::Update | ✗ | — | assumé en commentaire (« single record ») mais 2 `update!` séquentiels (statut puis attributs) → update partiel possible |
| CraServices::Destroy | ✓ | ❌ dans le bloc | impact faible (1 statement) |
| CraServices::Export | ✗ | — | `recalculate_totals` (écriture) **hors transaction** + erreurs avalées (`recalc_totals_safe`) → export sur totaux potentiellement obsolètes |
| CraEntryServices::Create | ✗ | — | compensation manuelle (fragile) |
| CraEntryServices::Update | ✗ | — | header mensonger |
| CraEntryServices::Destroy | ✓ | ✓ | la seule vraie transaction du namespace |
| MissionServices::Create | ✓ | ❌ **dans** le bloc | 🔴 C-2 |
| MissionServices::Update | ✗ | — | 2 `update!` séquentiels |
| MissionServices::Delete | ✗ | — | soft delete unique (acceptable) |
| CompanyServices::Create | ✓ | ✓ hors bloc | **le pattern correct de référence** |

### 5.5 Interface `.call`
- Standard : `self.call(**kwargs)` déléguant à une instance. 4 variantes dans CraEntryServices : `Create` porte un **paramètre fantôme `_ = nil`** pour forcer `arity == -2`, figé par un test — hack non répliqué par Update/Destroy/List du même namespace.
- `CraEntryServices::List` : `current_user: nil` par défaut + jamais utilisé (pas d'autorisation, pas de pagination — la pagination documentée "9/9 ✅" n'existe pas dans le code vivant).

### 5.6 Duplications
`parse_date` ×2 avec implémentations différentes (Mission create/update) · règles financières month/year/currency dupliquées Cra Create↔Update avec statuts HTTP divergents · `handle_update_errors` vs `handle_record_invalid_errors` (~20 lignes quasi identiques) · boilerplate input-validation ×4 CraEntry · rescue `StandardError → internal_error` + `if defined?(Rails)` ×4 · `mask_ip` ×2 avec comportements divergents (IPv6) · `OAUTH_TOKEN_EXPIRATION` duplique `JsonWebToken::ACCESS_TOKEN_EXPIRATION` · OAuth : `OAuthConcern` duplique ~60 LOC de `OAuthValidationService`/`OAuthUserService` **sans transaction ni anti-race** (2 pipelines OAuth parallèles de robustesse inégale).

### 5.7 Hygiène
Logs `[DEBUG]` avec inspect de params en production (`update.rb` L93 fuite de données en log, `create.rb` ×4) · magic strings (`'draft'`/`'EUR'`/`'lead'` au lieu des constantes existantes) · commentaires morts (« Automatic CRA-Mission linking via CraMissionLinker » mensonger, commentaires russes) · `export_minimal_spec.rb` redondant (repro de debug du 27/01) · `check_rate_limit(endpoint, ip, _request = nil)` paramètre mort · HS256 implicite + clé = `secret_key_base` (durcissement JWT possible).

---

## 6. État des specs (filet unitaire)

| Famille | Examples | Trous notables |
|---|---|---|
| CraServices | 99 `it` | **Update (318 LOC) et Destroy (169 LOC) : 0 spec unitaire** — couverts seulement par 6/4 cas RSwag ; doublon/rollback/`internal_error` non testés |
| CraEntryServices | 46 | Update sans test doublon (risque 500), List : 1 spec (caractérisation, nominal jamais testé), Create : rollback relations non testé |
| CraMissionLinker | 45 | le mieux testé… **pour un service sans appelant** |
| MissionServices | 56 | relations créées non testées (MissionCompany/UserMission), atomicité non testée |
| CompanyServices | **0** | service FC-08 jamais testé en unitaire (indirect modèle seulement ; INV-16/17 non testés au niveau service) |
| Infra | 122 | AuthenticationService/OAuthValidationService/OAuthTokenService : indirect seulement ; **ApmService (mort) = le mieux testé (34)** — inversion de valeurs |

Asymétrie structurelle : le code mort est sur-testé, les chemins critiques (Update/Destroy CRA, atomicité création) sont sous-testés — conséquence directe de l'historique (migration 01/2026 sans filet pour 2 services).

---

## 7. Mapping critères Platinum

| Critère projet | État |
|---|---|
| TDD (RED mesuré → GREEN) | 🟠 les services hérités de la migration 01/2026 n'ont pas suivi le cycle (Update/Destroy CRA sans specs) |
| ApplicationResult uniforme | 🟢 socle ✓ / 🟠 API d'usage fragmentée (§3) |
| Transaction discipline | 🔴 2 P0 + 3 services sans transaction |
| Zéro offense (RuboCop 0 / Brakeman 0) | 🟢 gates CI verts (aucune offense) — la qualité perçue vient des conventions, pas des gates |
| Erreurs standardisées `{code, message, details}` | 🟠 fuites `e.message` (CraEntry ×3, Mission ×2), vocabulaires multiples |
| Docs fidèles | 🟠 rot documenté §5.1 + headers mensongers |
| Code mort éliminé | 🔴 CraMissionLinker (règle FC-07 morte) + ApmService + commentaires mensongers — la campagne P6 a éliminé 9 fichiers legacy mais ceux-ci ont échappé au nettoyage (l'enquête "examen avant exclusion" était en suspens) |

---

## 8. Ce que l'étude ne change pas

- Aucun code modifié, aucun spec écrit, aucun test lancé (étude uniquement, consigne).
- Les constats critiques C-1/C-2/C-4 et l'orphelinat du linker sont re-vérifiés ligne à ligne par
  l'auteur de l'étude ; les autres constats proviennent des 4 analyses de périmètre (lecture seule,
  provenance : lecture de fichiers + grep + `wc -l`, croisés au hub pour l'historique).
- Les constats ne préjugent pas des arbitrages : **C-3 (règle FC-07 : ressusciter la liaison auto
  ou l'assumer comme abandonnée) est une décision produit**, pas une correction mécanique.

---

## 9. Plan d'uniformisation **proposé** (arbitrage CTO avant exécution)

| ID | Chantier | Priorité | Nature | Critère de validation | Statut |
|---|---|---|---|---|---|
| **S-1** | **Corriger les 2 bugs transactionnels (C-1/C-2)** — rescue hors bloc (pattern `lifecycle.rb`/`CompanyServices::Create`), RED d'abord : test qui prouve le commit sans pivot, puis GREEN | 🔴 | code + specs | specs rollback vertes ; invariant « pivot = unique lien créateur » testé | ⬜ |
| **S-2** | **Arbitrage règle FC-07 (C-3)** — réactiver la liaison auto CRA↔Mission via le linker (ou l'assumer abandonnée et le supprimer avec sa spec) + décider unlink à la Destroy | 🔴 | arbitrage produit puis code | décision tracée + code aligné (linker appelé ou supprimé) | ⬜ arbitrage CTO |
| **S-3** | **Mapping contrôleur CraEntries (C-4)** : mapper `:invalid_transition` → 409 ; unifier la convention (`.status` vs `.error`) sur les 4 contrôleurs | 🟠 | code + specs | update/destroy sur CRA non-draft → 409 testé | ⬜ |
| **S-4** | **Vocabulaire d'erreurs** : table de correspondance unique (1 invariant = 1 code = 1 status), supprimer les fuites `e.message`, remplacer le parsing de messages par des erreurs typées (`CraErrors::*` existe déjà) | 🟠 | refactor guidé par specs existantes | audit grep : 0 `e.message` dans payload client ; 1 vocable/invariant | ⬜ |
| **S-5** | **Specs manquantes** : Update/Destroy CRA (unitaire), CompanyServices::Create, doublon CraEntry Update, nominal List | 🟠 | specs | 0 service métier sans spec unitaire ; verrou 72,5 inchangé ou relevé | ⬜ |
| **S-6** | **Dead code** : arbitrer CraMissionLinker (avec S-2) + ApmService (254 LOC) + `export_minimal_spec` + logs `[DEBUG]` + commentaires mensongers ; décision sur `MemoryBackend`-only (C-5 : brancher RedisBackend ou corriger les headers) | 🟠 | suppression/branchement | 0 service sans call-site non arbitré ; rate limiting distribué ou doc corrigée | ⬜ arbitrage CTO |
| **S-7** | **Conventions documentées** : 1 ADR « Service Layer Contract » (nomenclature sans suffixe, `.call` kwargs, ApplicationResult sémantique, transaction obligatoire pour >1 écriture, autorisation : modèle unique à décider, pas de `e.message` dans les payloads) + correction des headers mensongers + stubs namespace alignés | 🟢 | doc + comments | headers = réalité ; ADR revu | ⬜ |
| **S-8** | **Déduplication** (§5.6) : helpers partagés (`parse_date`, input-validation, rescue), expiration JWT unique, OAuth single-pipeline (transaction + anti-race dans OAuthConcern ou suppression du doublon) | 🟢 | refactor | 0 duplication identifiée restante | ⬜ |

**Règle de campagne applicable** (P6.0, rappel) : caractériser avant de corriger ; RED mesuré pour
tout changement de comportement ; pas de refactoring opportuniste ; S-2 et C-5 exigent un arbitrage
CTO (produit/ops), le reste est de l'exécution guidée par les specs existantes.

---

## 10. Références

- `app/lib/application_result.rb` — façade (lecture directe intégrale)
- `app/services/cra_services/{create,lifecycle}.rb` L243-276 / L146-199 — preuves C-1 et pattern correct
- `app/services/mission_services/create.rb` L305-336 — preuve C-2
- `app/controllers/api/v1/cra_entries_controller.rb` L268-291 — preuve C-4
- `app/services/cra_mission_linker.rb` + grep call-sites — preuve C-3
- Historique RAG : `technical/corrections/[DONE]_2026_01_11_FC07_Architecture_Services_Unified_Migration.md`, `2026_01_27_DDD_Audit_CRA_Tests_Migration.md`, tracker P6-Wave 3 (caractérisation services/lib), mémoire `fc08::009` (baseline couverture services)
- BACKLOG #19 (entrée pointant ce document)

---

**Document créé le :** 24 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Convention : plan S-1…S-8 suivi dans §9 ; préfixe `[DONE]_` à la clôture du plan.*