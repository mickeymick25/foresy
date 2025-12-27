# 🧪 Guide Tests E2E Staging - Foresy API

**Version :** 1.2  
**Date :** 26 décembre 2025  
**Statut :** Production Ready (Gold Level)

---

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Environnement staging](#environnement-staging)
3. [Tests de smoke](#tests-de-smoke)
4. [Tests E2E complets](#tests-e2e-complets)
5. [Scripts de test](#scripts-de-test)
6. [CI/CD Integration](#cicd-integration)
7. [Troubleshooting](#troubleshooting)

---

## Vue d'ensemble

Les tests E2E (End-to-End) staging vérifient le fonctionnement complet de l'API Foresy dans un environnement proche de la production. Ils complètent les tests unitaires et d'intégration en validant le pipeline complet.

### Objectifs

| Objectif | Description |
|----------|-------------|
| **Smoke tests** | Vérifier que l'API démarre et répond |
| **Sanity checks** | Valider les endpoints critiques |
| **Regression tests** | Détecter les régressions avant production |
| **OAuth flow** | Tester le flux OAuth complet (si possible) |
| **Token revocation** | Valider la révocation des tokens JWT |

### Scripts Disponibles

| Script | Description | Tests | Level |
|--------|-------------|-------|-------|
| `bin/e2e/smoke_test.sh` | Tests de base API | 15 tests | ✅ |
| `bin/e2e/e2e_auth_flow.sh` | Flux authentification complet | 8 tests | ✅ |
| `bin/e2e/e2e_revocation.sh` | Révocation tokens JWT | 4 tests | 🏆 Gold |

---

## Environnement staging

### URLs

| Environnement | URL | Usage |
|---------------|-----|-------|
| Production | https://foresy-api.onrender.com | Live |
| Staging | https://foresy-api-staging.onrender.com | Pré-prod (si configuré) |
| Local | http://localhost:3000 | Développement |

### Variables d'environnement requises

```bash
# Pour les tests E2E
export STAGING_URL="https://foresy-api.onrender.com"
export TEST_USER_EMAIL="e2e-test@example.com"
export TEST_USER_PASSWORD="secure_password_123"
```

---

## Tests de smoke

### Script bash rapide

```bash
#!/bin/bash
# smoke_test.sh - Smoke tests basiques

API_URL="${STAGING_URL:-http://localhost:3000}"
PASS=0
FAIL=0

echo "🔥 Smoke Tests - Foresy API"
echo "=============================="
echo "Target: $API_URL"
echo ""

# Test 1: Health check
echo -n "1. Health check... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/health")
if [ "$RESPONSE" = "200" ]; then
    echo "✅ PASS"
    ((PASS++))
else
    echo "❌ FAIL (HTTP $RESPONSE)"
    ((FAIL++))
fi

# Test 2: Root endpoint
echo -n "2. Root endpoint... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/")
if [ "$RESPONSE" = "200" ]; then
    echo "✅ PASS"
    ((PASS++))
else
    echo "❌ FAIL (HTTP $RESPONSE)"
    ((FAIL++))
fi

# Test 3: API docs (dev/test only)
echo -n "3. API docs... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api-docs")
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "404" ]; then
    echo "✅ PASS (or disabled in prod)"
    ((PASS++))
else
    echo "❌ FAIL (HTTP $RESPONSE)"
    ((FAIL++))
fi

# Test 4: Login endpoint (expects 401 without credentials)
echo -n "4. Login endpoint... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{}')
if [ "$RESPONSE" = "401" ]; then
    echo "✅ PASS (correctly returns 401)"
    ((PASS++))
else
    echo "❌ FAIL (HTTP $RESPONSE, expected 401)"
    ((FAIL++))
fi

# Test 5: Signup endpoint (check it exists)
echo -n "5. Signup endpoint... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/api/v1/signup" \
    -H "Content-Type: application/json" \
    -d '{}')
if [ "$RESPONSE" = "422" ] || [ "$RESPONSE" = "400" ]; then
    echo "✅ PASS (correctly validates input)"
    ((PASS++))
else
    echo "❌ FAIL (HTTP $RESPONSE, expected 422)"
    ((FAIL++))
fi

# Test 6: OAuth callback (invalid provider)
echo -n "6. OAuth invalid provider... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/api/v1/auth/invalid/callback" \
    -H "Content-Type: application/json" \
    -d '{"code": "test", "redirect_uri": "http://test.com"}')
if [ "$RESPONSE" = "400" ]; then
    echo "✅ PASS (correctly returns 400)"
    ((PASS++))
else
    echo "❌ FAIL (HTTP $RESPONSE, expected 400)"
    ((FAIL++))
fi

# Summary
echo ""
echo "=============================="
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -gt 0 ]; then
    exit 1
else
    echo "🎉 All smoke tests passed!"
    exit 0
fi
```

---

## Tests E2E complets

### Scénario 1: Inscription et authentification

```bash
#!/bin/bash
# e2e_auth_flow.sh - Test du flux d'authentification complet

API_URL="${STAGING_URL:-http://localhost:3000}"
TIMESTAMP=$(date +%s)
TEST_EMAIL="e2e-test-${TIMESTAMP}@example.com"
TEST_PASSWORD="SecurePassword123!"

echo "🔐 E2E Auth Flow Tests"
echo "======================"
echo "Target: $API_URL"
echo "Test email: $TEST_EMAIL"
echo ""

# Step 1: Signup
echo "1. Creating new user..."
SIGNUP_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/signup" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"$TEST_PASSWORD\", \"password_confirmation\": \"$TEST_PASSWORD\"}")

TOKEN=$(echo $SIGNUP_RESPONSE | jq -r '.token')
REFRESH_TOKEN=$(echo $SIGNUP_RESPONSE | jq -r '.refresh_token')

if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo "   ✅ Signup successful, token received"
else
    echo "   ❌ Signup failed: $SIGNUP_RESPONSE"
    exit 1
fi

# Step 2: Test authenticated endpoint
echo "2. Testing authenticated request..."
AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/api/v1/auth/revoke" \
    -H "Authorization: Bearer $TOKEN")

if [ "$AUTH_RESPONSE" = "200" ]; then
    echo "   ✅ Authenticated request successful"
else
    echo "   ❌ Auth request failed (HTTP $AUTH_RESPONSE)"
    exit 1
fi

# Step 3: Login with same credentials
echo "3. Testing login..."
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"$TEST_PASSWORD\"}")

NEW_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')
NEW_REFRESH=$(echo $LOGIN_RESPONSE | jq -r '.refresh_token')

if [ "$NEW_TOKEN" != "null" ] && [ -n "$NEW_TOKEN" ]; then
    echo "   ✅ Login successful"
else
    echo "   ❌ Login failed: $LOGIN_RESPONSE"
    exit 1
fi

# Step 4: Test refresh token
echo "4. Testing token refresh..."
REFRESH_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/refresh" \
    -H "Content-Type: application/json" \
    -d "{\"refresh_token\": \"$NEW_REFRESH\"}")

REFRESHED_TOKEN=$(echo $REFRESH_RESPONSE | jq -r '.token')

if [ "$REFRESHED_TOKEN" != "null" ] && [ -n "$REFRESHED_TOKEN" ]; then
    echo "   ✅ Token refresh successful"
else
    echo "   ❌ Refresh failed: $REFRESH_RESPONSE"
    exit 1
fi

# Step 5: Test logout
echo "5. Testing logout..."
LOGOUT_RESPONSE=$(curl -s -X DELETE "$API_URL/api/v1/auth/logout" \
    -H "Authorization: Bearer $REFRESHED_TOKEN")

LOGOUT_MSG=$(echo $LOGOUT_RESPONSE | jq -r '.message')

if [ "$LOGOUT_MSG" = "Logged out successfully" ]; then
    echo "   ✅ Logout successful"
else
    echo "   ❌ Logout failed: $LOGOUT_RESPONSE"
    exit 1
fi

# Step 6: Verify token is invalid after logout
echo "6. Verifying token invalidation..."
INVALID_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/api/v1/auth/revoke" \
    -H "Authorization: Bearer $REFRESHED_TOKEN")

if [ "$INVALID_RESPONSE" = "401" ]; then
    echo "   ✅ Token correctly invalidated"
else
    echo "   ❌ Token still valid (HTTP $INVALID_RESPONSE)"
    exit 1
fi

echo ""
echo "=============================="
echo "🎉 All E2E auth tests passed!"
```

### Scénario 2: Test Token Revocation

```bash
#!/bin/bash
# e2e_revocation.sh - Test de la revocation de tokens

API_URL="${STAGING_URL:-http://localhost:3000}"
TIMESTAMP=$(date +%s)
TEST_EMAIL="e2e-revoke-${TIMESTAMP}@example.com"
TEST_PASSWORD="SecurePassword123!"

echo "🔒 E2E Token Revocation Tests"
echo "=============================="

# Create user and get multiple sessions
echo "1. Creating user and multiple sessions..."

# Signup
SIGNUP=$(curl -s -X POST "$API_URL/api/v1/signup" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"$TEST_PASSWORD\", \"password_confirmation\": \"$TEST_PASSWORD\"}")
TOKEN1=$(echo $SIGNUP | jq -r '.token')

# Login again for second session
LOGIN=$(curl -s -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"$TEST_PASSWORD\"}")
TOKEN2=$(echo $LOGIN | jq -r '.token')

echo "   ✅ Two sessions created"

# Test revoke_all
echo "2. Testing revoke_all..."
REVOKE_ALL=$(curl -s -X DELETE "$API_URL/api/v1/auth/revoke_all" \
    -H "Authorization: Bearer $TOKEN2")

REVOKED_COUNT=$(echo $REVOKE_ALL | jq -r '.revoked_count')

if [ "$REVOKED_COUNT" -ge "2" ]; then
    echo "   ✅ Revoked $REVOKED_COUNT sessions"
else
    echo "   ❌ Expected 2+ sessions, got: $REVOKED_COUNT"
    exit 1
fi

# Verify both tokens are invalid
echo "3. Verifying all tokens invalidated..."
CHECK1=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/api/v1/auth/revoke" \
    -H "Authorization: Bearer $TOKEN1")
CHECK2=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/api/v1/auth/revoke" \
    -H "Authorization: Bearer $TOKEN2")

if [ "$CHECK1" = "401" ] && [ "$CHECK2" = "401" ]; then
    echo "   ✅ All tokens correctly invalidated"
else
    echo "   ❌ Token still valid (T1: $CHECK1, T2: $CHECK2)"
    exit 1
fi

echo ""
echo "=============================="
echo "🎉 All revocation tests passed!"
```

---

## Scripts de test

### Installation

```bash
# Créer le dossier des scripts E2E
mkdir -p bin/e2e

# Copier les scripts
cp smoke_test.sh bin/e2e/
cp e2e_auth_flow.sh bin/e2e/
cp e2e_revocation.sh bin/e2e/

# Rendre exécutables
chmod +x bin/e2e/*.sh
```

### Exécution

```bash
# Smoke tests locaux
./bin/e2e/smoke_test.sh

# Smoke tests staging
STAGING_URL=https://foresy-api.onrender.com ./bin/e2e/smoke_test.sh

# E2E complet
./bin/e2e/e2e_auth_flow.sh
./bin/e2e/e2e_revocation.sh
```

---

## CI/CD Integration

### GitHub Actions workflow

```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on:
  workflow_dispatch:  # Manual trigger
  schedule:
    - cron: '0 6 * * *'  # Daily at 6am UTC

jobs:
  e2e-staging:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Install jq
        run: sudo apt-get install -y jq
      
      - name: Run smoke tests
        env:
          STAGING_URL: https://foresy-api.onrender.com
        run: |
          chmod +x bin/e2e/smoke_test.sh
          ./bin/e2e/smoke_test.sh
      
      - name: Run E2E auth flow
        env:
          STAGING_URL: https://foresy-api.onrender.com
        run: |
          chmod +x bin/e2e/e2e_auth_flow.sh
          ./bin/e2e/e2e_auth_flow.sh
      
      - name: Run E2E revocation tests
        env:
          STAGING_URL: https://foresy-api.onrender.com
        run: |
          chmod +x bin/e2e/e2e_revocation.sh
          ./bin/e2e/e2e_revocation.sh
```

### Post-deploy hook (Render)

```bash
# Dans render.yaml ou comme deploy hook
curl -X POST https://api.github.com/repos/OWNER/foresy/dispatches \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d '{"event_type": "e2e-tests"}'
```

---

## Troubleshooting

### Erreurs communes

| Erreur | Cause probable | Solution |
|--------|----------------|----------|
| `curl: (7) Failed to connect` | API non démarrée | Vérifier le déploiement |
| `401 Unauthorized` sur signup | Email déjà utilisé | Utiliser timestamp dans email |
| `500 Internal Server Error` | Erreur serveur | Vérifier les logs Render |
| `jq: command not found` | jq non installé | `apt-get install jq` |

### Logs de debug

```bash
# Mode verbose pour debug
curl -v -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email": "test@test.com", "password": "password"}'
```

### Cleanup des utilisateurs de test

Les utilisateurs créés par les tests E2E ont un pattern reconnaissable :
- `e2e-test-{timestamp}@example.com`
- `e2e-revoke-{timestamp}@example.com`

Pour nettoyer (si nécessaire) :
```sql
DELETE FROM users WHERE email LIKE 'e2e-%@example.com';
```

---

## Prochaines étapes

- [ ] Ajouter tests E2E OAuth (nécessite credentials de test)
- [ ] Intégrer avec Datadog Synthetics
- [ ] Ajouter alerting sur échec E2E
- [ ] Dashboard de monitoring E2E

---

## Changelog

| Date | Version | Description |
|------|---------|-------------|
| 2025-12-24 | 1.0 | Guide initial avec smoke tests et E2E auth |