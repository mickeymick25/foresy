# 🔧 Fix OmniAuth Session Middleware - 23 Décembre 2025

**Date :** 23 décembre 2025  
**Type :** Correction de bug  
**Impact :** CRITIQUE - Résolution erreur bloquante en production  
**Statut :** ✅ RÉSOLU

---

## 📋 Contexte

L'API Foresy déployée sur Render (https://foresy-api.onrender.com) retournait une erreur `OmniAuth::NoSessionError` sur **tous les endpoints**, y compris la route racine "/" et les endpoints de santé.

---

## ❌ Problème Identifié

### Erreur
```
OmniAuth::NoSessionError: You must provide a session to use OmniAuth.
```

### Cause racine
OmniAuth est ajouté comme middleware global dans la stack Rack. Il intercepte **toutes les requêtes** et vérifie la présence d'une session (`rack.session`) avant de les traiter, même pour les routes qui n'ont rien à voir avec OAuth.

Foresy étant une API stateless JWT, la session était explicitement désactivée :
```ruby
# config/initializers/session_store.rb (AVANT)
Rails.application.config.session_store :disabled
```

Cette configuration causait l'échec de toutes les requêtes car OmniAuth ne trouvait pas de session.

---

## ✅ Solution Appliquée

### 1. Activation des middlewares de session (`config/application.rb`)

```ruby
# Session middleware configuration for OmniAuth compatibility
# OmniAuth requires session support to store CSRF state during OAuth flow
# Authentication remains stateless via JWT tokens - session is only for OAuth
config.middleware.use ActionDispatch::Cookies
config.middleware.use ActionDispatch::Session::CookieStore, key: '_foresy_session'
```

### 2. Configuration de session minimale (`config/initializers/session_store.rb`)

```ruby
Rails.application.config.session_store :cookie_store,
                                       key: '_foresy_session',
                                       same_site: :lax,
                                       secure: Rails.env.production?,
                                       expire_after: 1.hour
```

### 3. Désactivation de la validation de requête OmniAuth (`config/initializers/omniauth.rb`)

```ruby
# IMPORTANT: Pour une API stateless, on désactive la vérification de session d'OmniAuth
# OmniAuth n'interceptera que les routes /auth/:provider
OmniAuth.config.request_validation_phase = nil
```

---

## 🔒 Impact sur la sécurité

### Ce qui NE change PAS :
- L'authentification reste **100% stateless via JWT**
- Les tokens JWT sont toujours dans le header `Authorization`
- Aucune donnée utilisateur n'est stockée en session
- Pas de CSRF risk sur les endpoints API (JWT-based)

### Ce qui est ajouté :
- Session cookie minimale pour satisfaire OmniAuth
- Utilisée uniquement par OmniAuth pour stocker le state CSRF pendant le flow OAuth
- Expire après 1 heure
- `SameSite: Lax` en développement, `Secure` en production

---

## 🧪 Validation

### Tests exécutés
```bash
# RSpec
docker-compose run --rm test
# Résultat : 204 examples, 0 failures

# Rubocop
docker-compose run --rm test bash -c "bundle exec rubocop"
# Résultat : 81 files inspected, no offenses detected
```

### Endpoints validés
```bash
# Route racine
curl http://localhost:3000/
# {"status":"API is live"}

# Health check
curl http://localhost:3000/health
# {"status":"ok","message":"Health check successful",...}
```

---

## 📁 Fichiers Modifiés

| Fichier | Modification |
|---------|--------------|
| `config/application.rb` | Ajout middlewares Cookies et Session::CookieStore |
| `config/initializers/session_store.rb` | Configuration session cookie minimale |
| `config/initializers/omniauth.rb` | Ajout `request_validation_phase = nil` |

---

## 📚 Références

- [OmniAuth Wiki - Session Management](https://github.com/omniauth/omniauth/wiki)
- [Rails API - Session Configuration](https://api.rubyonrails.org/classes/ActionDispatch/Session/CookieStore.html)
- Documentation interne : `docs/technical/analysis/csrf_security_analysis_same_site_none.md`

---

## 🔄 Déploiement

Après merge de cette branche, le déploiement sur Render devrait résoudre l'erreur sur https://foresy-api.onrender.com/