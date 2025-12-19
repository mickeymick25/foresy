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
> Rswag docs notent que Feature Contract attend UUIDs pour user.id mais DB uses integer bigints. C'est documenté dans PR. Si le contract exige UUID, prévoir migration et attention à compatibilité.

### État Avant

- **Type d'ID** : `bigint` (integer auto-incrémenté)
- **Problème** : IDs prévisibles, non conformes au Feature Contract
- **Swagger** : Documentait `type: integer` au lieu de `type: string, format: uuid`

---

## ✅ Solution Appliquée

### 1. Extension PostgreSQL

Activation de `pgcrypto` pour la fonction `gen_random_uuid()`.

### 2. Migration des tables

Création de la migration `20251219160648_enable_pgcrypto_and_migrate_to_uuid.rb` :

- Suppression des tables existantes (sessions puis users)
- Recréation avec `id: :uuid, default: -> { 'gen_random_uuid()' }`
- Mise à jour des foreign keys pour utiliser UUID

### 3. Mise à jour des specs Swagger

Modification de `spec/requests/api/v1/oauth_spec.rb` :

```ruby
# Avant
id: { type: :integer, description: 'User unique identifier' }

# Après
id: { type: :string, format: :uuid, description: 'User unique identifier' }
```

### 4. Régénération du Swagger

```bash
bundle exec rails rswag:specs:swaggerize
```

---

## 📊 Schéma Après Migration

### Table `users`

```ruby
create_table :users, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
  t.string :email
  t.string :password_digest
  t.string :provider
  t.string :uid
  t.string :name
  t.boolean :active, default: true, null: false
  t.timestamps
end
```

### Table `sessions`

```ruby
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
```

---

## 📋 Swagger Généré

```yaml
id:
  type: string
  format: uuid
  description: User unique identifier
```

---

## 🧪 Validation

### Tests RSpec

```
97 examples, 0 failures
```

### Rubocop

```
70 files inspected, no offenses detected
```

### Swagger

```
48 examples, 0 failures
Swagger doc generated at /app/swagger/v1/swagger.yaml
```

---

## 📋 Bénéfices

1. **Sécurité** - IDs non prévisibles, impossible d'énumérer les ressources
2. **Conformité** - Alignement avec le Feature Contract
3. **Standards** - Format UUID standard pour les APIs REST modernes
4. **Décentralisation** - Possibilité de générer des IDs côté client si nécessaire

---

## ⚠️ Notes Importantes

### Perte de données

Cette migration **supprime et recrée** les tables. Elle ne doit être exécutée que sur :
- Environnements de développement
- Environnements de staging
- Production **avec backup préalable**

### Compatibilité

- Les modèles Rails n'ont pas besoin de modification
- Les foreign keys sont automatiquement gérées avec `type: :uuid`
- Les factories et specs fonctionnent sans changement

---

## 🏷️ Tags

- **🔑 SECURITY** : Identifiants non prévisibles
- **📐 ARCHITECTURE** : Changement de schéma
- **MAJEUR** : Modification structurelle de la base de données

---

**Document créé le :** 20 décembre 2025  
**Responsable technique :** Équipe Foresy