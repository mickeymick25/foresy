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
### W3-D3 — services/lib (prévu, non démarré)
### W3-D4 — modèles (prévu, non démarré)

## 5. Journal de suivi

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