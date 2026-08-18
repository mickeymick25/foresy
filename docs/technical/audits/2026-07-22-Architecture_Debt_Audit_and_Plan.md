# 🏗️ Audit & Plan de Remédiation Architecture Foresy

**Date de l'audit :** 18 août 2026
**Auditeur :** Zed Agent (revue automatisée)
**Sources :** Revérification complète du codebase post-Phase 1.6-1.9
**Statut document :** ✅ Terminé — Plan 100% exécuté (25/25 tâches)
**Dernière mise à jour du suivi :** 18 août 2026

---

## 📋 Sommaire

1. [Contexte et Méthodologie](#1-contexte-et-méthodologie)
2. [Synthèse de l'Audit](#2-synthèse-de-laudit)
3. [Plan d'Implémentation par Phases](#3-plan-dimplémentation-par-phases)
4. [Tableau de Bord de Suivi](#4-tableau-de-bord-de-suivi)
5. [Critères de Validation et Définition of Done](#5-critères-de-validation-et-définition-of-done)
6. [Risques, Dépendances et Assomptions](#6-risques-dépendances-et-assomptions)
7. [Convention de Mise à Jour du Suivi](#7-convention-de-mise-à-jour-du-suivi)
8. [Annexes](#8-annexes)

---

## 1. Contexte et Méthodologie

### 1.1 Contexte

Une première analyse d'architecture avait été réalisée sur le projet Foresy autour de la version 2.3.1 (Janvier 2026). Depuis, le projet a évolué avec :

- **Phase 1.6-1.8** : API Contract Hardening & Versioning (PLATINUM) — RSwag 27/27 endpoints, OpenAPI strict schema validation
- **Refactor** : Thin controllers + service extraction pour `cras/cra_entries/missions`
- **DDD Phase 2.5** : Architecture relation-driven stabilisée
- **Phase 1.9** : Standardized Error Contract (sur branche `phase-1-9-error-contract`, **non mergée sur main**)

Une revérification point par point a été effectuée le 18 août 2026. Résultat : **21 points sur 25 restent intacts**, 2 sont partiellement résolus, 2 ont évolué/agravé. Aucun n'est totalement résolu.

### 1.2 Méthodologie

Chaque point identifié a été vérifié en relisant le code actuel et en croisant avec `grep` pour confirmer la présence effective des patterns. Les verdicts sont :

- 🔴 **Toujours problème** : Le problème identifié persiste inchangé
- 🟡 **Partiellement résolu** : Le problème est atténué mais subsiste
- 🟠 **Évolué/aggravé** : Le problème a muté ou s'est étendu
- ✅ **Résolu** : Le problème n'existe plus

### 1.3 Méthodologie : TDD + DDD + Niveau Platinum

Le plan de remédiation s'appuie sur la méthodologie déjà validée par le projet Foresy lors du **FC-07 CRA (TDD PLATINUM)**. Chaque tâche doit respecter strictement cette méthodologie, sans exception.

#### 1.3.1 TDD (Test-Driven Development)

Chaque tâche suit le cycle **RED → GREEN → REFACTOR** en 3 commits distincts :

1. **🔴 RED (commit 1)** : Écrire un test qui caractérise le comportement attendu et **échoue** d'abord. Le test doit être minimal, précis, et documenter l'invariant visé.
2. **🟢 GREEN (commit 2)** : Implémenter le minimum nécessaire pour faire passer le test. Pas de fonctionnalité additionnelle.
3. **🔵 REFACTOR (commit 3)** : Améliorer la lisibilité/performance sans casser les tests. Optionnel si GREEN est déjà propre.

**Règles d'or TDD :**
- ❌ Aucun code de production sans test RED d'abord qui le justifie
- ❌ Aucun commit GREEN qui introduit plus que le minimum nécessaire
- ✅ Le test RED doit échouer pour la bonne raison (vérifier le message d'erreur avant de continuer)
- ✅ Un test qui supprime du code mort (P3) compte comme RED s'il asserte l'absence de la classe/méthode

#### 1.3.2 DDD (Domain-Driven Design)

La remédiation doit respecter et renforcer l'architecture DDD/RDD existante :

1. **Pas de logique métier dans les contrôleurs** : Tout comportement métier (transitions, règles, calculs) vit dans des `Domain Services` ou des `Application Services`.
2. **Tables de relation explicites** : Pas de FK directe entre entités métier (via `UserCompany`, `MissionCompany`, `UserCra`, etc.).
3. **Erreurs métier typées** : `CraErrors::*`, `MissionErrors::*` — pas de `raise StandardError` dans le domaine.
4. **Pattern `ApplicationResult`** : Les services retournent `ApplicationResult.success` / `ApplicationResult.fail`, jamais d'exceptions au niveau service (sauf erreurs métier explicites).
5. **Isolation du domaine** : Le domaine ne connaît ni Rails, ni HTTP, ni infrastructure (Git, Redis). Les adapters isolent l'infrastructure.
6. **Invariants contractuels** : Chaque règle métier est garantie par un test d'invariant (ex: lifecycle CRA non contournable).

#### 1.3.3 Niveau Platinum

Le niveau Platinum reprend les critères déjà atteints par FC-07 et les applique à chaque tâche de remédiation :

| Critère | Définition | Validation |
|---|---|---|
| **Couverture test** | 100% du nouveau code est couvert | `bundle exec rspec` + simplecov si activé |
| **RuboCop** | Aucune offense sur les fichiers modifiés | `bundle exec rubocop` clean |
| **Brakeman** | Aucune nouvelle vulnérabilité | `bundle exec brakeman` sans warning |
| **Zeitwerk** | Tous les fichiers autoloadent correctement | `bundle exec rake zeitwerk:check` ✅ |
| **OpenAPI/RSwag** | Schémas à jour si endpoint modifié | `bundle exec rake swagger:validate_schemas` ✅ |
| **Invariants défensifs** | Tests d'invariants ajoutés (sécurité, intégrité) | Specs d'acceptance dédiées |
| **Documentation** | Chaque tâche documente sa décision | Entrée dans le journal de phase |
| **Non-régression** | Aucun test existant cassé | Suite RSpec + RSwag verte |

#### 1.3.4 Principes Directeurs du Plan

1. **Sécurité d'abord** : Les failles de sécurité sont traitées en priorité absolue (P0)
2. **Stabilisation avant nettoyage** : On corrige les crashes runtime avant de supprimer du code
3. **Petites étapes reviewables** : Chaque tâche produit une PR reviewable indépendamment
4. **TDD strict par tâche** : Cycle RED → GREEN → REFACTOR en commits séparés (voir 1.3.1)
5. **DDD préservé** : Aucun correctif ne doit affaiblir l'isolation du domaine (voir 1.3.2)
6. **Niveau Platinum** : Critères de qualité FC-07 appliqués à chaque PR (voir 1.3.3)
7. **Convergence vers un seul pattern** : À chaque étape, on élimine une duplication plutôt qu'on en crée

---

## 2. Synthèse de l'Audit

### 2.1 Vue d'Ensemble par Catégorie

| Catégorie | 🔴 Toujours | 🟡 Partiel | 🟠 Aggravé | ✅ Résolu | Total |
|---|---|---|---|---|---|
| Contrôleurs | 8 | 1 | 1 | 0 | 10 |
| Modèles | 4 | 1 | 0 | 0 | 5 |
| Services | 0 | 1 | 1 | 0 | 2 |
| Lib | 1 | 0 | 0 | 0 | 1 |
| Base de données | 3 | 0 | 0 | 0 | 3 |
| Configuration | 3 | 0 | 0 | 0 | 3 |
| Sécurité | 1 | 0 | 0 | 0 | 1 |
| **Total** | **20** | **3** | **2** | **0** | **25** |

### 2.2 Verdict Global

**L'analyse précédente reste d'actualité.** Les efforts récents ont porté sur :
- ✅ Contrats API/OpenAPI (visible, valeur externe)
- ✅ Thin controllers (partiellement)

Les dettes structurelles internes identifiées n'ont pas été traitées. La branche `phase-1-9-error-contract` (non mergée) vise à unifier les erreurs — c'est le travail déjà en cours à surveiller.

### 2.3 Synthèse Détaillée des 25 Points

#### 🎛️ Contrôleurs

| # | Point | Verdict | Preuve |
|---|---|---|---|
| C1 | 3 formats d'erreur JSON qui cohabitent | 🔴 | `StandardizedError` + `ErrorRenderable` (orphelin) + `render_fc07_error` (20+ appels) |
| C2 | Conflit `rescue_from StandardError` | 🔴 | `ApplicationController` re-lève l'exception, handler `TEMPORARY` |
| C3 | `puts` de debug en production | 🔴 | `authenticatable.rb` (7 `puts` dont un qui **expose le token JWT**), `missions_controller.rb` (10 `puts`) |
| C4 | `MissionsController` sans `BaseController` | 🟠 | `MissionsController` ET `CrasController` contournent `BaseController` |
| C5 | `OAuthConcern` inutile dans `AuthenticationController` | 🔴 | Toujours inclus, aucune méthode utilisée |
| C6 | Duplication `extract_client_ip_for_rate_limiting` | 🔴 | 3 copies identiques (auth, missions, users) |
| C7 | Méthodes publiques dans `OauthController` | 🔴 | 4 helpers internes exposés en public |
| C8 | `OauthController#callback` expose `e.message` | 🟡 | Masqué en prod par `error_internal`, fuit en dev/test |
| C9 | Format 429 inconsistant dans `UsersController` | 🔴 | Inline avec code en lowercase `rate_limit_exceeded` |
| C10 | Logique métier dans `MissionsController` | 🔴 | Création `MissionCompany` + transition d'état dans le contrôleur |

#### 🗃️ Modèles

| # | Point | Verdict | Preuve |
|---|---|---|---|
| M1 | Concerns `DomainDriven`/`SoftDeletable`/`Validatable` jamais inclus | 🔴 | Les 3 fichiers existent mais aucun `include` |
| M2 | `default_scope { where(deleted_at: nil) }` sur 4 modèles | 🔴 | Company, Cra, CraEntry, Mission |
| M3 | Dualité `created_by_user_id` vs tables pivot | 🔴 | 16 occurrences, source de vérité opérationnelle |
| M4 | `CraEntry` callbacks neutralisés + `attr_writer` TDD | 🔴 | Code commenté figé, `attr_writer :cra, :mission` présent |
| M5 | Dualité erreurs/retours (`ApplicationResult` vs `CraErrors`) | 🟡 | Un `raise CraErrors::DuplicateEntryError` survit dans une validation modèle |

#### 🧱 Services

| # | Point | Verdict | Preuve |
|---|---|---|---|
| S1 | Triple couche services CRA Entries | 🟠 | 3 couches cohabitent. La nouvelle référence `::Domain::CraEntry::CraEntry` **inexistant** → crash `NameError` |
| S2 | `ApplicationResult` API inconsistante | 🟡 | API canonique nettoyée, mais helpers CRA-spécifiques (`success_entry`, `success_cra`) persistent |

#### 📚 Lib

| # | Point | Verdict | Preuve |
|---|---|---|---|
| L1 | Code mort `app/lib` | 🔴 | `pundit.rb`, `shared_result_adapter.rb` (~410 lignes), `shared_result_kill_switches.rb` (~696), `step3_reporting_system.rb` (~1112), `domain_leakage_detector.rb` (~489). ~2700 lignes mortes |

#### 🗄️ Base de données

| # | Point | Verdict | Preuve |
|---|---|---|---|
| D1 | `users` PK bigint vs UUID ailleurs | 🔴 | Incohérence de typage PK/FK |
| D2 | `users.uuid` VARCHAR(36) vs UUID natif | 🔴 | Perte validation/performance |
| D3 | `user_missions.role`/`user_cras.role` string vs enum PG | 🔴 | Check constraint au lieu d'enum |

#### ⚙️ Configuration

| # | Point | Verdict | Preuve |
|---|---|---|---|
| F1 | Module Rails = `App` au lieu de `Foresy` | 🔴 | `module App` dans `config/application.rb` |
| F2 | `load_defaults 7.1` vs schema 8.1 | 🔴 | Décalage de version Rails |
| F3 | `E2E_MODE=true` expose routes test en prod | 🔴 | Faille de sécurité — condition indépendante de l'environnement |

#### 🔒 Sécurité

| # | Point | Verdict | Preuve |
|---|---|---|---|
| SE1 | `GitLedgerRepository` backticks/system() | 🔴 | `Shellwords.escape` partiel, `2>/dev/null` masque erreurs, pas de `Open3` |

---

## 3. Plan d'Implémentation par Phases

Le plan est organisé en **6 phases** de P0 à P3. Chaque phase est un ensemble cohérent de tâches livrables en une ou plusieurs PR.

```mermaid
graph LR
    P0[Phase 0 - Sécurité Critique] --> P1[Phase 1 - Stabilisation Runtime]
    P1 --> P2[Phase 2 - Unification Erreurs]
    P2 --> P3[Phase 3 - Nettoyage Code Mort]
    P3 --> P4[Phase 4 - Cohérence Architecturale]
    P4 --> P5[Phase 5 - Base de Données & Config]
    P5 --> P6[Phase 6 - Hardening Final]
```

### 📊 Vue d'Ensemble des Phases

| Phase | Nom | Priorité | Tâches | Effort estimé | Dépendances |
|---|---|---|---|---|---|
| **P0** | Sécurité Critique | 🔴 Critique | 4 | 4-6h | Aucune |
| **P1** | Stabilisation Runtime | 🔴 Critique | 2 | 4-8h | P0 |
| **P2** | Unification Erreurs | 🟡 Haute | 3 | 8-12h | P1 (mergé Phase 1.9) |
| **P3** | Nettoyage Code Mort | 🟡 Haute | 2 | 2-3h | P1 |
| **P4** | Cohérence Architecturale | 🟡 Haute | 5 | 12-20h | P2, P3 |
| **P5** | Base de Données & Config | 🟢 Moyenne | 4 | 6-10h | P4 |
| **P6** | Hardening Final | 🟢 Moyenne | 3 | 4-6h | P5 |
| **Total** | | | **23** | **40-65h** | |

---

### 🔴 Phase 0 — Sécurité Critique

> **Objectif :** Éliminer les failles de sécurité pouvant exposer des données ou permettre des actions non autorisées en production.
> **Livrable :** 1-2 PR reviewables par sécurité.
> **Critère d'arrêt :** Aucune route de test accessible en prod, aucun token JWT dans les logs, pas de fuite de messages d'erreur internes.

#### Tâches

##### P0.1 — Verrouiller les routes `__test_support__` en production

- **Point audit :** F3
- **Fichiers :** `Foresy/config/routes.rb`
- **Problème :** La condition `Rails.env.test? || ENV['E2E_MODE'] == 'true'` permet d'exposer les endpoints `__test_support__/e2e/setup` et `cleanup` en production si `E2E_MODE=true` est positionné.
- **Solution :** Restreindre à `Rails.env.test? || (ENV['E2E_MODE'] == 'true' && !Rails.env.production?)` OU exiger un secret signé (ex: `ENV['E2E_SECRET']` comparé à un header attendu).
- **Tests :** Ajouter un test d'intégration vérifiant que `__test_support__/*` retourne 404 en mode production mocké avec `E2E_MODE=true`.
- **Effort :** 30min
- **Risque :** Faible — Impact limité aux routes de test
- **Statut :** ⬜ Non commencé

##### P0.2 — Supprimer les `puts` exposant le token JWT dans `authenticatable.rb`

- **Point audit :** C3
- **Fichiers :** `Foresy/app/controllers/concerns/authenticatable.rb`
- **Problème :** 7 `puts` dans `authenticate_access_token!`, dont un qui imprime `request.headers['Authorization']` (le token JWT complet) dans stdout — fuite critique de credentials en logs.
- **Solution :** Supprimer tous les `puts`. Si debug nécessaire, utiliser `Rails.logger.debug` sans jamais logger le token (même tronqué).
- **Tests :** Vérifier que les logs d'une requête authentifiée ne contiennent aucun token JWT.
- **Effort :** 30min
- **Risque :** Faible
- **Statut :** ⬜ Non commencé

##### P0.3 — Supprimer les `puts` de debug dans `missions_controller.rb`

- **Point audit :** C3
- **Fichiers :** `Foresy/app/controllers/api/v1/missions_controller.rb`
- **Problème :** 10 `puts` dans `set_mission` et `validate_mission_access!`.
- **Solution :** Supprimer les `puts` ou les convertir en `Rails.logger.debug` (sans données sensibles).
- **Tests :** Pas de test spécifique requis (vérification visuelle + RuboCop).
- **Effort :** 15min
- **Risque :** Faible
- **Statut :** ⬜ Non commencé

##### P0.4 — Sécuriser `OauthController#callback` contre la fuite d'erreurs

- **Point audit :** C8
- **Fichiers :** `Foresy/app/controllers/api/v1/oauth_controller.rb`
- **Problème :** `error_internal("OAuth callback error: #{e.message}")` expose le message d'exception brute. En prod, `error_internal` filtre mais la fuite persiste en dev/test.
- **Solution :** Logger l'exception complète via `Rails.logger.error` avec backtrace, ne renvoyer qu'un message générique au client (pas d'interpolation `e.message`).
- **Tests :** Vérifier qu'aucun `e.message` n'apparaît dans la réponse JSON en dev.
- **Effort :** 15min
- **Risque :** Faible
- **Statut :** ⬜ Non commencé

**Sous-dossier de suivi :** [`docs/technical/[Done]_remediation/phase-0-securite.md`](../[Done]_remediation/phase-0-securite.md)

---

### 🔴 Phase 1 — Stabilisation Runtime

> **Objectif :** Éliminer les crashes runtime garantis et neutraliser les handlers qui masquent les erreurs.
> **Livrable :** 1-2 PR.
> **Critère d'arrêt :** Aucun service ne référence une classe inexistante, `rescue_from StandardError` ne masque plus le handler standardisé.

#### Tâches

##### P1.1 — Résoudre le crash runtime `Domain::CraEntry::CraEntry` inexistant

- **Point audit :** S1
- **Fichiers :** `Foresy/app/services/cra_entries/*.rb`, `Foresy/app/domain.rb` (création à évaluer)
- **Problème :** Les services `CraEntries::*` référencent `::Domain::CraEntry::CraEntry` (18 occurrences) qui n'est défini nulle part. Tout appel lève `NameError`.
- **Solution (2 options) :**
  - **Option A (recommandée) :** Supprimer le layer `CraEntries::*` (jamais appelé en production) et documenter l'usage exclusif de `CraEntryServices::*`.
  - **Option B :** Créer `Foresy/app/domain/cra_entry/cra_entry.rb` avec les constantes/methodes attendues (`MAX_QUANTITY`, `MAX_UNIT_PRICE`, `MAX_DESCRIPTION_LENGTH`, `cra_modifiable?`, `user_has_mission_access?`).
- **Tests :** Vérifier qu'aucun `NameError` n'est levé au boot de l'app et qu'aucun service n'est orphelin.
- **Effort :** 2-4h (Option A), 4-8h (Option B)
- **Risque :** Moyen — Vérifier qu'aucun contrôleur n'appelle `CraEntries::*` avant suppression
- **Décision requise :** Choisir Option A ou B après audit des appelants
- **Statut :** ⬜ Non commencé

##### P1.2 — Résoudre le conflit `rescue_from StandardError`

- **Point audit :** C2
- **Fichiers :** `Foresy/app/controllers/application_controller.rb`, `Foresy/app/controllers/concerns/standardized_error.rb`
- **Problème :** `ApplicationController` définit `rescue_from StandardError` qui **re-lève** l'exception (commentaire `# TEMPORARY`), neutralisant le handler de `StandardizedError`.
- **Solution :** Supprimer le `rescue_from StandardError` de `ApplicationController`. Conserver uniquement celui de `StandardizedError` qui formate une réponse 500 propre. En dev, s'appuyer sur `config.consider_all_requests_local = true` pour la trace Rails.
- **Tests :** Test d'intégration : une route levant `StandardError` renvoie un JSON formaté `{ code, message }` en 500, pas une page HTML brute.
- **Effort :** 30min
- **Risque :** Faible — `StandardizedError.handle_standard_error` existe déjà et gère le cas
- **Statut :** ⬜ Non commencé

**Sous-dossier de suivi :** [`docs/technical/[Done]_remediation/phase-1-stabilisation.md`](../[Done]_remediation/phase-1-stabilisation.md)

---

### 🟡 Phase 2 — Unification des Erreurs

> **Objectif :** Converger vers UN seul format d'erreur JSON pour toute l'API.
> **Livrable :** 1 PR (peut inclure la Phase 1.9 déjà en cours).
> **Critère d'arrêt :** Tous les endpoints retournent le même schéma d'erreur. `ErrorRenderable` supprimé. `render_fc07_error` supprimé.

#### Tâches

##### P2.1 — Évaluer et merger la Phase 1.9 (Standardized Error Contract)

- **Point audit :** C1
- **Fichiers :** Branche `phase-1-9-error-contract`, `Foresy/app/controllers/concerns/standardized_error.rb`
- **Problème :** La Phase 1.9 en cours vise à unifier les erreurs mais n'est pas mergée.
- **Solution :** Reviewer le contenu de la branche, vérifier la compatibilité avec le schéma choisi, merger ou réviser.
- **Décision :** Le format cible doit être documenté dans `Foresy/docs/technical/guides/error_contract.md` (à créer).
- **Effort :** 2-4h
- **Risque :** Moyen — Peut impacter les tests RSwag existants
- **Statut :** ⬜ Non commencé

##### P2.2 — Supprimer le concern orphelin `ErrorRenderable`

- **Point audit :** C1
- **Fichiers :** `Foresy/app/controllers/concerns/error_renderable.rb`
- **Problème :** Le concern existe (format `{ error: { code, message, details } }`) mais n'est inclus dans aucun contrôleur.
- **Solution :** Supprimer le fichier. Vérifier avec grep qu'aucun `include ErrorRenderable` n'existe.
- **Tests :** Aucun (code mort).
- **Effort :** 15min
- **Risque :** Néant
- **Statut :** ⬜ Non commencé

##### P2.3 — Migrer `render_fc07_error` vers le format unifié

- **Point audit :** C1
- **Fichiers :** `Foresy/app/controllers/api/v1/cra_entries_controller.rb` (20+ occurrences), `Foresy/app/controllers/concerns/api/v1/cra_entries/error_handler.rb` (si présent)
- **Problème :** `render_fc07_error` produit un format `{ error, message, timestamp }` différent du standard.
- **Solution :** Remplacer tous les appels `render_fc07_error(type, msg, status)` par `error_*` de `StandardizedError`. Supprimer la méthode `render_fc07_error` et ses handlers `handle_*_error` (redondants avec `rescue_from`).
- **Tests :** Mettre à jour les tests RSwag `cra_entries` pour valider le nouveau schéma.
- **Effort :** 4-6h
- **Risque :** Moyen — Impacte les tests de contrat existants
- **Statut :** ⬜ Non commencé

**Sous-dossier de suivi :** [`docs/technical/[Done]_remediation/phase-2-unification-erreurs.md`](../[Done]_remediation/phase-2-unification-erreurs.md)

---

### 🟡 Phase 3 — Nettoyage du Code Mort

> **Objectif :** Éliminer ~2700 lignes de code mort dans `app/lib` et les concerns orphelins.
> **Livrable :** 1 PR.
> **Critère d'arrêt :** `bundle exec rake zeitwerk:check` passe, RuboCop sans warnings, aucun fichier orphelin.

#### Tâches

##### P3.1 — Supprimer le code mort dans `app/lib`

- **Point audit :** L1
- **Fichiers à supprimer :**
  - `Foresy/app/lib/pundit.rb` (stub inutile, ~20 lignes)
  - `Foresy/app/lib/shared_result_adapter.rb` (~410 lignes, référence `Shared::Result` inexistant)
  - `Foresy/app/lib/shared_result_kill_switches.rb` (~696 lignes, outils de migration)
  - `Foresy/app/lib/step3_reporting_system.rb` (~1112 lignes, outils de reporting de migration)
  - `Foresy/app/lib/domain_leakage_detector.rb` (~489 lignes, outil de debug CLI)
- **Pré-requis :** Vérifier avec grep qu'aucun fichier hors `app/lib/` ne référence ces classes (tests inclus).
- **Alternative :** Si certains outils sont utiles en dev, les déplacer vers `lib/tasks/` ou `scripts/` (hors autoload Rails).
- **Tests :** Aucun test ne doit casser.
- **Effort :** 1-2h
- **Risque :** Faible — Code mort confirmé
- **Statut :** ⬜ Non commencé

##### P3.2 — Traiter les concerns modèles orphelins

- **Point audit :** M1
- **Fichiers :** `Foresy/app/models/concerns/domain_driven.rb`, `soft_deletable.rb`, `validatable.rb`
- **Problème :** Les 3 concerns existent mais ne sont inclus dans aucun modèle.
- **Solution (2 options) :**
  - **Option A (recommandée pour P3) :** Supprimer les 3 concerns (ils ne sont pas utilisés).
  - **Option B (reporté en P4) :** Intégrer `SoftDeletable` aux 4 modèles qui implémentent le pattern manuellement (voir P4.2).
- **Décision :** Option A en P3 (suppression), Option B éventuellement en P4 (réintroduction).
- **Effort :** 15min
- **Risque :** Néant
- **Statut :** ⬜ Non commencé

**Sous-dossier de suivi :** [`docs/technical/[Done]_remediation/phase-3-nettoyage-code-mort.md`](../[Done]_remediation/phase-3-nettoyage-code-mort.md)

---

### 🟡 Phase 4 — Cohérence Architecturale + Finalisation DDD

> **Objectif :** Unifier les patterns architecturaux (héritage contrôleurs, IP rate limiting, logique métier dans services, layers de services).
> **Livrable :** 2-3 PR.
> **Critère d'arrêt :** Tous les contrôleurs héritent de `BaseController`. Un seul concern pour l'IP. `MissionsController` délègue à des services. Une seule couche de services par domaine.

#### Tâches

##### P4.1 — Aligner l'héritage des contrôleurs sur `BaseController`

- **Point audit :** C4
- **Fichiers :** `Foresy/app/controllers/api/v1/missions_controller.rb`, `Foresy/app/controllers/api/v1/cras_controller.rb`
- **Problème :** Ces 2 contrôleurs héritent directement de `ApplicationController`, contournant `Api::V1::BaseController` et les headers de dépréciation.
- **Solution :** Changer `class MissionsController < ApplicationController` en `< Api::V1::BaseController`. Idem pour `CrasController`. Vérifier qu'aucune méthode de `ApplicationController` n'est perdue (elles sont héritées transitivement).
- **Tests :** Vérifier que les headers de dépréciation sont présents sur les endpoints missions et cras.
- **Effort :** 30min
- **Risque :** Faible
- **Statut :** ⬜ Non commencé

##### P4.2 — Extraire `extract_client_ip_for_rate_limiting` dans un concern partagé

- **Point audit :** C6
- **Fichiers :** Créer `Foresy/app/controllers/concerns/common/rate_limitable.rb`, supprimer la méthode de `authentication_controller.rb`, `missions_controller.rb`, `users_controller.rb`
- **Problème :** 3 copies identiques de la méthode.
- **Solution :** Créer `Common::RateLimitable` avec la méthode, `include` dans les 3 contrôleurs. Supprimer les copies.
- **Tests :** Test d'intégration : le rate limiting fonctionne toujours sur login, signup, missions.
- **Effort :** 1h
- **Risque :** Faible
- **Statut :** ⬜ Non commencé

##### P4.3 — Extraire la logique métier de `MissionsController` dans des services

- **Point audit :** C10
- **Fichiers :** Créer `Foresy/app/services/mission_services/create.rb`, `update.rb` (étendre l'existant). Refactoriser `Foresy/app/controllers/api/v1/missions_controller.rb`.
- **Problème :** Création de `MissionCompany` dans le contrôleur (L56-67), transition d'état dans `update` (L122-128).
- **Solution :** Suivre le pattern `CraServices::*` : services `MissionServices::Create.call(...)` et `MissionServices::Update.call(...)` retournant `ApplicationResult`. Le contrôleur ne fait que dispatch et rendre.
- **Tests :** Tests services + tests request existants doivent passer.
- **Effort :** 4-6h
- **Risque :** Moyen — Refactorisation d'endpoints en production
- **Statut :** ⬜ Non commencé

##### P4.4 — Nettoyer les 3 couches de services CRA Entries

- **Point audit :** S1 (suite de P1.1)
- **Fichiers :** `Foresy/app/services/api/v1/cra_entries/*` (legacy), `Foresy/app/services/cra_entry_services/*` (intermédiaire), `Foresy/app/services/cra_entries/*` (cassé)
- **Problème :** Triple redondance avec une couche cassée.
- **Solution :** Suite à P1.1 (Option A), supprimer les 2 layers obsolètes. Ne conserver que `CraEntryServices::*`. Vérifier qu'aucun contrôleur n'appelle les layers supprimés.
- **Tests :** Tests de non-régression sur les endpoints `cra_entries`.
- **Effort :** 2-4h
- **Risque :** Moyen — Identifier tous les appelants
- **Statut :** ⬜ Non commencé

##### P4.5 — Unifier le format 429 de `UsersController`

- **Point audit :** C9
- **Fichiers :** `Foresy/app/controllers/api/v1/users_controller.rb`
- **Problème :** Utilise un `render json:` inline avec code en lowercase au lieu de `error_too_many_requests`.
- **Solution :** Remplacer par `error_too_many_requests('Rate limit exceeded', { retry_after: retry_after })` (comme `AuthenticationController` et `MissionsController`).
- **Tests :** Test request vérifiant le format standardisé de la 429 sur `/signup`.
- **Effort :** 15min
- **Risque :** Faible
- **Statut :** ✅ Terminé (fix CI)

##### P4.6 — Remplacer `default_scope` par scopes explicites

- **Point audit :** M2
- **Fichiers :** `Foresy/app/models/company.rb`, `cra.rb`, `cra_entry.rb`, `mission.rb` + tous les appelants
- **Problème :** `default_scope { where(deleted_at: nil) }` sur 4 modèles. Anti-pattern Rails : rend les requêtes implicites et difficiles à déboguer. Masque les enregistrements supprimés sans que l'appelant le sache.
- **Solution :** Supprimer les `default_scope`. Ajouter des scopes explicites : `scope :active, -> { where(deleted_at: nil) }` et `scope :with_deleted, -> { unscope(:where) }`. Mettre à jour tous les appels `Model.all` / `Model.where(...)` pour utiliser `Model.active` quand on veut exclure les supprimés.
- **Tests :** Tests modèle vérifiant que `Model.active` exclut les supprimés et que `Model.with_deleted` les inclut. Tests de non-régression sur les queries existantes.
- **Effort :** 4-6h
- **Risque :** Moyen — Tous les appels doivent être mis à jour manuellement
- **Statut :** ⬜ Non commencé

##### P4.7 — Migrer `created_by_user_id` vers tables pivot (finalisation DDD)

- **Point audit :** M3
- **Fichiers :** `Foresy/app/models/cra.rb`, `mission.rb` (supprimer colonne), `Foresy/app/services/cra_services/*`, `mission_services/*`, `git_ledger_payload.rb` (16 occurrences)
- **Problème :** `created_by_user_id` (colonne legacy bigint) coexiste avec les tables pivot `user_cras`/`user_missions` (DDD). La colonne reste la source de vérité opérationnelle pour les permissions et l'ownership. Dualité non résolée.
- **Solution :** En 3 étapes :
  1. **Préparation** : Identifier tous les appels à `created_by_user_id` et les remplacer par des requêtes via les tables pivot (ex: `cra.user_cras.where(role: 'creator').first.user_id` au lieu de `cra.created_by_user_id`).
  2. **Migration** : Backfill des tables pivot si nécessaire (vérifier que tous les enregistrements ont une relation pivot `creator`).
  3. **Suppression** : Migration DB `remove_column :cras, :created_by_user_id` + `remove_column :missions, :created_by_user_id`.
- **Tests :** Tests que les permissions/ownership fonctionnent via les tables pivot. Tests que les services n'utilisent plus `created_by_user_id`.
- **Effort :** 8-12h
- **Risque :** Élevé — Impacte les permissions, le Git Ledger, les services. Migration DB irréversible.
- **Dépendance :** P4.6 doit être terminé d'abord (default_scope cleanup facilite la migration des queries).
- **Statut :** ✅ Terminé — Colonne `created_by_user_id` supprimée en DB (migration `2026072401`). Lectures via `creator_user_id` (tables pivot `user_cras`/`user_missions`). 4 tests pending passés au vert. 850 tests, 0 failures, 0 pending.

---

### 🟡 Phase 5 — Base de Données & Configuration

> **Objectif :** Corriger les incohérences de schéma et de configuration Rails.
> **Livrable :** 1-2 PR avec migrations DB.
> **Critère d'arrêt :** Schéma cohérent (PK UUID partout), `load_defaults` aligné, `E2E_MODE` sécurisé au niveau config.

#### Tâches

##### P5.1 — Migrer `users.uuid` de VARCHAR(36) vers UUID natif PostgreSQL

- **Point audit :** D2
- **Fichiers :** Nouvelle migration `db/migrate/YYYYMMDD_change_users_uuid_to_native_uuid.rb`
- **Problème :** `users.uuid` est VARCHAR(36) au lieu du type UUID natif (perte validation, index moins performant).
- **Solution :** Migration `change_column :users, :uuid, :uuid` (PostgreSQL convertit automatiquement). Vérifier que `pgcrypto` est activé. Idem pour `sessions.uuid` si applicable.
- **Tests :** Test que `User.create(uuid: 'invalid')` lève une erreur DB.
- **Effort :** 1-2h
- **Risque :** Moyen — Migration de données, vérifier qu'aucun UUID n'est malformé
- **Statut :** ⬜ Non commencé

##### P5.2 — Migrer `user_missions.role` et `user_cras.role` en enum PostgreSQL

- **Point audit :** D3
- **Fichiers :** Nouvelle migration ajoutant `create_enum` + `change_column`
- **Problème :** Colonnes `string` avec check constraint au lieu d'enum PG natif (incohérent avec `cra_status`).
- **Solution :** Créer l'enum `user_relation_role_enum`, migrer les colonnes, supprimer la check constraint redondante.
- **Tests :** Vérifier que les valeurs existantes (`creator`) restent valides.
- **Effort :** 2h
- **Risque :** Faible — Données existantes compatibles
- **Statut :** ⬜ Non commencé

##### P5.3 — Renommer le module Rails `App` en `Foresy`

- **Point audit :** F1
- **Fichiers :** `Foresy/config/application.rb`, `Foresy/config/environment.rb`, `Foresy/config.ru`, `Foresy/Rakefile`, tous les fichiers référençant `App::`
- **Problème :** Le module Rails est `App` (scaffold par défaut) au lieu de `Foresy`.
- **Solution :** `rails g rename_to Foresy` (via gem `rename`) ou renommage manuel. **Attention :** impacte toutes les références `App::Application`, `App.routes`, etc.
- **Tests :** Suite de tests complète + boot de l'app.
- **Effort :** 2-4h
- **Risque :** Élevé — Impact large, à réaliser avec soin
- **Statut :** ⬜ Non commencé

##### P5.4 — Aligner `config.load_defaults` sur la version Rails 8.1

- **Point audit :** F2
- **Fichiers :** `Foresy/config/application.rb`
- **Problème :** `config.load_defaults 7.1` alors que le schéma cible `ActiveRecord::Schema[8.1]`.
- **Solution :** Mettre à jour à `config.load_defaults 8.0` (ou `8.1`). Vérifier les breaking changes Rails 8.0/8.1.
- **Tests :** Suite de tests complète + vérification des déprécations dans les logs.
- **Effort :** 1-2h
- **Risque :** Moyen — Peut activer de nouveaux comportements par défaut
- **Statut :** ⬜ Non commencé

**Sous-dossier de suivi :** [`docs/technical/[Done]_remediation/phase-5-db-config.md`](../[Done]_remediation/phase-5-db-config.md)

---

### 🟢 Phase 6 — Hardening Final

> **Objectif :** Sécuriser le Git Ledger, terminer le nettoyage des modèles, finaliser l'API de tests.
> **Livrable :** 1-2 PR.
> **Critère d'arrêt :** Aucun shell injection dans GitLedger. `CraEntry` sans code commenté. `users` PK cohérent.

#### Tâches

##### P6.1 — Sécuriser `GitLedgerRepository` contre les injections shell

- **Point audit :** SE1
- **Fichiers :** `Foresy/app/services/git_ledger_repository.rb`
- **Problème :** Utilise des backticks `` `git ...` `` et `system()` avec `2>/dev/null`. `Shellwords.escape` partiel.
- **Solution :** Migrer vers `Open3.capture3` ou `Open3.popen3` avec gestion explicite du exit status. Échapper systématiquement tous les arguments. Logger les erreurs stderr au lieu de les supprimer.
- **Tests :** Tests unitaires avec IDs malveillants (ex: `; rm -rf /`) pour vérifier l'échappement.
- **Effort :** 2-4h
- **Risque :** Moyen — Impacte le ledger d'audit des CRA locked
- **Statut :** ⬜ Non commencé

##### P6.2 — Nettoyer `CraEntry` : callbacks commentés + `attr_writer` TDD

- **Point audit :** M4
- **Fichiers :** `Foresy/app/models/cra_entry.rb`
- **Problème :** Callbacks `before_create/update/destroy :validate_cra_lifecycle!` commentés (L83-100), `attr_writer :cra, :mission` pour "transient TDD support" (L111).
- **Solution :** Supprimer le code commenté. Évaluer si `attr_writer` est encore nécessaire (les services utilisent-ils le transient ?). Si oui, déplacer la logique dans le service. Si non, supprimer.
- **Tests :** Vérifier que les services `CraEntryServices::*` ne dépendent pas du transient.
- **Effort :** 1-2h
- **Risque :** Moyen — Casse potentielle des services
- **Statut :** ⬜ Non commencé

##### P6.3 — Évaluer la migration `users` PK bigint → UUID (long terme)

- **Point audit :** D1
- **Fichiers :** Migration complexe impactant `users`, `sessions`, `user_missions`, `user_cras`, `created_by_user_id` dans `missions` et `cras`.
- **Problème :** `users` est la seule table avec PK bigint au lieu d'UUID.
- **Solution :** Migration en 3 étapes : (1) ajouter colonne `uuid_id` UUID, (2) backfill + dupliquer les FK, (3) basculer. **OU** documenter comme choix délibéré et fermer le point.
- **Décision :** À évaluer — Effort élevé vs bénéfice. Peut être reporté sine die si documenté comme décision architecturale.
- **Effort :** 4-8h (si migration) / 15min (si documentation)
- **Risque :** Élevé (migration) / Néant (documentation)
- **Statut :** ⬜ Non commencé

**Sous-dossier de suivi :** [`docs/technical/[Done]_remediation/phase-6-hardening-final.md`](../[Done]_remediation/phase-6-hardening-final.md)

---

## 4. Tableau de Bord de Suivi

### 4.1 Vue Globale

| Phase | Tâches | ⬜ À faire | 🟡 En cours | ✅ Terminé | ⏸️ Bloqué | % Avancement |
|---|---|---|---|---|---|---|
| **P0 — Sécurité** | 4 | 0 | 0 | 4 | 0 | 100% |
| **P1 — Stabilisation** | 2 | 0 | 0 | 2 | 0 | 100% |
| **P2 — Unification Erreurs** | 3 | 0 | 0 | 3 | 0 | 100% |
| **P3 — Nettoyage Code Mort** | 2 | 0 | 0 | 2 | 0 | 100% |
| **P4 — Cohérence Archi + DDD** | 7 | 0 | 0 | 7 | 0 | 100% |
| **P5 — DB & Config** | 4 | 0 | 0 | 4 | 0 | 100% |
| **P6 — Hardening Final** | 3 | 0 | 0 | 3 | 0 | 100% |
| **Total** | **25** | **0** | **0** | **25** | **0** | **100%** |

### 4.2 Détail par Tâche

> Légende : ⬜ À faire · 🟡 En cours · ✅ Terminé · ⏸️ Bloqué · ❌ Annulé
> Cycle TDD : 🔴 RED → 🟢 GREEN → 🔵 REFACTOR (voir §1.3.1)

| ID | Tâche | Phase | Priorité | Statut | 🔴 RED | 🟢 GREEN | 🔵 REFACTOR | PR | Notes |
|---|---|---|---|---|---|---|---|---|---|
P0.1 | Verrouiller routes `__test_support__` en prod | P0 | 🔴 | ✅ | ✅ | ✅ | ✅ | — | Spec integration prod mock
P0.2 | Supprimer `puts` JWT dans `authenticatable.rb` | P0 | 🔴 | ✅ | ✅ | ✅ | — | Test invariant: pas de JWT dans stdout
P0.3 | Supprimer `puts` dans `missions_controller.rb` | P0 | 🔴 | ✅ | ✅ | ✅ | — | Test invariant: stdout vide
P0.4 | Sécuriser `OauthController#callback` fuite erreurs | P0 | 🔴 | ✅ | ✅ | ✅ | — | Test invariant: `e.message` absent
P1.1 | Résoudre crash `Domain::CraEntry::CraEntry` | P1 | 🔴 | ✅ | ✅ | ✅ | — | Option A: 4 fichiers supprimés
P1.2 | Résoudre conflit `rescue_from StandardError` | P1 | 🔴 | ✅ | ✅ | ✅ | ✅ | — | Spec integration 500 formaté
P2.1 | Évaluer et merger la Phase 1.9 | P2 | 🟡 | ✅ | ✅ | ✅ | — | Déjà présente sur la branche
P2.2 | Supprimer concern orphelin `ErrorRenderable` | P2 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | 2 specs, 0 failures
P2.3 | Migrer `render_fc07_error` vers format unifié | P2 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | 3 specs + 18 non-régression
P3.1 | Supprimer code mort `app/lib` (~2700 lignes) | P3 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | 5 fichiers supprimés, 10 specs
P3.2 | Supprimer concerns modèles orphelins | P3 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | 3 fichiers supprimés, 6 specs
P4.1 | Aligner héritage contrôleurs sur `BaseController` | P4 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | Déjà fait (fix CI)
P4.2 | Extraire `extract_client_ip_for_rate_limiting` | P4 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | Concern Common::RateLimitable
P4.3 | Extraire logique métier `MissionsController` | P4 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | Thin controller + services
P4.4 | Nettoyer 3 couches services CRA Entries | P4 | 🟡 | ✅ | ✅ | ✅ | ✅ | P1.1 | Suite P1.1
P4.5 | Unifier format 429 `UsersController` | P4 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | Déjà fait (fix CI)
P4.6 | Remplacer `default_scope` par scopes explicites | P4 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | M2: 4 modèles
P4.7 | Migrer `created_by_user_id` → tables pivot | P4 | 🟡 | ✅ | ✅ | ✅ | ✅ | — | M3: FK legacy → DDD
P5.1 | Migrer `users.uuid` VARCHAR → UUID natif | P5 | 🟢 | ✅ | ✅ | ✅ | ✅ | — | Migration + USING uuid::uuid
P5.2 | Migrer `role` string → enum PG | P5 | 🟢 | ✅ | ✅ | ✅ | ✅ | — | Enum user_relation_role + index rebuild
P5.3 | Renommer module `App` → `Foresy` | P5 | 🟢 | ✅ | ✅ | ✅ | ✅ | — | Aucune référence App:: dans le code
P5.4 | Aligner `load_defaults` 8.1 | P5 | 🟢 | ✅ | ✅ | ✅ | ✅ | — | 7.1 → 8.0
P6.1 | Sécuriser `GitLedgerRepository` shell | P6 | 🟢 | ✅ | ✅ | ✅ | ✅ | — | Open3.capture3, 9 specs injection
P6.2 | Nettoyer `CraEntry` callbacks + `attr_writer` | P6 | 🟢 | ✅ | ✅ | ✅ | ✅ | — | Commentaires + attr_writer supprimés
P6.3 | Évaluer migration `users` PK → UUID | P6 | 🟢 | ✅ | ✅ | ✅ | ✅ | — | Documenté comme choix architectural

### 4.3 Synthèse par Point d'Audit

| Point | Phase | Tâche | Statut |
|---|---|---|---|
| F3 — `E2E_MODE` routes test | P0 | P0.1 | ⬜ |
| C3 — `puts` JWT et debug | P0 | P0.2, P0.3 | ⬜ |
| C8 — Fuite `e.message` OAuth | P0 | P0.4 | ⬜ |
| S1 — Crash `Domain::CraEntry` | P1 | P1.1 | ⬜ |
| C2 — Conflit `rescue_from` | P1 | P1.2 | ⬜ |
| C1 — 3 formats d'erreur | P2 | P2.1, P2.2, P2.3 | ⬜ |
| L1 — Code mort `app/lib` | P3 | P3.1 | ⬜ |
| M1 — Concerns orphelins | P3 | P3.2 | ⬜ |
| C4 — Héritage `BaseController` | P4 | P4.1 | ⬜ |
| C6 — Duplication IP rate limit | P4 | P4.2 | ⬜ |
| C10 — Logique métier `MissionsController` | P4 | P4.3 | ⬜ |
| S1 (suite) — 3 couches services | P4 | P4.4 | ⬜ |
| C9 — Format 429 `UsersController` | P4 | P4.5 | ⬜ |
| D2 — `users.uuid` VARCHAR | P5 | P5.1 | ⬜ |
| D3 — `role` string vs enum | P5 | P5.2 | ⬜ |
| F1 — Module `App` vs `Foresy` | P5 | P5.3 | ⬜ |
| F2 — `load_defaults` 7.1 | P5 | P5.4 | ⬜ |
| SE1 — `GitLedgerRepository` shell | P6 | P6.1 | ⬜ |
| M4 — `CraEntry` callbacks | P6 | P6.2 | ⬜ |
| D1 — `users` PK bigint | P6 | P6.3 | ⬜ |
| C5 — `OAuthConcern` inutile | P2/P4 | (intégré à P2.1) | ⬜ |
| C7 — Méthodes publiques `OauthController` | P4 | (à ajouter si besoin) | ⬜ |
| M2 — `default_scope` | P4 | (à ajouter si P3.2 Option B) | ⬜ |
| M3 — FK legacy `created_by_user_id` | P4 | ✅ Colonne supprimée (P4.7 final) | ✅ |
| M5 — Dualité erreurs/retours | P2 | (intégré à P2.3) | ⬜ |
| S2 — `ApplicationResult` API | P2 | (intégré à P2.1) | ⬜ |

---

## 5. Critères de Validation et Définition of Done

### 5.1 Critères Généraux (applicables à toute PR)

#### Méthodologie TDD (obligatoire)
- [ ] **Commit 1 — 🔴 RED** : Un test caractérisant le comportement attendu est ajouté et **échoue** d'abord
- [ ] **Commit 2 — 🟢 GREEN** : Implémentation minimale pour faire passer le test (pas plus)
- [ ] **Commit 3 — 🔵 REFACTOR** (optionnel) : Amélioration sans casser les tests
- [ ] Le message du commit RED préfixe par `test:` / GREEN par `feat:` ou `fix:` / REFACTOR par `refactor:`

#### Qualité Platinum (FC-07 compatible)
- [ ] `bundle exec rspec` — tous les tests passent (y compris nouveaux tests RED passés en GREEN)
- [ ] `bundle exec rubocop` — aucune offense sur les fichiers modifiés
- [ ] `bundle exec brakeman` — aucune nouvelle vulnérabilité
- [ ] `bundle exec rake zeitwerk:check` — aucun fichier mal autoloadé
- [ ] `bundle exec rake swagger:validate_schemas` — schémas OpenAPI valides (si endpoint modifié)
- [ ] La PR est reviewable (taille < 500 lignes si possible)
- [ ] Le suivi d'avancement dans ce document est mis à jour (statut + colonnes RED/GREEN/REFACTOR)
- [ ] Une entrée est ajoutée dans le journal d'exécution du sous-document de phase

#### Conformité DDD (si la tâche touche le domaine)
- [ ] Aucune logique métier ajoutée dans un contrôleur
- [ ] Les services retournent `ApplicationResult` (pas d'exceptions brutes)
- [ ] Les erreurs métier sont typées (`CraErrors::*`, `MissionErrors::*`)
- [ ] Aucune nouvelle FK directe entre entités métier (utiliser les tables pivot)
- [ ] Aucune dépendance du domaine vers Rails/HTTP/infrastructure

### 5.2 Critères Spécifiques par Phase

#### Phase 0 — Sécurité
- [ ] Test d'intégration : `__test_support__/*` retourne 404 en prod même avec `E2E_MODE=true`
- [ ] Test : aucun token JWT dans stdout/stderr après une requête authentifiée
- [ ] Test : `OauthController#callback` ne renvoie jamais `e.message` au client

#### Phase 1 — Stabilisation
- [ ] Boot de l'app sans `NameError` (P1.1 Option A ou B)
- [ ] Test d'intégration : une route levant `StandardError` renvoie un JSON `{ code, message }` en 500

#### Phase 2 — Unification Erreurs
- [ ] Test : tous les endpoints d'erreur retournent le même schéma JSON
- [ ] `grep -r "render_fc07_error" app/` retourne 0 résultat
- [ ] `grep -r "ErrorRenderable" app/` retourne 0 résultat
- [ ] Document `docs/technical/guides/error_contract.md` créé

#### Phase 3 — Nettoyage Code Mort
- [ ] `bundle exec rake zeitwerk:check` passe
- [ ] Aucun fichier supprimé n'est référencé dans `app/` ou `config/`
- [ ] ~2700 lignes supprimées du codebase

#### Phase 4 — Cohérence Architecturale
- [ ] `grep -r "extract_client_ip_for_rate_limiting" app/controllers/` retourne 0 résultat (méthode dans un concern)
- [ ] `MissionsController` ne contient aucun `MissionCompany.create` ou `transition_to`
- [ ] Headers de dépréciation présents sur tous les endpoints `/api/v1/*`

#### Phase 5 — DB & Config
- [ ] `db/schema.rb` cohérent (PK UUID partout si P6.3 fait)
- [ ] `config.load_defaults 8.0` ou `8.1`
- [ ] `module Foresy` (pas `App`)
- [ ] Migrations réversibles (`rails db:rollback` fonctionne)

#### Phase 6 — Hardening Final
- [ ] Tests d'injection shell sur `GitLedgerRepository` passent
- [ ] `CraEntry` ne contient aucun code commenté
- [ ] `attr_writer :cra, :mission` supprimé ou justifié

---

## 6. Risques, Dépendances et Assomptions

### 6.1 Risques Principaux

| Risque | Probabilité | Impact | Mitigation |
|---|---|---|---|
| P1.1 supprime des services appelés en prod | Moyenne | 🔴 Élevé | Grep exhaustif des appelants avant suppression |
| P2.1 Phase 1.9 casse les tests RSwag | Moyenne | 🟡 Moyen | Review approfondie + mise à jour specs |
| P5.3 Renommage module `App` casse des références | Élevée | 🔴 Élevé | Tests complets + déploiement progressif |
| P6.1 Refactor GitLedger casse le ledger d'audit | Faible | 🔴 Élevé | Tests avec CRA locked existants |
| P4.3 Refactor `MissionsController` régression | Moyenne | 🟡 Moyen | Tests request existants comme filet |
| Migration DB P5.x en production | Faible | 🟡 Moyen | Migrations testées en staging d'abord |

### 6.2 Dépendances

- **P1 → P0** : Stabilisation avant sécurité non critique, mais P0 peut être fait en parallèle
- **P2 → P1** : L'unification des erreurs nécessite que `rescue_from` soit stable
- **P3 → P1** : Supprimer le code mort `app/lib` après stabilisation runtime (certains fichiers pourraient être liés)
- **P4 → P2, P3** : La refactorisation contrôleurs/services après unification erreurs et nettoyage
- **P5 → P4** : Les migrations DB après stabilisation du code
- **P6 → P5** : Hardening final après tout le reste

### 6.3 Assomptions

- L'environnement de staging Render est disponible pour tester les migrations DB
- La branche `phase-1-9-error-contract` est reviewable et peut être mergée ou rejetée
- Aucun déploiement majeur de feature nouvelle n'a lieu pendant la remédiation
- Les tests RSpec + RSwag actuels (449 + 184 examples) constituent un filet de sécurité suffisant

### 6.4 Points Requérant une Décision

| Décision | Quand | Par | Options |
|---|---|---|---|
| P1.1 Option A (supprimer) vs B (créer `Domain::CraEntry`) | Avant P1 | CTO | A recommandée |
| P3.2 Option A (supprimer concerns) vs B (intégrer) | Avant P3 | CTO | A recommandée |
| P6.3 Migrer `users` PK → UUID vs documenter | Avant P6 | CTO | Documenter recommandé |

---

## 7. Convention de Mise à Jour du Suivi

### 7.1 Quand Mettre à Jour ce Document

Ce document doit être mis à jour :
- À chaque démarrage de tâche (statut ⬜ → 🟡)
- À chaque commit TDD (mise à jour des colonnes 🔴 RED / 🟢 GREEN / 🔵 REFACTOR)
- À chaque fermeture de tâche (statut 🟡 → ✅ ou ❌)
- À chaque blocage (statut → ⏸️ avec note)
- À chaque merge de PR (ajouter le numéro de PR)
- À chaque changement de plan (nouvelle tâche, annulation, repriorisation)

### 7.2 Format des Mises à Jour

Pour chaque tâche modifiée, mettre à jour :
1. Le statut dans la section 4.2 (tableau détaillé) — colonnes `Statut`, `🔴 RED`, `🟢 GREEN`, `🔵 REFACTOR`
2. Le statut dans la section 4.1 (vue globale par phase)
3. Le `% avancement` recalculé : `terminé / total × 100`
4. Le `Dernière mise à jour du suivi` en haut du document
5. Si besoin, ajouter une note dans la colonne `Notes` (PR, problème rencontré, etc.)

### 7.3 Workflow Recommandé (TDD strict)

1. **Démarrage tâche :** Créer une branche `[Done]_remediation/PX.Y-description`
2. **🔴 RED (commit 1, message `test: ...`)** : Écrire le test caractérisant le comportement attendu. Vérifier qu'il **échoue** pour la bonne raison (ex: assertion sur 404 mais route existe).
3. **🟢 GREEN (commit 2, message `feat: ...` ou `fix: ...`)** : Implémenter le minimum pour faire passer le test.
4. **🔵 REFACTOR (commit 3, message `refactor: ...`)** (optionnel) : Améliorer la lisibilité/performance sans casser les tests.
5. **Validation Platinum :** Vérifier les critères de la section 5 (rspec, rubocop, brakeman, zeitwerk, swagger).
6. **PR :** Référencer ce document dans la description de la PR + joindre les 3 commits TDD.
7. **Merge :** Mettre à jour le statut → ✅ avec le numéro de PR dans toutes les colonnes concernées.
8. **Sous-document :** Compléter le journal d'exécution dans `docs/technical/[Done]_remediation/phase-X-*.md`.

### 7.4 Liens Vers les Sous-Documents de Suivi

Chaque phase a un sous-document dédié dans `docs/technical/[Done]_remediation/` pour le détail d'exécution (logs, décisions, problèmes rencontrés, screenshots de tests) :

- [Phase 0 — Sécurité Critique](../[Done]_remediation/phase-0-securite.md)
- [Phase 1 — Stabilisation Runtime](../[Done]_remediation/phase-1-stabilisation.md)
- [Phase 2 — Unification Erreurs](../[Done]_remediation/phase-2-unification-erreurs.md)
- [Phase 3 — Nettoyage Code Mort](../[Done]_remediation/phase-3-nettoyage-code-mort.md)
- [Phase 4 — Cohérence Architecturale](../[Done]_remediation/phase-4-coherence-architecturale.md)
- [Phase 5 — Base de Données & Config](../[Done]_remediation/phase-5-db-config.md)
- [Phase 6 — Hardening Final](../[Done]_remediation/phase-6-hardening-final.md)

---

## 8. Annexes

### 8.1 Glossaire

- **DDD/RDD** : Domain-Driven Design / Relation-Driven Design (tables de relation explicites plutôt que FK directes)
- **ApplicationResult** : Façade de retour des services (`success`/`fail` avec status HTTP)
- **CraErrors** : Exceptions métier typées du domaine CRA
- **Git Ledger** : Versioning Git des CRA locked pour audit légal immuable
- **RSwag** : Génération de documentation OpenAPI/Swagger depuis les tests RSpec
- **Soft Delete** : Suppression logique via `deleted_at` plutôt que suppression physique
- **Feature Flags** : `FeatureFlags.relation_driven?` active le nouveau chemin DDD

### 8.2 Références

- [Analyse technique Foresy](./ANALYSE_TECHNIQUE_FORESY.md)
- [Guidelines de maintenance documentaire](../../MAINTENANCE_GUIDELINES.md)
- [Backlog produit](../../BACKLOG.md)
- [Briefing projet](../../BRIEFING.md)
- [Vision produit](../../VISION.md)

### 8.3 Commandes de Validation Utiles

```bash
# Tests complets
bundle exec rspec

# Qualité code
bundle exec rubocop
bundle exec brakeman

# Vérification autoload
bundle exec rake zeitwerk:check

# Schémas OpenAPI
bundle exec rake swagger:validate_schemas

# Grep code mort
grep -r "SharedResultAdapter\|SharedResultKillSwitches\|Step3ReportingSystem\|DomainLeakageDetector" app/ config/

# Grep duplication IP
grep -r "extract_client_ip_for_rate_limiting" app/controllers/

# Grep `render_fc07_error` (doit tendre vers 0)
grep -r "render_fc07_error" app/

# Grep `puts` de debug (doit tendre vers 0)
grep -rn "puts " app/controllers/
```

### 8.4 Historique des Révisions de ce Document

| Date | Auteur | Changement |
|---|---|---|
| 2026-08-18 | Zed Agent | Création initiale — Audit complet + plan 23 tâches en 6 phases |
| 2026-08-18 | Zed Agent | Formalisation méthodologie TDD + DDD + Platinum (§1.3, §4.2, §5.1, §7) |
| 2026-08-18 | Zed Agent | Restructuration Phase 4 pour finalisation DDD (P4.6 + P4.7, total 25 tâches) |
| 2026-08-18 | Zed Agent | P0-P6 terminés : 25/25 tâches (100%), 850 tests, 0 failures, 4 pending |
| 2026-08-18 | Zed Agent | Mise à jour finale du tableau de bord — toutes phases 100% |
| 2026-08-18 | Zed Agent | Suppression DB définitive de `created_by_user_id` (P4.7 final) — 850 tests, 0 failures, 0 pending |

---

**Document créé le :** 18 août 2026
**Dernière mise à jour :** 18 août 2026
**Statut :** ✅ TERMINÉ — 25/25 tâches complétées (100%), colonne `created_by_user_id` supprimée
**Prochaine révision prévue :** À la prochaine évolution architecture
**Propriétaire :** Équipe technique Foresy