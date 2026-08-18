# 📖 Contrat d'Erreur API — Foresy

**Date :** 18 août 2026
**Source de vérité :** `app/controllers/concerns/standardized_error.rb`

---

## Format unifié

Toutes les réponses d'erreur de l'API Foresy suivent un format unique :

```json
{
  "code": "ERROR_CODE",
  "message": "Description lisible de l'erreur",
  "details": { }
}
```

| Champ | Type | Description |
|---|---|---|
| `code` | String (UPPERCASE) | Code d'erreur standardisé (voir liste ci-dessous) |
| `message` | String | Message humain lisible |
| `details` | Object (optionnel) | Détails additionnels (champ invalide, retry_after, etc.) |

### ⚠️ Breaking change (vs ancien format)

L'ancien format utilisait des schémas variés selon les endpoints :

```json
// Avant — format 1 (auth, missions)
{ "code": "ERROR_CODE", "message": "...", "details": {} }

// Avant — format 2 (CRA entries, jamais utilisé)
{ "error": { "code": "ERROR_CODE", "message": "..." } }

// Avant — format 3 (CRA entries controller)
{ "error": "invalid_transition", "message": "...", "timestamp": "2026-..." }
```

**Après :** un seul format partout `{ code, message, details }`.

---

## Codes d'erreur standardisés

### 4xx — Erreurs client

| Code | HTTP Status | Helper | Description |
|---|---|---|---|
| `BAD_REQUEST` | 400 | `error_bad_request` | Requête malformée |
| `UNAUTHORIZED` | 401 | `error_unauthorized` | Non authentifié / token invalide |
| `FORBIDDEN` | 403 | `error_forbidden` | Accès refusé (permissions) |
| `NOT_FOUND` | 404 | `error_not_found` | Ressource introuvable |
| `CONFLICT` | 409 | `error_conflict` | Conflit d'état (duplicate, locked) |
| `UNPROCESSABLE_ENTITY` | 422 | `error_unprocessable_entity` | Erreur de validation métier |
| `TOO_MANY_REQUESTS` | 429 | `error_too_many_requests` | Rate limit dépassé |
| `INVALID_PAYLOAD` | 422 | `error_invalid_payload` | Payload invalide (paramètres) |
| `INVALID_PARAMETER` | 400 | `error_invalid_parameter` | Paramètre invalide |
| `MISSING_PARAMETER` | 400 | `error_missing_parameter` | Paramètre requis manquant |
| `INVALID_ENUM` | 400 | `error_invalid_enum` | Valeur d'enum invalide |
| `MALFORMED_JSON` | 400 | `error_malformed_json` | JSON malformé |
| `RATE_LIMIT_EXCEEDED` | 429 | `error_too_many_requests` | Alias pour rate limit |

### 5xx — Erreurs serveur

| Code | HTTP Status | Helper | Description |
|---|---|---|---|
| `INTERNAL_SERVER_ERROR` | 500 | `error_internal` | Erreur interne (masquée en prod) |
| `SERVICE_UNAVAILABLE` | 503 | — | Service indisponible |

---

## Comportement par environnement

| Environnement | `error_internal` | `handle_standard_error` |
|---|---|---|
| **Production** | Renvoie `"An unexpected error occurred"` (masqué) | Masque `e.message` et backtrace |
| **Development/Test** | Renvoie le message passé en argument | Inclut `exception_class`, `exception_message`, `backtrace` dans `details` |

### Exemple — réponse en production

```json
{
  "code": "INTERNAL_SERVER_ERROR",
  "message": "An unexpected error occurred"
}
```

### Exemple — réponse en développement

```json
{
  "code": "INTERNAL_SERVER_ERROR",
  "message": "OAuth callback error",
  "details": {
    "exception_class": "NoMethodError",
    "exception_message": "undefined method `foo' for nil",
    "backtrace": ["app/controllers/...", "..."]
  }
}
```

---

## Rescue_from automatiques

Le concern `StandardizedError` installe automatiquement les handlers suivants :

| Exception | Handler | HTTP Status |
|---|---|---|
| `ActiveRecord::RecordNotFound` | `handle_record_not_found` | 404 |
| `ActiveRecord::RecordInvalid` | `handle_record_invalid` | 422 |
| `ActionController::ParameterMissing` | `handle_parameter_missing` | 400 |
| `ActionController::UnpermittedParameters` | `handle_unpermitted_parameters` | 400 |
| `StandardError` | `handle_standard_error` | 500 |

---

## Migration clients

### Pour un client qui consommait l'ancien format

```ruby
# Avant — parser l'erreur
error = response['error']           # String ou Hash selon l'endpoint
message = response['message']

# Après — parser l'erreur
code = response['code']             # String UPPERCASE
message = response['message']       # String
details = response['details']       # Hash (optionnel)
```

### Exemples de codes par endpoint

| Endpoint | Scenario | Code | Status |
|---|---|---|---|
| `POST /api/v1/auth/login` | Email manquant | `UNAUTHORIZED` | 401 |
| `POST /api/v1/auth/login` | Credentials invalides | `UNAUTHORIZED` | 401 |
| `POST /api/v1/signup` | Rate limit | `RATE_LIMIT_EXCEEDED` | 429 |
| `POST /api/v1/missions` | Payload invalide | `INVALID_PAYLOAD` | 422 |
| `POST /api/v1/cras/:id/submit` | CRA already submitted | `CONFLICT` | 409 |
| `POST /api/v1/cras/:id/lock` | CRA already locked | `CONFLICT` | 409 |
| `DELETE /api/v1/cras/:id` | CRA locked | `CONFLICT` | 409 |
| `GET /api/v1/cras/:id` | Not found | `NOT_FOUND` | 404 |
| `POST /api/v1/cras/:id/submit` | No entries | `UNPROCESSABLE_ENTITY` | 422 |

---

**Document créé le :** 18 août 2026
**Auteur :** Zed Agent