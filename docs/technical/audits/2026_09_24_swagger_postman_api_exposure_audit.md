# 🔍 Audit Fraîcheur & Complétude — Swagger · Exposition API · Collection Postman

**Date de l'audit :** 24 septembre 2026
**Auditeur :** Zed Agent (revue automatisée, demande CTO)
**Statut document :** ✅ Analyse terminée — plan d'intégration **ouvert** (P1-P5, §6)
**Sources de vérification :** lecture directe `config/routes.rb`, `swagger/v1/swagger.yaml`,
`docs/postman/Foresy_API.postman_collection.json`, `lib/tasks/swagger_audit.rake`,
`lib/tasks/swagger_validate_schemas.rake`, `.github/workflows/ci.yml`, `Gemfile`,
historique git (dates de dernier commit par artefact) + requêtes RAG `foresy__knowledge`.
**Autorité :** ce document est la source de vérité des chantiers P1-P5 ; les entrées
correspondantes de `docs/BACKLOG.md` pointent ici (règle anti-drift du backlog).

---

## 1. Synthèse exécutive

| Artefact | Verdict | Constat central |
|---|---|---|
| **Swagger** (`swagger/v1/swagger.yaml`) | 🟢 Frais, 1 manque contractuel | Régénéré au commit FC-08 `f402b118` (14/09) — même commit que le dernier changement de `routes.rb` : **zéro drift structurel**. CI régénère + audite à chaque PR. Mais `GET /api/v1/cras/{id}/export` est **absent** (exclusion volontaire de l'audit) et la divergence #13 (`name` OAuth) persiste. |
| **Exposition des API** | 🟢 Propre | 36 endpoints API v1 + health (2) + root. `__test_support__` verrouillé en prod (défense en profondeur vérifiée). `/api-docs` non exposé en production (gems rswag en groupe dev/test uniquement). |
| **Collection Postman** | 🔴 Obsolète — retard d'un cycle produit | Dernière MAJ 19/08 (`37f2f8d4`) — **avant FC-08**. 28 requêtes, **0 des 10 endpoints FC-08** (Companies + UserCompanies). Description revendique « 28 endpoints » (faux depuis le 15/09 : 36). **Aucune protection anti-drift.** |

**Conclusion** : la chaîne Swagger ↔ routes est bien gouvernée (CI). Le chantier prioritaire est
la **résynchronisation Postman (P1)**, suivi de la **requalification de l'exclusion de l'export
CSV dans Swagger (P2)**. Les items P3-P5 sont de l'hygiène.

---

## 2. Méthodologie

1. Extraction des routes réelles depuis `config/routes.rb` (source de vérité de l'exposition).
2. Extraction des chemins/opérations de `swagger.yaml` (20 paths, 37 opérations).
3. Extraction des requêtes de la collection Postman (jq, 28 requêtes, 5 dossiers).
4. Lecture du rake `swagger:audit_coverage` et du job CI `contracts` pour comprendre ce que
   l'audit mesure et ce qu'il exclut.
5. Datation de chaque artefact par `git log` (dernier commit le touchant).
6. Croisement avec le hub RAG (`foresy__knowledge`) pour l'historique : audit 35/35 revendiqué
   dans le README, plan de complétion Swagger de février 2026, divergence #13.

---

## 3. Swagger — constats détaillés

### 3.1 Fraîcheur : ✅
- `swagger.yaml` : dernier commit **2026-09-14** (`f402b118` — FC-08 P7-P9, 10 schémas centralisés,
  audit routes OK). Aucun changement de `routes.rb` depuis le même commit.
- Le job CI `contracts` (`.github/workflows/ci.yml` L285, L297) régénère la spec
  (`rswag:specs:swaggerize`) puis exécute `rake swagger:audit_coverage` à chaque PR : le drift
  **est détecté automatiquement** et bloquant.
- « Audit 35/35 » (README) vérifié : 36 routes API v1 réelles − 1 exclusion (export CSV) = 35
  routes auditées, 35 documentées. Le chiffre est exact **au périmètre des exclusions près** (§3.2).

### 3.2 Manques & divergences
| ID | Constat | Impact | Gravité |
|---|---|---|---|
| **S-1** | `GET /api/v1/cras/{id}/export` (export CSV, endpoint **public réel** : présent dans `routes.rb` L48, documenté README L95, présent Postman) est **absent de `swagger.yaml`**. Il est exclu de l'audit via `EXCLUDED_ENDPOINTS` (`swagger_audit.rake` L80) au motif « File download (CSV), non-standard JSON response ». | Les consommateurs de la spec ne voient pas un endpoint public. OpenAPI 3.0 supporte pourtant les réponses binaires (`text/csv`, `schema: {type: string, format: binary}`). | 🟠 Contrat incomplet |
| **S-2** | Divergence contrat ↔ réponse : le payload user du callback OAuth inclut `name`, non déclaré au schéma RSwag (`oauth_spec.rb`) — déjà tracée **BACKLOG #13** (revue CTO 20/09, PR #39). Ne pas dupliquer ici : pointer. | Contrat ≠ production. | 🟠 (déjà suivi) |
| **S-3** | Bruit de contrat : `GET /api/v1/auth/login` est documenté (summary « Test Redis unavailable - fail closed », réponse 404 « endpoint does not exist ») — un endpoint inexistant se retrouve dans la spec, héritage des specs négatives de rate-limiting. | Spéculation possible sur un endpoint qui n'existe pas. | 🟢 Hygiène |
| **S-4** | `/up` (Rails health) présent dans `routes.rb` L11 mais absent de la spec (seul `/health` y est). Les deux sont exclus de l'audit (`EXCLUDED_PATHS`). | Nul en pratique (non contractuel). | 🟢 Acceptable |

**Verdict Swagger** : mécanique de fraîcheur saine et verrouillée en CI. Le seul manque réellement
contractuel est **S-1** ; S-2 est déjà suivi ; S-3/S-4 sont de l'hygiène.

---

## 4. Exposition des API — constats

| Vérification | Résultat |
|---|---|
| Routes API v1 | **36 endpoints** : 7 auth (login, refresh, logout, revoke, revoke_all, OAuth callback, failure) + 1 signup + 5 companies + 5 user_companies + 5 missions + 8 cras (dont submit/lock/export) + 5 cra_entries |
| Santé / racine | `GET /health`, `GET /up`, `GET /` (root JSON « API is live ») — non contractuels |
| `__test_support__/e2e/*` | ✅ Montés **uniquement** en `Rails.env.test?` ou `E2E_MODE=true && !production` (`routes.rb` L66-73) + garde contrôleur (défense en profondeur, P0.1 `884a3da4`) |
| `/api-docs` (Swagger UI) | ✅ Monté seulement `if defined?(Rswag::Ui)` — gems `rswag`, `rswag-specs`, `rswag-ui` en `group :development, :test` (`Gemfile` L55-61) → **non monté en production** |
| Rate limiting | Login 5/min, signup 3/min, refresh 10/min (FC-05) — inchangé |

**Verdict exposition** : 🟢 rien à corriger. Aucune route interne exposée, aucune surface
non désirée détectée. Le root et les routes santé sont volontairement hors contrat (exclusions
formalisées dans le rake d'audit).

---

## 4bis. Collection Postman — constats détaillés

**Fichier** : `docs/postman/Foresy_API.postman_collection.json` — **dernier commit 2026-08-19**
(`37f2f8d4` « collection Postman complete (28 endpoints) + config Supabase »).

| ID | Constat | Gravité |
|---|---|---|
| **PM-1** | **0 des 10 endpoints FC-08** : aucun dossier Companies (5 requêtes manquantes) ni UserCompanies (5 requêtes manquantes). Onboarding atomique, SIREN, rôles, soft delete — tout ce qui a été livré en PR #24 est absent de la collection. | 🔴 Blocant pour le debug production de FC-08 |
| **PM-2** | La description de collection revendique « 28 endpoints » — l'API v1 en compte **36** depuis le 14/09. La revendication est fausse depuis FC-08. | 🟠 |
| **PM-3** | Variables de collection : `base_url, jwt_token, refresh_token, mission_id, cra_id, entry_id` — **pas de `company_id`, `user_company_id`**. | 🟠 |
| **PM-4** | Aucun mécanisme anti-drift : contrairement à Swagger (audit CI bloquant), la collection n'est comparée à rien. Rien ne détectera le prochain retard. | 🟠 |
| **PM-5** | Dossier Health : `GET /` et `GET /health` présents, `GET /up` absent — cohérent avec le statut non contractuel, mais à harmoniser si P5 est retenu. | 🟢 |

**Verdict Postman** : 🔴 la collection décrit l'API d'**août 2026**, pas celle de septembre.
Elle est utile pour auth/missions/CRAs, muette sur FC-08.

---

## 5. Tableau de bord des écarts

| Artefact | Conforme | Écart bloquant | Écart recommandé | Hygiène |
|---|---|---|---|---|
| Swagger | Fraîcheur + CI gate ✅ | — | S-1 (export CSV), S-2 (#13, déjà suivi) | S-3, S-4 |
| Exposition | 4/4 vérifications ✅ | — | — | — |
| Postman | — | PM-1 (FC-08 absent) | PM-2, PM-3, PM-4 | PM-5 |

---

## 6. Plan d'intégration & suivi

**Principe (règle campagne P6.0)** : pas de travail cosmétique non arbitré — chaque item a un
critère de validation mesurable. Décision CTO requise pour P2 (arbitrage exclusion) et P5
(périmètre anti-drift).

| ID | Tâche | Priorité | Livrable | Critère de validation | Statut |
|---|---|---|---|---|---|
| **P1** | **Postman FC-08** : dossiers `Companies` (5 req) + `UserCompanies` (5 req) avec scripts de test automatisés (extraction `company_id`, `user_company_id`), variables de collection, scénario onboarding atomique ; mise à jour de la description (36 endpoints) | 🔴 | Collection à jour | 36 requêtes alignées `routes.rb` ; rejouable en dev (2 exécutions consécutives) ; README L110 corrigé | ⬜ À faire |
| **P2** | **Swagger export CSV** : documenter `GET /api/v1/cras/{id}/export` (200 `text/csv` + codes d'erreur réels relevés dans les specs FC-07) puis retirer l'exclusion de `EXCLUDED_ENDPOINTS` — **ou** arbitrage CTO de conserver l'exclusion, formalisé ici | 🟠 | Path documenté + audit sans exclusion | `rake swagger:audit_coverage` vert **sans** l'entrée export dans `EXCLUDED_ENDPOINTS` (ou décision d'arbitrage tracée) | ⬜ Arbitrage CTO puis exécution |
| **P3** | **Divergence #13** (déjà au BACKLOG) : rattacher au présent plan — arbitrage `name` : soit `name` entre au contrat (RSwag corrigé), soit la réponse production change | 🟠 | Clôture de #13 | Contrat = production, audit vert | ⬜ Déjà suivi (pointer BACKLOG #13) |
| **P4** | **Hygiène contrat Swagger** : retirer (ou marquer explicitement hors contrat) l'opération négative `GET /api/v1/auth/login` ; décision sur `/up` | 🟢 | Spec épurée | 0 opération documentée qui n'existe pas ; audit vert | ⬜ Optionnel |
| **P5** | **Anti-drift Postman** : mini-audit (script `bin/` ou tâche rake) comparant méthodes+paths de la collection à `routes.rb`, philosophie `swagger:audit_coverage` | 🟢 | Détection de drift | Échec du script si un endpoint réel manque de la collection | ⬜ Arbitrage CTO (périmètre) |

### Journal d'exécution

| Date | Étape | Notes |
|---|---|---|
| 2026-09-24 | Audit réalisé (ce document) | Constats S-1..S-4, PM-1..PM-5, exposition 4/4 ✅ |
| — | *à compléter à chaque état substantiel* | — |

---

## 7. Risques & hypothèses

- **Risque de non-action P1** : tout debug/démonstration FC-08 en production via Postman est
  impossible ; la collection « complète » de la description induit en erreur.
- **Hypothèse P2** : les codes d'erreur de l'export (401/403/404, éventuellement 409 selon
  lifecycle) sont à relever dans `spec/requests` FC-07 avant rédaction — pas d'invention de contrat.
- **Hypothèse P5** : la collection n'étant pas générée automatiquement, l'audit ne peut être
  qu'un garde-fou (échec en cas de drift), pas un générateur.

---

## 8. Références

- `config/routes.rb` — 36 endpoints API v1, gardes `__test_support__` (L61-73)
- `swagger/v1/swagger.yaml` — 20 paths / 37 opérations (dernier commit `f402b118`, 14/09)
- `lib/tasks/swagger_audit.rake` — `EXCLUDED_ENDPOINTS` L78-81 (export CSV, GET login)
- `.github/workflows/ci.yml` — job `contracts` : swaggerize (L285) + audit (L297)
- `docs/postman/Foresy_API.postman_collection.json` — 28 requêtes (dernier commit `37f2f8d4`, 19/08)
- `docs/BACKLOG.md` — entrées #13 (divergence `name`), nouvelles entrées P1/P2/P5
- Hub RAG `foresy__knowledge` — plan complétion Swagger (02/2026), trackers FC-08 P7-P9

---

**Document créé le :** 24 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Convention de mise à jour : à chaque état substantiel, journal §6 complété ; préfixe `[DONE]` à ajouter au nom du fichier lorsque P1-P5 sont clos.*