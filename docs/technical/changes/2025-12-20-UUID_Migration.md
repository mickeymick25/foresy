# 🔑 Migration vers UUID - 20 Décembre 2025

**Date :** 20 décembre 2025  
**Projet :** Foresy API  
**Type :** Migration - Changement de type d'identifiants  
**Status :** ✅ **COMPLÉTÉ**

---

## 🎯 Problème Identifié

### Analyse CI - Point 9

> Swagger / schema : ID type mismatch
>
> Rswag docs notent que Feature Contract attend UUIDs pour user.id mais DB uses integer bigints.

### Décision

Migrer vers UUID dès le départ pour :
- Conformité avec le Feature Contract
- Identifiants non prévisibles (sécurité)
- Standards modernes pour APIs REST

---

## ✅ Solution Appliquée

### Migrations consolidées et propres

Plutôt que d'avoir des migrations incrémentales et une migration de conversion, nous avons consolidé tout en **2 migrations propres** avec UUID dès le départ.

### Migration 1 : CreateUsers (20250425142809)

```ruby
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :users, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.string :email
      t.string :password_digest
      t.string :provider
      t.string :uid
      t.string :name
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, %i[provider uid], unique: true, where: 'provider IS NOT NULL'
  end
end
```

### Migration 2 : CreateSessions (20250425142901)

```ruby
class CreateSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :sessions, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_activity_at, null: false
      t.string :ip_address
      t.string :user_agent
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :sessions, :token, unique: true
    add_index :sessions, :expires_at
    add_index :sessions, :active
  end
end
```

---

## 📊 Schéma Final

### Table `users`

| Colonne | Type | Contraintes |
|---------|------|-------------|
| id | uuid | PK, gen_random_uuid() |
| email | string | unique index |
| password_digest | string | - |
| provider | string | - |
| uid | string | unique avec provider |
| name | string | - |
| active | boolean | default: true, NOT NULL |
| created_at | datetime | NOT NULL |
| updated_at | datetime | NOT NULL |

### Table `sessions`

| Colonne | Type | Contraintes |
|---------|------|-------------|
| id | uuid | PK, gen_random_uuid() |
| user_id | uuid | FK → users, NOT NULL |
| token | string | unique, NOT NULL |
| expires_at | datetime | NOT NULL |
| last_activity_at | datetime | NOT NULL |
| ip_address | string | - |
| user_agent | string | - |
| active | boolean | default: true, NOT NULL |
| created_at | datetime | NOT NULL |
| updated_at | datetime | NOT NULL |

---

## 🧪 Validation

### Migrations Up/Down

```bash
$ rails db:rollback STEP=2
== 20250425142901 CreateSessions: reverted
== 20250425142809 CreateUsers: reverted

$ rails db:migrate
== 20250425142809 CreateUsers: migrated
== 20250425142901 CreateSessions: migrated
```

### Tests RSpec

```
97 examples, 0 failures
```

### Rubocop

```
70 files inspected, no offenses detected
```

---

## 📋 Bénéfices

1. **Propreté** - 2 migrations simples au lieu de 6 incrémentales
2. **UUID natif** - Pas de conversion, UUID dès le départ
3. **Réversible** - Rollback/migrate fonctionnels
4. **Maintenable** - Code clair et documenté

---

## 🏷️ Tags

- **🔑 SECURITY** : Identifiants non prévisibles
- **📐 ARCHITECTURE** : Schéma consolidé
- **MAJEUR** : Refonte des migrations

---

**Document créé le :** 20 décembre 2025  
**Dernière mise à jour :** 20 décembre 2025  
**Responsable technique :** Équipe Foresy