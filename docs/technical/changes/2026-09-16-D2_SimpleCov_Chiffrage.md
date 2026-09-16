# D-2 — Chiffrage : Couverture de lignes (SimpleCov)

**Date :** 16 septembre 2026
**Dette :** D-2 (registre `docs/technical/fc08_debt_register.md`) — « Aucun outil de couverture de lignes en place (gem absente, `coverage/` vide) — chantier transverse à chiffrer séparément »
**Décision co-CTO :** revue PR #26 du 16/09 — « chiffrage du coût (gem + setup), sprint dédié »
**Standard :** platinium — l'outil complète les gates d'invariants/E2E, il ne les remplace pas

---

## 1. Constat (état vérifié au 16/09)

- `Gemfile` : aucune gem de couverture (`simplecov` absente — vérifié par grep)
- `coverage/` à la racine : artefacts **périmés de janvier 2026** (`.resultset.json`, `coverage.json`, `.last_run.json` — reliquats d'une installation disparue) ; à purger au setup
- CI **déjà partiellement câblée** : le job « Tests & Coverage » exporte `COVERAGE: true`, écrit `coverage/rspec.json` (formateur JSON de RSpec — ce n'est pas de la couverture) et uploade `coverage/` en artefact → la plomberie existe, il ne manque que la gem + la config

## 2. Solution proposée

| Élément | Choix | Justification |
|---|---|---|
| Gem principale | `simplecov` | standard de facto Rails/RSpec, rapport HTML inclus |
| Rapport XML CI | `simplecov-cobertura` | `coverage/coverage.xml` exploitable (annotations, outils CI) |
| Filtres | `spec/`, `app/controllers/__test_support__/`, `bin/`, `config/`, `db/`, `vendor/`, `node_modules/` | périmètre = code applicatif `app/` |
| Métrique | lignes **+ branche** (`enable_coverage :branch`) | la branche détecte les conditions non testées |
| Seuil | **Phase 1 : rapport sans échec** (baseline mesurée) → **Phase 2 : `minimum_coverage 95`** (standard maison « coverage cible 95% ») | ne pas bloquer avant de connaître la base réelle |
| Groupes | par contexte délimité (Models, Controllers, Services, Integration) | lisibilité du rapport |

## 3. Étapes du chantier

| # | Étape | Contenu | Durée |
|---|---|---|---|
| 1 | Gems | Gemfile group `:test` : `simplecov` + `simplecov-cobertura`, `bundle install` (lockfile) | 15 min |
| 2 | Config | `.simplecov` à la racine (auto-chargé par SimpleCov) : start, filtres, `enable_coverage :branch`, groupes, seuil | 45 min |
| 3 | Branchement | 1ère ligne de `spec/rails_helper.rb` ou `spec_helper.rb` : `require 'simplecov'` (avant tout le reste — contrainte SimpleCov) | 10 min |
| 4 | Hygiène | purger les artefacts périmés de `coverage/` ; vérifier `.gitignore` | 10 min |
| 5 | Baseline | exécution suite complète (`foresy_test`, 957 exemples) → mesurer le % réel → décider passage phase 1 → phase 2 | 30 min |
| 6 | CI | plomberie déjà en place (`COVERAGE=true` + upload `coverage/`) — rien à ajouter ; option : exposer le % dans le résumé du job | 20 min |
| 7 | Docs | registre D-2 → résolue ; guide `docs/technical/testing/line_coverage.md` (procédure, lecture, seuils) + journal | 45 min |

**Total estimé : ~3 heures effectives (½ journée)** — sprint dédié, conforme à la décision co-CTO.

## 4. Impact

| Aspect | Impact |
|---|---|
| Durée suite | +10-20 % (957 exemples, ~2 min → ~2,5 min) — acceptable |
| CI | aucun nouveau job ; l'artefact `coverage/` sera désormais rempli (HTML + XML + resultset) |
| Risques | (1) « fausse assurance » : couverture de lignes ≠ couverture contractuelle — les invariants (21/22) et l'E2E restent les gates de fond ; (2) un seuil dur 95% peut exiger des specs complémentaires sur le code faiblement couvert — **à chiffrer après la baseline** ; (3) le merge de couverture multi-jobs n'est pas nécessaire (suite single-job) |
| Non-cibles | badge externe (Codecov/Coveralls), couverture des scripts shell E2E, merge multi-OS |

## 5. Décisions attendues du CTO

1. **Seuil initial** : rapport sans échec (recommandé) ou seuil dur 95% dès le premier commit ?
2. **Cobertura XML** : oui (recommandé — annotations/outils CI) / non (HTML seul) ?
3. **Planification** : sprint ½ journée ; specs complémentaires éventuelles chiffrées séparément post-baseline

## 6. Références

- Registre : `docs/technical/fc08_debt_register.md` (D-2, §6 item 5)
- Standard platinium §1.3 (audit 2026-07-22) : « Coverage cible : 95% minimum pour futures features »
- Suivi : `docs/technical/d1_d11_corrective_actions_tracker.md` (action 8)