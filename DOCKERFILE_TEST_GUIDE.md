# Guide de Test - Nouveau Dockerfile Foresy

## 🎯 Objectif

Ce guide permet de valider les corrections apportées au Dockerfile de Foresy suite aux retours de l'analyse de la Pull Request.

## 🔧 Problèmes Corrigés

### 1. Bundle Paths Incohérents
**Problème initial :**
- Builder installait les gems dans `/usr/local/bundle` (défaut)
- COPY copiait `/usr/local/bundle` mais path potentiellement inutile

**Solution appliquée :**
```dockerfile
# Builder stage
RUN bundle config set --local path 'vendor/bundle'
RUN bundle install --jobs 4 --retry 3 --path vendor/bundle

# Production stage  
COPY --from=builder /app/vendor/bundle /app/vendor/bundle
```

### 2. Format CMD Non-Standard
**Problème initial :**
```dockerfile
CMD bundle exec rails server -b 0.0.0.0 -p ${PORT:-3000}
```

**Solution appliquée :**
```dockerfile
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "${PORT:-3000}"]
```

### 3. Permissions Bundle
**Ajouté :**
```dockerfile
RUN chown -R rails:rails /app/vendor/bundle
RUN su - rails -c "bundle check" || true
```

## 🧪 Tests de Validation

### Test 1 : Construction de l'Image

```bash
# Nettoyer les images existantes
docker rmi foresy-api:v2 2>/dev/null || true

# Construire la nouvelle image
docker build -t foresy-api:v2 .

# Vérifier qu'il n'y a pas de warnings JSON
# Résultat attendu : Build successful, 0 warning
```

**Critères de succès :**
- ✅ Image construite sans erreur
- ✅ Pas de warning "JSON arguments recommended"
- ✅ Taille d'image raisonnable (optimisée multi-stage)

### Test 2 : Fonctionnement de l'Application

```bash
# Arrêter les conteneurs existants
docker-compose down

# Démarrer la nouvelle image
docker run --rm -d \
  -p 3000:3000 \
  -e PORT=3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=test_secret_key_base_32_characters_long \
  -e DATABASE_URL="postgresql://postgres:password@localhost:5432/foresy_test" \
  foresy-api:v2

# Attendre le démarrage
sleep 10
```

**Critères de succès :**
- ✅ Conteneur démarre sans erreur
- ✅ Pas de "bundler: command not found"
- ✅ Process Rails visible dans les logs

### Test 3 : Endpoint Health

```bash
# Tester l'endpoint health
curl -s http://localhost:3000/health

# Résultat attendu :
# {"status":"ok","timestamp":"2025-12-22T..."}
```

**Critères de succès :**
- ✅ Endpoint répond rapidement
- ✅ Retour JSON valide
- ✅ Pas d'erreur 500

### Test 4 : Bundle Integrity

```bash
# Vérifier les logs du conteneur
docker logs <container_id>

# Chercher ces lignes :
# "=== Foresy API Entrypoint ==="
# "Running database migrations..."
# "✅ Migrations completed" 
# "=== Starting Rails server ==="
```

**Critères de succès :**
- ✅ Entrypoint s'exécute correctement
- ✅ Migrations en production (si DB disponible)
- ✅ Server démarre sans erreur bundle

### Test 5 : Permissions et Utilisateur

```bash
# Vérifier que l'application tourne sous l'utilisateur rails
docker exec <container_id> whoami

# Résultat attendu : rails

# Vérifier l'accès aux gems
docker exec <container_id> bundle --version

# Résultat attendu : Bundler version 2.x.x
```

**Critères de succès :**
- ✅ Application tourne sous utilisateur non-root
- ✅ Bundle accessible et fonctionnel
- ✅ Pas d'erreur de permissions

## 🔍 Validation des Corrections

### Test Bundle Paths

```bash
# Vérifier que les gems sont dans vendor/bundle
docker exec <container_id> ls -la /app/vendor/bundle

# Résultat attendu : Répertoire bundle avec gems installées

# Vérifier BUNDLE_PATH
docker exec <container_id> env | grep BUNDLE_PATH

# Résultat attendu : BUNDLE_PATH=/app/vendor/bundle
```

