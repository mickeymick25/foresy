# FC-08 — État de la Dette (Registre)

**Date de mise à jour :** 14 septembre 2026
**Contrat :** FC-08 v3.2.3
**Autorité :** `docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]`
**Statut :** 🟢 Phases 1-9 terminées — seule P10.1 (PR) restante

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
| D-2 | Couverture de lignes (SimpleCov) | Aucun outil de couverture de lignes en place (gem absente, `coverage/` vide) — chantier transverse à chiffrer séparément | 🟡 Moyenne | Transverse |
| D-3 | P10.1 — Pull Request | Ouvrir la PR `feature/fc-08-companies` → main (description, evidence de tests, checklist Definition of Done) | 🔴 Restante | FC-08 |
| D-4 | Scripts E2E hérités | `e2e_cra_lifecycle.sh` et `e2e_auth_flow.sh` : bugs latents préexistants (return HTTP > 255 tronqué, parse d'environnement) les rendant inexécutables — réparation complète hors périmètre FC-08 | 🟡 Moyenne | FC-07 / auth |
| D-5 | Brakeman préexistant | 2 warnings Command Injection dans `GitLedgerRepository` (code CRA, commits 10680ec2/a0ea0f97) + 1 entrée d'ignore obsolète — documentés per contrat §63 step 12 | 🟡 Moyenne | FC-07 |
| D-6 | Cosmétique modèle | `UserCompany` : le scope d'unicité `[:user_id, :company_id, :role]` inclut `user_id` (attribut validé) en double — fonctionnellement équivalent à `[:company_id, :role]`, aucun impact | 🟢 Faible | FC-08 |
| D-7 | Dépréciations Rack | `:unprocessable_entity` déprécié dans les matchers rspec-rails 8.0.2 — warnings cosmétiques transverses, sans rapport avec FC-08 | 🟢 Faible | Transverse |
| D-8 | Signup 500 sur body vide — **bloque CI (job E2E)** | `POST /api/v1/signup` avec `{}` rend 500 (`{"code":"INTERNAL_SERVER_ERROR","message":"param is missing…: user"}`) au lieu de 400/422 attendu par `smoke_test.sh` (test 6). Endpoint non touché par FC-08 — dernier commit le concernant : `a460dedc` (pré-FC-08, wrap_parameters). Le job E2E (skipped sur main depuis le 19/08) ne l'avait jamais détecté | 🔴 Bloque CI | Users / StandardizedError |
| D-9 | CVE rubyzip — **bloque CI (Security Audit)** | `rubyzip 3.2.2` : CVE-2026-85396 (High, path traversal, fix ≥ 3.4.0), advisory DB du 13/09/2026 — postérieure au dernier CI vert (main, 31/08). Dépendance transitive (rswag), pas introduite par FC-08. `bundle audit check --update` échoue | 🔴 Bloque CI | Transverse |
| D-10 | Isolation bases test/dev (conteneur) | Le conteneur web exporte `DATABASE_URL=…foresy_development` → RSpec et E2E partagent la base dev ; `foresy_test` n'existe pas localement. La pollution E2E (10 companies, 13 users `e2e-*`, SIREN 123456789 en dur) a fait échouer 28 tests — fausse alerte de régression. Base nettoyée le 15/09 → 955/955 vert. À créer : `foresy_test` + procédure documentée | 🟡 Moyenne | Transverse |
| D-11 | Dépréciation Node.js 20 dans les actions GitHub — **5 warnings CI/CD** | `actions/checkout@v4` et `actions/upload-artifact@v4` tournent sous Node 20, forcé par GitHub vers Node 24 (constat CTO, 5 warnings sur la CI de PR #24, 15/09). Non bloquant, sans rapport avec FC-08. Fix futur : bump des versions d'actions dans `.github/workflows/ci.yml` quand les versions compatibles Node 24 sont stabilisées, avec run CI vert avant merge | 🟢 Faible | CI/CD transverse |

## 5. Plan d'Action — CI Gate PR #24 (avant merge)

> Constat : RuboCop corrigé (`7262d92c`) ; Tests & Coverage et API Contracts verts. **D-8 et D-9 bloquent les 2 jobs restants** (E2E, Security Audit) ; Quality Gate est agrégat. Discipline « one feature = one contract » : correctifs en commits séparés, étiquetés, sur accord CTO.

| # | Action | Étape | Validation | Statut |
|---|---|---|---|---|
| 1 | **D-9 — rubyzip** | `bundle update rubyzip` (→ ≥ 3.4.0), commit `chore(security)` | `bundle-audit check --update` → 0 vuln ; job Security Audit vert | ✅ Fait 15/09 (`17943769`) |
| 2 | **D-8 — signup 500** | Mécanisme confirmé (rescuable.rb : dernier déclaré gagne) ; `StandardError` déclaré en premier dans `StandardizedError` ; RED spec ajouté (`users_spec.rb`) ; commit `fix(signup)` | Suite 956/0 ; smoke 15/15 ; p1_2 (500 générique) reste vert ; job E2E vert attendu | ✅ Fait 15/09 (`19b9c16c`) |
| 3 | **D-10 — isolement** | `env -u DATABASE_URL RAILS_ENV=test bin/rails db:prepare` dans le conteneur ; documenter la procédure (dev guide) | Suite verte après rejeu E2E ×2 (plus de pollution croisée) | ⬜ À faire |
| 4 | **Gate finale** | Push → re-vérifier les 6 checks de PR #24 | **6/6 verts le 15/09** (head `aeac4a77`) → GO merge (CTO) | ✅ Fait |

## 6. Prochaines Actions

1. **D-3 / P10.1** — Merge de PR #24 (gate finale passée : 6/6 checks verts, 15/09)
2. **D-10** (hors FC-08) — Créer `foresy_test` dans le conteneur + documenter la procédure d'isolement
3. **D-4** (hors FC-08) — Réparer `e2e_cra_lifecycle.sh` / `e2e_auth_flow.sh`
4. **D-5** (hors FC-08) — Traiter les warnings Brakeman préexistants `GitLedgerRepository` et l'entrée d'ignore obsolète
5. **D-11** (hors FC-08) — Bump des actions GitHub (Node 24) : `checkout`/`upload-artifact` — dette CI/CD, opportuniste
6. **D-2** (transverse) — Couverture de lignes (SimpleCov) à chiffrer

---

## Références

- Contrat FC-08 v3.2.3 : `docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]`
- Plan de suivi : `docs/technical/fc08_implementation_tracker.md`
- Rapport de couverture : `docs/technical/testing/fc08_coverage_report.md`
- Invariants : INV-01 à INV-22 (contrat, lignes 1606-1694)