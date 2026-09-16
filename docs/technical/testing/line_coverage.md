# Guide — Couverture de lignes (SimpleCov)

**Date :** 16 septembre 2026
**Dette :** D-2 — implémentée (PR #29) ; décisions actées D-2.1 / D-2.2 / D-2.3 (co-CTO, checkpoint du 16/09)
**Standard :** platinium — l'outil complète les gates d'invariants/E2E, il ne les remplace pas

---

## 1. Ce qui est en place

- **Gems** : `simplecov` (1.3.0) + `simplecov-cobertura` (4.0.0) — group `:test` du `Gemfile`
- **`.simplecov`** (racine, auto-chargé) : lignes **+ branches** (`enable_coverage :branch`), filtres (`spec/`, `config/`, `bin/`, `db/`, `vendor/`, `node_modules/`, `__test_support__/`), groupes (Models, Controllers, Services)
- **Boot dédié** `spec/coverage_boot.rb` : SimpleCov démarre **avant** `config/environment` — constat : `.rspec` charge l'application au boot, avant les helpers ; un require tardif donnerait une couverture vide
- **`.rspec`** : `--require ./spec/coverage_boot`
- **Formatters** : HTML (`coverage/index.html`) + Cobertura XML (`coverage/coverage.xml`)
- **CI** : `COVERAGE=true` + upload `coverage/` déjà en place — l'artefact contient désormais HTML + XML (aucun job ajouté)
- **Pas de seuil dur** en phase 1 (D-2.1) — le seuil 95 % est la décision P6, post-mesure

## 2. Exécuter et mesurer

```bash
# Conteneur, base foresy_test (guide test_database_isolation.md)
docker compose exec -T web sh -c \
  "DATABASE_URL=postgres://postgres:password@db:5432/foresy_test RAILS_ENV=test bundle exec rspec"
```

Fin de run : résumé `Line Coverage` / `Branch Coverage` + rapports régénérés (SimpleCov s'exécute à l'`at_exit`).

## 3. Lire les rapports

- `coverage/index.html` : détail par groupe et par fichier, lignes + branches, code annoté
- `coverage/coverage.xml` (Cobertura) : attributs `line-rate` / `branch-rate` (0-1) au niveau racine et par fichier — exploitable par les outils CI
- `coverage/.last_run.json` : résumé du dernier run — **`coverage/` est gitignoré**, rien de tout cela n'est commité

## 4. Baseline du 16/09/2026 (phase 1 — suite 957 exemples, 0 échec)

| Couche | Lignes | Branches |
|---|---|---|
| Models | 84,8 % (525/619) | 46,7 % (79/169) |
| Services | 80,5 % (1262/1568) | 62,5 % (462/739) |
| Controllers | 61,2 % (920/1504) | 27,9 % (187/670) |
| Autres (app/*) | 64,9 % (172/265) | 19,5 % (16/82) |
| **Total** | **72,78 % (2879/3956)** | **44,82 % (744/1660)** |

Top fichiers sous-couverts (lignes) : concerns API du refactoring FC-07 — `access_validation` 18,1 %, `CraServices::List` 24,6 %, `OAuthConcern` 32,7 %, `error_handler` CRA 35,5 % / CRA entries 37,0 %, `parameter_extractor`s ~36-42 %, `response_formatter` 37,3 %, `GitLedgerService` 44,7 %.

Lecture : ces concerns sont partiellement exercés par les request specs/E2E (chemins de succès) ; leurs **branches d'erreur et d'extraction de paramètres** restent à densifier — c'est le sujet de la décision P6 (seuil 95 %), hors périmètre de l'implémentation D-2.

## 5. Politique de seuils (2 phases)

- **Phase 1 (actuelle)** : rapport sans échec — `minimum_coverage` **absent** (D-2.1)
- **Phase 2 (P6, post-baseline)** : décision du CTO — `minimum_coverage 95` (standard maison) et/ou seuils par groupe ; alors corriger les fichiers critiques en priorité (specs complémentaires chiffrées séparément)

## 6. Références

- Registre : `docs/technical/fc08_debt_register.md` (D-2, §6 item 5)
- Chiffrage : `docs/technical/changes/2026-09-16-D2_SimpleCov_Chiffrage.md`
- Plan/suivi : `docs/technical/d2_simplecov_implementation_tracker.md`
- Isolement bases : `docs/technical/testing/test_database_isolation.md`