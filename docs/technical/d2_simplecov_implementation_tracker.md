# Plan d'implémentation & Suivi d'intégration — D-2 : Couverture de lignes (SimpleCov)

**Date de création :** 16 septembre 2026
**Dette :** D-2 (registre `docs/technical/fc08_debt_register.md`) — seule dette active restante de la vague D-1→D-11 (checkpoint co-CTO : 10/11 closes)
**Chiffrage :** `docs/technical/changes/2026-09-16-D2_SimpleCov_Chiffrage.md` (~3 h effectives, mergé via PR #28)
**Décisions actées (co-CTO, checkpoint du 16/09) :** **D-2.1** baseline sans échec CI / **D-2.2** Cobertura XML : oui / **D-2.3** sprint : maintenant
**Branche :** `chore/d2-simplecov-baseline` → PR #29 — **une seule PR**, pas de bookkeeping séparé (décision co-CTO)
**Standard :** platinium — gates réellement exécutées, traçabilité, outillage ≠ changement de comportement
**Philosophie (décision co-CTO) :** la première PR D-2 répond à « **Quelle est réellement notre couverture actuelle ?** » — pas à « Comment atteindre artificiellement 95 % le plus vite possible ». **Aucune correction de fichiers sous-couverts dans ce périmètre.**

---

## 1. Constats techniques (relevés le 16/09)

| Constat | Détail vérifié | Conséquence |
|---|---|---|
| Gems | Aucune gem de couverture — group `:test` (Gemfile L71-78) : capybara, faker, parallel_tests, rspec_junit_formatter, selenium-webdriver, shoulda-matchers | Ajout `simplecov` + `simplecov-cobertura` |
| Point d'entrée des specs | `.rspec` = `--require ./config/environment` → **l'application Rails se charge au boot, AVANT `rails_helper`/`spec_helper`** (rails_helper re-require ensuite `config/environment` puis `spec_helper`) | SimpleCov doit démarrer **avant le chargement de l'app** → un simple `require 'simplecov'` en tête de `spec_helper` serait **trop tard** ; boot dédié requis |
| `coverage/` | **Non suivi par Git** (`git ls-files` vide) + ignoré (`.gitignore` L53-54) ; contient des artefacts périmés de janvier 2026 | Purge filesystem simple, aucun changement Git |
| CI | `COVERAGE: true` déjà exporté + upload `coverage/` déjà en place (jobs tests/lint/contracts) | P4 = vérification uniquement, aucun nouveau job |

## 2. Vue d'ensemble — phases P1→P6 (plan co-CTO du checkpoint)

| Phase | Contenu | Gate de validation | Statut |
|---|---|---|---|
| **P0** | Cadrage : chiffrage mergé + 3 décisions actées | — | ✅ fait 16/09 |
| **P1** | Instrumentation : gems, `.simplecov`, boot SimpleCov, purge | Suite **957/0** avec rapport généré **sans échec** ; RuboCop 0 offense | ✅ fait 16/09 |
| **P2** | Baseline réelle : % lignes, % branche, fichiers couverts, top sous-couverts | Chiffres consignés au journal (mesure sur `foresy_test`, conteneur — guide D-10) | ✅ **72.78 % lignes / 44.82 % branches** |
| **P3** | Rapports : HTML + Cobertura XML | `coverage/index.html` + `coverage/coverage.xml` présents et exploitables | ✅ fait (XML parsé OK) |
| **P4** | CI : artefact/remontée | Artefact `coverage/` de la PR contient HTML + XML ; aucun job ajouté | ✅ fait + **assertion bloquante XML ajoutée au job tests** (revue CI co-CTO P0/P1 : 📋 Validate Coverage Report) — artefact à constater sur la CI de la PR |
| **P5** | Documentation : guide + registre + suivi + décisions tracées | `docs/technical/testing/line_coverage.md` créé ; registre/suivi à jour (incl. rattrapage shas merges A6 `8d19bce8` / D-11 `689a4b15`) | ✅ fait |
| **P6** | Décision du seuil 95 % | **Hors périmètre PR #29 — APRÈS mesure** (décision co-CTO) | ⬜ post-PR — baseline : 72.78 % lignes / 44.82 % branches |

## 3. Détail d'implémentation

### P1 — Instrumentation
- **`Gemfile`** (group `:test`) : `gem 'simplecov'` + `gem 'simplecov-cobertura'` → `bundle install` (lockfile)
- **`.simplecov`** (racine — auto-chargé par `require 'simplecov'`) :
  - `SimpleCov.start` avec filtres : `spec/`, `app/controllers/__test_support__/`, `bin/`, `config/`, `db/`, `vendor/`, `node_modules/`
  - `enable_coverage :branch` (métrique lignes + branche)
  - Groupes par couche : Models / Controllers / Services / Integration
  - `SimpleCov.formatter SimpleCov::Formatter::MultiFormatter[HTMLFormatter, CoberturaFormatter]`
  - **PAS de `minimum_coverage`** — D-2.1 : phase baseline sans échec
- **`spec/coverage_boot.rb`** (NOUVEAU) : `require 'simplecov'` **puis** `require` de `config/environment` — SimpleCov démarre avant le chargement de l'application (consat §1)
- **`.rspec`** : `--require ./config/environment` → `--require ./spec/coverage_boot`
- **Purge** des artefacts périmés de `coverage/` (non suivis)
- **Nature :** outillage — aucun changement de comportement applicatif ; cycle RED/GREEN non applicable (validation par exécution, conformément au standard pour l'outillage)
- **Risque identifié :** `.rspec` est le point d'entrée universel (CI, rejeux locaux, RSwag via rspec) — le boot doit rester minimal et inconditionnel

### P2 — Baseline
- **Commande de mesure (référence, guide D-10)** : `docker compose exec -T web sh -c "DATABASE_URL=postgres://postgres:password@db:5432/foresy_test RAILS_ENV=test bundle exec rspec"`
- **Collecte :** % lignes + % branches (sortie SimpleCov / `coverage/.last_run.json`), fichiers couverts, top fichiers sous-couverts par groupe (dont critiques : services, GitLedger)
- **Consignation :** journal §5 de ce suivi + ligne D-2 du registre

### P3 — Rapports
- HTML : `coverage/index.html` (simplecov-html inclus) ; XML : `coverage/coverage.xml` (CoberturaFormatter)
- Vérification : présence + XML bien formé (parse)

### P4 — CI
- Plomberie en place (`COVERAGE: true` + upload `coverage/`). Gate : l'artefact de la PR contient HTML + XML ; runtime acceptable (+10-20 % attendu sur ~2 min, chiffrage §4)
- Aucun nouveau job ; option « exposer le % dans le résumé du job » notée, non bloquante

### P5 — Documentation
- **`docs/technical/testing/line_coverage.md`** : procédure d'exécution, lecture des rapports, politique de seuils en 2 phases (baseline → 95 % post-mesure), décisions D-2.1/2.2/2.3 actées
- **Registre** : D-2 → implémentée + baseline chiffrée + seuil 95 % à décider post-mesure ; rattrapage des mentions « PR en cours » (A6 → merge `8d19bce8`, D-11 → merge `689a4b15`)
- **Suivi** : journal + statuts ; **README explicitement hors périmètre** (décision co-CTO : pass doc post-D-2 avec les métriques SimpleCov réelles)

### P6 — Seuil 95 % (post-mesure, hors PR #29)
- La baseline P2 éclaire la décision : écart réel vs 95 %, fichiers critiques, coût des specs complémentaires — aucune action dans cette PR

## 4. Gates globales de PR #29

| Gate | Attendu |
|---|---|
| Suite RSpec (`foresy_test`) | **957 exemples, 0 échec** (runtime +10-20 % toléré) |
| Rapport SimpleCov | Généré, **sans échec** (pas de seuil dur — D-2.1) |
| RuboCop | 0 offense |
| Brakeman | 0 warning (gems de test) |
| bundle-audit | 0 vulnérabilité |
| CI PR | **6/6 verts**, artefact `coverage/` rempli (HTML + XML) |
| Hub | Réindexé après commits |

## 5. Journal d'exécution

### 2026-09-16 — [P0] Cadrage
- Chiffrage mergé (PR #28) : ~3 h effectives
- Décisions actées (co-CTO, checkpoint du 16/09) : **D-2.1** baseline sans échec ; **D-2.2** Cobertura XML oui ; **D-2.3** sprint maintenant
- Périmètre arrêté : mesurer, ne pas corriger ; seuil 95 % post-mesure ; README différé après D-2
- Constats techniques relevés (§1) — dont le point d'entrée `.rspec` qui charge l'app au boot : boot SimpleCov dédié requis

### 2026-09-16 — [P1] Instrumentation exécutée
- Gems `simplecov` 1.3.0 + `simplecov-cobertura` 4.0.0 (group :test, lockfile) ; APIs vérifiées en conteneur
- `.simplecov` : lignes + branches, filtres, groupes (Models/Controllers/Services), MultiFormatter HTML+Cobertura, **pas de `minimum_coverage`** (D-2.1)
- Boot dédié : `spec/coverage_boot.rb` (SimpleCov d'abord, puis `config/environment`) + `.rspec` réécrit — un require tardif aurait donné une couverture vide
- Purge artefacts périmés `coverage/` (janvier 2026, non suivis) ; RuboCop 0 offense après autocorrect
- **Gate P1 ✅ : suite 957 exemples, 0 échec sur `foresy_test` avec rapport généré sans échec** — TDD non applicable (outillage, validation par exécution)

### 2026-09-16 — [P2-P3] Baseline mesurée + rapports
- **Baseline : 72.78 % lignes (2879/3956) / 44.82 % branches (744/1660)** — par couche : Models 84.8 %, Services 80.5 %, Controllers 61.2 %, Autres 64.9 % (branches 46.7 / 62.5 / 27.9 / 19.5 %)
- **Top sous-couverts :** concerns API (access_validation 18.1 %, error_handlers ~35-37 %, parameter_extractors ~36-42 %, response_formatter 37.3 %), `CraServices::List` 24.6 %, `OAuthConcern` 32.7 %, `GitLedgerService` 44.7 % — branches d'erreur/extraction partiellement exercées par les request specs/E2E (sujet P6, hors périmètre)
- **P3 ✅ :** `coverage/index.html` + `coverage/coverage.xml` générés, XML parsé OK (line-rate 0.7278 / branch-rate 0.4482)
- **P4 ✅ (plomberie) :** CI inchangée — artefact à constater sur la CI de la PR

### 2026-09-16 — [P5] Documentation exécutée
- Guide `docs/technical/testing/line_coverage.md` (procédure, lecture, baseline, politique de seuils 2 phases)
- Registre : D-2 ✅ résolue (baseline chiffrée, seuil P6) ; rattrapage shas merges A6 `8d19bce8` / D-11 `689a4b15`
- Chiffrage : décisions actées consignées (§5) ; **README hors périmètre** (décision co-CTO)

## 6. Références

- Registre : `docs/technical/fc08_debt_register.md` (D-2, §6 item 5)
- Chiffrage : `docs/technical/changes/2026-09-16-D2_SimpleCov_Chiffrage.md`
- Checkpoint co-CTO 16/09 : PR #25→#28 mergées, vague 10/11 closes, seule D-2 active
- Guide isolation bases : `docs/technical/testing/test_database_isolation.md`
- Suivi vague corrective : `docs/technical/d1_d11_corrective_actions_tracker.md`