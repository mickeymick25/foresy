# P6.0 — Analyse exhaustive des manques de couverture (SimpleCov)

**Date :** 17 septembre 2026
**Source :** `coverage/.resultset.json` du run de référence (suite complète **957 exemples, 0 échec**, base `foresy_test`, conteneur, SimpleCov 1.3.0, commit `b8237402`+docs — état main au 17/09) — mesures re-productibles via **`scripts/coverage_gap_analysis.rb` (versionné)** : exécuter la suite complète puis le script (usage en en-tête du script ; E2E shell n'y contribuent pas — le process serveur n'est pas instrumenté)
**Baseline (16-17/09) :** **72.78 % lignes (2879/3956)** · **44.82 % branches (744/1660)** — guide `docs/technical/testing/line_coverage.md`
**Portée :** code applicatif `app/` (78 fichiers Ruby, filtres `.simplecov` : spec/, config/, db/, bin/, vendor/, `__test_support__/`)
**Objet :** documenter **où sont les manques** et **par quel type de test les combler** (unitaire / intégration / non-régression / E2E) — base du plan P6 (`p6_coverage_implementation_tracker.md`)

---

## 1. Ce que SimpleCov mesure — et ne mesure pas

| Type de test | Mesuré par SimpleCov ? | Détail |
|---|---|---|
| **Unitaires** (models, services, lib) | ✅ Oui | Exécutés dans le process RSpec → instrumentés |
| **Intégration** (request specs, specs ledger, contraintes DB) | ✅ Oui | Idem — le code applicatif traversé compte |
| **Acceptance specs** (`spec/acceptance/`, dans la suite) | ✅ Oui | Font partie des 957 exemples |
| **Non-régression** | ✅ (transverse) | La suite existante **est** le filet ; le verrou `minimum_coverage` (P6.1) empêchera la dérive |
| **E2E shell** (`bin/e2e/*.sh`, smoke) | ❌ **NON** | Exécutés **hors RSpec**, contre le serveur en cours d'exécution — le process serveur n'est pas instrumenté. **Même après D-12** (intégration CI), leur contribution à la métrique restera nulle : l'E2E est une **gate de parcours réel**, pas un contributeur de couverture |
| **Non-régression CI** (RuboCop, Brakeman, RSwag, bundle-audit) | ❌ (hors périmètre) | Gates qualité, pas de couverture |

**Conséquence pour P6 :** les 95 % (lignes) ne peuvent être atteints que par des chemins **exécutables via RSpec** (unitaire + intégration). L'E2E consolide la confiance parcours, pas la métrique.

## 2. Synthèse des manques

| Indicateur | Valeur |
|---|---|
| Fichiers avec écarts | **67 / 78** |
| Lignes non couvertes | **1 077** (2879/3956) |
| Branches non couvertes | **916** (744/1660) |
| Concentration | **Top 10 fichiers ≈ 455 lignes (42 % du manque)** — dont 9 concerns API du refactoring FC-07 |
| Constat critique | Les concerns API n'ont **quasi aucune branche couverte** : `access_validation` **0/46**, `parameter_extractor` commun **0/56**, `parameter_extractor` cra_entries **1/72**, `CraServices::List` **0/36**, `error_handler` cras **0/14**, `o_auth_concern` **0/20** — ils ne sont aujourd'hui exercés que par les chemins de succès des request specs |

## 3. Analyse par typologie de test — où sont les manques, par quel véhicule les combler

### 3.1 Intégration — request specs (le plus gros bloc : ≈ 430 lignes à gagner)

Concerns API du refactoring FC-07 + contrôleurs : les branches **non- succès** (erreurs, params invalides, 403, 429, codes) ne sont pas traversées.

| Fichier | l% | Manque (lignes) | Branches | Scénarios à écrire |
|---|---|---|---|---|
| `concerns/api/v1/cras/access_validation.rb` | 18.1 | 77 | **0/46** | **Sécurité** — 403/404 d'accès CRA (owner/creator, CRA d'autrui, soft-deleted), rôles |
| `concerns/api/v1/cras/error_handler.rb` | 35.5 | 49 | 0/14 | 404, 422, 409 (locked), RecordInvalid |
| `api/v1/cra_entries_controller.rb` | 65.2 | 49 | 27/71 | CRU entries : dates invalides, quantités, mission inexistante, erreurs |
| `concerns/common/response_formatter.rb` | 37.3 | 47 | 0/20 | Formats de réponse : meta, listes, cas limites |
| `concerns/api/v1/cra_entries/parameter_extractor.rb` | 38.2 | 47 | 1/72 | Params entries manquants/invalides, types |
| `concerns/api/v1/cra_entries/error_handler.rb` | 37.0 | 46 | 0/14 | 404/422/409 entries |
| `concerns/common/parameter_extractor.rb` | 36.1 | 39 | 0/56 | Params CRA : month/year invalides, format |
| `concerns/api/v1/cras/parameter_extractor.rb` | 41.8 | 39 | 1/56 | Params CRA idem |
| `concerns/standardized_error.rb` | 69.0 | 26 | 10/34 | Chaque code d'erreur (§ contrat) : TOO_MANY_REQUESTS, INVALID_PAYLOAD… |
| `concerns/api/deprecation.rb` | 83.9 | 5 | 3/4 | Header Sunset/Deprecation |
| `controllers/api/v1/cras_controller.rb` | 78.0 | 24 | 25/53 | Submit/lock/export : cas d'erreur |
| `controllers/api/v1/missions_controller.rb` | 81.9 | 13 | 15/26 | Erreurs lifecycle |
| `controllers/api/v1/companies_controller.rb` | 87.2 | 6 | 8/14 | 409/422 create (déjà bien couvert FC-08) |
| `controllers/api/v1/user_companies_controller.rb` | 90.5 | 4 | 9/12 | Marges |
| Sous-total | | **≈ 430** | | |

