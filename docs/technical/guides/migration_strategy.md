# 🗄️ Stratégie de Migration Database — Foresy

**Date :** 18 août 2026
**Contexte :** Projet pré-launch (aucune donnée de production à préserver)

---

## Décision : Squash complet

Les 16 migrations accumulées (décembre 2025 → août 2026) ont été squashées en **une seule migration** `20260101000000_initial_schema.rb` qui crée tout le schéma dans son état final.

### Pourquoi un squash ?

| Raison | Détail |
|---|---|
| Pré-launch | Aucune DB de production, aucun utilisateur, aucune donnée à préserver |
| Migrations contradictoires | Plusieurs migrations se contredisaient (create column then drop column, add constraints then remove) |
| Simplicité | 1 migration propre au lieu de 16 (dont 3 ajoutées par la remédiation) |
| Performance | `db:schema:load` en un seul passage au lieu de 16 migrations séquentielles |

### Migration unique

```
db/migrate/
└── 20260101000000_initial_schema.rb  # Schéma complet (13 tables, 6 enums, 14 FK)
```

Cette migration crée :
- 6 enums PostgreSQL (`cra_status`, `mission_status_enum`, etc.)
- 13 tables avec PK UUID (sauf `users` en bigint)
- 14 foreign keys avec cascading
- Check constraints (pays, devise, dates, type financier)
- Index partiels (soft delete, uniqueness)

---

## Commandes de déploiement

### Nouvelle installation (staging/production vierge)

```bash
# Créer la DB et appliquer le schéma en une seule commande
bundle exec rails db:setup

# Ou étape par étape
bundle exec rails db:create
bundle exec rails db:migrate
```

### Reset complet (en cas de problème)

```bash
# ATTENTION : supprime toutes les données
bundle exec rails db:drop db:create db:migrate
```

### En Docker

```bash
docker compose exec web bundle exec rails db:setup
```

---

## Ce qui n'existe PAS dans le schéma final

| Élément supprimé | Raison |
|---|---|
| `created_by_user_id` (cras, missions) | Remplacé par tables pivot `user_cras`/`user_missions` (DDD) |
| Triggers DB de protection creator | Gérés au niveau application |
| Check constraints sur `role` (string) | Remplacé par enum PostgreSQL `user_relation_role` |
| `users.uuid` VARCHAR(36) | Remplacé par type UUID natif PostgreSQL |
| `sessions.uuid` VARCHAR(36) | Remplacé par type UUID natif PostgreSQL |

---

## Réversibilité

La migration `InitialSchema` contient un `def down` complet qui supprime toutes les tables et enums. Cependant, **les données seront perdues** lors d'un `db:rollback`.

**Recommandation :** Toujours faire un backup avant toute opération DB en production.

---

**Document créé le :** 18 août 2026
**Auteur :** Zed Agent