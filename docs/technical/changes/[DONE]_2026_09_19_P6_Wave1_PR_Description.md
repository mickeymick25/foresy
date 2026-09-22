# P6 Wave 1 — Sécurité et erreurs critiques — Description de PR

**Date :** 19 septembre 2026
**Branche :** `feat/p6-wave1` → `main` (base : `547c8d8a`, tête de la PR #34 — à merger d'abord)
**Plan de campagne :** `docs/technical/testing/[DONE]_2026_09_17_coverage_campaign_p6.md` · Suivi : `docs/technical/testing/[DONE]_2026_09_18_p6_wave1_tracker.md` (journal complet)
**Décisions CTO :** GO Wave 1 (18/09), arbitrages D1/D3-1/D3-2/D3-3/fc08::005, clôture de vague (19/09)

---

## 1. Résumé

Wave 1 complète (W1-D1 → W1-D4), exécutée selon la règle P6.0 : **traverser les chemins de
sécurité et d'erreur réels — pas monter un pourcentage**. La progression de couverture
(73,21 % → 76,49 % lignes) est une **conséquence** des caractérisations et surtout des
suppressions de code démontré mort. Aucun test artificiel. Deux bugs d'autorisation
découverts par caractérisation et corrigés par cycle RED → GREEN arbitré.

## 2. Étapes et commits

| Étape | Contenu | Commit |
|---|---|---|
| Tracker | Plan de suivi Wave 1 + pivot campagne W1-D1 | `a32aafbc` |
| W1-D1 | Suppression du concern mort `Api::V1::Cras::AccessValidation` (éclipsé à 100 % : validateurs redéfinis dans les contrôleurs, méthodes à argument inappellables par `before_action` sans argument, implémentation pré-RDD) — 962/0 **inchangé**, 74,54 % | `d97ab927` |
| W1-D2 | Caractérisation sécurité vivante : voie via-missions FC06 (200 en requête réelle), rôles pivots, séparation — 8 specs | `6a2134e6` |
| W1-D2-BUG | **2 bugs d'autorisation corrigés (RED → GREEN, arbitrage CTO)** : soft-delete non propagé — mission supprimée / adhésion révoquée (FC-08) continuaient d'accorder l'accès. CRA (`relation_accessible_to`) puis Mission (cycle symétrique) | `88c7a9ad` · `de329d78` |
| W1-D3-A | Caractérisation des 2 seuls chemins rate-limit vivants (CRA + CRA-entries) : 429, contrat plat, `RATE_LIMIT_EXCEEDED` | `30a55da7` |
| Divergence | Contrat 429 aligné sur l'implémentation (`2026_08_18_error_contract.md`) — **doc seulement, aucun breaking change** | `2c6a3cd7` |
| W1-D3-B | Suppression des 3 concerns d'erreur morts/éclipsés (~400 lignes) + relocalisation de `handle_rate_limit_exceeded` (×2 contrôleurs) et `log_api_error` (5 appelants vivants découverts par le grep final) — 975/0 inchangé, 76,49 % | `e9a53168` |
| W1-D4 | Caractérisation `standardized_error` (401 sans email, 400 `MISSING_PARAMETER` via `params.require`) + **fc08::005 tranchée par preuve d'exécution** : `expect_error_response` = zéro usage → helper mort, aucune modification | `3aa6db22` |

## 3. Bilan mesuré

| Métrique | Avant Wave 1 | Après Wave 1 |
|---|---|---|
| Couverture lignes (corpus conteneur) | 73,21 % | **76,49 %** (2825/3693) |
| Couverture branches | 45,07 % | **47,60 %** (756/1588) |
| Exemples RSpec | 962 | **977** (+15, tous des caractérisations ou bascules d'attentes de bugs) |
| Tests artificiels | — | **0** |
| Bugs d'autorisation corrigés | — | **2** (soft-delete propagation, CRA + Mission) |
| Code mort supprimé | — | 4 zones (concern AccessValidation, 3 concerns d'erreur) |
| RuboCop / Brakeman | 0 / 0 | **0 / 0** |

**Verrou : inchangé** — `minimum_coverage line: 72.0` transitoire (contrat P6.1) ; le retour à
72,5 reste contractuellement rattaché à la caractérisation de `OAuthCodeExchangeService` en
**Wave 2** (arbitrage CTO 18/09 : aucun changement de seuil malgré 76,49 %).

## 4. Dettes identifiées — HORS périmètre, reportées à la réévaluation de fin de campagne

| Élément | État | Décision CTO 19/09 |
|---|---|---|
| `spec/support/error_response_helper.rb` (fc08::005) | Helper mort (zéro usage) — l'incompatibilité `{error: {code}}` n'est pas démontrable par exécution | **Maintenu temporairement, tracé comme dette distincte** — pas de cleanup opportuniste |
| 6 helpers `standardized_error` sans appelant (`error_invalid_enum`, `error_malformed_json`, `validate_required_params` ×2 copies, `validate_enum`, `validate_json`) | Identifiés (zéro appelant) | Reportés — cycle suppression/conservation à arbitrer en fin de campagne |
| 4 latents `rate_limitable` (`render_cra_rate_limit_response`, `render_cra_entry_rate_limit_response`, `get_rate_limit_config`, `render_rate_limit_response`) | Identifiés (zéro appelant) | Idem |
| `handle_unpermitted_parameters` / `handle_record_not_found` | Injoignables (config `:log` par défaut ; aucun `.find(params)`) | Documentés au journal W1-D4 |
| D3-3 : couches d'erreur réellement vivantes des contrôleurs (handlers locaux, `handle_cra_error`) | Couverture partielle significative | Réévaluation séparée en fin de vague/campagne |

## 5. Validation

- **Gates par étape** : journal complet au tracker (`docs/technical/testing/[DONE]_2026_09_18_p6_wave1_tracker.md`) — chaque étape : RSpec complet, RuboCop 0, Brakeman 0, SimpleCov réel mesuré (jamais projeté)
- **Arbitrage CI** : les 6/6 jobs de cette PR seront l'arbitre final (le push de branche ne déclenche pas le workflow — merge PR #34 d'abord, puis cette PR)
- **Référence de mesure** : suite 977/0, conteneur `foresy_test` propre, verrou 72,0 tenu sur toutes les mesures de vague

---
*Description générée le 19/09/2026 — branche `feat/p6-wave1`, 10 commits, base PR #34 `547c8d8a`*