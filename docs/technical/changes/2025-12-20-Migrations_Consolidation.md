# 🔧 Consolidation des migrations Active - 20 Décembre 2025

**Date :** 20 décembre 2025  
**Projet :** Foresy API  
**Type :** Consolidation - Migrations  
**Status :** ✅ **COMPLÉTÉ**

---

## 🎯 Problème Identifié

### Analyse CI - Point 6

> Migration AddActiveToUsers n'ajoute pas de default / NOT NULL
>
> AddActiveToUsers ajoute : `add_column :users, :active, :boolean` (sans default/null). Vous avez ensuite une migration FixUsersActiveColumn qui backfill et met default+not null — OK si l'ordre est correct, mais attention à l'ordre d'exécution et à la compatibilité inter-branches.

### État Avant

Deux migrations séparées :

1. **`20250514101621_add_active_to_users.rb`** - Ajout colonne sans contraintes
2. **`20251216144630_fix_users_active_column.rb`** - Backfill + contraintes

Risques :
- Complexité inutile pour nouveaux environnements
- Dépendance à l'ordre d'exécution
- Backfill inutile sur base vide

---

## ✅ Solution Appliquée

### 1. Mise à jour de la migration originale

**`20250514101621_add_active_to_users.rb`** :

```ruby
class AddActiveToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :active, :boolean, default: true, null: false
  end
end
```

### 2. Suppression de la migration de fix

Suppression de `20251216144630_fix_users_active_column.rb` devenue redondante.

### 3. Mise à jour du schema.rb

Version mise à jour : `20_250_515_120_000` (dernière migration valide)

---

## 📊 Résultat

### Avant

| Fichier | Lignes | Fonction |
|---------|--------|----------|
| `add_active_to_users.rb` | 11 | Ajout colonne sans contraintes |
| `fix_users_active_column.rb` | 55 | Backfill + contraintes |
| **Total** | **66** | 2 migrations |

### Après

| Fichier | Lignes | Fonction |
|---------|--------|----------|
| `add_active_to_users.rb` | 12 | Ajout colonne avec contraintes |
| **Total** | **12** | 1 migration |

---

## 🧪 Validation

### Migration sur base neuve

```
== 20250514101621 AddActiveToUsers: migrating =================================
-- add_column(:users, :active, :boolean, {:default=>true, :null=>false})
   -> 0.0069s
== 20250514101621 AddActiveToUsers: migrated (0.0070s) ========================
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

1. **Simplicité** - Une seule migration au lieu de deux
2. **Robustesse** - Pas de dépendance à l'ordre
3. **Performance** - Pas de backfill inutile sur nouvelles bases
4. **Maintenabilité** - Moins de code à maintenir

---

## ⚠️ Note Importante

Cette consolidation est possible car :
- Le projet n'est pas encore en production avec des données réelles
- Les migrations n'ont pas été exécutées sur des environnements externes

Pour un projet en production, il faudrait conserver les deux migrations pour la compatibilité ascendante.

---

## 🏷️ Tags

- **🔧 REFACTORING** : Consolidation migrations
- **📐 ARCHITECTURE** : Simplification schéma
- **MINEUR** : Pas de changement fonctionnel

---

**Document créé le :** 20 décembre 2025  
**Responsable technique :** Équipe Foresy