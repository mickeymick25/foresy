# Plan d'implémentation & Suivi — P6 Wave 4

**Date :** 21 septembre 2026
**Décision CTO :** GO Wave 4 (20/09) — A + C combinés (P6.6 Assessment §9) — couche contrôleur D3-3 élargi + exclusions formalisées · 90 % = objectif de validation, pas promesse préalable
**Campagne :** `docs/technical/testing/2026_09_17_coverage_campaign_p6.md` (§4)
**Assessment de référence :** `docs/technical/testing/2026_09_21_p6_6_assessment.md` (§5-§9)
**Branche :** `feat/p6-wave4` — base : `main` @ `09466953` (clôture formelle Wave 3, verrou 72,5)

---

## 1. Règles de la vague (P6.0 + contrat Wave 4 CTO)

| Règle | Énoncé |
|---|---|
| Pas de spec artificielle | Caractérisation des chemins réellement joignables ; pas de chasse au pourcentage |
| RED → correction → GREEN | Comme Waves 2/3 |
| Gain fonctionnel | Chaque sous-étape produit un gain fonctionnel identifiable |
| Mesure SimpleCov | Après chaque sous-étape |
| Pas de refactor | Aucun refactoring opportuniste |
| Dettes hors périmètre | D3-3/P1/BACKLOG #13-#16/link-rot — sauf si une spec les rencontre naturellement |
| 90 % = objectif mesuré | Pas une promesse préalable — si la couverture plafonne sous 90 % pour des raisons structurelles documentées, on clôture avec cette justification quantitative |
| Exclusions formalisées | apm_service (infrastructure/outillage) · rescues défensifs (~40 lignes) · façades `service_available?` |

## 2. Cibles et état mesuré

| Cible | Non couvert | Nature |
|---|---|---|
| `controllers/api/v1/cra_entries_controller.rb` | 52 | couches `rescue_from` (L192-249 — **injoignables**), blocs `rescue StandardError`, branches `handle_service_error`, guards `set_cra`/`set_cra_entry` |
| `controllers/api/v1/cras_controller.rb` | 24 | index en échec, `render_result_error` ×6, `handle_cra_error` case ×9+fallback |
| `controllers/api/v1/missions_controller.rb` | 13 | branches restantes |
| `controllers/api/v1/companies_controller.rb` | 6 | branches restantes |
| `controllers/api/v1/user_companies_controller.rb` | 4 | branches restantes |
| `controllers/concerns/*` (extractors, formatter, rate_limitable ×3, o_auth_concern, standardized_error, authentication_*) | ~340 | couches extraction/rendu/erreurs/monitoring |
| `services/cra_services/update.rb` | 30 | branches de mise à jour |
| `services/apm_service.rb` | 17 | infrastructure Datadog — **candidat exclusion** |
| résidus models/lib | ~33 | post-W3-D4 (défensifs + contrats) |
| **TOTAL résidu** | **~625** | |

## 3. Séquence validée

### W4-D1 — contrôleurs CRA / CraEntries — ✅ FAIT (21/09)

**Specs ajoutées (8, `spec/requests/api/v1/cras/cra_error_handlers_spec.rb` — nouveau, suite 1129 → 1138) :**
- **CraEntriesController — 5 blocs `rescue StandardError`** (create, index, show, update, destroy) : exception hors-CraErrors → 500 + log_api_error
- **CraEntriesController — handle_service_error (L271-291)** : 13 clés d'erreur mappées vers leur statut HTTP
- **CrasController — index en échec** (L75-76) : le message du résultat est rendu tel quel (la clé `:invalid_payload` est passée au lieu du message humain)
- **CrasController — render_result_error** (L174-189) : 6 statuts de résultat mappés vers le rendu standardisé

**Découverte structurelle :** les handlers `rescue_from CraErrors::*` (L197-249 de cra_entries_controller) sont **injoignables via le flow normal** — chaque action a un `rescue StandardError` inline qui attrape tout avant le rescue_from. Ils sont **documentés comme défensifs** (pas de spec artificielle pour les traverser).

**Gates :** suite **1138/0** ✓ · RuboCop **0** ✓ · Brakeman **0** ✓ · **SimpleCov : 83,83 % lignes (3101/3699) · 56,52 % branches (884/1564)**.

**Commits :** `6c31c00c` (specs + tracker)

### W4-D2 — concerns (hybride B + C) — ✅ FAIT (21/09)

**B — harness `Class.new(ActionController::Base)` (9 specs, `concerns_common_spec.rb`) :**
- `Common::ParameterExtractor` : extract_pagination_params (bornes page/per_page), extract_sort_params (default + asc/desc), extract_date_range_params (parse valides/invalides + range_valid?), extract_filter_params (filtre autorisés + hash vide), extract_search_params (strip/nil)
- le harness a `helper_method`, `params`, `request` gratuits — pas de route, pas de cycle HTTP

