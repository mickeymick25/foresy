# FC-08 — Rapport de Couverture de Tests

**Date :** 14 septembre 2026
**Contrat :** FC-08 v3.2.3 — Company & User–Company Relationships
**Autorité :** `docs/FeatureContract/08_Feature Contract — Entreprise Indépendant_[3.2.3]`
**Branche :** `feature/fc-08-companies` — Phases 1-9 complètes (16/19), P10.1 (PR) en attente

---

## 1. Synthèse par couche de test

| Couche | Fichiers FC-08 | Exemples | Résultat | Périmètre contractuel |
|---|---|---|---|---|
| **Model specs** | `spec/models/company_spec.rb`, `spec/models/user_company_spec.rb` | 27 + 25 = 52 | ✅ 0 échec | §56 (règles domaine), INV-07…13, INV-18…21 |
| **Request specs** | `spec/requests/api/v1/companies/`, `spec/requests/api/v1/user_companies/` | 19 + 13 = 32 | ✅ 0 échec | §57 (endpoints, auth, autorisation, erreurs, flat JSON) |
| **RSwag** | specs request + `swagger_helper.rb` (10 schémas FC-08) | 402 (toutes features) | ✅ 0 échec | §58 (doc générée depuis specs) |
| **Régression FC-06** | missions + mission_lifecycle | 21 | ✅ 0 échec | §59 |
| **Régression FC-07** | cras + cra_entries + cra_services | 158 | ✅ 0 échec | §60 |
| **Suite complète** | tout `spec/` | 948 | ✅ 0 échec | §61 Quality Gates |
| **E2E (HTTP réel)** | `bin/e2e/e2e_companies.sh` | 17 étapes / 19 assertions | ✅ 19/19 ×2 runs | §55 scénarios 1,2,3,4,5,6,8,9,10,12,13,14,15 |
| **Audit d'architecture** | `spec/integration/p4_6_default_scope_removal_spec.rb` (Company → `.deleted`) | 20 | ✅ 0 échec | INV-19/20 |

Toutes les exécutions datées du 14/09/2026, environnement test + serveur de dev réel pour l'E2E.

### 1.1 Gates qualité (re-vérifiées le 14/09/2026, conteneur Docker)

| Gate | Commande | Résultat |
|---|---|---|
| RuboCop | `bundle exec rubocop` | 234 fichiers, 0 offense ✅ |
| Brakeman | `bundle exec brakeman` | 0 warning FC-08 ; 2 préexistants CRA (dette D-5) ✅ |
| Audit routes ↔ Swagger | `bundle exec rake swagger:audit_coverage` | 35/35 routes — PASSÉ ✅ |
| RSwag swaggerize | `bundle exec rake rswag:specs:swaggerize` | 402 exemples, 0 échec ✅ |

---

## 2. Matrice de traçabilité — Invariants → Tests

