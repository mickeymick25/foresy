# docker-compose.yml (Structure Réelle)
services:
  db:
    image: postgres:15
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: password
      POSTGRES_USER: postgres
      POSTGRES_DB: foresy_development
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      retries: 5
      start_period: 10s
      timeout: 5s

  web:
    image: foresy-web:latest
    command: bash -c "rm -f tmp/pids/server.pid && bundle exec rails s -p 3000 -b '0.0.0.0'"
    volumes:
      - .:/app
    working_dir: /app
    ports:
      - "3000:3000"
    environment:
      RAILS_ENV: development
      DATABASE_URL: postgres://postgres:password@db:5432/foresy_development
      DB_HOST: db
      DB_USERNAME: postgres
      DB_PASSWORD: password
      SECRET_KEY_BASE: development_secret_key_base_for_testing_only_32_characters_minimum
      PORT: 3000
    depends_on:
      db:
        condition: service_healthy

  test:
    image: foresy-web:latest
    command: bash -c "bundle exec rails db:drop db:create db:schema:load && bundle exec rspec"
    volumes:
      - .:/app
    working_dir: /app
    environment:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:password@db:5432/foresy_test
      DB_HOST: db
      DB_USERNAME: postgres
      DB_PASSWORD: password
      SECRET_KEY_BASE: test_secret_key_base_for_rspec_testing_32_characters_minimum
      RAILS_MAX_THREADS: 5
    depends_on:
      db:
        condition: service_healthy

volumes:
  postgres_data:
```

### Health Endpoints Fonctionnels

```
GET /health           # Health check de base
GET /up              # Service up status  
GET /health/detailed # Informations système complètes
```

---

## 🔧 Commandes de Maintenance

### 🚀 Démarrage et Arrêt

```bash
# Démarrer tous les services
docker-compose up -d

# Démarrer un service spécifique
docker-compose up -d web

# Démarrer les tests
docker-compose up -d test

# Arrêter tous les services
docker-compose down

# Arrêter et supprimer les volumes
docker-compose down -v
```

### 🔄 Restart et Reload

```bash
# Restart complet (rebuild des images)
docker-compose restart

# Restart d'un service spécifique (recommandé après modifications)
docker-compose restart web

# Restart du service de tests si nécessaire
docker-compose restart test

# Recharger sans restart (pour les assets)
docker-compose exec web rails assets:precompile

# Note: Pas de rebuild automatique - l'image foresy-web:latest est construite séparément
```

### 📊 Monitoring et Logs

```bash
# Voir le statut des conteneurs
docker-compose ps

# Voir les logs en temps réel
docker-compose logs -f web

# Voir les logs d'un service spécifique
docker-compose logs -f db

# Voir les dernières lignes des logs
docker-compose logs --tail=50 web

# Logs avec timestamp
docker-compose logs -f -t web
```

### 🧹 Nettoyage et Maintenance

```bash
# Nettoyer les conteneurs arrêtés
docker container prune

# Nettoyer les images non utilisées
docker image prune -a

# Nettoyer tous les éléments Docker non utilisés
docker system prune -a

# Recréer les services (utile après modifications de configuration)
docker-compose down
docker-compose up -d --force-recreate

# Recréer les volumes (ATTENTION: perd les données)
docker-compose down -v
docker-compose up -d

# Note: L'image foresy-web:latest doit être reconstruite séparément
```

### 🔍 Inspection et Debug

```bash
# Accéder au shell d'un conteneur
docker-compose exec web bash

# Accéder à la console Rails
docker-compose exec web rails console

# Accéder à la console PostgreSQL
docker-compose exec db psql -U postgres foresy_development

# Inspecter un conteneur
docker inspect foresy-web-1

# Voir les processus dans un conteneur
docker-compose exec web ps aux

# Tester la connectivité réseau vers la base de données
docker-compose exec web nc -zv db 5432

