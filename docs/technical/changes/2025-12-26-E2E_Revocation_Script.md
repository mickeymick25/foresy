# E2E Token Revocation Script

**Date**: 26 décembre 2025  
**Type**: Feature  
**Statut**: ✅ Terminé  
**Feature Contract**: `docs/FeatureContract/04_Feature Contract  — E2E Revocation`

---

## 📋 Résumé

Implémentation du script de test E2E pour la validation de la révocation des tokens JWT, conformément au Feature Contract 04.

---

## 🎯 Objectif

Garantir qu'un token JWT révoqué ne peut plus être utilisé pour accéder aux endpoints protégés de l'API.

---

## 📁 Fichiers Créés

| Fichier | Description |
|---------|-------------|
| `bin/e2e/e2e_revocation.sh` | Script de test E2E pour la révocation de tokens |

---

## ✅ Critères d'Acceptation (Gherkin)

```gherkin
Feature: Token revocation E2E

Scenario: Access is denied after token revocation
  Given a user is authenticated and has a valid JWT token
  When the user accesses a protected endpoint
  Then the response status should be 200

  When the user revokes the token via logout endpoint
  Then the response status should be 200 or 204

  When the user accesses the protected endpoint again with the same token
  Then the response status should be 401
```

---

## 🧪 Tests Effectués

| Test | Résultat |
|------|----------|
| Authentification utilisateur | ✅ Token JWT obtenu |
| Accès endpoint protégé (token valide) | ✅ HTTP 200 |
| Révocation token (logout) | ✅ HTTP 200 |
| Accès endpoint protégé (token révoqué) | ✅ HTTP 401 |

---

## 🔧 Spécifications Techniques

### Variables d'Environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `BASE_URL` | `http://localhost:3000` | URL de l'API |
| `TEST_USER_EMAIL` | `e2e-revocation-{timestamp}@example.com` | Email utilisateur test |
| `TEST_USER_PASSWORD` | `SecurePassword123!` | Mot de passe utilisateur test |

### Dépendances

- `bash`
- `curl`
- `jq`

### Exécution

```bash
# Local
./bin/e2e/e2e_revocation.sh

# Production/Staging
BASE_URL=https://foresy-api.onrender.com ./bin/e2e/e2e_revocation.sh
```

---

## 📊 Résultats de Validation

```
==============================================
🔒 E2E Token Revocation Validation
==============================================

[✅ PASS] JWT token obtained successfully
[✅ PASS] Protected endpoint returned HTTP 200 with valid token
[✅ PASS] New JWT token obtained
[✅ PASS] Token revoked successfully (HTTP 200)
[✅ PASS] Protected endpoint correctly returned HTTP 401 with revoked token

==============================================
🎉 E2E Token Revocation Test PASSED
==============================================
```

---

## 📚 Documentation Associée

- Feature Contract: `docs/FeatureContract/04_Feature Contract  — E2E Revocation`
- Guide E2E: `docs/technical/testing/e2e_staging_tests_guide.md`
- Backlog: `docs/BACKLOG.md`

---

## 🔗 Références

- PR associée: À créer
- Tests RSpec: 221 tests, 0 failures
- Tests E2E: 5/5 passed