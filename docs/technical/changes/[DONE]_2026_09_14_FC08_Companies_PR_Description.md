# FC-08 — Company & User-Company Relationships (v3.2.3) — Description de PR

**Date :** 14 septembre 2026
**Contrat :** `docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]` (gelé, Implementation-Ready / TDD-Ready)
**Branche :** `feature/fc-08-companies` → `main`
**Plan de suivi :** `docs/technical/[DONE]_2026_08_31_fc08_implementation_tracker.md` (16/19 tâches + DoD 9/9)

---

## 1. Résumé

Implémentation complète de FC-08 selon le contrat v3.2.3, en TDD strict (RED mesurés → GREEN), DDD/RDD, niveau Platinum :

- **Migration `20260914000001`** (§47-52) : `companies.siren` NOT NULL + UNIQUE (index remplacé, pas dupliqué), `siret` nullable (unique conservé, multi-NULL PostgreSQL), `vat_regime` string nullable, `user_companies.deleted_at` (soft delete, INV-21) ; enum conservé ; garde-fou données §47.1 + `down` complet.
- **Models** : `Company` (SIREN requis/valide/unique INV-07…10, SIRET optionnel INV-11/12, `vat_regime` INV-13, scopes `.active`/`.deleted` §29, pas de default_scope INV-20) ; `UserCompany` (unicité `(user_id, company_id, role)` INV-18, soft delete §27, pas de résurrection implicite).
- **API (§36-44)** : `CompaniesController` + `UserCompaniesController` — CRUD, onboarding atomique `CompanyServices::Create` (INV-16/17), `wrap_parameters :company` sans role (INV-22), paramètres forts (§42), autorisation via relation active (§43), erreurs standardisées plates (§44).
- **RSwag (§58)** : 10 schémas centralisés FC-08 (dont `ErrorStandardized` plat), yaml régénéré depuis les specs, audit routes↔Swagger 35/35 PASSÉ.
- **E2E** : `bin/e2e/e2e_companies.sh` — 17 étapes / 19 assertions en HTTP réel, **rejouable** (SIREN/SIRET dérivés du RUN_ID), 2 runs consécutifs 19/19.

## 2. Evidence de tests

| Gate | Commande | Résultat |
|---|---|---|
| Model specs | `bundle exec rspec spec/models/company_spec.rb spec/models/user_company_spec.rb` | 52 exemples, 0 échec |
| Request specs | `bundle exec rspec spec/requests/api/v1/companies spec/requests/api/v1/user_companies` | 32 exemples, 0 échec |
| Suite complète | `bundle exec rspec` | 948 exemples, 0 échec |
| Régression FC-06 (§59) | missions + mission_lifecycle | 21, 0 échec |
| Régression FC-07 (§60) | cras + cra_entries + cra_services | 158, 0 échec |
| RSwag | `rake rswag:specs:swaggerize` | 402, 0 échec |
| Audit routes | `rake swagger:audit_coverage` | 35/35 PASSÉ |
| RuboCop | `bundle exec rubocop` | 234 fichiers, 0 offense |
| Brakeman | `bundle exec brakeman` | 0 warning FC-08 (2 préexistants CRA documentés — dette D-5) |
| E2E | `./bin/e2e/e2e_companies.sh` | 19/19 ×2 runs |

## 3. Commits (18)

| Commit | Contenu |
|---|---|
| `b7f3cb0e` | docs: réorganisation + contrats FC-08 v3.0-v3.2.3 + gitignore AGENTS.md/.rag.yaml |
| `ef08f332` | P1.1-P1.2 gel contrat + vérification schéma |
| `eba1b396` | P2.1 RED Company model specs (27 ex, 9 RED attendus) |
| `616c70d5` | P3.1 migration contrat Company/UserCompany |
| `874d347c` | P4.1 Company model GREEN — 27/27 |
| `d71b2ed9` | P2.2 RED UserCompany model specs (25 ex, 11 RED attendus) + factory alignée |
| `cf9436ab` | P4.2 UserCompany model GREEN — 25/25 |
| `50d48157` | P5 request specs RED (19 + 13 ex) + routes API |
| `5c54f424` | P6 contrôleurs + services GREEN — 32/32, suite 948/948 |
| `f402b118` | P7-P9 swagger (10 schémas, audit OK) + quality gates + régression |
| `5bf46211` / `2a30a5b2` | db: schema.rb régénéré / newline migration |
| `a3f064a6` | docs: checklist Definition of Done vérifiée |
| `2656cc29` | test: E2E companies (19/19 HTTP réel) + compat scripts hérités |
| `17b5f8b0` | docs: figer registre de dette + rapport de couverture |
| `ec2690a3` | memory: FC-08 implémenté + dette transverse |
| `93585863` | test: rejouabilité e2e_companies + journal vérification |

## 4. Definition of Done (✅ 9/9 — détail dans le tracker)

- [x] Architecture RDD : Company sans user_id, User sans company_id, UserCompany explicite, no default_scope
- [x] Database : UUID PK, SIREN NOT NULL+UNIQUE, SIRET nullable+unique, vat_regime, UserCompany.deleted_at, enum conservé
- [x] Models : validations + scopes explicites
- [x] API : CRUD, atomicité, PATCH role only, autorisation, erreurs standardisées, wrap_parameters
- [x] TDD : RED mesurés (9 + 11 + 32 échecs attendus) avant chaque GREEN
- [x] RSwag : endpoints documentés depuis les specs
- [x] Quality : RSpec/RSwag 0 échec, RuboCop 0 offense, Brakeman 0 warning FC-08
- [x] Regression : FC-06 green, FC-07 green, pas de breaking change
- [x] Git : feature branch, commits atomiques, evidence de tests

## 5. Couverture & Dette

- **Rapport de couverture** : `docs/technical/testing/[DONE]_2026_09_14_fc08_coverage_report.md` — 19/22 invariants entièrement couverts (matrice INV-01→22)
- **Registre de dette** : `docs/technical/2026_09_14_fc08_debt_register.md` — D-1…D-7 (dont D-2 SimpleCov, D-4 scripts E2E hérités, D-5 Brakeman préexistants — hors périmètre FC-08)
- **Mémoire hub RAG** : `foresy__memories` fc08::001…005

## 6. Points d'attention pour la revue

1. `.only_deleted` → `.deleted` sur `Company`/`UserCompany` (exigence contrat §29/30) — les autres models (Cra, CraEntry, Mission) gardent `.only_deleted` (alignement futur hors périmètre)
2. Erreurs API **plates** `{code, message, details}` (§44, format `render_error` existant) — le helper de test `ErrorResponseHelper` attend un format imbriqué et n'est pas aligné (fc08::005)
3. P8.4 adapté : pas de tag `:swagger` dans la maison — équivalent `rake rswag:specs:swaggerize` + `rake swagger:audit_coverage`
4. Brakeman : 2 warnings Command Injection **préexistants** dans `GitLedgerRepository` (code CRA, hors périmètre) — documentés per §63 step 12

---
*Description générée le 14/09/2026 — FC-08 v3.2.3 — feature/fc-08-companies*