**C — request specs via les contrôleurs réels (3 specs, `cra_response_formatter_spec.rb`) :**
- `ResponseFormatter.single/collection` exercés via CraEntriesController (create 201, index 200)
- `StandardizedError.error_internal` : le message est exposé en test (Rails.env.test?), masqué en production

**Gates :** ciblé **12/0** ✓ · suite **1130/0** ✓ · RuboCop **0** ✓ · Brakeman **0** ✓

### W4-D3 — résidu + mesure finale (prévu, non démarré)
### P6.6 final (prévu, non démarré)

## 4. Journal de suivi

### 2026-09-21 (4) — P6.6 CLOSED — arbitrage CTO : pas de Wave 4.5 maintenant

- **Arbitrage CTO** : P6.6 **CLOSED** — 84,21 % lignes / 57,41 % branches · **90 % NON ATTEINT et NON REQUIS** comme condition de clôture · le question est maintenant "90 % apporte-t-il suffisamment de valeur pour justifier 30-40 specs ?" — **la réponse est non, sans mesure incrémentale démontrant la valeur**
- **Résidu contrôleur (~280 lignes)** : non homogène (contrôleurs + concerns + authentication + OAuth + transversaux) — ne pas déduire que 280 résiduelles = 214 facilement récupérables = 90 % garanti · l'estimation "30-40 specs pour 90 %" reste une **estimation, pas un objectif contractuel**
- **Décision : P6.6 CLOSED · Wave 4.5 non lancée · la dette contrôleurs/concerns est enregistrée séparément (~280 lignes, ~30-40 specs estimées) · le prochain chantier Foresy sera tranché sur la base de la valeur produit/risque, et non mécaniquement sur SimpleCov**

### 2026-09-21 (3) — W4-D3 clôturée — mesure finale Wave 4 : 1150/0 · 84,21 % lignes / 57,41 % branches

- **Mesure finale (corpus complet, résultat du run intégral) :** suite **1150/0** · SimpleCov **84,21 % lignes (3115/3699) · 57,41 % branches (898/1564)** — verrou 72,5 tenu · arbre propre (artefact rspec.xml non tracké)
- **Comparaison avec le diagnostic P6.6 initial (83,10 % / 54,86 %) :**
  - **Gain W4-D1** : +0,73 pt lignes, +1,66 pt branches (8 specs contrôleurs CRA/CraEntries)
  - **Gain W4-D2** : +0,11 pt lignes, +0,35 pt branches (12 specs concerns — le corpus chargé ne change pas car les specs sont additives sur le corpus déjà chargé)
  - **Gain total Wave 4 : +1,11 pt lignes (83,10 → 84,21) · +2,55 pt branches (54,86 → 57,41)**
- **Résidu post-D3 (625 → ~584 lignes non couvertes) — reclassification :**
  - **Défensif (documenté, non testable naturellement) :** ~40 lignes (rescues défensifs contrôleurs + git_ledger_repository L39/61/191-193 + cra_errors L188 InternalError init + cra L309-311 + mission L309/314)
  - **Contrôleur (dette D3-3 — résidu pertinent, non exclu) :** ~280 lignes (cra_entries_controller 52, cras_controller 24, missions_controller 13, companies_controller 6, user_companies_controller 4, oauth_controller 2, authentication_controller 1, concerns parameter_extractors ×3 ~90, response_formatter ×2 ~24, rate_limitable ×3 ~35, standardized_error 13, authentication_metrics/logging 16, api/deprecation 5, o_auth_concern 35, cra_entry/response_formatter 1)
  - **Infrastructure (exclusion formalisée) :** apm_service ~17 lignes (Datadog telemetry)
  - **Tooling/façades (conservées) :** 3 (service_available? ×3)
  - **Contrats lib résiduels (application_result) :** 23 (helpers/factories conservés — dette cleanup dédiée)
- **Analyse du palier 90 % :**
  - Cible 90 % = 3329 lignes → **il manque +214 lignes** (de 3115 à 3329)
  - Le résidu contrôleur (~280 lignes) est supérieur à 214 → **90 % est théoriquement atteignable** en caractérisant la couche contrôleur
  - MAIS le gain par exemple est dégressif (~0,02 pt/spec) et la densité varie selon les fichiers
  - **Coût estimé pour franchir 90 % : ~30-40 specs supplémentaires** (Wave 4.5)
  - Le gain marginal par spec décroît : les chemins restants sont de plus en plus défensifs
