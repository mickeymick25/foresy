# E2E Token Revocation Script - Gold Level

**Date**: 26 décembre 2025  
**Type**: Feature  
**Statut**: ✅ Terminé (Gold Level)  
**Feature Contract**: `docs/FeatureContract/04_Feature Contract  — E2E Revocation`

---

## 📋 Résumé

Implémentation du script de test E2E pour la validation de la révocation des tokens JWT, conformément au Feature Contract 04. Script certifié **Gold Level** après review CTO.

---

## 🎯 Objectif

Garantir qu'un token JWT révoqué ne peut plus être utilisé pour accéder aux endpoints protégés de l'API.

**Assertion de sécurité** : Un token qui ÉTAIT valide devient INVALIDE après révocation.

---

## 📁 Fichiers

| Fichier | Description |
|---------|-------------|
| `bin/e2e/e2e_revocation.sh` | Script E2E Gold Level |
| `docs/FeatureContract/04_Feature Contract  — E2E Revocation` | Feature Contract source |

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

  When the user accesses the protected endpoint again with the SAME token
  Then the response status should be 401
```

---

## 🏆 Gold Level Compliance

| Critère | Status |
|---------|--------|
| `set -euo pipefail` | ✅ |
| Variables d'environnement (`BASE_URL`, `TEST_USER_EMAIL`, `TEST_USER_PASSWORD`) | ✅ |
| Outils: bash, curl, jq | ✅ |
| Fail fast on error | ✅ |
| Log each step | ✅ |
| Idempotent (timestamp email) | ✅ |
| No mocks, real HTTP only | ✅ |
| **MÊME token** avant/après révocation | ✅ |
| `readonly` pour constantes | ✅ |
| Helper `fail_and_exit()` | ✅ |
| Gherkin mapping dans summary | ✅ |

---

## 🔄 User Journey (Contract Flow)

```
1. User authenticates → receives TOKEN
2. User accesses protected endpoint with TOKEN → HTTP 200
3. User revokes TOKEN via logout → HTTP 200/204
4. User accesses SAME endpoint with SAME TOKEN → HTTP 401
```

**Preuve** : Le même token (`LOGOUT_TOKEN`) est utilisé pour les étapes 3 et 4.

---

## 🧪 Tests Effectués

| Test | Résultat |
|------|----------|
| RSpec | ✅ 221 examples, 0 failures |
| Rswag | ✅ 27 examples, 0 failures |
| Rubocop | ✅ 81 files, 0 offenses |
| Brakeman | ✅ 0 security warnings |
| E2E Revocation | ✅ 4/4 steps passed |

---

## 🔧 Spécifications Techniques

### Variables d'Environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `BASE_URL` | `http://localhost:3000` | URL de l'API |
| `TEST_USER_EMAIL` | `e2e-revocation-{timestamp}@example.com` | Email utilisateur test |
| `TEST_USER_PASSWORD` | `SecurePassword123!` | Mot de passe utilisateur test |

### Exécution

```bash
# Local
./bin/e2e/e2e_revocation.sh

# Production/Staging
BASE_URL=https://foresy-api.onrender.com ./bin/e2e/e2e_revocation.sh
```

---

## 📊 Résultat de Validation

```
==============================================
🔒 E2E Token Revocation Test (Gold Level)
==============================================

[✅ PASS] JWT token obtained
[✅ PASS] Protected endpoint returned HTTP 200
[✅ PASS] Token revoked via logout (HTTP 200)
[✅ PASS] Protected endpoint returned HTTP 401 (access denied)

==============================================
🎉 E2E Token Revocation Test PASSED
==============================================

Feature Contract Verified (Gherkin):
  ✅ Given: User authenticated with valid JWT token
  ✅ When: User accessed protected endpoint → HTTP 200
  ✅ When: User revoked token via logout → HTTP 200/204
  ✅ Then: User accessed with SAME token → HTTP 401

Security Assertion:
  ✅ Revoked tokens are immediately invalidated
  ✅ No unauthorized access after revocation
```

---

## 📝 Review CTO

### Points Corrigés

1. **Single Token Flow** : Le même token est utilisé pour steps 3-4 (pas de confusion entre tokens)
2. **Simplicité** : Flow minimal, pas de complexité inutile
3. **Validation JSON** : Body responses validées
4. **Contract Strict** : Alignement exact avec le Feature Contract Gherkin

---

## 📚 Documentation Associée

- Feature Contract: `docs/FeatureContract/04_Feature Contract  — E2E Revocation`
- Guide E2E: `docs/technical/testing/e2e_staging_tests_guide.md`
- Backlog: `docs/BACKLOG.md`
- BRIEFING: `docs/BRIEFING.md`

---

## 🔗 Références

- PR: #9
- Commit: Gold Level implementation
- Tests: 221 RSpec + 27 Rswag + 4 E2E steps