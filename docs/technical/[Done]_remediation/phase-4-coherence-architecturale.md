# Phase 4 — Cohérence Architecturale

**Phase :** P4 — Cohérence Architecturale
**Priorité :** 🟡 Haute
**Statut phase :** ✅ Terminée
**Date de début :** 2026-08-18
**Date de fin prévue :** 2026-08-18
**Document parent :** [`docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md)

---

## 🎯 Objectif

Unifier les patterns architecturaux (héritage contrôleurs, IP rate limiting, logique métier dans services, layers de services) ET finaliser la migration DDD (suppression des `default_scope`, migration des FK legacy vers tables pivot).

## 🧪 Méthodologie TDD + DDD + Platinum

Chaque tâche suit le cycle **🔴 RED → 🟢 GREEN → 🔵 REFACTOR** en 3 commits distincts (voir [§1.3 du document principal](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#13-méthodologie-tdd--ddd--niveau-platinum)).

- 🔴 **RED** : Test caractérisant l'architecture cible (ex: scope explicite, service appelé, format unifié)
- 🟢 **GREEN** : Implémentation minimale du pattern unifié
- 🔵 **REFACTOR** : Suppression des duplications / couches obsolètes

**DDD** : P4.3 (services `MissionServices::*`) doit suivre strictement le pattern `CraServices::*` — services retournent `ApplicationResult`, contrôleurs minces. P4.6 et P4.7 finalisent la migration DDD en supprimant les `default_scope` anti-pattern et les FK legacy.

**Critères Platinum :** rspec ✅ / rubocop ✅ / brakeman ✅ / zeitwerk:check ✅ + tests RSwag à jour + grep `extract_client_ip_for_rate_limiting` retourne 0 dans les contrôleurs.

## 📋 Tâches

| ID | Tâche | Statut | 🔴 RED | 🟢 GREEN | 🔵 REFACTOR | PR | Notes |
|---|---|---|---|---|---|---|---|
| P4.1 | Aligner héritage contrôleurs sur `BaseController` | ✅ | ✅ | ✅ | ✅ | fix CI | Déjà fait |
| P4.2 | Extraire `extract_client_ip_for_rate_limiting` | ✅ | ✅ | ✅ | ✅ | — | Concern Common::RateLimitable |
| P4.3 | Extraire logique métier `MissionsController` | ✅ | ✅ | ✅ | ✅ | — | Thin controller + services |
| P4.4 | Nettoyer 3 couches services CRA Entry | ✅ | ✅ | ✅ | ✅ | P1.1 | Suite P1.1 |
| P4.5 | Unifier format 429 `UsersController` | ✅ | ✅ | ✅ | ✅ | fix CI | Déjà fait |
| P4.6 | Remplacer `default_scope` par scopes explicites | ✅ | ✅ | ✅ | ✅ | — | M2: 4 modèles |
| P4.7 | Migrer `created_by_user_id` → tables pivot | ✅ | ✅ | ✅ | ✅ | — | Colonne supprimée en DB |

---

## 📝 Design : Concern `Common::RateLimitable`

> À créer en P4.2.

**Fichier :** `Foresy/app/controllers/concerns/common/rate_limitable.rb`

```ruby
module Common
  module RateLimitable
    extend ActiveSupport::Concern

    private

    def extract_client_ip_for_rate_limiting
      request.remote_ip
    rescue StandardError
      'unknown'
    end
  end
end
```

**Contrôleurs à mettre à jour :**
- `AuthenticationController` — `include Common::RateLimitable`, supprimer la méthode
- `UsersController` — idem
- `MissionsController` — idem

---

## 📝 Design : Services `MissionServices::Create` et `Update`

> À créer en P4.3. Suivre le pattern `CraServices::*`.

### `MissionServices::Create`

```ruby
class MissionServices::Create
  def self.call(user:, params:)
    new(user, params).call
  end

  def call
    # Validation → Permission → Build → Save → Create MissionCompany
    # Retourner ApplicationResult
  end
end
```

### `MissionServices::Update`

```ruby
class MissionServices::Update
  def self.call(user:, mission:, params:)
    new(user, mission, params).call
  end

  def call
    # Validation → Permission → Transition state + Update attributes
    # Retourner ApplicationResult
  end
end
```

---

## 📝 Journal d'Exécution (TDD)

### 🔴 RED — 2026-08-18 — P4.2

- **Test ajouté :** `spec/integration/p4_2_rate_limitable_concern_spec.rb`
- **Invariant visé :** `Common::RateLimitable` est autoloadable et définit `extract_client_ip_for_rate_limiting` ; les contrôleurs ne définissent plus cette méthode
- **Raison de l'échec :** La méthode est dupliquée dans 3 contrôleurs, aucun concern partagé
- **Commit :** `test: P4.2 caracterise l'extraction de extract_client_ip_for_rate_limiting`

### 🟢 GREEN — 2026-08-18 — P4.2

- **Implémentation minimale :** Création du concern `Common::RateLimitable` + inclusion dans les 3 contrôleurs + suppression des méthodes dupliquées
- **Fichiers modifiés :** `app/controllers/concerns/common/rate_limitable.rb` (créé), `authentication_controller.rb`, `users_controller.rb`, `missions_controller.rb`
- **Test passe ✅ :** 4 examples, 0 failures
- **Commit :** `feat: P4.2 extrait extract_client_ip_for_rate_limiting dans Common::RateLimitable`

### 🔴 RED — 2026-08-18 — P4.3

- **Test ajouté :** `spec/integration/p4_3_missions_controller_thin_spec.rb`
- **Invariant visé :** `MissionsController` ne contient aucun `MissionCompany.create` ni `transition_to` ; il délègue à `MissionServices::*`
- **Raison de l'échec :** La logique métier (création/update/delete) est inline dans le contrôleur
- **Commit :** `test: P4.3 caracterise MissionsController comme thin controller`

### 🟢 GREEN — 2026-08-18 — P4.3

- **Implémentation minimale :** Création de `MissionServices::Create/Update/Delete` (pattern `CraServices::*`, retournent `ApplicationResult`) + `MissionsController` devient thin
- **Fichiers modifiés :** `app/services/mission_services/create.rb`, `update.rb`, `delete.rb` (créés), `app/controllers/missions_controller.rb`
- **Test passe ✅ :** 6 examples, 0 failures
- **Commit :** `feat: P4.3 extrait la logique metier de MissionsController vers MissionServices`

### 🔴 RED — 2026-08-18 — P4.6

- **Test ajouté :** `spec/integration/p4_6_default_scope_removal_spec.rb`
- **Invariant visé :** Les modèles n'ont plus de `default_scope` ; scopes explicites `active`, `with_deleted`, `only_deleted` disponibles ; associations mises à jour
- **Raison de l'échec :** 4 modèles utilisent `default_scope where(deleted_at: nil)` (anti-pattern)
- **Commit :** `test: P4.6 caracterise l'absence de default_scope sur les modeles`

### 🟢 GREEN — 2026-08-18 — P4.6

- **Implémentation minimale :** Remplacement des `default_scope` par des scopes explicites (`active`, `with_deleted`, `only_deleted`) + mise à jour des associations
- **Fichiers modifiés :** 4 modèles concernés + leurs associations
- **Test passe ✅ :** 5 examples, 0 failures
- **Commit :** `fix: P4.6 remplace default_scope par scopes explicites actifs/with_deleted/only_deleted`

### 🔴 RED — 2026-08-18 — P4.7

- **Test ajouté :** `spec/integration/p4_7_creator_user_id_pivot_migration_spec.rb`
- **Invariant visé :** `creator_user_id` est lu via les tables pivot (`user_missions.role == 'creator'`), la colonne `created_by_user_id` n'existe plus en DB
- **Raison de l'échec :** 16 occurrences lisent encore la colonne legacy `created_by_user_id`
- **Commit :** `test: P4.7 caracterise la lecture de creator via tables pivot`

### 🟢 GREEN — 2026-08-18 — P4.7

- **Implémentation minimale :** Migration des 16 occurrences vers les tables pivot, puis suppression de la colonne DB via la migration `2026072401`
- **Fichiers modifiés :** 16 fichiers + `db/migrate/2026072401_drop_created_by_user_id.rb`
- **Test passe ✅ :** 7 examples, 0 failures
- **Commit :** `fix: P4.7 migre creator_user_id vers tables pivot et supprime la colonne`

### 🎯 Merge — 2026-08-18

- **PR :** Branche `phase-4-architectural-coherence`
- **Validation Platinum :** rspec ✅ / rubocop ✅ / brakeman ✅ / zeitwerk ✅ + tests RSwag à jour + `grep extract_client_ip_for_rate_limiting app/controllers/` retourne 0
- **Notes :** P4.1 et P4.5 déjà faits via fix CI ; P4.4 déjà fait en P1.1 (couche cassée supprimée)

---

## ✅ Critères de Fin de Phase

- [ ] `grep -r "extract_client_ip_for_rate_limiting" app/controllers/` retourne 0 résultat (méthode dans le concern)
- [ ] `MissionsController` ne contient aucun `MissionCompany.create` ou `transition_to`
- [ ] Headers de dépréciation présents sur tous les endpoints `/api/v1/*`
- [ ] Une seule couche de services pour `cra_entries` (`CraEntryServices::*`)
- [ ] `UsersController` 429 utilise `error_too_many_requests`
- [ ] `bundle exec rspec` passe
- [ ] Tests RSwag passent

---

## 🔗 Références

- [Tâche P4.1 — Aligner héritage contrôleurs](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p41--aligner-lhéritage-des-contrôleurs-sur-basecontroller)
- [Tâche P4.2 — Extraire `extract_client_ip_for_rate_limiting`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p42--extraire-extract_client_ip_for_rate_limiting-dans-un-concern-partagé)
- [Tâche P4.3 — Extraire logique métier `MissionsController`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p43--extraire-la-logique-métier-de-missionscontroller-dans-des-services)
- [Tâche P4.4 — Nettoyer 3 couches services CRA Entries](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p44--nettoyer-les-3-couches-de-services-cra-entries)
- [Tâche P4.5 — Unifier format 429 `UsersController`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p45--unifier-le-format-429-de-userscontroller)