# Plan d'implémentation & Suivi — P6 Wave 3

**Date :** 20 septembre 2026
**Décision CTO :** GO Wave 3 (20/09) — ordre : W3-D1 `CraServices::List` + filtres → W3-D2 git ledger → W3-D3 services/lib → W3-D4 modèles → réévaluation ; P6.6 différé
**Campagne :** `docs/technical/testing/2026_09_17_coverage_campaign_p6.md` (§4)
**Branche :** `feat/p6-wave3` (à créer) — base : `main` @ `50c52649` (merge PR #39 — Wave 2, verrou **72,5** armé)
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

## 2. Cibles et état mesuré (corpus conteneur, suite 994/0 du 20/09)

| Cible | Lignes utiles / couvertes | Taux |
|---|---|---|
| `app/services/cra_services/list.rb` | 65 utiles / 16 couvertes | **24,62 %** — pire fichier du namespace |
| `app/services/cra_services.rb` (façade) | 3 / 2 | 66,67 % |
| `app/services/cra_services/create.rb` | 98 / 80 | 81,63 % |
| `app/services/cra_services/update.rb` | 105 / 75 | 71,43 % |
| `app/services/cra_services/destroy.rb` | 50 / 41 | 82,00 % |
| `app/services/cra_services/lifecycle.rb` | 57 / 48 | 84,21 % |
| `app/services/cra_services/export.rb` | 66 / 63 | 95,45 % |

*(source : `coverage/.resultset.json` du run 994/0 — extraction `tmp/cov_extract.rb`)*

## 3. Reconnaissance W3-D1 — découvertes structurantes (20/09)

1. **`CraServices::List` n'a AUCUN spec unitaire** — grep exhaustif `spec/` : aucune référence de test directe ; les specs requête `index_spec.rb` et `deprecation_headers_integration_spec.rb` **stubbent** le service (« Stub CraServices::List to avoid domain setup issues »)
2. **Les 16 specs Mini-FC-01 (filtrage) ont disparu** — le Mini-FC documentait `spec/services/api/v1/cras/list_service_filtering_spec.rb` (ancien namespace `Api::V1::Cras::ListService`, pré-migration unifiée du 11/01) ; ce fichier n'existe plus et rien ne le remplace : **le contrat de filtrage Mini-FC-01 est aujourd'hui sans filet** (grep des erreurs de validation `invalid_status_filter`/`missing_year_for_month`/`invalid_currency_filter` : 0 match)
3. **Divergence Mini-FC-01 ↔ code détectée** : le Mini-FC fige « `per_page` défaut : 25 » ; le code fait `per_page&.to_i || 20` → **défaut réel 20** — arbitrage CTO requis (doc alignée sur l'implémentation, pattern W1-D3)
4. **Filtres au-delà du Mini-FC-01** : `currency` (validation ISO 4217 `\A[A-Z]{3}\z`) et `description` (ILIKE insensible à la casse — paramétré, wildcards `%`/`_` non échappés : observation, pas d'injection SQL) — le contrat réel dépasse le contrat documenté
5. Chaîne d'appel : `CrasController#index` → `CraServices::List.call` → `ApplicationResult` (`success?/failure?/status/data/error/message` — `app/lib/application_result.rb`) ; base query = `Cra.accessible_to(user).active` + includes + `order(year: :desc, month: :desc)` (sécurité = scope W1-D2, déjà caractérisé)
6. Résidus défensifs : 2 blocs `rescue StandardError → internal_error` (L62-67 call — quasi-inojoignable car `fetch_cras` internalise déjà son rescue ; L144-150 `:query_failed` — joignable par levée d'exception)

## 4. Séquence validée (proposée au GO CTO)

### W3-D1 — `CraServices::List` + filtres — ✅ reconnaissance FAIT (20/09) · 🔴 RED démontré (bug production) — correction en attente d'arbitrage CTO

**Périmètre :** validation des filtres (missing_user, invalid_status, missing_year_for_month, invalid_month, invalid_year, invalid_currency), application AND (year / year+month / status / currency / description ILIKE), soft-delete jamais retourné, pagination (défaut 20 — divergence Mini-FC, clamp 1..100, page min 1, hash {total, page, per_page, pages, prev, next}), sécurité accessible_to (créateur voit les siens, autrui ne voit rien), rescue `:query_failed`.

**Gates :** suite verte (compte documenté), RuboCop 0, Brakeman 0, SimpleCov réel au journal. **Verrou 72,5 inchangé** (la vague vise le palier 90 à P6.6, pas de relèvement intermédiaire sans arbitrage).

**Commit :** `test(p6): characterize CraServices::List filters and pagination`

### W3-D2 — Git ledger (prévu, non démarré)
### W3-D3 — services/lib + façades — ✅ reconnaissance FAIT (20/09) — dossier d'arbitrage CTO (code mort) + specs de chemins vivants en attente de GO
### W3-D4 — modèles (prévu, non démarré)

### 2026-09-20 (2) — W3-D3 reconnaissance — carte complète app/ (76 fichiers) + classement vivant/mort

- **Méthode :** suite complète rejouée pour régénérer le resultset (le corpus ciblé ne reflétait que 23 fichiers) → carte authoritative `app/` (76 fichiers) via outil temporaire racine (supprimé après) · grep d'appelants pour chaque méthode suspecte
- **Périmètre W3-D3 (services + lib) — hors contrôleurs/concerns (dette D3-3) et modèles (W3-D4)**
- **Classification VIVANT (specs de caractérisation en attente de GO) :**
  - `RateLimit::RedisBackend` 58,82 % — **incrément/count/clear ZSET sliding window (FC-05)** : Redis réel du conteneur (stub sur la lecture `redis` privée seulement) · `RateLimit::Backend` L22/31/39 : **contrat abstrait NotImplementedError** ×3
  - `o_auth_user_service` 61,54 % : **race condition retry** (retry_find_after_race_condition direct : trouvé / RecordNotFound) · **link par email** (find_by_email_and_link_provider + update_existing_oauth_user!) · **RecordInvalid** re-raised (email déjà pris par un autre uid du même provider) — chemins vivants réels
  - `cra_entry_services/list.rb` 76,92 % — L27 : `missing_cra` (bad_request naturel) · L41-42 : rescue `list_failed` (défensif)
  - `rate_limit_service.rb` 84,29 % — 11 lignes à cartographier à la lecture (L59, 122, 131-132, 164-165, 173, 241-245)
  - `lib/cra_errors.rb` 70 % — **18 lignes = initialisateurs/default_message de classes d'erreur du domaine** (CraLockedError L48, CraSubmittedError L59, InvalidTransitionError L70-75, InvalidPayloadError L84-85, to_h L26-36, CraNotFoundError L122, etc.) — **caractérisation du contrat de la taxonomie d'erreurs** (initialize + to_h par classe) — pas du code mort, des contrats non exercés
- **Dossier d'arbitrage — code mort (preuve : grep d'appelants = 0 dans app/spec/bin) :**
  1. **façades `service_available?` ×3** (cra_services L23, mission_services L27, company_services L33) — stubs anti-EmptyClass jamais appelés — suppression OU conservation documentée (au choix CTO)
  2. **o_auth_token_service** — 5 méthodes sans appelant : `can_generate_token?` (L46-52), `extract_user_info` (L55-62), `generate_stateless_jwt_with_expiration` (L65-75), `token_expiration_time` (L78-80), `can_authenticate_oauth?` (L83-91) — suppression OU caractérisation si jugées contrat
  3. **o_auth_user_service** — `valid_oauth_user_data?` (L106-113), `find_existing_user` (L116-118) — zéro appelant
  4. **application_result** — helpers « for controllers » sans appelant : `value`/`value!` (L37-44), `items`/`item`/`cra`/`total_count`/`pagination`/`totals` (L48-70) + factory compat **`success_entry`/`success_entries`/`success_cra`/`success_cras`** (L151-172) + `no_content` (L97) + `unauthorized` (L124 — non utilisé par les services ; les contrôleurs passent par StandardizedError)
- **Correction importante vs hypothèse initiale :** les builders `created`/`unprocessable_entity`/`forbidden`/`conflict`/`not_found` sont **VIVANTS** (services entry/mission/company — preuve grep) — pas du code mort ; leur non-couverture ne figure pas dans les lignes relevées sauf branches précises
- **Aucune spec écrite, aucune suppression effectuée** — arbitrage CTO attendu avant d'écrire (pattern G1/G2 : arbitrage du mort avant l'exécution)

### 2026-09-20 (2) — W3-D2 clôturée — ledger : service 100 %, repository 95,88 %, payload 100 % — 1029/0

- **Specs ajoutées (16, suite 1013 → 1029) :** `git_ledger_service_spec.rb` — 12 exemples W3-D2 (gardes validate_cra! REAL ×2 → GitLedgerError chaîné · **double lock idempotent** — handle_existing_commit : même hash, delta de commits 0, warn loggé · get_existing_commit_info ×2 (repo absent → nil, repo vide → nil) · **échec git init → GitLedgerError** (LEDGER_PATH sur un chemin-fichier) · délégations ×5 (repository_info fetch_info complet / info {exists: false} / valid? git rev-parse / ensure_ledger_repository! / cleanup! force:) · **history_rewritten? fail-closed sur exception** — Open3 levant → GitLedgerError) ; `git_ledger_payload_spec.rb` — **nouveau fichier, 4 exemples** (payload canonique contractuel, entries mappées + ordre (date, id), totals serveur, soft-delete exclu)
- **Bilan couverture ledger (corpus ciblé, extraction container) :** `git_ledger_service.rb` 77,78 % → **100,00 % (45/45)** · `git_ledger_repository.rb` 76,29 % → **95,88 % (93/97)** · `git_ledger_payload.rb` 90,91 % → **100,00 % (11/11)** — résidu repository = branches défensives documentées (rescue valid? L39, rescue info L61, log_stderr L191-193 — non naturelles sans stub Open3 artificiel)
- **Incidents de mécanique (transparents, 3 cycles d itération) :** (a) `CraEntry` n'a pas d'attribut `active` — le soft delete est `deleted_at` (scope `.active`) → `entry.destroy` ; (b) mes deux entries partageaient la même date → `DuplicateEntryError` (invariant cra+mission+date) → dates distinctes ; (c) modifier-if après saut de ligne = SyntaxError + `remove_const` privé → `send(:remove_const, ...)` gardé (pattern D-12) + gardes `const_defined?` pour l'ordre aléatoire ; (d) `/app/cra-ledger` existe comme répertoire dans le conteneur → `info` caractérisé sur overlay chemin absent
- **Gates :** suite **1029/0** ✓ · RuboCop **0** (6 autocorrectées) ✓ · Brakeman **0** ✓ · **SimpleCov : 79,44 % lignes (2961/3727) · 50,94 % branches (811/1592)** — verrou 72,5 tenu
- **Note :** le ledger est invisible au resultset hôte (volume coverage/ non sync en temps réel) — l'extraction se fait depuis le resultset conteneur (outil racine `cov_ledger_tmp.rb`, à supprimer)
- **Suivant :** réévaluation CTO D2 → **W3-D3 services/lib** → W3-D4 modèles → réévaluation globale → P6.6

### 2026-09-20 (3) — W3-D1 clôturée — bug 500 corrigé (2 lignes), list 24,62 → 96,92 %, 1013/0

- **Arbitrages CTO exécutés** : (1) 🟢 correction minimale **2 lignes** — L77/L119 : `ApplicationResult.success(data: nil)` (le `data:` de la validation n'est jamais consommé) ; (2) 🔴 pas de refactor de List, pas de changement de contrat API, code per_page 20 **conservé** ; (3) 🟢 doc Mini-FC-01 : `per_page` défaut **25 → 20** (aligné implémentation, seule correction du contrat) ; (4) 🟢 `:query_failed` caractérisé — **déjà couvert** par l'exemple résilience du spec (pas d'ajout nécessaire)
- **D1.2/D1.3 :** ciblé **19/0** ( GREEN complet — le RED du 20/09 (2) résolu) — le rescue interne `:query_failed` passe désormais (stub `Cra.accessible_to` levant StandardError, seul stub non-réseau)
- **Gates :** suite **1013/0** (994 + 19) ✓ · RuboCop **0** (1 offense autocorrectée) ✓ · Brakeman **0** ✓ · **SimpleCov : 79,09 % lignes (2948/3727) · 50,50 % branches (804/1592)** — verrou 72,5 tenu · `cra_services/list.rb` **24,62 % → 96,92 % (63/65)** (résidu : rescue externe quasi-inojoignable, documenté défensif)
- **Bug production fermé :** `GET /api/v1/cras` opérationnel (sans filtres ET avec filtres — year/month/status/currency/description ILIKE AND) · pagination (défaut 20, clamp 1..100, page min 1) · soft-delete jamais retourné · sécurité `accessible_to` (créateur oui, autre non) — le tout désormais caractérisé
- **Divergence per_page 25↔20 : arbitrée** — doc alignée sur le code (arbitrage CTO : aucune preuve que 25 est une intention produit encore valide ; un changement 20→25 serait une correction distincte avec RED explicite)
- **Commits :** `test(p6): W3-D1 caractérisation` (`895c1e3a` — RED + tracker) · `fix(p6): ... corrigé` (cette livraison) — branche `feat/p6-wave3`
- **Suivant :** réévaluation CTO D1 → **W3-D2 git ledger** → W3-D3 services/lib → W3-D4 modèles → réévaluation globale → P6.6

### 2026-09-20 (2) — W3-D1 : RED DÉMONTRÉ — bug production `GET /api/v1/cras` = 500 — arbitrage CTO requis

- **Cycle RED démontré (13/17 specs en échec au premier run — exactement le chemin fetch)** : toute invocation de `CraServices::List` avec filtres valides ou vides retourne `internal_error(:internal_error, "An unexpected error occurred while listing CRAs")` au lieu du listing
- **Cause racine identifiée (preuves) :** `list.rb` **L77** (`return ApplicationResult.success if filters.empty?`) et **L119** (`return ApplicationResult.success` — fin de `validate_filters`) appellent `ApplicationResult.success` **sans le keyword `data:` obligatoire** (`def self.success(data:, message: nil, meta: {})`) → `ArgumentError: missing keyword: :data` (reproduite hors-spec par rails runner) → rescue **externe** de `call` (L62) → `internal_error(:internal_error)` → **500 en production**
- **Portée production :** `GET /api/v1/cras` **sans filtres** → `filters: {}` → L77 → **500 systématique** ; **avec filtres valides** → L119 → **500** — l'index CRA est totalement inopérant. `CrasController#index` (L63) appelle bien `CraServices::List.call(..., filters: extract_filters)`
- **Pourquoi invisible depuis la migration du 11/01 :** (a) les specs requête `index_spec.rb`/`deprecation_headers_integration_spec.rb` **stubbent** `CraServices::List.call` ; (b) `bin/e2e/smoke_test.sh` ne teste pas `GET /cras` (grep vide) ; (c) les 16 specs Mini-FC-01 ciblaient l'ancien namespace et ont disparu → **zéro filet**
- **Proposition de correction minimale (arbitrage CTO attendu — aucune modification sans GO) :** 2 lignes — L77 et L119 : `return ApplicationResult.success(data: nil)` (le data de la validation n'est jamais consommé : L47 ne lit que `failure?`, le contenu vient de `fetch_cras`) — pas de refactor, pas de changement de contrat
- **Impact attendu post-correction :** les 13 specs RED passent au GREEN (elles caractérisent le contrat correct) ; le rescue interne `:query_failed` (L144-150) devient joignable et sera caractérisé ; **le bug de 500 sur l'index disparaît**
- **6/17 specs vertes d'emblée** : les validations de filtres (missing_user, invalid_status, month sans year, month 13, year 1999, currency EURO) — elles précèdent `fetch_cras` et ne traversent pas les chemins cassés
- **Aucune modification production effectuée** — en attente de l'arbitrage CTO (pattern W1-D2-BUG : arbitrage avant correction)

### 2026-09-20 — GO Wave 3 + reconnaissance W3-D1

- **Contrat de routage respecté :** requêtes hub `foresy__knowledge` (CraServices::List, Mini-FC-01) — sources : `technical/fc07/enhancements/[DONE]_2026_01_06_MINI-FC-01-CRA-Filtering.md` (règles figées : month sans year → 422, status invalide → 422, AND, soft-delete jamais retourné, per_page défaut 25), `technical/fc07/enhancements/2026_01_06_FC07-Future-Enhancements.md` ; puis lectures locales complémentaires
- **Lectures locales :** `app/services/cra_services/list.rb` (200 lignes — 6 validations, 5 filtres, Pagy, 2 rescues) · `app/lib/application_result.rb` (contrat `success?/failure?/status/data/error/message`) · greps specs · mesure fraîche `coverage/.resultset.json` (994/0 du 20/09)
- **Découvertes (§3)** : aucun spec unitaire List · specs Mini-FC-01 disparues à la migration 11/01 · divergence per_page 25→20 · filtres currency + description au-delà du Mini-FC · specs requête stubbent le service
- **Suivant :** specs de caractérisation `spec/services/cra_services/list_spec.rb` (17 exemples prévus) — puis gates

## 6. Critères de sortie de vague

- [ ] W3-D1 → W3-D4 : chaque étape validée (suite verte, RuboCop 0, Brakeman 0, mesure réelle au journal)
- [ ] Divergences détectées : journalisées + arbitrées CTO
- [ ] Code mort démontré : suppression après preuve (arbitrage)
- [ ] Journal complet + campagne à jour
- [ ] PR Wave 3 au format maison — CI 6/6 = clôture
- [ ] P6.6 : arbitrage post-Wave 3 sur mesure représentative

## 7. Références

- Campagne : `docs/technical/testing/2026_09_17_coverage_campaign_p6.md` · Tracker Wave 2 : `docs/technical/testing/2026_09_20_p6_wave2_tracker.md`
- Mini-FC-01 (contrat figé) : `docs/technical/fc07/enhancements/[DONE]_2026_01_06_MINI-FC-01-CRA-Filtering.md`
- Sécurité (scope) : `spec/models/cra_access_spec.rb` (W1-D2) · Contrat : `app/lib/application_result.rb`
- Mémoire : `fc08::011` (amendement 20/09 — continuité P6)