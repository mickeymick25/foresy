# Phase 5 — Base de Données & Configuration

**Phase :** P5 — Base de Données & Configuration
**Priorité :** 🟢 Moyenne
**Statut phase :** ✅ Terminée
**Date de début :** 2026-08-18
**Date de fin prévue :** 2026-08-18
**Document parent :** [`docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md)

---

## 🎯 Objectif

Corriger les incohérences de schéma et de configuration Rails.

## 🧪 Méthodologie TDD + DDD + Platinum

Chaque tâche suit le cycle **🔴 RED → 🟢 GREEN → 🔵 REFACTOR** en 3 commits distincts (voir [§1.3 du document principal](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#13-méthodologie-tdd--ddd--niveau-platinum)).

- 🔴 **RED** : Test caractérisant le schéma cible (ex: `User.create(uuid: 'invalid')` lève une erreur DB)
- 🟢 **GREEN** : Migration DB qui réalise le changement
- 🔵 **REFACTOR** : Nettoyage des contraintes redondantes (ex: check constraint supprimé car enum PG natif)

**DDD** : Les migrations DB ne doivent pas affaiblir les invariants métier. Les enums PG renforcent le typage domaine.

**Critères Platinum** : rspec ✅ / rubocop ✅ / brakeman ✅ + `db:migrate` ✅ + `db:rollback` ✅ (réversibilité) + tests sur les invariants DB.

## 📋 Tâches

| ID | Tâche | Statut | 🔴 RED | 🟢 GREEN | 🔵 REFACTOR | PR | Notes |
|---|---|---|---|---|---|---|---|
| P5.1 | Migrer `users.uuid` VARCHAR → UUID natif | ✅ | ✅ | ✅ | ✅ | — | Migration + USING uuid::uuid |
| P5.2 | Migrer `role` string → enum PG | ✅ | ✅ | ✅ | ✅ | — | Enum user_relation_role + index rebuild |
| P5.3 | Renommer module `App` → `Foresy` | ✅ | ✅ | ✅ | ✅ | — | Aucune référence App:: dans le code |
| P5.4 | Aligner `load_defaults` 8.1 | ✅ | ✅ | ✅ | ✅ | — | 7.1 → 8.0 |

---

## 📝 Migrations à Créer

### P5.1 — `change_users_uuid_to_native_uuid.rb`

```ruby
class ChangeUsersUuidToNativeUuid < ActiveRecord::Migration[8.1]
  def up
    # PostgreSQL convertit automatiquement VARCHAR(36) → uuid
    change_column :users, :uuid, :uuid
    # Idem pour sessions si applicable
    change_column :sessions, :uuid, :uuid if column_exists?(:sessions, :uuid)
  end

  def down
    change_column :users, :uuid, :string, limit: 36
  end
end
```

### P5.2 — `create_user_relation_role_enum.rb`

```ruby
class CreateUserRelationRoleEnum < ActiveRecord::Migration[8.1]
  def up
    create_enum :user_relation_role, %w[creator contributor reviewer]

    change_column :user_missions, :role, :enum, enum_type: :user_relation_role
    change_column :user_cras, :role, :enum, enum_type: :user_relation_role

    # Supprimer la check constraint redondante
    remove_check_constraint :user_missions, name: :user_missions_role_check
    remove_check_constraint :user_cras, name: :user_cras_role_check
  end

  def down
    add_check_constraint :user_missions, "role IN ('creator','contributor','reviewer')", name: :user_missions_role_check
    add_check_constraint :user_cras, "role IN ('creator','contributor','reviewer')", name: :user_cras_role_check

    change_column :user_missions, :role, :string, default: 'creator'
    change_column :user_cras, :role, :string, default: 'creator'

    drop_enum :user_relation_role
  end
end
```

> ⚠️ Vérifier les noms exacts des check constraints dans `db/schema.rb` avant d'exécuter.

---

## 📝 Checklist Renommage `App` → `Foresy` (P5.3)

> ⚠️ Risque élevé — À réaliser avec soin. Idéalement via la gem `rename` ou un script dédié.

**Fichiers à modifier :**
- [ ] `Foresy/config/application.rb` — `module App` → `module Foresy`
- [ ] `Foresy/config/environment.rb` — `App` → `Foresy`
- [ ] `Foresy/config.ru` — `App` → `Foresy`
- [ ] `Foresy/Rakefile` — `App` → `Foresy`
- [ ] `Foresy/config/environments/*.rb` — `App` → `Foresy`
- [ ] `Foresy/config/initializers/*.rb` — références `App::`
- [ ] Tous les contrôleurs avec namespace `App::`
- [ ] Tous les tests avec `App::`
- [ ] `Foresy/config/puma.rb` — références `App`

**Commande de recherche :**
```bash
grep -rn "App::" app/ config/ spec/ lib/ | grep -v node_modules
```

---

## 📝 Journal d'Exécution (TDD)

### 🔴 RED — 2026-08-18 — P5.1

- **Test ajouté :** `spec/integration/p5_1_users_uuid_native_spec.rb`
- **Invariant visé :** `users.uuid` est de type UUID natif PostgreSQL ; `User.create(uuid: 'invalid')` lève une erreur DB
- **Raison de l'échec :** `users.uuid` est en `VARCHAR(36)`, accepte n'importe quelle chaîne
- **Commit :** `test: P5.1 caracterise users.uuid comme UUID natif`

### 🟢 GREEN — 2026-08-18 — P5.1

- **Migration / Implémentation :** `change_column :users, :uuid, :uuid` avec `USING uuid::uuid`
- **Fichiers modifiés :** `db/migrate/..._change_users_uuid_to_native_uuid.rb`, `db/schema.rb`
- **Test passe ✅ :** 3 examples, 0 failures + `db:rollback` ✅
- **Commit :** `feat: P5.1 migre users.uuid VARCHAR(36) vers UUID natif`

### 🔴 RED — 2026-08-18 — P5.2

- **Test ajouté :** `spec/integration/p5_2_user_missions_role_enum_spec.rb`
- **Invariant visé :** `user_missions.role` utilise un enum PG (`user_relation_role`), les valeurs invalides sont rejetées par la DB
- **Raison de l'échec :** `role` est en `string` + check constraint applicative
- **Commit :** `test: P5.2 caracterise user_missions.role comme enum PG`

### 🟢 GREEN — 2026-08-18 — P5.2

- **Migration / Implémentation :** `create_enum :user_relation_role` + `change_column ... :enum` avec `USING` + rebuild de l'index + suppression des check constraints redondantes
- **Fichiers modifiés :** `db/migrate/..._create_user_relation_role_enum.rb`, `db/schema.rb`
- **Test passe ✅ :** 4 examples, 0 failures + `db:rollback` ✅
- **Commit :** `feat: P5.2 migre role string vers enum PG user_relation_role`

### 🔴 RED — 2026-08-18 — P5.3

- **Test ajouté :** `spec/integration/p5_3_module_renaming_spec.rb`
- **Invariant visé :** Le module racine est `Foresy`, aucune référence `App::` dans `app/`/`config/`/`spec/`
- **Raison de l'échec :** `config/application.rb` définit `module App`
- **Commit :** `test: P5.3 caracterise le module racine comme Foresy`

### 🟢 GREEN — 2026-08-18 — P5.3

- **Migration / Implémentation :** `module App` → `module Foresy` dans `config/application.rb` + propagation aux références
- **Fichiers modifiés :** `config/application.rb` + fichiers référençant `App::`
- **Test passe ✅ :** 3 examples, 0 failures
- **Commit :** `fix: P5.3 renomme le module App en Foresy`

### 🔴 RED — 2026-08-18 — P5.4

- **Test ajouté :** `spec/integration/p5_4_load_defaults_spec.rb`
- **Invariant visé :** `config.load_defaults >= 8.0`
- **Raison de l'échec :** `config.load_defaults 7.1`
- **Commit :** `test: P5.4 caracterise load_defaults >= 8.0`

### 🟢 GREEN — 2026-08-18 — P5.4

- **Migration / Implémentation :** `config.load_defaults 7.1` → `config.load_defaults 8.0`
- **Fichiers modifiés :** `config/application.rb`
- **Test passe ✅ :** 1 example, 0 failures
- **Commit :** `fix: P5.4 aligne config.load_defaults sur 8.0`

### 🎯 Merge — 2026-08-18

- **PR :** Branche `phase-5-db-config`
- **Validation Platinum :** rspec ✅ / rubocop ✅ / brakeman ✅ / zeitwerk ✅ + `db:migrate` ✅ + `db:rollback` ✅
- **Notes :** `db/schema.rb` montre `users.uuid` en UUID natif et `user_missions.role` en enum PG ; `config/application.rb` contient `module Foresy` et `load_defaults 8.0`

---

## ✅ Critères de Fin de Phase

- [ ] `db/schema.rb` montre `users.uuid` comme type `uuid` natif
- [ ] `db/schema.rb` montre `user_missions.role` et `user_cras.role` comme enum PG
- [ ] `config/application.rb` contient `module Foresy`
- [ ] `config.load_defaults 8.0` ou `8.1`
- [ ] `bundle exec rspec` passe
- [ ] `bundle exec rake zeitwerk:check` passe
- [ ] Migrations réversibles (`rails db:rollback` fonctionne)

---

## 🔗 Références

- [Tâche P5.1 — Migrer `users.uuid`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p51--migrer-usersuuid-de-varchar36-vers-uuid-natif-postgresql)
- [Tâche P5.2 — Migrer `role` en enum PG](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p52--migrer-user_missionsrole-et-user_crasrole-en-enum-postgresql)
- [Tâche P5.3 — Renommer module `App`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p53--renommer-le-module-rails-app-en-foresy)
- [Tâche P5.4 — Aligner `load_defaults`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p54--aligner-configload_defaults-sur-la-version-rails-81)