### 3.2 Intégration — rate limiting & OAuth (≈ 130 lignes)

| Fichier | l% | Manque | Scénarios |
|---|---|---|---|
| `concerns/api/v1/cra_entries/rate_limitable.rb` | 47.5 | 31 | Dépassement 429 sur entries |
| `concerns/common/rate_limitable.rb` | 56.5 | 30 | 429 login/signup/refresh |
| `concerns/api/v1/cras/rate_limitable.rb` | 60.5 | 17 | 429 cras |
| `concerns/o_auth_concern.rb` | 32.7 | 35 | Callbacks erreurs, échecs provider, session |
| `services/o_auth_user_service.rb` | 61.5 | 20 | Unitaire/intégration OAuth user |
| `services/o_auth_token_service.rb` | 50.0 | 15 | Erreurs exchange |
| `services/o_auth_validation_service.rb` | 80.4 | 11 | Marges |
| `controllers/api/v1/oauth_controller.rb` | 96.3 | 2 | Marges |

### 3.3 Unitaire — services & lib (≈ 230 lignes)

| Fichier | l% | Manque | Véhicule |
|---|---|---|---|
| `services/cra_services/list.rb` | 24.6 | 49 | **Unitaire** — filtres year/month/status (Mini-FC-01) : cas limites, combinaisons |
| `services/git_ledger_service.rb` | 44.7 | 26 | **Intégration** — orchestration lock (payload, commit, vérification) |
| `services/cra_services/update.rb` | 71.4 | 30 | Unitaire — transitions invalides |
| `services/apm_service.rb` | 82.7 | 17 | Unitaire — marges instrumentation |
| `lib/application_result.rb` | 67.1 | 23 | **Unitaire** — helpers Result non utilisés par les specs actuelles |
| `lib/cra_errors.rb` | 70.0 | 18 | **Unitaire** — erreurs typées (CraErrors::*) |
| `services/rate_limit/redis_backend.rb` + `backend.rb` | 58.8/62.5 | 10 | Unitaire — backends |
| `models/cra.rb` | 78.7 | 27 | Unitaire — validations/edge cases |
| `models/mission.rb` | 82.4 | 21 | Unitaire — lifecycle |
| `models/company.rb` | 81.5 | 12 | Unitaire — marges FC-08 |
| `services/mission_services/create.rb` | 84.6 | 21 | Unitaire — marges |
| Autres services/models (marges ≤ 10 lignes × ~25 fichiers) | ~85-95 | ≈ 105 | Unitaire/intégration — gagnes marginales |

### 3.4 E2E — rôle et limite

- **Acceptance specs** (dans la suite) : comptées par SimpleCov — les densifier ajoute de la couverture, mais leur vocation est le parcours.
- **E2E shell / smoke** : **invisible pour la métrique** (§1). Leur valeur : rejouabilité parcours réel HTTP (D-4), smoke CI (15/15). **Pas un levier P6.**
- Les scénarios 403/409/429 des request specs (3.1-3.2) **complètent** l'E2E : ils couvrent les branches d'erreur que le parcours nominal ne traverse pas.

## 4. Scénarios de progression (mathématique du verrou)

| Cible lignes | Lignes à gagner | Fichiers (top manques) | Écart vs baseline |
|---|---|---|---|
| 80 % | +286 | ≈ 6 | Wave 1 (3.1 critique) |
| 85 % | +484 | ≈ 11 | Waves 1+2 |
| 90 % | +681 | ≈ 18 | Waves 1-3 |
| **95 %** | **+879** | **≈ 29** | Waves 1-4 — le reste = ~40 fichiers de marges fines |

## 5. Chiffrage indicatif (h effectives, agent + CTO review)

| Wave | Contenu | Gain estimé | Durée |
|---|---|---|---|
| 1 | Sécurité & erreurs critiques (3.1 : access_validation, error_handlers, standardized_error) | ~130 lignes → ~76 % | 2,5-3 h |
| 2 | Extraction/formatage + rate limiting + OAuth (3.1 suite + 3.2) | ~200 lignes → ~81 % | 3-4 h |
| 3 | Services/lib unitaires + contrôleurs + models (3.3) | ~250 lignes → ~87-90 % | 4-5 h |
| 4 | Marges fines (≈ 40 fichiers ≤ 10 lignes chacun) | → **95 %** | 4-6 h |
| **Total 95 %** | | **+879 lignes** | **≈ 14-18 h** |

## 6. Décisions attendues du CTO (alimentées par cette analyse)

1. **Verrou initial (P6.1)** : `minimum_coverage line: 72.5` recommandé (baseline 72.78 — marge fine anti-bruit d'environnement, suite déterministe).
2. **Cible de vague** : 90 % en waves 1-3 puis décision 95 % ? ou 95 % direct (4 waves) ?
3. **Zone morte assumée ?** : fichiers d'infra (ex. `apm_service`) — couvrir (par défaut) ou exclure du dénominateur via `.simplecov` (décision à documenter).
4. **Branches (44.82 %)** : verrou de branche en fin de wave 2 (mesure d'abord — même philosophie que D-2.1).

## 7. Références

- Baseline & guide : `docs/technical/testing/line_coverage.md`
- Chiffrage D-2 : `docs/technical/changes/2026-09-16-D2_SimpleCov_Chiffrage.md`
- Suivi D-2 : `docs/technical/d2_simplecov_implementation_tracker.md` (P6 = phase héritée)
- Plan P6 : `docs/technical/p6_coverage_implementation_tracker.md`