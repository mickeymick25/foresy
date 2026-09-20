# 🔒 FC-05 — Rate Limiting Implementation (Platinum Level)
Historique / état au 2025-12-28


## 📋 Feature Contract

**Rate Limiting for Authentication Endpoints**

Protège les endpoints critiques d'authentification contre :
- Brute force attacks
- Credential stuffing
- Automated abuse

## ✅ Endpoints Protégés

| Endpoint | Limit | Window | Strategy |
|----------|-------|--------|----------|
| `POST /api/v1/auth/login` | 5 req | 1 minute | Sliding window |
| `POST /api/v1/signup` | 3 req | 1 minute | Sliding window |
| `POST /api/v1/auth/refresh` | 10 req | 1 minute | Sliding window |

## 🏗️ Architecture Decision

### Pourquoi `before_action` (Controller-based) vs Rack Middleware ?

**Choix retenu : Controller-based avec `before_action` filters + RateLimitService**

> ⚠️ **Note importante** : Le gem `rack-attack` est présent dans le Gemfile mais **n'est PAS utilisé**.
> Aucun initializer `config/initializers/rack_attack.rb` n'existe.
> Le rate limiting est entièrement géré par `RateLimitService` + `before_action`.

| Critère | Middleware (rack-attack) | Controller-based (retenu) |
|---------|-------------------------|---------------------------|
| **Granularité** | Path matching complexe | Configuration par action ✅ |
| **Intégration Rails** | Hors contexte Rails | Accès natif request/params ✅ |
| **Testabilité** | Difficile à mocker | RSpec request specs simple ✅ |
| **Maintenabilité** | Configuration séparée | Conventions Rails standard ✅ |
| **Rails 8.1.1** | Problèmes d'intégration ❌ | Compatible ✅ |
| **Sliding Window** | Fixed window par défaut | TRUE sliding window (Redis ZSET) ✅ |

**Trade-off accepté** : Légèrement plus tard dans le cycle de requête, mais négligeable pour des endpoints d'authentification où la logique métier est le coût principal.

### Où le service est-il appelé ?

```ruby
# app/controllers/api/v1/authentication_controller.rb
before_action :check_rate_limit!, only: %i[login refresh]

# app/controllers/api/v1/users_controller.rb  
before_action :check_rate_limit!, only: [:create]
```

Le `before_action` appelle `RateLimitService.check_rate_limit(endpoint, client_ip)` **AVANT** toute logique métier.

### Sliding Window Algorithm (Redis Sorted Sets)

```
Pourquoi Sorted Sets vs simple counter avec TTL ?

❌ Simple counter : Reset complet après TTL → burst possible aux frontières
✅ Sorted Set : Chaque requête a son propre timestamp → vraie fenêtre glissante

Exemple avec limite 5 req/min :
  T=0s:  Request 1 → score=0   → count=1 → ALLOWED
  T=50s: Request 5 → score=50  → count=5 → ALLOWED
  T=55s: Request 6 → count=5   → BLOCKED (retry_after=5s)
  T=61s: Request 7 → count=4   → ALLOWED (request 1 expired)
```

## 🔐 Security Features

- **Fail Closed** : Redis indisponible → HTTP 429 (pas 500)
- **IP Masking** : Logs affichent `192.168.x.x` (pas l'IP complète)
- **Generic Messages** : `"Rate limit exceeded"` sans détails internes
- **No Token Logging** : Aucun token dans les logs

## 📊 Response Format

### Success (under limit)
```
HTTP 200/201/401 (selon logique métier existante)
```

### Rate Limited (429)
```json
HTTP 429 Too Many Requests
Retry-After: 42

{
  "error": "Rate limit exceeded",
  "retry_after": 42
}
```

## 🧪 Tests Coverage

| Category | Tests | Status |
|----------|-------|--------|
| Login under limit | ✅ | Pass |
| Login over limit (6th request) | ✅ | Pass |
| Login exact boundary (5th request) | ✅ | Pass |
| Signup rate limiting | ✅ | Pass |
| Refresh rate limiting | ✅ | Pass |
| Out-of-scope endpoints | ✅ | Pass |
| Redis unavailable → 429 | ✅ | Pass |
| Redis::CannotConnectError → 429 | ✅ | Pass |
| Redis failure HTTP response | ✅ | Pass |
| Retry-After header | ✅ | Pass |
| IP extraction (X-Forwarded-For) | ✅ | Pass |
| Centralized logic verification | ✅ | Pass |
| Sliding window verification | ✅ | Pass |
| Logging with masked IP | ✅ | Pass |

**Total : 34 tests, 0 failures**

## ✅ Quality Gates

- [x] **RSpec** : 32 examples, 0 failures
- [x] **RuboCop** : 0 offenses
- [x] **Brakeman** : 0 vulnerabilities
- [x] **Swagger** : 429 responses documented with examples

## 📚 Files Changed

### New Files
- `app/services/rate_limit_service.rb` - Centralized rate limiting logic
- `spec/requests/api/v1/rate_limiting/rate_limiting_api_integration_spec.rb` - Complete test suite

### Modified Files
- `app/controllers/api/v1/authentication_controller.rb` - Added `before_action :check_rate_limit!`
- `app/controllers/api/v1/users_controller.rb` - Added `before_action :check_rate_limit!`
- `swagger/v1/swagger.yaml` - 429 responses with examples
- `README.md` - Rate Limiting documentation section
- `.github/workflows/ci.yml` - Added Redis service for CI

## 🚀 Breaking Changes

**None** - Les endpoints hors-scope ne sont pas affectés.

## 📖 Documentation

- [Feature Contract 05](../FeatureContract/05_Feature%20Contract%20—%20Rate%20Limiting)
- [Swagger API Docs](../../swagger/v1/swagger.yaml)
- [README Rate Limiting Section](../../README.md#-rate-limiting-feature-contract-05----opérationnel)