# Tester le service web depuis la base de données
docker-compose exec db nc -zv web 3000
```

---

## 🏥 Health Checks et Monitoring

### Endpoints de Santé

#### 1. Health Check de Base
```bash
curl -f http://localhost:3000/health
```

**Réponse attendue :**
```json
{
  "status": "ok",
  "message": "Health check successful",
  "timestamp": "2025-12-23T16:28:57Z",
  "environment": "development",
  "version": "1.8"
}
```

#### 2. Service Status
```bash
curl http://localhost:3000/up
```

**Réponse attendue :**
```json
{
  "status": "up",
  "message": "Service is up",
  "timestamp": "2025-12-23T16:29:06Z",
  "environment": "development",
  "version": "1.8"
}
```

#### 3. Health Détaillé
```bash
curl http://localhost:3000/health/detailed
```

**Réponse attendue :**
```json
{
  "status": "ok",
  "timestamp": "2025-12-23T16:29:24Z",
  "environment": "development",
  "version": "1.8",
  "database": "connected",
  "uptime": 7816.62,
  "memory": {
    "rss": 110460,
    "units": "KB"
  },
  "ruby": {
    "version": "3.3.0",
    "platform": "x86_64-linux"
  }
}
```

### Monitoring des Conteneurs

```bash
# Vérifier le statut healthy/unhealthy
docker-compose ps

# Monitoring continu des health checks
watch -n 5 'curl -s http://localhost:3000/health | jq .'

# Vérifier les health checks depuis l'intérieur du conteneur
docker exec foresy-web-1 curl -f http://localhost:3000/health

# Voir les métriques système
docker stats foresy-web-1 foresy-db-1 foresy-redis-1
```

---

## 🚨 Troubleshooting

### Problèmes Courants et Solutions

#### 1. Conteneur Unhealthy
**Symptômes :**
- `foresy-web-1` status "Up X minutes (unhealthy)"
- Health check échoue avec erreur 500

**Solutions :**
```bash
# Vérifier les logs pour identifier le problème
docker-compose logs web

# Redémarrer le service web
docker-compose restart web

# Si le problème persiste, rebuild complet
docker-compose down
docker-compose up -d --build
```

#### 2. Erreur OmniAuth Session
**Symptômes :**
- `OmniAuth::NoSessionError: "You must provide a session to use OmniAuth."`
- Problème architectural entre OmniAuth et design stateless

**Solution :**
```bash
# Vérifier que les health endpoints fonctionnent
curl -f http://localhost:3000/health

# Les endpoints OAuth doivent fonctionner via /api/v1/auth/*
curl http://localhost:3000/api/v1/auth/google
```

#### 3. Problème de Base de Données
**Symptômes :**
- `database: "disconnected"` dans /health/detailed
- Erreurs de connexion PostgreSQL

**Solutions :**
```bash
# Vérifier le statut de la DB
docker-compose ps db

# Redémarrer la base de données
docker-compose restart db

# Vérifier les logs de la DB
docker-compose logs db

# Tester la connectivité
docker-compose exec web rails db:version
```

#### 4. Problème de Mémoire
**Symptômes :**
- Memory usage élevé (> 500MB)
- Conteneur killed par OOM

**Solutions :**
```bash
# Analyser l'utilisation mémoire
docker stats --no-stream

# Redémarrer pour nettoyer la mémoire
docker-compose restart web