- **Découvertes additionnelles (W4-D3) :** `cra_entry_services/list` L41-42 (rescue défensif — caractérisé au ciblé W3-D1) · les models cra/mission sont maintenant à 96/98 % (résidu post-W3-D4 caractérisé)
- **Clôture recommandée (arbitrage CTO attendu) :**
  - La caractérisation du résidu pertinent (modèles + services + façades + controllers) est **complète**
  - Le plafond réel est ~84-85 % sans la couche contrôleur — le 90 % exige la Wave 4 (contrôleur + concerns)
  - **Recommandation :** clôturer P6.6 avec le plafond documenté ET enregistrer la Wave 4 (contrôleur + concerns) comme chantier de couverture distinct, chiffré et arbitrable

### 2026-09-21 (2) — W4-D2 clôturée — concerns caractérisés (hybride B + C) — 12/0 ciblé

- **Arbitrage CTO exécuté :** approche hybride B + C (pas de anonymous controller + override set_json_content_type — l'override modifierait le mécanisme testé)
- **B — harness `Class.new(ActionController::Base)` (9 specs, `concerns_common_spec.rb`) :**
  - `Common::ParameterExtractor` : extract_pagination_params (bornes page/per_page), extract_sort_params (default + asc/desc), extract_date_range_params (parse valides/invalides + range_valid?), extract_filter_params (filtre autorisés + hash vide), extract_search_params (strip/nil)
  - le harness a `helper_method`, `params`, `request` gratuits — pas de route, pas de cycle HTTP
  - 9/0 ✓
- **C — request specs via les contrôleurs réels (3 specs, `cra_response_formatter_spec.rb`) :**
  - `ResponseFormatter.single/collection` exercés via CraEntriesController (create 201, index 200)
  - `StandardizedError.error_internal` : le message est exposé en test (Rails.env.test?), masqué en production
  - 3/0 ✓
- **Gates :** ciblé **12/0** ✓ · suite **1130/0** ✓ · RuboCop **0** ✓ · Brakeman **0** ✓
- **Découverte structurelle (W4-D2) :** les concerns sont des **mixins de contrôleur Rails**, pas des services PORO — le contexte Rails fait partie du contrat d'exécution ; l'approche hybride B + C est le seul moyen de les caractériser fidèlement
- **Suivant :** réévaluation CTO D2 → **W4-D3 résidu + mesure finale** → P6.6 final → PR

### 2026-09-21 — GO Wave 4 + reconnaissance W4-D1

- **Contrat de routage respecté :** requêtes hub `foresy__knowledge` (P6.6, campagne §1) — sources : campagne, D-2 tracker · puis lectures locales complémentaires
- **Découvertes structurantes (reconnaissance) :**
  - les handlers `rescue_from CraErrors::*` de cra_entries_controller sont injoignables via le flow normal (inline `rescue StandardError` précède le rescue_from)
  - le message du résultat est rendu tel quel (la clé `:invalid_payload` est passée au lieu du message humain — divergence mineure, caractérisée)
  - `render_result_error` a 6 branches de statut mappées (conflict/forbidden/not_found/bad_request/internal_server_error/unprocessable_entity)
  - `handle_service_error` a 13 clés d'erreur mappées (422/409/404/403/500)
- **Suivant :** specs W4-D1 (écrites) → gates → commit → W4-D2

## 5. Critères de sortie de vague

- [x] W4-D1 ✅ · W4-D2 ✅ · W4-D3 ✅ (mesure finale 1150/0 · 84,21 % lignes / 57,41 % branches)
- [x] Exclusions formalisées : apm_service (infra) · rescues défensifs (~40 lignes) · façades `service_available?`
- [x] Contrôleurs métier : **non exclus** (résidu pertinent identifié par P6.6)
- [ ] Divergences détectées : journalisées + arbitrées CTO
- [ ] Journal complet + campagne à jour
- [ ] PR Wave 4 au format maison — CI 6/6 = clôture
- [ ] P6.6 final : palier 90 % = objectif de validation mesuré, pas critère artificiel

- [ ] W4-D1 → W4-D3 : chaque étape validée (suite verte, RuboCop 0, Brakeman 0, mesure réelle au journal)
- [ ] Exclusions formalisées : apm_service (infra) · rescues défensifs (~40 lignes) · façades `service_available?`
- [ ] Contrôleurs métier : **non exclus** (résidu pertinent identifié par P6.6)
- [ ] Divergences détectées : journalisées + arbitrées CTO
- [ ] Journal complet + campagne à jour
- [ ] PR Wave 4 au format maison — CI 6/6 = clôture
- [ ] P6.6 final : palier 90 % = objectif de validation mesuré, pas critère artificiel

## 6. Références

- Assessment P6.6 : `docs/technical/testing/2026_09_21_p6_6_assessment.md` · Campagne : `2026_09_17_coverage_campaign_p6.md` · Trackers Wave 2-3
- Contrat d'erreur : `docs/technical/guides/error_contract.md` · Contrat : `app/lib/application_result.rb`
- Mémoire : `fc08::011` (amendement 20/09) · Registre dette : `fc08_debt_register.md` (D-12)