### Test JSON CMD Format

```bash
# Vérifier que le CMD est en format JSON
docker inspect <container_id> | grep -A 10 "Cmd"

# Résultat attendu : 
# "Cmd": [
#     "bundle",
#     "exec", 
#     "rails",
#     "server",
#     "-b",
#     "0.0.0.0",
#     "-p",
#     "${PORT:-3000}"
# ]
```

## 📊 Métriques de Performance

### Taille d'Image
```bash
docker images foresy-api:v2

# Tailles attendues :
# builder : ~500-600MB (avec build tools)
# production : ~200-300MB (runtime only)
```

### Temps de Build
```bash
time docker build -t foresy-api:v2 .

# Temps attendu : < 2 minutes (avec cache)
```

### Temps de Démarrage
```bash
time docker run --rm -e SECRET_KEY_BASE=test foresy-api:v2

# Temps attendu : < 30 secondes jusqu'au premier log
```

## 🚨 Dépannage

### Problème : "bundler: command not found"
**Cause :** Bundle path incorrect ou permissions
**Solution :**
```bash
# Vérifier BUNDLE_PATH
docker exec <container_id> env | grep BUNDLE

# Vérifier l'ownership
docker exec <container_id> ls -la /app/vendor/bundle
```

### Problème : "Permission denied" 
**Cause :** Utilisateur rails n'a pas accès aux gems
**Solution :**
```bash
# Corriger les permissions
docker exec <container_id> chown -R rails:rails /app/vendor/bundle
```

### Problème : Container exit avec code 1
**Cause :** Migration DB échouée ou config manquante
**Solution :**
```bash
# Vérifier les logs
docker logs <container_id>

# Tester sans migrations
RAILS_SKIP_DB_MIGRATION=true docker run ...
```

### Problème : Port déjà utilisé
**Cause :** Another container sur le port 3000
**Solution :**
```bash
# Arrêter les conteneurs existants
docker stop $(docker ps -q --filter ancestor=foresy-api)

# Ou utiliser un port différent
docker run -p 3001:3000 ...
```

## ✅ Checklist de Validation

- [ ] Image construite sans warning JSON
- [ ] Conteneur démarre sans erreur "command not found"
- [ ] Endpoint `/health` répond correctement
- [ ] Logs montrent entrypoint → migrations → server start
- [ ] Application tourne sous utilisateur `rails`
- [ ] Gems accessibles dans `/app/vendor/bundle`
- [ ] BUNDLE_PATH configuré correctement
- [ ] CMD en format JSON array
- [ ] Taille d'image optimisée (< 300MB)
- [ ] Temps de build < 2 minutes

## 📋 Comparaison Avant/Après

| Aspect | Avant | Après |
|--------|-------|-------|
| Bundle path | `/usr/local/bundle` (défaut) | `/app/vendor/bundle` (explicite) |
| CMD format | Shell string | JSON array |
| Permissions | Basique | Vérifiées + intégrité bundle |
| Warnings Docker | 1 warning JSON | 0 warning |
| API-only optimisé | Partiellement | Complètement |
| Health check | Non | Oui |
| Labels metadata | Non | Oui |

## 🎯 Résultat Attendu

Après validation, le nouveau Dockerfile doit :
1. ✅ Résoudre tous les problèmes identifiés dans la PR
2. ✅ Maintenir la fonctionnalité existante
3. ✅ Améliorer la sécurité (permissions, non-root)
4. ✅ Optimiser les performances (caching, layers)
5. ✅ Être production-ready pour Render

## 📞 Support

En cas de problème lors des tests :
1. Vérifier les logs avec `docker logs <container_id>`
2. Comparer avec les critères de succès ci-dessus
3. Consulter la section dépannage
4. Documenter tout problème non résolu

---

*Guide créé le 22 décembre 2025*  
*Objectif : Validation complète du nouveau Dockerfile Foresy*