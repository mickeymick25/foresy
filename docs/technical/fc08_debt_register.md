# FC-08 — État de la Dette (Registre)

**Date de mise à jour :** 14 septembre 2026
**Contrat :** FC-08 v3.2.3
**Autorité :** `docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]`
**Statut :** 🟢 FC-08 mergée (PR #24, v0.1.1) · dette D-1→D-11 vérifiée le 16/09 · correctifs post-vérification **MERGÉS** (PR #25, GREEN FOR MERGE)

---

## 1. Résumé Exécutif

FC-08 est implémenté conformément au contrat v3.2.3 : le schéma existant a été inspecté (P1.2) puis migré (§47-52), les modèles, l'API, la documentation Swagger et les tests sont au niveau contractuel, et toutes les gates qualité passent. Ce registre trace la dette résolue et la dette restante.

## 2. État du Schéma (final — appliqué)

| Élément | État initial (P1.2) | État actuel | Cible contractuelle | Statut |
|---|---|---|---|---|
| `companies.siren` | nullable, index non-unique | **NOT NULL + UNIQUE** (index remplacé, pas dupliqué) | §47.1 : NOT NULL + UNIQUE | ✅ |
| `companies.siret` | NOT NULL + UNIQUE | **nullable**, index unique conservé | §48 : nullable + UNIQUE si non-null | ✅ |
| `companies.vat_regime` | absent | **string nullable** (aucun enum, aucun calcul) | §49 | ✅ |
| `user_companies.deleted_at` | absent | **datetime nullable** | §50, INV-21 | ✅ |
| `UNIQUE(user_id, company_id, role)` | présent | conservé | §26, INV-18 | ✅ |
| Enum `user_company_role_enum` | independent/client | conservé (aucune migration vers string) | §51 | ✅ |
| PK / FK | Company uuid ; user_id bigint → users.id ; company_id uuid → companies.id | inchangés | UUID conservés (§22-23) | ✅ |

Migration : `db/migrate/20260914000001_fc08_company_user_company_contract.rb` — garde-fou données §47.1 (refuse la migration si des companies sans SIREN existent) + `down` complet.

## 3. Dette Résolue (traitée par l'implémentation)

| Écart initial | Résolution | Preuve |
|---|---|---|
| SIREN nullable + non-unique | Migration §47.1 + validations modèle (INV-07/08/09/10) | `company_spec.rb` 27/27 ; `db/schema.rb` |
| SIRET NOT NULL | `change_column_null :companies, :siret, true` (INV-11/12) | `db/schema.rb` ; request spec Scenario 10/11 |
| `vat_regime` absent | Colonne ajoutée, stockage contextuel seul (INV-13) | `company_spec.rb` ; request specs |
| Soft delete UserCompany absent | `deleted_at` + `discard`/`undiscard`/`discarded?` (§27) | `user_company_spec.rb` 25/25 |
| Scopes maison `.only_deleted` | Remplacés par `.active`/`.deleted` explicites (§29/30, INV-19/20) | specs modèles ; audit p4_6 mis à jour |
| Aucun contrôleur companies/user_companies | API complète §36-37 (wrap §40, sécurité §42, autorisation §43, erreurs §44) | request specs 32/32 |
| Swagger FC-08 absent | 10 schémas centralisés, yaml généré depuis les specs (§58) | swaggerize 402/402 ; audit 35/35 PASSÉ |
| E2E non rejouable (constat de la vérification d'implémentation) | SIREN/SIRET dérivés du RUN_ID au lieu de valeurs en dur | `e2e_companies.sh` : 2 runs consécutifs 19/19 |

## 4. Dette Restante

| ID | Élément | Description | Priorité | Périmètre |
|---|---|---|---|---|
| D-1 | INV-01/02 par inspection | `Company` sans `user_id` / `User` sans `company_id` vérifiés par inspection du schéma (P1.2), pas par spec automatisée — à épingler par un test d'architecture si souhaité | 🟢 Faible | FC-08 |
| D-2 | Couverture de lignes (SimpleCov) | **✅ Résolue le 16/09** (PR #29) : décisions actées (D-2.1 baseline sans échec, D-2.2 Cobertura oui, D-2.3 sprint maintenant) ; implémentation `simplecov` 1.3.0 + `simplecov-cobertura` 4.0.0, boot dédié (`.rspec` charge l'app au boot — `spec/coverage_boot.rb`), **baseline mesurée : 72.78 % lignes / 44.82 % branches** (Models 84.8 %, Services 80.5 %, Controllers 61.2 % — détail : `docs/technical/testing/line_coverage.md`) ; seuil 95 % à statuer post-mesure (P6) | ✅ Résolue | Transverse |
| D-3 | ~~P10.1 — Pull Request~~ | ~~Ouvrir la PR `feature/fc-08-companies` → main~~ **MERGÉE le 15/09/2026** (PR #24) — restent les conditions post-merge CTO : tag version, déploiement staging E2E, monitoring prod 24-48h | ✅ Résolue | FC-08 |
| D-4 | Scripts E2E hérités | **RÉSOLUE 15/09** (branche `chore/d4-e2e-scripts-repair`) : `e2e_cra_lifecycle.sh` réparé — pattern `run_request`/`HTTP_CODE` (codes > 255 tronqués : 422→166, 500→244, 409→153), `"month": 09` JSON invalide → `%-m`, comparaisons décimales flottantes (awk), code mort nettoyé ; `e2e_auth_flow.sh` vérifié conforme en l'état. Rejeux : PASSED ×2 ; **vérif. 16/09** : rejeux indépendants ×2 PASSED chacun ; **MERGÉE via PR #25 le 16/09** (GREEN FOR MERGE, merge commit `8d6c9918`) — commentaire L23-24 corrigé (`4caa50ec`) | ✅ Résolue (mergée) | FC-07 / auth |
| D-5 | Brakeman préexistant | **RÉSOLUE 15/09** : durcissement `GitLedgerRepository` (garde `SAFE_ID_PATTERN` sur cra_id — refus silencieux sans invoquer Git, spec p6_1 mise à jour vers le contrat renforcé) ; `config/brakeman.ignore` régénéré (2 fingerprints ignorés avec justification, entrée obsolète supprimée) → **Brakeman 0 warning** ; ⚠️ **vérif. 16/09** : 2 offenses RuboCop introduites à L92 (`Lint/UselessConstantScoping`, `Style/RedundantFreeze`) — gate 0-offense cassée sur main, correctif `style(d5)` en attente | 🟡 Résolue (réserve RuboCop) | FC-07 |
| D-6 | Cosmétique modèle | `UserCompany` : le scope d'unicité `[:user_id, :company_id, :role]` inclut `user_id` (attribut validé) en double — fonctionnellement équivalent à `[:company_id, :role]`, aucun impact | 🟢 Faible | FC-08 |
| D-7 | Dépréciations Rack | `:unprocessable_entity` déprécié dans les matchers rspec-rails 8.0.2 — warnings cosmétiques transverses, sans rapport avec FC-08 | 🟢 Faible | Transverse |
| D-8 | Signup 500 sur body vide — **bloque CI (job E2E)** | `POST /api/v1/signup` avec `{}` rend 500 (`{"code":"INTERNAL_SERVER_ERROR","message":"param is missing…: user"}`) au lieu de 400/422 attendu par `smoke_test.sh` (test 6). Endpoint non touché par FC-08 — dernier commit le concernant : `a460dedc` (pré-FC-08, wrap_parameters). Le job E2E (skipped sur main depuis le 19/08) ne l'avait jamais détecté | 🔴 Bloque CI | Users / StandardizedError |
| D-9 | CVE rubyzip — **bloque CI (Security Audit)** | `rubyzip 3.2.2` : CVE-2026-85396 (High, path traversal, fix ≥ 3.4.0), advisory DB du 13/09/2026 — postérieure au dernier CI vert (main, 31/08). Dépendance transitive (rswag), pas introduite par FC-08. `bundle audit check --update` échoue | 🔴 Bloque CI | Transverse |
| D-10 | Isolation bases test/dev (conteneur) | **RÉSOLUE 15/09** : `foresy_test` créée, procédure documentée dans `docs/technical/testing/test_database_isolation.md` (piège DATABASE_URL, TRUNCATE dev). Validation : suite 956/0 après rejeu E2E ×2 — isolement prouvé | ✅ Résolue | Transverse |
| D-11 | Dépréciation Node.js 20 dans les actions GitHub — **5 warnings CI/CD** | **RÉSOLUE le 16/09** (branche `chore/d2-d11-quality-tooling`) : `actions/checkout` v4→v5 (×5, **Node 24 natif** — annotations disparues sur les jobs sans upload) et `actions/upload-artifact` v4→**v7** (×3 — v5 ciblait encore Node 20, **constaté par l'annotation CI du 16/09** ; v7.0.1 = dernière stable) dans `ci.yml` ; gate : run CI vert **et 0 warning Node** sur la PR | ✅ Résolue (merge PR #28, `689a4b15`) | CI/CD transverse |
| D-12 | Scripts E2E shell hors CI (constat revue CI co-CTO 16/09, P1b) | `e2e_cra_lifecycle.sh` / `e2e_auth_flow.sh` (réparés D-4, PASSED ×3/×2 en HTTP réel local) ne sont pas exécutés dans le job E2E de la CI — cause vérifiée : `LEDGER_PATH` = `/app/cra-ledger` **codé en dur** (conteneur Docker ; inexistant/non créable sur les runners GitHub, L13 ; les specs isolent en tmpdir) ; statut formel retenu (option b, co-CTO) : **gates de vérification manuelle HTTP réel** ; intégration CI future en rendant `LEDGER_PATH` configurable (ENV) — à chiffrer séparément | 🟡 Moyenne | CI/CD / E2E |

## 5. Plan d'Action — CI Gate PR #24 (avant merge)

> Constat : RuboCop corrigé (`7262d92c`) ; Tests & Coverage et API Contracts verts. **D-8 et D-9 bloquent les 2 jobs restants** (E2E, Security Audit) ; Quality Gate est agrégat. Discipline « one feature = one contract » : correctifs en commits séparés, étiquetés, sur accord CTO.

| # | Action | Étape | Validation | Statut |
|---|---|---|---|---|
| 1 | **D-9 — rubyzip** | `bundle update rubyzip` (→ ≥ 3.4.0), commit `chore(security)` | `bundle-audit check --update` → 0 vuln ; job Security Audit vert | ✅ Fait 15/09 (`17943769`) |
| 2 | **D-8 — signup 500** | Mécanisme confirmé (rescuable.rb : dernier déclaré gagne) ; `StandardError` déclaré en premier dans `StandardizedError` ; RED spec ajouté (`users_spec.rb`) ; commit `fix(signup)` | Suite 956/0 ; smoke 15/15 ; p1_2 (500 générique) reste vert ; job E2E vert attendu | ✅ Fait 15/09 (`19b9c16c`) |
| 3 | **D-10 — isolement** | `env -u DATABASE_URL RAILS_ENV=test bin/rails db:prepare` dans le conteneur ; documenter la procédure (dev guide) | Suite verte après rejeu E2E ×2 (plus de pollution croisée) | ⬜ À faire |
| 4 | **Gate finale** | Push → re-vérifier les 6 checks de PR #24 | **6/6 verts le 15/09** (head `aeac4a77`) → GO merge (CTO) | ✅ Fait |

## 6. Prochaines Actions

1. **`style(d5)`** — ✅ Fait 16/09 (`650d80c1`) : `SAFE_ID_PATTERN` déplacée au niveau module + `.freeze` retiré — RuboCop 235 fichiers 0 offense, suite 957/0
2. **PR D-4** — ✅ **PR #25 MERGÉE** le 16/09 12:53 UTC (merge commit `8d6c9918`, verdict co-CTO GREEN FOR MERGE) — branche complète : D-4 + correctifs A1/A3/A4/A7 + docs de suivi ; CI 6/6 verts pré-merge
3. **`docs(d5)`** — ✅ Fait 16/09 (`4caa50ec`) : journal rectifié — p6_1 = 10/0 (23 = somme 13+10 des deux specs D-5)
4. **Mémoire** — ✅ `fc08::007` **validée humain** le 16/09 (co-CTO, GREEN FOR MERGE) — pas de `fc08::008` (« pas de travail supplémentaire ») ; entrée amendée à l'état final + hub resynchronisé
5. **D-2** (transverse) — ✅ **résolue le 16/09** : décisions actées (D-2.1 baseline sans échec / D-2.2 Cobertura / D-2.3 sprint), implémentation + **baseline mesurée 72.78 % lignes / 44.82 % branches** (guide `docs/technical/testing/line_coverage.md`) ; seuil 95 % à statuer post-mesure (P6)
6. **D-11** (hors FC-08) — ✅ bump posé le 16/09 (branche `chore/d2-d11-quality-tooling` : `checkout@v5` ×5 + `upload-artifact@v7` ×3 — v5 d'upload-artifact ciblait encore Node 20, corrigé après lecture des annotations CI) — ✅ **mergée via PR #28** (`689a4b15`), 6/6 verts + 0 annotation Node vérifié
7. **Hygiène identité Git** — ✅ **A6 close le 16/09, mergée via PR #27** (`8d19bce8`) : `.git/config` corrigé (racine des 181 commits `foresy-ledger`) ; conteneur vérifié — bind mount `.:/app:cached`, config partagée ; identité **auto-réparante** via la commande du service `web` (compose, surcharge `GIT_USER_NAME`/`GIT_USER_EMAIL`) ; ledger `cra-ledger` non concerné (identité `foresy-ledger` posée par `GitLedgerRepository.configure_identity` avec `chdir LEDGER_PATH` — scopée, par design)
8. **A7 (nouvelle, détectée en revue conjointe 16/09)** — ✅ CI corrigée (`11432c68`) : `--ignore-config` pointé vers `config/brakeman.ignore` — le fichier racine référencé depuis `3ce4c7d7` (30/01) n'existait plus ; suivi dédié : `docs/technical/d1_d11_corrective_actions_tracker.md`
9. **Gate CI — revue co-CTO 16/09 (CHANGES REQUESTED sur PR #29)** — ✅ corrections appliquées sur la branche : **P0** E2E bloquant dans la Quality Gate (success ou `skipped` hors PR, échecs affichés explicitement) ; **P1** Brakeman strict (retrait `--no-exit-on-warn` — tout warning non ignoré fait échouer le job) ; **recommandations appliquées** : assertion bloquante `coverage/coverage.xml` dans le job tests, gate DDD explicite `🏛️` (invariants + p4_6) ; **D-12 créée** (E2E shell hors CI, `LEDGER_PATH`)

## 7. Vérification d'implémentation (16/09/2026)

Vérification platinium D-1→D-11 : **fond conforme** (suite 957/0, Brakeman 0, bundle-audit 0, smoke 15/15, E2E rejoués ×2) ; 4 anomalies documentées (RuboCop cassé par D-5 ; PR D-4 non ouverte ; commentaire obsolète L23-24 ; journal D-5 surévalué p6_1 10/0 vs « 23/0 ») — rapport complet : `docs/technical/changes/2026-09-16-D1-D11_Debt_Verification_Report.md`.

**Revue conjointe CTO du 16/09 (après-midi)** : anomalies A1-A4 re-contrôlées par exécution puis corrigées (A1 `650d80c1` ; A3+A4 `4caa50ec`) ; A5 constatée **périmée** (le hub indexe déjà `fc08::007` et `fc08::006` à jour) ; **A7 détectée** (CI `--ignore-config` vers un fichier supprimé) et corrigée (`11432c68`) ; A6 racine corrigée (`.git/config` du dépôt → identité humaine). Gates froides : RuboCop 235 fichiers 0 offense, suite 957/0. Suivi dédié : `docs/technical/d1_d11_corrective_actions_tracker.md`.

**Merge PR #25 (16/09, 12:53 UTC)** : merge commit `8d6c9918` — **verdict co-CTO GREEN FOR MERGE** (platinium confirmé : gates, traçabilité, commits séparés, TDD/DDD, aucun bruit) ; anomalies A1/A3/A4/A7 closes, A5 close (`fc08::007` validée humain). Restent : A6 conteneur (PR séparée), D-2 SimpleCov (chiffrage), D-11 Node 24 (opportuniste) — décisions co-CTO de la revue du 16/09.

---

## Références

- Contrat FC-08 v3.2.3 : `docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]`
- Plan de suivi : `docs/technical/fc08_implementation_tracker.md`
- Rapport de couverture : `docs/technical/testing/fc08_coverage_report.md`
- Invariants : INV-01 à INV-22 (contrat, lignes 1606-1694)