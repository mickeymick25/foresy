# Plan d'implémentation & Suivi — P6 Wave 3

**Date :** 20 septembre 2026
**Décision CTO :** GO Wave 3 (20/09) — ordre : W3-D1 `CraServices::List` + filtres → W3-D2 git ledger → W3-D3 services/lib + façades → W3-D4 modèles → réévaluation ; P6.6 différé
**Campagne :** `docs/technical/testing/2026_09_17_coverage_campaign_p6.md` (§4)
**Branche :** `feat/p6-wave3` — base : `main` @ `50c52649` (merge PR #39 — Wave 2, verrou **72,5** armé)
**Règle de campagne :** caractériser → mesurer → corriger uniquement si divergence réelle → mesurer → documenter — pas de chasse artificielle au pourcentage
**Classification par groupe (règle CTO) :** non couvert mais valide → caractérisation · code mort → suppression après preuve · incorrect → cycle RED · ambigu → arbitrage · vivant hors périmètre → dette explicitement reportée

---

## 1. Règles de la vague (P6.0, inchangées)

| Règle | Énoncé |
|---|---|
| Pas de tests artificiels | Caractérisation du comportement existant ; RED uniquement sur divergence démontrée |
| Bug découvert | Vrai cycle RED → correction → GREEN, décision CTO avant correction |
| Stabilité des specs | Évolution du compte justifiée au journal (les ajouts = périmètre de caractérisation) |
| Mesures | Projections non contractuelles — SimpleCov fait foi |
| Verrou | 72,5 armé (marge mesurée 77,83 → +5,33 pts au GO) |
| Hors périmètre | P1 · D3-3 · BACKLOG #13/#14/#15 · link-rot — jamais injectés dans la vague |

## 2. Cibles et état mesuré

| Cible | Avant (994/0) | Après (1065/0) |
|---|---|---|
| `app/services/cra_services/list.rb` | **24,62 %** (16/65) | **96,92 %** (63/65) — W3-D1 |
| `app/services/cra_services.rb` (façade) | 66,67 % (2/3) | 66,67 % — `service_available?` conservé (arbitrage) |
| `app/services/git_ledger_service.rb` | 77,78 % (35/45) | **100,00 %** (45/45) — W3-D2 |
| `app/services/git_ledger_repository.rb` | 76,29 % (74/97) | **95,88 %** (93/97) — W3-D2 (résidu défensif) |
| `app/services/git_ledger_payload.rb` | 90,91 % (10/11) | **100,00 %** (11/11) — W3-D2 |
| `app/services/rate_limit/redis_backend.rb` | 58,82 % (10/17) | **100,00 %** — W3-D3 |
| `app/services/rate_limit/backend.rb` | 62,50 % (5/8) | **100,00 %** — W3-D3 |
| `app/services/o_auth_user_service.rb` | 61,54 % (32/52) | **95,45 %** — W3-D3 (résidu rescue défensif) |
| `app/services/o_auth_token_service.rb` | 50,00 % (15/30) | **100,00 %** — 5 méthodes mortes supprimées (W3-D3) |
| `app/lib/cra_errors.rb` | 70,00 % (42/60) | **98,33 %** — W3-D3 (résidu : InternalError init) |
| `app/lib/application_result.rb` | 67,14 % (47/70) | conservé — helpers/factories documentés (dette cleanup dédiée) |
| `app/services/rate_limit_service.rb` | 84,29 % | 70,00 % (corpus ciblé) — 11 lignes cartographiées, partiellement caractérisées |

*(source : `coverage/.resultset.json` du run 994/0 puis runs ciblés conteneur — outils décrits au journal)*

## 3. Séquence validée

### W3-D1 — `CraServices::List` + filtres — ✅ CLOSED / GREEN (20/09, validation CTO)

**RED démontré puis corrigé :** `GET /api/v1/cras` = **500 en production** — `ApplicationResult.success` **sans le keyword `data:` obligatoire** (L77 filtres vides / L119 fin de `validate_filters`) → `ArgumentError: missing keyword: :data` → rescue externe → 500. Invisible depuis la migration unifiée du 11/01 : specs requête **stubbant** le service, `smoke_test.sh` sans `GET /cras`, 16 specs Mini-FC-01 disparues (ancien namespace).

**Correction (GO CTO, 2 lignes) :** `ApplicationResult.success(data: nil)` aux L77/L119 — le `data:` de la validation n'est jamais consommé.

**Gates :** suite **1013/0** · RuboCop 0 · Brakeman 0 · SimpleCov 79,09 % lignes / 50,50 % branches · `list.rb` **24,62 → 96,92 % (63/65)** (résidu = rescue externe défensif, accepté CTO).

**Specs ajoutées (19, `spec/services/cra_services/list_spec.rb` — nouveau) :** validations (missing_user, invalid_status, missing_year_for_month, invalid_month, invalid_year, invalid_currency), filtres AND (year / year+month / status / **currency** hors Mini-FC / **description ILIKE**), soft-delete jamais retourné, pagination (défaut **20** — divergence Mini-FC arbitrée, clamp 1..100, page min 1, hash complet), sécurité `accessible_to` (créateur oui, autre non), rescue `:query_failed`.

**Divergence per_page arbitrée :** doc Mini-FC-01 aligné sur le code (**25 → 20**) — `docs/technical/fc07/enhancements/[DONE]_2026_01_06_MINI-FC-01-CRA-Filtering.md` L31.

**Commits :** `895c1e3a` (RED + tracker) · `162c1f78` (fix + specs)

### W3-D2 — Git ledger — ✅ FAIT (20/09) — CLOSED / GREEN (validation CTO)

**Specs ajoutées (16 — `git_ledger_service_spec.rb` +12 · `git_ledger_payload_spec.rb` nouveau +4) :** gardes `validate_cra!` REAL ×2 (→ GitLedgerError chaîné) · **double lock idempotent** (même hash, delta de commits 0, warn loggé) · `get_existing_commit_info` (repo absent/vide → nil) · **échec git init → GitLedgerError** (LEDGER_PATH sur un chemin-fichier) · délégations ×5 (`repository_info` fetch_info / `info` {exists: false} / `valid?` git rev-parse / `ensure_ledger_repository!` / `cleanup!` force:) · **history_rewritten? fail-closed sur exception** · payload canonique (missions triées, entries mappées FC-07 + ordre (date, id), totals serveur, soft-delete exclu).

**Bilan (corpus ciblé conteneur) :** `git_ledger_service.rb` **100 %** · `git_ledger_repository.rb` **95,88 %** (résidu défensif : rescues `valid?`/`info` + `log_stderr`) · `git_ledger_payload.rb` **100 %**.

**Gates :** suite **1029/0** · RuboCop 0 · Brakeman 0 · SimpleCov 79,44 % lignes / 50,94 % branches.

**Commits :** `31184c10` (specs + journal)

### W3-D3 — services/lib + façades — ✅ FAIT (20/09) — reconnaissance + arbitrage + exécution

**Reconnaissance :** carte authoritative `app/` (76 fichiers) après rejeu de la suite complète (le corpus ciblé n'en reflétait que 23).

**Suppressions exécutées (arbitrage CTO — OAuth ciblé uniquement) :**
- `o_auth_token_service` — **5 méthodes supprimées** : `can_generate_token?`, `extract_user_info`, `generate_stateless_jwt_with_expiration`, `token_expiration_time`, `can_authenticate_oauth?` (zéro appelant) — `generate_stateless_jwt` + `format_success_response` conservés (100 % couverts)
- `o_auth_user_service` — **2 méthodes supprimées** : `valid_oauth_user_data?`, `find_existing_user`
- **Conserver + documenter** : `service_available?` ×3 (candidate suppression post-audit de contrat) · `application_result` helpers/factories (dette D3-3/cleanup dédiée)

**Specs ajoutées (36, suite 1013 → 1065) — chemins vivants :**
- `rate_limit_backends_spec.rb` (nouveau, 11) : **RedisBackend sur Redis réel du conteneur** (aucun stub réseau — connexion via `RateLimitService.redis` L59-63 naturelle) : incr/count, **purge sliding window**, clear · **Backend contrat abstrait NotImplementedError ×3** · `RateLimitService` : `current_count` injecté + **sémantique MemoryBackend par instance** (current_count de classe = 0 sur instance neuve) · `rate_limited_endpoint?` · `extract_endpoint` · **mask_ip branches (IPv4/IPv6/unknown)**
- `o_auth_user_service_spec.rb` (nouveau, 5) : **race condition retry** (trouvé / RecordNotFound) · **liaison par email + update_existing_oauth_user!** · **RecordInvalid re-raised** (uid manquant — la liaison par email absorbe le conflit email par design)
- `spec/lib/cra_errors_spec.rb` (nouveau — répertoire `spec/lib/` créé, 16) : **contrat de la taxonomie d'erreurs** (message/code/http_status par classe, to_h démodulisé en String, InvalidPayloadError.field, InvalidTransitionError ±statuts)
- `cra_entry_services/list_spec.rb` (nouveau, 1) : `missing_cra` bad_request (le rescue `list_failed` documenté défensif — pas de spec artificielle)

**Arbitrages exécutés conformes :** `service_available?` ×3 **conserver + documenter** (candidate suppression post-audit de contrat) · `application_result` **conserver + documenter** (dette D3-3/cleanup dédiée) · suppressions **uniquement OAuth ciblé** · rescues défensifs non spécifiés.

**Gates :** suite **1065/0** · RuboCop **0** · Brakeman **0** · **SimpleCov : 81,21 % lignes (3004/3699) · 52,36 % branches (820/1566)** — corpus −28 lignes (suppressions OAuth ciblées). Verrou 72,5 tenu.

**Bilan couverture cibles (corpus ciblé) :** backend 62,5 → **100 %** · redis_backend 58,82 → **100 %** · cra_errors 70 → **98,33 %** (résidu : init `InternalError` — à couvrir si jugé contrat) · o_auth_user 61,54 → **95,45 %** (résidu : rescue RecordNotUnique, défensif — retry direct caractérisé) · o_auth_token — fichier réduit aux 2 méthodes vivantes (**100 %**).

**Commit :** cette livraison.

### W3-D4 — modèles — ✅ FAIT (20/09) — 64 specs, invariants métier caractérisés

Cible : modèles sous 90 % du corpus complet (cra 78,74 %, mission 82,35 %, mission_company 82,76 %, user_company 81,82 %, company 81,54 %, cra_entry 87,27 %, pivots 88-90 %) — carte complète au journal (2) de cette vague.

## 4. Journal de suivi

### 2026-09-20 (7) — W3-D4 correction exécutée — blocker ISO3166 levé (REQUEST CHANGES PR #40 traité)

- **Revue CTO PR #40** : REQUEST CHANGES — 1 blocker (ISO3166), 1 warning documenté (validate_uniqueness), le reste 🟢 ; traçabilité Git 7 commits ✅, W3-D1→D3 ✅, W3-D4 caractérisation ✅
- **Blocker traité — Option A2 (correction minimale sans dépendance) :** `Company#country_name` dépendait de la gem `countries` **jamais déclarée** (Gemfile/Gemfile.lock : absent, historique complet ; introduite implicitement dans le commit de migration FC-06 `a460a860`) → `NameError` = 500 potentiel · **preuves :** zéro appelant production de `country_name`/`full_address` · zéro mention dans le contrat FC-08 · la gem absente du conteneur (`gem list` vide) → **correction minimale : `country_name` retourne le code stocké** (le fallback brut existait déjà dans le code) — la résolution ISO3166 exigerait de déclarer la dépendance explicitement (dette documentée au journal) · le spec RED (NameError) remplacé par un GREEN **fonctionnel**
- **Gates post-correction :** suite **1130/0** ✓ · RuboCop **0** ✓ · Brakeman **0** ✓ · **SimpleCov : 83,10 % lignes (3074/3699) · 54,86 % branches (858/1564)** — corpus −2 lignes (ISO3166 retiré) · verrou 72,5 tenu
- **BACKLOG #16 ajouté (WARNING CTO) :** `Cra#validate_uniqueness` inerte à la création (pivot créateur absent à la validation) — point d'architecture traité séparément
- **Suivant :** push → réévaluation CTO PR #40 (CI du commit final 6/6) → merge → sync + réindexation hub → clôture formelle Wave 3

### 2026-09-20 (6) — WAVE 3 clôture administrative (validation CTO) — PR feat/p6-wave3 prête

- **W3-D4 validée GREEN** (1129/0 · 83,07 % lignes / 54,78 % branches · RuboCop 0 · Brakeman 0) + **contrôle complémentaire git_ledger_service_spec.rb** : 17/0 · Syntax OK · **diff vs commit `31184c10` vide — zéro dérive accidentelle** ; occurrences `sc.send`/`sc.const_defined?` justifiées (remove_const privé, ordre aléatoire, restauration d'overlays, filesystem conteneur) — aucune simplification demandée
- **Bilan Wave 3 (validation CTO)** : W3-D1 list 24,62 → 96,92 % (bug 500 corrigé) · W3-D2 ledger service 100 % / repo 95,88 % / payload 100 % · W3-D3 chemins vivants + nettoyage OAuth (7 méthodes mortes supprimées, façades + application_result conservés documentés) · W3-D4 modèles caractérisés — **hausse 79,44 → 83,07 % obtenue par caractérisation de contrats vivants + suppression de code mort démontré + documentation des chemins défensifs, pas par chasse au pourcentage**
- **Résidus arbitrés :** cra_errors init `InternalError` (défensif tant que rien de distinct n'est identifié — micro-complément possible post-réévaluation si appelant réel) · o_auth_user rescue RecordNotUnique (garde défensif, 95,45 % accepté) · **clôture administrative** : campagne P6 mise à jour · PR au format maison · CI 6/6 · merge · sync · réindexation hub · clôture formelle
- **Pas de nouveau chantier technique avant la PR** — seuil de clôture atteint

### 2026-09-20 (5) — W3-D4 clôturée — modèles : 64 specs, gap métier résorbé — 1129/0 · 83,07 % / 54,78 %

- **Specs ajoutées (64, suite 1065 → 1129) — 4 fichiers nouveaux :**
  - `cra_contracts_spec.rb` (24) : **discard/undiscard** (draft ok, submitted/locked refusés) · modifiable? (draft/submitted ok, locked non) · display_name (« 2/2026 (Draft) ») · **modifiable_by?** (créateur oui, sans pivot non, nil non, locked non) · **can_transition_to? machine à états** (draft→submitted, submitted→locked, locked terminal) · transition_to! (valide/invalide) · submit! (garde + happy, totaux recalculés) · **lock! : garde + fake commit + ATOMICITÉ GitLedgerError** (GIT_LEDGER_REAL=true + LEDGER_PATH fichier → raise + **CRA reste unlocked** — rollback complet FC-07 PLATINUM) · currency hors ISO 4217 · doublon validate_uniqueness à la re-validation · enum hors contrat
  - `mission_contracts_spec.rb` (17) : discard/undiscard · active?/completed?/current? · time_based?/fixed_price? · display_name · duration_in_days (calcul inclusif / nil sans end_date) · **total_amount par type (daily_rate vs fixed_price)** · currency_symbol (EUR/USD/GBP/brut) · **exclusivité financière par type ×4** · enum hors contrat (ArgumentError setter) · notifications post-won
  - `company_contracts_spec.rb` (7) : with_role · utilisateurs/missions par rôle · active?/display_name · full_address/country_name · normalisations callbacks
  - `pivot_contracts_spec.rb` (nouveau, 12) : UserCra/UserMission (rôles, cra_creator/mission_creator, user_created_cras/missions) · CraMission display_link + **garde lien dupliqué** · CraEntryCra (lien entry↔CRA) · CraEntryMission (display_link/cra/entry_date + garde dupliqué) · **MissionCompany exclusivité independent/client** (rejets ×2 + tolérance non-exclusif)
- **Gates :** suite **1129/0** ✓ · RuboCop **0** (7 autocorrectées) ✓ · Brakeman **0** ✓ · **SimpleCov : 83,07 % lignes (3073/3699) · 54,78 % branches (858/1566)** — verrou 72,5 tenu
- **Découvertes de contrat (journal) :** validate_uniqueness **inerte à la création** (le pivot créateur n'existe pas à la validation — créé post-insert par la factory ; le garde ne s'exerce qu'à la re-validation/update) — comportement observé, documenté pour arbitrage CTO · set_default_status/currency fonctionnels · exclusivité mission_company câblée
- **Suivant :** réévaluation CTO D4 → réévaluation globale Wave 3 → mise à jour campagne → **PR au format maison** → CI 6/6 → clôture

### 2026-09-20 (4) — W3-D3 clôturée — suppressions OAuth ciblées + 36 specs chemins vivants — 1065/0

- **Suppressions exécutées (arbitrage CTO — OAuth ciblé uniquement) :** `o_auth_token_service` — **5 méthodes supprimées** (zéro appelant ; `generate_stateless_jwt` + `format_success_response` conservés, 100 % couverts) · `o_auth_user_service` — **2 méthodes supprimées** (`valid_oauth_user_data?`, `find_existing_user`) · **aucune suppression ailleurs** — `service_available?` ×3 et `application_result` helpers/factories **conserver + documenter** (candidates de suppression post-audit de contrat — dette cleanup dédiée)
- **Arbitrage supplémentaire validé :** builders `created`/`unprocessable_entity`/`forbidden`/`conflict`/`not_found` **VIVANTS** (services entry/mission/company — preuve grep) — pas du code mort, sortent du périmètre
- **Specs ajoutées (36) — chemins vivants :** cf. §3/W3-D3
- **Incidents de mécanique (transparents) :** CraEntry sans attribut `active` (soft delete = `deleted_at`) · entries en même date → `DuplicateEntryError` (invariant cra+mission+date) · modifier-if multi-ligne = SyntaxError · `remove_const` privé → `send` gardé (pattern D-12) · `/app/cra-ledger` existe dans le conteneur → overlays déterministes · cascade NameError des ensures non protégés → gardes `const_defined?` systématiques
- **Gates :** suite **1065/0** ✓ · RuboCop **0** (4+4 autocorrectées) ✓ · Brakeman **0** ✓ · **SimpleCov : 81,21 % lignes (3004/3699) · 52,36 % branches (820/1566)** — verrou 72,5 tenu
- **Bilan couverture cibles D3 (corpus ciblé) :** backend 62,5 → **100 %** · redis_backend 58,82 → **100 %** · cra_errors 70 → **98,33 %** (résidu : init `InternalError` — à trancher contrat/défensif à la réévaluation) · o_auth_user 61,54 → **95,45 %** (résidu : rescue RecordNotUnique, défensif — retry direct caractérisé)
- **Note outillage :** ledger/services invisibles au resultset hôte (volume coverage/ sans sync temps réel) — extractions depuis le resultset conteneur (outils temporaires racine supprimés après usage)
- **Suivant :** réévaluation CTO D3 → **W3-D4 modèles** → réévaluation globale → P6.6

### 2026-09-20 (3) — W3-D2 clôturée — ledger : service 100 %, repository 95,88 %, payload 100 % — 1029/0

- **Specs ajoutées (16, suite 1013 → 1029) :** `git_ledger_service_spec.rb` — 12 exemples W3-D2 (gardes validate_cra! REAL ×2 → GitLedgerError chaîné · **double lock idempotent** — handle_existing_commit : même hash, delta de commits 0, warn loggé · get_existing_commit_info ×2 (repo absent → nil, repo vide → nil) · **échec git init → GitLedgerError** (LEDGER_PATH sur un chemin-fichier) · délégations ×5 (repository_info fetch_info complet / info {exists: false} / valid? git rev-parse / ensure_ledger_repository! / cleanup! force:) · **history_rewritten? fail-closed sur exception** — Open3 levant → GitLedgerError) ; `git_ledger_payload_spec.rb` — **nouveau fichier, 4 exemples** (payload canonique contractuel, entries mappées + ordre (date, id), totals serveur, soft-delete exclu)
- **Bilan couverture ledger (corpus ciblé, extraction container) :** `git_ledger_service.rb` 77,78 % → **100,00 % (45/45)** · `git_ledger_repository.rb` 76,29 % → **95,88 % (93/97)** · `git_ledger_payload.rb` 90,91 % → **100,00 % (11/11)** — résidu repository = branches défensives documentées (rescue valid? L39, rescue info L61, log_stderr L191-193)
- **Incidents de mécanique (transparents) :** (a) `CraEntry` n'a pas d'attribut `active` — soft delete = `deleted_at` → `entry.destroy` ; (b) deux entries en même date → `DuplicateEntryError` (invariant cra+mission+date) → dates distinctes ; (c) modifier-if après saut de ligne = SyntaxError + `remove_const` privé → `send(:remove_const, ...)` gardé + gardes `const_defined?` pour l'ordre aléatoire ; (d) `/app/cra-ledger` existe comme répertoire dans le conteneur → `info` caractérisé sur overlay chemin absent
- **Gates :** suite **1029/0** ✓ · RuboCop **0** ✓ · Brakeman **0** ✓ · **SimpleCov : 79,44 % lignes (2961/3727) · 50,94 % branches (811/1592)** — verrou 72,5 tenu
- **Note :** le ledger est invisible au resultset hôte (volume coverage/ sans sync temps réel) — extraction depuis le resultset conteneur
- **Suivant :** réévaluation CTO D2 → **W3-D3 services/lib** → W3-D4 modèles

### 2026-09-20 (2) — W3-D1 clôturée — bug 500 corrigé (2 lignes), list 24,62 → 96,92 %, 1013/0

- **Arbitrages CTO exécutés** : (1) 🟢 correction minimale **2 lignes** — L77/L119 : `ApplicationResult.success(data: nil)` ; (2) 🔴 pas de refactor de List, pas de changement de contrat API, code per_page 20 **conservé** ; (3) 🟢 doc Mini-FC-01 : `per_page` défaut **25 → 20** ; (4) 🟢 `:query_failed` caractérisé — **déjà couvert** par l'exemple résilience
- **D1.2/D1.3 :** ciblé **19/0** (GREEN complet — le RED résolu) — le rescue interne `:query_failed` passe désormais (stub `Cra.accessible_to` levant StandardError, seul stub non-réseau)
- **Gates :** suite **1013/0** ✓ · RuboCop **0** ✓ · Brakeman **0** ✓ · **SimpleCov : 79,09 % lignes (2948/3727) · 50,50 % branches (804/1592)** — verrou 72,5 tenu · `cra_services/list.rb` **24,62 % → 96,92 % (63/65)**
- **Bug production fermé :** `GET /api/v1/cras` opérationnel (sans filtres ET avec filtres — year/month/status/currency/description ILIKE AND) · pagination (défaut 20, clamp 1..100, page min 1) · soft-delete jamais retourné · sécurité `accessible_to`
- **Divergence per_page 25↔20 : arbitrée** — doc alignée sur le code
- **Suivant :** réévaluation CTO D1 → **W3-D2 git ledger**

### 2026-09-20 (2) — W3-D1 : RED DÉMONTRÉ — bug production `GET /api/v1/cras` = 500 — arbitrage CTO requis

- **Cycle RED démontré (13/17 specs en échec — exactement le chemin fetch)** : toute invocation de `CraServices::List` avec filtres valides ou vides retourne `internal_error(:internal_error, "An unexpected error occurred while listing CRAs")`
- **Cause racine (preuves) :** `list.rb` L77/L119 — `ApplicationResult.success` **sans le keyword `data:` obligatoire** → `ArgumentError: missing keyword: :data` (reproduite hors-spec par rails runner) → rescue **externe** de `call` → `internal_error(:internal_error)` → **500 en production**
- **Portée production :** `GET /api/v1/cras` **sans filtres ET avec filtres valides** = 500 systématique — l'index CRA totalement inopérant (`CrasController#index` L63 appelle `CraServices::List.call(..., filters: extract_filters)`)
- **Pourquoi invisible depuis le 11/01 :** (a) specs requête **stubbant** `CraServices::List.call` ; (b) `smoke_test.sh` sans `GET /cras` ; (c) 16 specs Mini-FC-01 disparues à la migration (ancien namespace) → **zéro filet**
- **Proposition de correction minimale (soumise) :** 2 lignes — L77/L119 : `ApplicationResult.success(data: nil)`
- **6/17 specs vertes d'emblée** : les validations de filtres (pré-fetch)
- **Découvertes additionnelles (reconnaissance) :** les 16 specs Mini-FC-01 disparues · `per_page` défaut réel **20** vs Mini-FC 25 · filtres `currency` + `description` ILIKE au-delà du Mini-FC

### 2026-09-20 — GO Wave 3 + reconnaissance W3-D1

- **Contrat de routage respecté :** requêtes hub `foresy__knowledge` (CraServices::List, Mini-FC-01) — sources : `technical/fc07/enhancements/[DONE]_2026_01_06_MINI-FC-01-CRA-Filtering.md`, `technical/fc07/enhancements/2026_01_06_FC07-Future-Enhancements.md` ; puis lectures locales complémentaires
- **Découvertes :** aucun spec unitaire List · specs requête stubbent le service · specs Mini-FC-01 disparues · divergence per_page · filtres currency/description au-delà du Mini-FC
- **Suivant :** specs de caractérisation

## 5. Critères de sortie de vague

- [x] W3-D1 ✅ · W3-D2 ✅ · W3-D3 ✅ (cette livraison)
- [ ] W3-D4 modèles : à exécuter
- [ ] Divergences détectées : journalisées + arbitrées CTO
- [ ] Code mort démontré : suppressions après preuve (OAuth exécuté ; service_available?/application_result = documentés, arbitrage post-audit)
- [ ] Journal complet + campagne à jour (à finaliser à la clôture)
- [ ] PR Wave 3 au format maison — CI 6/6 = clôture
- [ ] P6.6 : arbitrage post-Wave 3 sur mesure représentative

## 6. Références

- Campagne : `docs/technical/testing/2026_09_17_coverage_campaign_p6.md` · Trackers : `2026_09_20_p6_wave2_tracker.md` · `[DONE]_2026_09_18_p6_wave1_tracker.md`
- Mini-FC-01 (contrat figé, per_page aligné) : `docs/technical/fc07/enhancements/[DONE]_2026_01_06_MINI-FC-01-CRA-Filtering.md`
- Sécurité (scope) : `spec/models/cra_access_spec.rb` (W1-D2) · Contrat : `app/lib/application_result.rb`
- Mémoire : `fc08::011` (amendement 20/09 — continuité P6) · Registre dette : `docs/technical/2026_09_14_fc08_debt_register.md` (D-12)