| Invariant | Modèle | Request | E2E | Preuve principale |
|---|---|---|---|---|
| INV-01 Company sans FK user | ✅ schéma | — | — | P1.2 (inspection `schema.rb`) |
| INV-02 User sans FK company | ✅ schéma | — | — | P1.2 |
| INV-03 UserCompany = la relation | ✅ model | ✅ CRUD | ✅ | associations + API |
| INV-04 User sans Company | ✅ schéma | ✅ GET vide | ✅ scénario 1 | aucune company auto-créée |
| INV-05 Pas de company fictive | — | ✅ GET vide | ✅ scénario 1 | liste = [] |
| INV-06 Role contextuel | ✅ enum UserCompany | ✅ | — | §24/25 |
| INV-07 SIREN obligatoire | ✅ model + DB NOT NULL | ✅ 422 | ✅ scénario 8 | validation + contrainte |
| INV-08 SIREN valide | ✅ format 9 digits | ✅ 422 | ✅ | format + garde DB |
| INV-09 SIREN unique | ✅ model + DB UNIQUE | ✅ 422 | ✅ scénario 9 | index unique `index_companies_on_siren` |
| INV-10 SIREN présent+valide+unique | ✅ combiné | — | — | company_spec |
| INV-11 SIRET nullable | ✅ DB nullable | ✅ 201 | ✅ scénario 10 | siret NULL accepté |
| INV-12 SIRET unique si présent | ✅ model + DB UNIQUE | ✅ 422 | — | index `index_companies_on_siret` |
| INV-13 vat_regime contextuel | ✅ stockage | ✅ PATCH | — | aucune logique de calcul |
| INV-14 Legal form contextuelle | ✅ nullable | — | — | pas d'enum PG |
| INV-15 Pas d'entité simulée | — | — | — | hors périmètre code |
| INV-16 Onboarding atomique | ✅ transaction service | ✅ 201 | ✅ scénario 2 | `CompanyServices::Create` |
| INV-17 Pas d'orphelin | ✅ rollback | ✅ 422 | ✅ scénario 12 | 0 Company persistée |
| INV-18 Unicité (user, company, role) | ✅ model + DB | ✅ 422 | ✅ scénarios 5/6 | index `unique_user_company_role` |
| INV-19 Scopes explicites | ✅ .active/.deleted | ✅ listes | ✅ étape 16 | specs scopes |
| INV-20 Pas de default_scope | ✅ `default_scopes` vide | — | — | p4_6 + specs |
| INV-21 Soft delete | ✅ discard/undiscard | ✅ DELETE 200 | ✅ scénario 14 | deleted_at persisté |
| INV-22 Role hors wrapper Company | ✅ wrap_parameters | ✅ flat JSON | ✅ scénario 15 | role lu séparément |

**Invariants entièrement couverts : 19/22** (INV-15 hors code, INV-01/02 par inspection du schéma plutôt que par spec automatisée — voir dette D-1).

---

## 3. Règles de champ (§19/§45) — traçabilité

| Règle contractuelle | Test automatisé |
|---|---|
| name obligatoire | company_spec (presence + longueur) |
| SIREN présent/valide/unique | company_spec ×4 (présence, format 9, unicité model, contrainte DB) |
| SIRET optionnel/unique/format 14 | company_spec + contrainte DB (plusieurs NULL permis) |
| legal_form nullable | company_spec |
| vat_regime stocké sans calcul | company_spec (INV-13) |
| country défaut FR | company_spec |
| currency default EUR | company_spec |
| Role ∈ {independent, client} (§25) | user_company_spec (enum strict + DB) |
| Pas de résurrection implicite (§27) | user_company_spec (RecordNotUnique) |
| Scopes .active/.deleted (§29/30) | specs des deux models + p4_6 |

## 4. Endpoints (§36/§37) — traçabilité

| Endpoint | Request specs | RSwag | E2E |
|---|---|---|---|
| GET /companies | ✅ vide + filtrage relation active | ✅ | ✅ |
| POST /companies (onboarding atomique §38) | ✅ 4 scénarios création + 4 rejets | ✅ | ✅ |
| GET /companies/:id | ✅ 200/403/404 | ✅ | ✅ |
| PATCH /companies/:id | ✅ 200/403 | ✅ | ✅ |
| DELETE /companies/:id (soft) | ✅ 200/403 | ✅ | ✅ |
| GET /user_companies | ✅ propriétaire seul | ✅ | ✅ |
| POST /user_companies | ✅ ajout role / doublon / invalide / user_id ignoré | ✅ | ✅ |
| PATCH /user_companies/:id (role only §37.3) | ✅ attributs protégés ignorés | ✅ | — |
| DELETE /user_companies/:id (soft) | ✅ 200/403 | ✅ | ✅ |

## 5. Ce que les tests ne couvrent PAS (renvoi au registre de dette)

- Couverture de **lignes** (SimpleCov) : aucun outil en place — chantier D-2 (voir `fc08_debt_register.md`)
- INV-01/02 : absence de FK vérifiée par inspection, pas par spec automatisée
- Scripts E2E hérités (`e2e_cra_lifecycle.sh`, `e2e_auth_flow.sh`) : bugs latents préexistants

---

**Références :** tracker `docs/technical/fc08_implementation_tracker.md` · registre de dette `docs/technical/fc08_debt_register.md` · contrat §54-63