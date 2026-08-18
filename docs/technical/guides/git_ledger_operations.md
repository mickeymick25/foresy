# 🔒 Git Ledger — Opérations et Permissions

**Date :** 18 août 2026
**Source :** `app/services/git_ledger_repository.rb`

---

## Vue d'Ensemble

Le Git Ledger assure l'immutabilité légale des CRA verrouillés (locked). Chaque CRA verrouillé génère un commit Git dans un dépôt dédié, fournissant un audit trail immuable.

## Architecture

```
GitLedgerService (orchestration)
  ├── GitLedgerRepository (opérations Git low-level)
  └── GitLedgerPayload (sérialisation JSON)
```

## Chemin du dépôt Git

```ruby
LEDGER_PATH = '/app/cra-ledger'
LEDGER_BRANCH = 'main'
```

### Permissions

Le chemin `/app/cra-ledger` est créé automatiquement par `GitLedgerRepository.ensure_initialized!` :

```ruby
def initialize_repository
  FileUtils.mkdir_p(LEDGER_PATH)
  # git init, configure identity, create .gitignore
end
```

### Docker

Dans le conteneur Docker (`docker-compose.yml`), le chemin `/app` est le répertoire de l'application. Le ledger est créé à la volée au premier `lock` d'un CRA.

**Attention :** Sans volume persistant, le ledger est perdu au redémarrage du conteneur. Pour la production :

```yaml
# Ajouter dans docker-compose.yml (service web) :
volumes:
  - cra_ledger:/app/cra-ledger

volumes:
  cra_ledger:
    driver: local
```

Sur Render, le filesystem est éphémère. Le ledger est recréé à chaque déploiement. Pour la persistance en production, envisager un stockage externe (S3, volume persistant).

## Sécurité

### Shell injection — mitigé (P6.1)

Toutes les opérations Git utilisent `Open3.capture3` au lieu de backticks ou `system()` :

```ruby
# Avant (vulnérable)
result = `git log --grep="CRA locked.*#{sanitized_id}" --oneline 2>/dev/null`

# Après (sécurisé)
stdout, _stderr, status = Open3.capture3('git', 'log', '--grep', "CRA locked.*#{sanitized_id}", '--oneline', chdir: LEDGER_PATH)
```

Avantages :
- Pas de shell intermédiaire (pas d'injection)
- Exit status géré explicitement
- stderr logué au lieu d'être supprimé (`2>/dev/null`)

### Protection contre la réécriture d'historique

```ruby
def history_rewritten?
  stdout, _stderr, status = Open3.capture3('git', 'config', 'receive.denyNonFastForwards', chdir: LEDGER_PATH)
  stdout.strip == 'true'
rescue StandardError
  true  # Fail-safe : si erreur, considère que l'historique est réécrit
end
```

## Opérations disponibles

| Méthode | Description | Retour |
|---|---|---|
| `exists?` | Le dépôt existe-t-il ? | Boolean |
| `initialized?` | Git initialisé ? | Boolean |
| `valid?` | Dépôt valide ? | Boolean |
| `ensure_initialized!` | Crée le dépôt si nécessaire | void |
| `commit_exists_for_cra?(cra_id)` | Un commit existe pour ce CRA ? | Boolean |
| `find_commit_info(cra_id)` | Infos du commit (hash, message, date) | Hash ou nil |
| `create_commit(cra, payload)` | Crée un commit pour un CRA locked | Hash (commit_info) |
| `info` | Infos générales du dépôt | Hash |
| `cleanup!` | Supprime le dépôt (non-prod) | void |

## Format du payload Git

Chaque commit contient un fichier JSON `cra_{id}_{month}_{year}.json` :

```json
{
  "cra_id": "uuid",
  "month": 1,
  "year": 2026,
  "status": "locked",
  "total_days": 20.0,
  "total_amount": 1200000,
  "currency": "EUR",
  "created_by_user_id": 123,
  "entries": [ ... ],
  "locked_at": "2026-01-15T10:00:00Z"
}
```

Le fichier est supprimé après le commit (le contenu vit dans l'historique Git).

---

**Document créé le :** 18 août 2026
**Auteur :** Zed Agent