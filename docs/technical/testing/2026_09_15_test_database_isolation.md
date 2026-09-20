# Guide — Isolement des bases test/dev (D-10)

**Date :** 15 septembre 2026
**Contexte :** dette D-10 du registre `docs/technical/2026_09_14_fc08_debt_register.md`
**Environnement :** conteneur Docker `foresy-web-1` (compose : Postgres sur le service `db`)

---

## 1. Le piège (constaté le 15/09/2026)

Le conteneur web exporte `DATABASE_URL=postgres://postgres:password@db:5432/foresy_development`.
Cette variable **écrase** la configuration `database.yml` pour tous les environnements, y compris
`RAILS_ENV=test` : les runs RSpec dans le conteneur exécutent donc la suite contre la base
**de développement**.

Conséquence observée : les runs E2E (`bin/e2e/e2e_companies.sh`, HTTP réel) persistent leurs
données dans la base dev — puis la suite RSpec échoue sur les contraintes FC-08
(UNIQUE SIREN/SIRET) et les effectifs de scopes. 28 échecs = fausse alerte de régression.

**Règle d'or :** les données E2E vivent dans la base dev ; les tests doivent toujours s'exécuter
contre `foresy_test`.

## 2. Ne pas faire

```bash
# ❌ Retire DATABASE_URL → database.yml vise localhost:5432 → Postgres
#    n'est PAS joignable depuis le conteneur (il est sur le service db)
env -u DATABASE_URL RAILS_ENV=test bin/rails db:prepare
```

## 3. Procédure correcte (conteneur)

```bash
# 1. Créer / mettre à jour la base de test (même hôte db, nom foresy_test)
docker compose exec -T web sh -c \
  "DATABASE_URL=postgres://postgres:password@db:5432/foresy_test RAILS_ENV=test bin/rails db:prepare"

# 2. Lancer la suite contre la base de test
docker compose exec -T web sh -c \
  "DATABASE_URL=postgres://postgres:password@db:5432/foresy_test RAILS_ENV=test bundle exec rspec"

# 3. Vider la base dev si elle a été polluée par des runs E2E (données 100% jetables)
docker compose exec -T web bin/rails runner 'ActiveRecord::Base.connection.execute(
  "TRUNCATE users, companies, missions, cras, cra_entries RESTART IDENTITY CASCADE")'
```

## 4. Validation (15/09/2026)

| Étape | Résultat |
|---|---|
| `db:prepare` sur `foresy_test` | Base créée, schéma FC-08 chargé |
| Suite sur `foresy_test` | **956 exemples, 0 échec** |
| Rejeu E2E ×2 (dev DB re-polluée : 6 companies, 4 users) | 19/19 ×2 |
| Suite sur `foresy_test` après pollution dev | **956 exemples, 0 échec** — isolement prouvé |

## 5. Références

- Registre de dette : `docs/technical/2026_09_14_fc08_debt_register.md` (D-10)
- Guide E2E staging : `docs/technical/testing/[DONE]_2025_12_24_e2e_staging_tests_guide.md`
- CI : le job « Tests & Coverage » utilise sa propre base (`foresy_test`) — comportement de référence