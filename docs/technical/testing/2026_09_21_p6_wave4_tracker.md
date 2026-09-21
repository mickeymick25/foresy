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

## 3. Séquence validée (proposée au GO CTO)

### W4-D1 — contrôleurs CRA / CraEntries — ✅ FAIT (21/09)

**Specs ajoutées (8, `spec/requests/api/v1/cras/cra_error_handlers_spec.rb` — nouveau, suite 1129 → 1138) :**
- **CraEntriesController — 5 blocs `rescue StandardError`** (create, index, show, update, destroy) : exception hors-CraErrors → 500 + log_api_error
- **CraEntriesController — handle_service_error (L271-291)** : 13 clés d'erreur mappées vers leur statut HTTP
- **CrasController — index en échec** (L75-76) : le message du résultat est rendu tel quel (la clé `:invalid_payload` est passée au lieu du message humain — comportement caractérisé)
- **CrasController — render_result_error** (L174-189) : 6 statuts de résultat mappés vers le rendu standardisé

**Découverte structurelle :** les handlers `rescue_from CraErrors::*` (L197-249 de cra_entries_controller) sont **injoignables via le flow normal** — chaque action a un `rescue StandardError` inline qui attrape tout avant le rescue_from. Ils sont **documentés comme défensifs** (pas de spec artificielle pour les traverser).

**Gates :** suite **1138/0** ✓ · RuboCop **0** ✓ · Brakeman **0** ✓ · **SimpleCov : 83,83 % lignes (3101/3699) · 56,52 % branches (884/1564)**.

**Commit :** cette livraison.

### W4-D2 — contrôleurs Missions / Companies + concerns (prévu, non démarré)
### W4-D3 — résidu contrôleurs + mesure finale (prévu, non démarré)
### P6.6 final (prévu, non démarré)

## 4. Journal de suivi

### 2026-09-21 — GO Wave 4 + reconnaissance W4-D1

- **Contrat de routage respecté :** requêtes hub `foresy__knowledge` (P6.6, campagne §1) — sources : campagne, D-2 tracker · puis lectures locales complémentaires
- **Découvertes structurantes (reconnaissance) :**
  - les handlers `rescue_from CraErrors::*` de cra_entries_controller sont injoignables via le flow normal (inline `rescue StandardError` précède le rescue_from)
  - le message du résultat est rendu tel quel (la clé `:invalid_payload` est passée au lieu du message humain — divergence mineure, caractérisée)
  - `render_result_error` a 6 branches de statut mappées (conflict/forbidden/not_found/bad_request/internal_server_error/unprocessable_entity)
  - `handle_service_error` a 13 clés d'erreur mappées (422/409/404/403/500)
- **Suivant :** specs W4-D1 (écrites) → gates → commit → W4-D2

## 5. Critères de sortie de vague

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