# Vérifier les fuites mémoire
docker-compose exec web rails runner 'puts GC.stat'
```

---

## 🔧 Problèmes Récents Résolus

### 🐳 Docker Build Health Check - 23/12/2025

**Problème :** Conteneurs Docker unhealthy, health check échouait avec OmniAuth session error

**Solution Implémentée :**
1. **HealthRackEndpoint** : Middleware Rack personnalisé
   - Fichier : `/config/initializers/health_rack_endpoint.rb`
   - Intercepte `/health`, `/up`, `/health/detailed`
   - Contourne OmniAuth pour les health checks

2. **Dockerfile mis à jour** : Ajout de curl
   ```dockerfile
   # Builder stage
   RUN apt-get install -y curl
   
   # Production stage  
   RUN apt-get install -y curl
   ```

3. **Health endpoints fonctionnels** : 3 endpoints opérationnels

**Résultat :**
- ✅ Conteneurs healthy
- ✅ Health checks < 100ms
- ✅ Architecture stateless préservée

### 🔒 Sécurité - 22/12/2025

**Changements :**
- Suppression token logging (risque fuite)
- Suppression middlewares Cookie/Session (risque CSRF)
- Architecture JWT stateless maintenue

### 📊 Standardisation APM - 22/12/2025

**Changements :**
- Standardisation API Datadog multi-versions
- Monitoring unifié production/development

---

## ✅ Bonnes Pratiques

### 🚀 Déploiement

1. **Restart Sélectif**
   ```bash
   # Privilégier le restart d'un service spécifique
   docker-compose restart web  # Après code changes
   
   # Rebuild de l'image foresy-web:latest (fait séparément)
   docker build -t foresy-web:latest .
   docker-compose up -d --force-recreate
   
   # Service test pour validation
   docker-compose up test  # Lance les tests RSpec
   ```

2. **Health Check Validation**
   ```bash
   # Toujours vérifier après un restart
   curl -f http://localhost:3000/health
   
   # Vérifier le health check de la base de données
   docker-compose exec db pg_isready -U postgres
   
   # Test complet des 3 endpoints
   curl -f http://localhost:3000/health && \
   curl http://localhost:3000/up && \
   curl http://localhost:3000/health/detailed
   ```

### 📊 Monitoring

1. **Logs Structurés**
   ```bash
   # Logs avec timestamps pour debugging
   docker-compose logs -f -t web
   
   # Limiter les logs pour éviter la saturation
   docker-compose logs --tail=100 web
   ```

2. **Resource Monitoring**
   ```bash
   # Monitoring mémoire et CPU
   docker stats
   
   # Vérification espace disque
   docker system df
   ```

### 🧹 Maintenance Préventive

1. **Nettoyage Régulier**
   ```bash
   # Nettoyage hebdomadaire recommandé
   docker system prune -a
   
   # Nettoyage des volumes orphelins
   docker volume prune
   ```

2. **Backup avant Opérations Majeures**
   ```bash
   # Backup base de données
   docker-compose exec db pg_dump -U postgres foresy_development > backup.sql
   
   # Backup volumes Redis
   docker-compose exec redis redis-cli BGSAVE
   ```

---

## 🔍 Validation Post-Opération

### Checklist Post-Restart

Après chaque `docker-compose restart web`, vérifier :

```bash
# 1. Statut conteneurs
docker-compose ps
# ✅ foresy-db-1 : Up X seconds (healthy) - pg_isready
# ✅ foresy-web-1 : Up X seconds (healthy) - Rails endpoints

# 2. Health endpoint principal
curl -f http://localhost:3000/health
# ✅ {"status":"ok","message":"Health check successful",...}

# 3. Service up status
curl http://localhost:3000/up
# ✅ {"status":"up","message":"Service is up",...}

# 4. Health détaillé (optionnel mais recommandé)
curl http://localhost:3000/health/detailed
# ✅ {"status":"ok","database":"connected",...}

# 5. Database health check
docker-compose exec db pg_isready -U postgres
# ✅ accepting connections

# 6. Logs sans erreurs
docker-compose logs --tail=50 web
# ✅ Pas d'erreurs critiques

# 7. Tests critiques (optionnel)
docker-compose run --rm web bundle exec rspec spec/acceptance/oauth_feature_contract_spec.rb
# ✅ Tests passent
```

### Métriques de Validation

- **Response Time** : < 100ms pour /health
- **Memory Usage** : < 200MB pour web service
- **Database Status** : "connected" dans /health/detailed
- **Uptime** : Progressive depuis le restart
- **Error Rate** : 0% dans les logs récents

---

## 🎯 Commandes de Référence Rapide

### Opérations Quotidiennes
```bash
# Start/Stop
docker-compose up -d
docker-compose down

# Restart service web (le plus fréquent)
docker-compose restart web

# Lancer les tests
docker-compose up test

# Monitoring
docker-compose ps
docker-compose logs -f web
```

### Debug
```bash
# Shell access
docker-compose exec web bash

# Console Rails
docker-compose exec web rails console

# Database console
docker-compose exec db psql -U postgres foresy_development

# Tester la connectivité DB
docker-compose exec web rails db:version
```

### Health Checks
```bash
# Health check complet
curl -f http://localhost:3000/health && \
curl http://localhost:3000/up && \
curl http://localhost:3000/health/detailed
```

---

## 📞 Support et Contact

### En Cas de Problème

1. **Documentation** : Consulter ce guide d'abord
2. **Logs** : `docker-compose logs -f web`
3. **Health Check** : Tester les 3 endpoints
4. **Recent Changes** : Vérifier `docs/technical/changes/`

### Fichiers de Référence

- **Dockerfile** : `/Dockerfile`
- **Compose Config** : `/docker-compose.yml`
- **Health Middleware** : `/config/initializers/health_rack_endpoint.rb`
- **Health Controller** : `/app/controllers/health_controller.rb`

---

**📅 Dernière mise à jour :** 23 décembre 2025  
**🔄 Prochaine révision :** À la migration Rails 7 → 8  
**✅ Statut :** Document validé et opérationnel  
**👨‍💻 Maintenu par :** CTO Foresy