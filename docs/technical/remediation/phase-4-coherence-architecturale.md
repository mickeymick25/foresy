# Phase 4 — Cohérence Architecturale

**Phase :** P4 — Cohérence Architecturale
**Priorité :** 🟡 Haute
**Statut phase :** ✅ Terminée
**Date de début :** —
**Date de fin prévue :** —
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
| P4.2 | Extraire `extract_client_ip_for_rate_limiting` | ⬜ | ⬜ | ⬜ | ⬜ | — | Concern `Common::RateLimitable` |
| P4.3 | Extraire logique métier `MissionsController` | ⬜ | ⬜ | ⬜ | ⬜ | — | 4-6h |
| P4.4 | Nettoyer 3 couches services CRA Entry | ✅ | ✅ | ✅ | ✅ | P1.1 | Suite P1.1 |
| P4.5 | Unifier format 429 `UsersController` | ✅ | ✅ | ✅ | ✅ | fix CI | Déjà fait |
| P4.6 | Remplacer `default_scope` par scopes explicites | ⬜ | ⬜ | ⬜ | ⬜ | — | M2: 4 modèles |
| P4.7 | Migrer `created_by_user_id` → tables pivot | ⬜ | ⬜ | ⬜ | ⬜ | — | M3: FK legacy → DDD |

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

### 🔴 RED — YYYY-MM-DD — [Tâche PX.Y]

- **Test ajouté :**
- **Invariant visé :**
- **Raison de l'échec :**
- **Commit :** `test: ...`

### 🟢 GREEN — YYYY-MM-DD — [Tâche PX.Y]

- **Implémentation minimale :**
- **Fichiers modifiés :**
- **Test passe ✅ :**
- **Commit :** `feat: ...` ou `fix: ...`

### 🔵 REFACTOR — YYYY-MM-DD — [Tâche PX.Y] (optionnel)

- **Amélioration :**
- **Tests toujours verts ✅ :**
- **Commit :** `refactor: ...`

### 🎯 Merge — YYYY-MM-DD

- **PR :** #
- **Validation Platinum :**
- **Notes :**

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