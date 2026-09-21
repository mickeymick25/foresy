# P6.6 — Coverage & Corpus Assessment

**Date :** 21 septembre 2026
**Décision CTO :** P6.6 direct → mesure → arbitrage (pas de Wave 4 préventive)
**Base de mesure :** `main` @ `09466953` (post-merge PR #40, Wave 3) — suite complète **1130/0** (foresy_test, conteneur, verrou 72,5 armé)
**Provenance :** requêtes hub `foresy__knowledge` (P6.6, campagne §1) + extraction authoritative `coverage/.resultset.json` (76 fichiers chargés) + inventaire disque `app/` (outil temporaire `cov_p66_tmp.rb`, supprimé après)

---

## 1. Corpus inclus / exclu

| Composante | Valeur |
|---|---|
| Corpus mesuré (fichiers chargés par la suite) | **76 fichiers app/** · 3699 lignes utiles |
| Lignes couvertes | 3074 |
| Lignes non couvertes | **625** |
| Fichiers `app/` jamais chargés par la suite | **0** — les 76 fichiers `app/` existants sont tous dans le corpus (aucun fichier applicatif aveugle) |
| Hors corpus structurel | `app/channels`, `app/jobs`, `app/mailers` (aucun fichier de ces répertoires n'est présent dans l'arborescence active) |

**Corpus conteneur (lazy) ≠ corpus CI (eager)** : le corpus d'enforcement CI inclut les fichiers chargés par eager load ; l'écart documenté (P6.1) est résorbé depuis le nettoyage du 18/09.

## 2. Méthode de mesure

```bash
docker compose exec -T web sh -c "DATABASE_URL=postgres://postgres:password@db:5432/foresy_test \
  RAILS_ENV=test bundle exec rspec"
# lecture : coverage/.resultset.json (conteneur) — extraction : outil racine (supprimé après usage)
```

- Suite complète **1130/0** sur `foresy_test` (D-10 : base propre obligatoire)
- SimpleCov 1.3.0 + Cobertura XML · `enable_coverage :branch` · verrou `minimum_coverage line: 72.5` armé uniquement sur la suite complète (at_exit, P6.1-bis)
- Extraction lignes/branches par fichier + numéros de lignes non couvertes

## 3. Lines : **83,10 %** (3074/3699)

## 4. Branches : **54,86 %** (858/1564)

*(totaux certifiés par le processus RSpec réel — SimpleCov 1.3 ; la ventilation branches par fichier requiert le rapport HTML/XML, résidu d'outillage documenté au §6)*

## 5. Top résidus par impact (lignes non couvertes)

| Fichier | Non couvert | Nature du chemin |
|---|---|---|
| `controllers/api/v1/cra_entries_controller.rb` | 52 | couches `rescue_from` (L192-249), branches `handle_service_error`, guards |
| `controllers/concerns/api/v1/cra_entries/parameter_extractor.rb` | 47 | extraction/validations de paramètres |
| `controllers/concerns/common/response_formatter.rb` | 47 | formats de réponse paginés/erreurs |
| `controllers/concerns/api/v1/cras/parameter_extractor.rb` | 39 | extraction des filtres CRA |
| `controllers/concerns/common/parameter_extractor.rb` | 37 | extraction commune |
| `concerns/o_auth_concern.rb` | 35 | gestion d'erreurs OAuth côté contrôleur |
| `services/cra_services/update.rb` | 30 | branches de recalcul/mise à jour non exercées |
| `controllers/concerns/api/v1/cra_entries/rate_limitable.rb` | 26 | rendu 429 CRA-entries |
| `lib/application_result.rb` | 23 | builders/helpers « for controllers » (dette cleanup documentée) |
| `controllers/api/v1/cras_controller.rb` | 24 | branches `render_result_error`/handlers |
| `lib/cra_errors.rb` | 1 | init `InternalError` (défensif) |
| `controllers/concerns/standardized_error.rb` | 13 | branches `error_*` restantes |
| `services/mission_services/create.rb` | 21 | branches mission fixed_price + erreurs |
| models résiduels post-W3-D4 | ~30 | cra L181/309-311/363, mission L309/314, pivots L44/54, user_cra L37-38 |
| façades ×3 (`service_available?`) | 3 | conservées (arbitrage W3-D3) |
| **TOTAL** | **625** | |

## 6. Classification métier / défensif / infrastructure / tooling

| Classe | Lignes (≈) | Détail |
|---|---|---|
| **Métier — contrôleur (dette D3-3, enregistrée)** | ~383 | `cra_entries_controller` (52) · `cras_controller` (24) · `missions_controller` (13) · `companies_controller` (6) · `user_companies_controller` (4) · `oauth_controller` (2) · `authentication_controller` (1) · **concerns** : `parameter_extractors` ×3 (123), `response_formatter` common (47), `o_auth_concern` (35), `rate_limitable` ×3 (55), `standardized_error` (13), `authentication_metrics/logging` (16), `api/deprecation` (5), `cra_entries/response_formatter` (1) |
| **Métier — lib/services (contrats résiduels, W3-D3)** | ~55 | `application_result` (23 — helpers/factories conservés), `cra_errors` (1 — init `InternalError` défensif), `cra_entry_services` (11), `oauth_controller` (2), `json_web_token` (2) |
| **Défensif (rescues/gardes, documentés)** | ~40 | `cra_services` list/list_failed + façades, `git_ledger_repository` (4), `cra`/`mission` résidus post-W3-D4, `cra_entry_services/destroy` |
| **Infrastructure (candidat exclusion)** | ~17 | `apm_service` — client Datadog (décision §9) |
| **Tooling/façades (conservées)** | 3 | `service_available?` ×3 |

## 7. Analyse de faisabilité du palier 90 %

| Élément | Analyse |
|---|---|
| Cible 90 % | **3329 lignes couvertes** sur 3699 → **+255 lignes** à couvrir (actuellement +625 disponibles) |
| Volume disponible | Oui — le résidu métier total (métier + D3-3) ≈ **423 lignes** (hors défensif/infra/tooling ≈ 60) > 255 |
| Condition | Atteindre 90 % **exige la couverture de la couche contrôleur** (D3-3) — sans elle, le plafond naturel est ≈ **84-85 %** (les models/lib/services sont déjà à 88-100 %) |
| Coût | D3-3 a été chiffré à ~15-20 specs pour CRA/CraEntries seul ; l'extension aux parameter_extractors/response_formatter/o_auth_concern ≈ 25-35 specs supplémentaires → **Wave 4 ≈ 45-55 specs**, 2-3 sous-étapes (même rythme que W2/W3) |
| Branche (54,86 %) | Les branches mesurées sont des conditions de contrôleurs/services/modèles (if/unless/case/rescue) — **significatives** pour la couche métier ; le gap branches est concentré sur les mêmes fichiers que les lignes (couche contrôleur) |
| Zone morte (décision P6.1) | `apm_service` : infra Datadog — **candidat exclusion formelle** ; rescues défensifs documentés — non chassés |

## 8. Coût estimé d'une Wave 4 (couche contrôleur = D3-3 élargi)

| Paramètre | Estimation |
|---|---|
| Périmètre | couches d'erreur/extraction/rendu des contrôleurs CRA, CRA-entries, Missions, Companies + o_auth_concern + rate_limitable ×3 + standardized_error branches |
| Specs | **~45-60 specs** (request-level, stubs services pour traverser les handlers — pattern W1-D3/W1-D4 éprouvé) |
| Sous-étapes | 3 (D4-1 CRA/CraEntries controllers, D4-2 concerns extraction/rendu, D4-3 OAuth + standardized_error) |
| Risques | couche rendu JSON = attentes de contrats stables (caractérisation pure) · rescues défensifs à documenter |
| Gain couverture attendu | ≈ 85-88 % lignes — **90 % dépend des parameter_extractors** (123 lignes d'extraction, les plus denses) |
| Verrou | 72,5 inchangé pendant la vague ; relèvement 90 contractuel seulement si mesuré atteint — sinon palier maintenu à ~85 |

## 9. Décision proposée (arbitrage CTO)

| Option | Contenu | Recommandation |
|---|---|---|
| **A — Wave 4 ciblée (couche contrôleur)** | Caractériser D3-3 + concerns (~45-60 specs), atteindre ≈ 88-90 %, puis P6.6 final | ✅ **recommandée** — le palier 90 % n'est atteignable que par cette couche ; la dette D3-3 est déjà enregistrée, la caractérisation est naturelle (handlers stables) |
| **B — P6.6 suffisant à 83,10 %** | Verrou porté à ~83 (marge +0,60) ; exclusions formalisées (apm_service) ; D3-3 reste dette vivante | possible mais le palier 90 % de la campagne serait abandonné sans mesure du reste |
| **C — Exclusions formalisées** | `apm_service` (infra) + rescues défensifs documentés exclus du corpus qualifié | complémentaire à A ou B (réduit le dénominateur ≈ 3682 lignes utiles qualifiées) |

**Recommandation détaillée** : **A + C combinés** — Wave 4 ciblée sur la couche contrôleur (métier, pas défensif) + formalisation de l'exclusion `apm_service` + rescues défensifs documentés. Le palier 90 % devient contractuel après la Wave 4 **si** la mesure confirme l'atteinte ; sinon maintien à 72,5 avec justification quantifiée.

## Références

- Campagne : `docs/technical/testing/2026_09_17_coverage_campaign_p6.md` (§1 décisions P6.6 — palier 90 % évalué sur mesure, branch coverage, zone morte) · Trackers Wave 1-3
- Dette D3-3 : registre `fc08_debt_register.md` + tracker Wave 1 §6 G4 · Contrat d'erreur : `docs/technical/guides/error_contract.md`
- Mémoire : `fc08::011` (amendement 20/09) · Outil : `cov_p66_tmp.rb` (racine, supprimé après usage — méthode documentée au journal)