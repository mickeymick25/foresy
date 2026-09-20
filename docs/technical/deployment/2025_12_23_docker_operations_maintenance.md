# 🐳 Docker Operations & Maintenance Guide

**Version:** 2.0 - Gold Level  
**Dernière mise à jour:** 26 décembre 2025  
**Stack:** Ruby 3.4.8 + Rails 8.1.1

---

## 📋 Architecture Docker

### Multi-stage Dockerfile (5 stages)

| Stage | Description | Usage |
|-------|-------------|-------|
| `base` | Dépendances runtime communes | Base pour tous les stages |
| `builder` | Compilation gems (dev+test+prod) | Build intermédiaire |
| `development` | Environnement complet dev/test | docker-compose local |
| `production-builder` | Compilation gems prod only | Build production |
| `production` | Image finale optimisée | Déploiement Render |

### Services docker-compose

```yaml
services:
  db:        # PostgreSQL 16-alpine
  redis:     # Redis 7-alpine  
  web:       # Rails app (development)
  test:      # Test runner (profile: test)
  console:   # Rails console (profile: tools)
```

---

## 🚀 Commandes Essentielles

### Démarrage

```bash
# Démarrer tous les services
docker-compose up -d

# Voir les logs
docker-compose logs -f web

# Vérifier le statut
docker-compose ps
```

### Tests

```bash
# Lancer les tests RSpec
docker-compose --profile test run --rm test

# Tests Rswag/Swagger
docker-compose exec web bundle exec rake rswag:specs:swaggerize

# Rubocop
docker-compose exec web bundle exec rubocop

# Brakeman
docker-compose exec web bundle exec brakeman -q
```

### Console & Debug

```bash
# Rails console
docker-compose --profile tools run --rm console

# Bash dans le container
docker-compose exec web bash

# Logs temps réel
docker-compose logs -f web
```

### Base de données

```bash
# Migrations
docker-compose exec web bundle exec rails db:migrate

# Reset complet
docker-compose exec web bundle exec rails db:drop db:create db:migrate

# Console PostgreSQL
docker-compose exec db psql -U postgres -d foresy_development
```

---

## 🔧 Maintenance

### Rebuild complet

```bash
# Arrêter et supprimer tout
docker-compose down -v --rmi all

# Nettoyer le système Docker
docker system prune -af --volumes
docker builder prune -af

# Rebuild from scratch
docker-compose build --no-cache

# Redémarrer
docker-compose up -d
```

### Mise à jour des gems

```bash
# Mettre à jour Gemfile.lock
docker-compose exec web bundle update

# Rebuild l'image
docker-compose build web
```

### Nettoyage régulier

```bash
# Supprimer les images non utilisées
docker image prune -f

# Supprimer les volumes orphelins
docker volume prune -f

# Nettoyage complet (attention!)
docker system prune -af --volumes
```

---

## 📊 Health Checks

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check principal |
| `GET /` | Root endpoint |

### Exemple de réponse health

```json
{
  "status": "ok",
  "message": "Health check successful",
  "timestamp": "2025-12-26T08:23:07Z",
  "environment": "development",
  "version": "1.8"
}
```

### Vérification manuelle

```bash
# Health check
curl -s http://localhost:3000/health | jq .

# Vérifier Redis
docker-compose exec redis redis-cli ping

# Vérifier PostgreSQL
docker-compose exec db pg_isready -U postgres
```

---

## ⚡ Optimisations Gold Level

### Ruby YJIT

YJIT est activé automatiquement via :
```yaml
environment:
  RUBY_YJIT_ENABLE: 1
```

Vérification dans les logs :
```
Ruby version: ruby 3.4.8 (...) +YJIT +PRISM [x86_64-linux]
```

### Puma Cluster Mode

Configuration dans `config/puma.rb` :
- **Workers:** 2 (WEB_CONCURRENCY)
- **Threads:** 5 min, 5 max
- **Preload:** Activé

### Memory Optimization

```yaml
environment:
  MALLOC_ARENA_MAX: 2  # Limite arenas glibc
```

---

## 🔒 Sécurité

### Bonnes pratiques appliquées

- ✅ User non-root (`rails`)
- ✅ Image slim (taille réduite)
- ✅ Secrets via variables d'environnement
- ✅ Pas de secrets dans l'image
- ✅ .dockerignore complet

### Variables sensibles

Ne jamais commiter :
- `SECRET_KEY_BASE`
- `DATABASE_URL` (production)
- Clés OAuth

---

## 🐛 Troubleshooting

### Container qui ne démarre pas

```bash
# Voir les logs d'erreur
docker-compose logs web

# Vérifier les dépendances
docker-compose ps
```

### Erreur de connexion DB

```bash
# Vérifier que PostgreSQL est healthy
docker-compose ps db

# Tester la connexion
docker-compose exec db pg_isready -U postgres
```

### Gems manquantes

```bash
# Rebuild le container
docker-compose build web

# Ou forcer bundle install
docker-compose exec web bundle install
```

### Port déjà utilisé

```bash
# Trouver le process
lsof -i :3000

# Ou changer le port
PORT=3001 docker-compose up
```

---

## 📁 Structure des volumes

| Volume | Contenu | Persistance |
|--------|---------|-------------|
| `postgres_data` | Données PostgreSQL | ✅ Persistant |
| `redis_data` | Données Redis | ✅ Persistant |
| `bundle_cache` | Gems Ruby | ✅ Persistant |
| `node_modules` | Dépendances Node | ✅ Persistant |

---

## 📞 Support

En cas de problème :
1. Vérifier les logs : `docker-compose logs`
2. Consulter ce guide
3. Rebuild si nécessaire
4. Contacter l'équipe technique

---

*Documentation maintenue par l'équipe CTO Foresy*