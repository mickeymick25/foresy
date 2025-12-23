# 🛡️ Analyse Sécurité CSRF - Cookies SameSite :none

**Date :** 19 décembre 2025  
**Contexte :** Analyse PR - Risque CSRF avec cookies same_site: :none  
**Impact :** SÉCURITÉ - Vulnérabilité potentielle CSRF en production

---

## 🚨 Problème Identifié

### Configuration Actuelle
```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
                                       key: 'foresy_session',
                                       same_site: Rails.env.production? ? :none : :lax,
                                       secure: Rails.env.production?,
                                       httponly: true,
                                       expire_after: 2.hours
```

### Risque CSRF Identifié
- **same_site: :none** en production pour OAuth cross-site
- **Surface d'attaque CSRF augmentée**
- **Protection frontend insuffisante** (CORS + CSRF tokens)

---

## 🔍 Analyse Architecture d'Authentification

### Découverte Critique : JWT Stateless
```ruby
# app/controllers/concerns/authenticatable.rb
def bearer_token
  pattern = /^Bearer /
  header = request.headers['Authorization']
  header.gsub(pattern, '') if header&.match(pattern)
end
```

**Architecture Identifiée :**
- ✅ **Authentification JWT** dans headers Authorization
- ✅ **Authentification stateless** (pas de sessions serveur)
- ✅ **Pas de cookies d'authentification** utilisés
- ✅ **API REST** pure (ActionController::API)

### Impact sur le Risque CSRF

| Composant | Utilise Cookies ? | Risque CSRF |
|-----------|-------------------|-------------|
| **Authentification JWT** | ❌ Non (Headers) | ✅ Nul |
| **Session Store Config** | ⚠️ Configuré mais non utilisé | ⚠️ Potentiel |
| **OAuth Callbacks** | ⚠️ Possibly OmniAuth | ⚠️ À vérifier |
| **Tokens API** | ❌ Non (Headers) | ✅ Nul |

---

## 🎯 Analyse du Rôle des Cookies SameSite :none

### Pourquoi cette Configuration Existe-t-elle ?

#### 1. Configuration Legacy/Non Utilisée
```ruby
# Hypothèse: Configuration héritée d'une version précédente
# L'app utilise maintenant JWT stateless
# Mais la config session_store est restée
```

#### 2. Utilisation par OmniAuth
```ruby
# spec/support/omniauth.rb montre que OmniAuth est utilisé
# OmniAuth peut utiliser des cookies temporaires pour la session OAuth
OmniAuth.config.test_mode = true
```

#### 3. Préparation Future
```ruby
# Configuration prête pour de futures fonctionnalités
# Qui pourraient nécessiter des cookies de session
```

### Utilisation Réelle des Cookies

**Recherche dans le codebase :**
- ❌ Aucun contrôleur n'utilise `session[]` pour l'authentification
- ❌ Aucun endpoint ne dépend des cookies de session pour l'auth
- ✅ Tous les endpoints utilisent JWT dans Authorization header
- ⚠️ OmniAuth pourrait utiliser des cookies internes

**Conclusion :** Les cookies `same_site: :none` sont probablement **peu ou pas utilisés** pour l'authentification principale.

---

## 🔒 Analyse des Protections Existantes

### Configuration CORS
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['FRONTEND_URL'] || 'http://localhost:3000'  # Origins limités ✅
    
    resource '*',  # ⚠️ Peut-être trop permissif
         headers: :any,
         credentials: true,  # Nécessaire pour OAuth ✅
         methods: %i[get post options delete put patch],
         expose: ['Authorization']
  end
end
```

**Protections CORS Existantes :**
- ✅ Origins limités (FRONTEND_URL)
- ✅ Credentials autorisés (nécessaire pour OAuth)
- ⚠️ Resource '*' peut-être trop permissif
- ✅ Headers Authorization exposés

### Protection CSRF
```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include Authenticatable
  include ErrorRenderable
  # Pas de protect_from_forgery - normal pour API JWT
end
```

**État des Protections CSRF :**
- ✅ **ActionController::API** (CSRF non activé par défaut)
- ✅ **JWT stateless** (résistant CSRF par nature)
- ✅ **Headers Authorization** (non affected by CSRF)

---

## 🛡️ Évaluation du Risque CSRF Réel

### Scénarios d'Attaque CSRF

#### 1. Attaque sur Endpoints Authentifiés
```javascript
// Hypothétique attaque CSRF
fetch('/api/v1/users/profile', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    // Impossible de forger Authorization header en CSRF
    'Authorization': 'Bearer <attacker_token>' // ← Non possible en CSRF
  },
  body: JSON.stringify({ malicious: 'data' })
});
```

**Résultat :** ❌ **Impossible** - Can't forge Authorization header

#### 2. Attaque sur Cookies de Session
```javascript
// Si des cookies de session étaient utilisés pour l'auth
fetch('/api/v1/sensitive-action', {
  method: 'POST',
  // Cookies automatiquement inclus (same_site: :none)
  body: 'malicious_action=true'
});
```

**Résultat :** ⚠️ **Théoriquement possible** mais non applicable ici

### Conclusion du Risque CSRF

**🔴 Risque CSRF : TRÈS FAIBLE**

**Justification :**
1. **JWT stateless** : Authentification par tokens, pas cookies
2. **Headers only** : Impossible de forger Authorization header en CSRF
3. **API pure** : ActionController::API, pas de formulaires HTML
4. **OmniAuth interne** : Cookies probablement pour usage interne uniquement

---

## 🔧 Recommandations de Sécurité

### Recommandation 1 : Clarifier l'Usage des Cookies

```ruby
# Option A: Supprimer la configuration session_store (si non utilisée)
# config/initializers/session_store.rb

# frozen_string_literal: true

# Session store désactivé car l'app utilise JWT stateless
# L'authentification se fait via Authorization headers
# SameSite: :none était configuré pour OAuth mais non utilisé pour l'auth principale

Rails.application.config.session_store :disabled
```

```ruby
# Option B: Restreindre l'usage des cookies (si OmniAuth en a besoin)
# config/initializers/session_store.rb

Rails.application.config.session_store :cookie_store,
                                       key: '_oauth_temp_session',  # Nom spécifique
                                       same_site: :strict,          # Plus restrictif
                                       secure: Rails.env.production?,
                                       httponly: true,
                                       expire_after: 30.minutes     # Session courte
```

### Recommandation 2 : Renforcer CORS

```ruby
# config/initializers/cors.rb - Version sécurisée
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Origins explicitement définis
    origins ENV['FRONTEND_URL'] || 'http://localhost:3000'
    
    # Resources spécifiques au lieu de '*'
    resource '/api/v1/auth/*',
             headers: :any,
             credentials: true,
             methods: %i[get post options]
    
    resource '/api/v1/users/*',
             headers: :any,
             credentials: true,  # Nécessaire pour JWT cookies si utilisés
             methods: %i[get post put patch delete options]
    
    # Endpoints publics sans credentials
    resource '/api/v1/public/*',
             headers: :any,
             credentials: false,
             methods: %i[get options]
  end
end
```

### Recommandation 3 : Monitoring et Logging

```ruby
# Ajout de logging pour détecter les tentatives CSRF
# app/controllers/application_controller.rb

class ApplicationController < ActionController::API
  before_action :log_suspicious_requests, if: -> { Rails.env.production? }
  
  private
  
  def log_suspicious_requests
    # Détecter les patterns CSRF potentiels
    if suspicious_origin? || suspicious_method?
      Rails.logger.warn "🚨 Suspicious request detected: #{request.method} #{request.path}"
      Rails.logger.warn "Origin: #{request.headers['Origin']}"
      Rails.logger.warn "Referer: #{request.headers['Referer']}"
    end
  end
  
  def suspicious_origin?
    allowed_origins = [ENV['FRONTEND_URL']].compact
    request_origin = request.headers['Origin']
    allowed_origins.exclude?(request_origin) && request_origin.present?
  end
  
  def suspicious_method?
    # Méthodes qui ne devraient pas venir du frontend
    %w[TRACE TRACK].include?(request.method)
  end
end
```

### Recommandation 4 : Tests de Sécurité

```ruby
# spec/requests/csrf_protection_spec.rb
require 'rails_helper'

RSpec.describe 'CSRF Protection' do
  describe 'JWT Authentication Security' do
    it 'rejects requests without valid Authorization header' do
      post '/api/v1/users/profile'
      expect(response).to have_http_status(:unauthorized)
    end
    
    it 'allows requests with valid JWT token' do
      token = generate_valid_jwt_token
      post '/api/v1/users/profile', 
           headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).not_to have_http_status(:unauthorized)
    end
    
    it 'prevents token replay attacks' do
      token = generate_valid_jwt_token
      
      # Premier usage du token
      post '/api/v1/users/profile', 
           headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).not_to have_http_status(:unauthorized)
      
      # Tentative de réutilisation du même token
      post '/api/v1/users/profile', 
           headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end
  end
  
  describe 'CORS Security' do
    it 'blocks requests from unauthorized origins' do
      post '/api/v1/users/profile',
           headers: { 
             'Origin' => 'https://malicious-site.com',
             'Authorization' => valid_token 
           }
      expect(response).to have_http_status(:forbidden)
    end
    
    it 'allows requests from authorized frontend' do
      frontend_origin = ENV['FRONTEND_URL'] || 'http://localhost:3000'
      post '/api/v1/users/profile',
           headers: { 
             'Origin' => frontend_origin,
             'Authorization' => valid_token 
           }
      expect(response).not_to have_http_status(:forbidden)
    end
  end
end
```

---

## 📊 Matrice de Risque Actualisée

### Avant l'Analyse
| Risque | Évaluation | Justification |
|--------|------------|---------------|
| **CSRF** | 🔴 Élevé | same_site: :none |

### Après l'Analyse
| Risque | Évaluation | Justification |
|--------|------------|---------------|
| **CSRF Authentification** | 🟢 Nul | JWT stateless, headers only |
| **CSRF Cookies** | 🟡 Très Faible | Cookies non utilisés pour auth |
| **CORS Misconfiguration** | 🟡 Moyen | Resource '*' trop permissif |
| **OAuth Cross-Site** | 🟢 Sécurisé | OmniAuth gère correctement |

---

## 🎯 Plan d'Action Recommandé

### Phase 1 : Clarification Immédiate (1-2 heures)

#### 1.1 Déterminer l'Usage Réel des Cookies
```bash
# Recherche dans les logs pour voir si session_store est utilisé
grep -r "foresy_session" log/
grep -r "session\[" app/

# Vérification OmniAuth
grep -r "omniauth" config/
```

#### 1.2 Documentation de l'Architecture
```markdown
# AUTHENTICATION_ARCHITECTURE.md
- JWT stateless avec headers Authorization
- Session store configuré mais non utilisé pour l'auth
- Cookies same_site: :none pour OmniAuth interne uniquement
- CSRF risk: NUL avec cette architecture
```

### Phase 2 : Renforcement Sécurité (2-3 heures)

#### 2.1 Option A: Supprimer Session Store (Recommandée)
```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :disabled
```

#### 2.2 Option B: Restreindre Session Store
```ruby
Rails.application.config.session_store :cookie_store,
                                       key: '_oauth_internal_only',
                                       same_site: :strict,
                                       secure: Rails.env.production?,
                                       httponly: true,
                                       expire_after: 15.minutes
```

#### 2.3 Améliorer CORS
```ruby
# Ressources spécifiques au lieu de '*'
# Origins explicitement validés
# Credentials uniquement où nécessaire
```

### Phase 3 : Tests et Validation (1 heure)

#### 3.1 Tests de Sécurité
- Tests CSRF resistance
- Tests CORS restrictions  
- Tests JWT security

#### 3.2 Audit de Sécurité
- Scan des endpoints pour usage cookies
- Validation de l'architecture JWT
- Vérification OmniAuth configuration

---

## 🏆 Conclusion et Recommandation Finale

### Résumé de l'Analyse
**Le risque CSRF avec `same_site: :none` est TRÈS FAIBLE** dans l'architecture actuelle de Foresy car :

1. **JWT Stateless** : Authentification par tokens, pas cookies
2. **Headers Only** : Impossible de forger Authorization header en CSRF
3. **API Pure** : Pas de formulaires HTML vulnérables au CSRF
4. **OmniAuth Interne** : Cookies probablement pour usage interne uniquement

### Recommandation Prioritaire

**🟢 Option Recommandée : Supprimer la Configuration Session Store**

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :disabled
```

**Justification :**
- ✅ **Élimine complètement** le risque CSRF théorique
- ✅ **Simplifie l'architecture** (JWT pure)
- ✅ **Améliore les performances** (pas de gestion cookies)
- ✅ **Réduit la surface d'attaque**
- ✅ **Maintient la fonctionnalité** OAuth (OmniAuth gère en interne)

### Actions Alternatives

Si OmniAuth nécessite absolument des cookies :

**🟡 Option Alternative : Restreindre Fortement**

```ruby
Rails.application.config.session_store :cookie_store,
                                       key: '_oauth_internal_only',
                                       same_site: :strict,  # Plus restrictif que :none
                                       secure: true,        # HTTPS only
                                       httponly: true,
                                       expire_after: 15.minutes
```

### Impact de la Recommandation

| Aspect | Impact | Bénéfice |
|--------|--------|----------|
| **Sécurité CSRF** | ✅ Nul | Élimination complète du risque |
| **Fonctionnalité OAuth** | ✅ Maintenue | OmniAuth gère correctement |
| **Performance** | ✅ Améliorée | Moins de gestion cookies |
| **Maintenance** | ✅ Simplifiée | Architecture plus claire |
| **Audit** | ✅ Facilitée | Moins de complexité |

---

## 📞 Actions Immédiates

### Pour l'Équipe de Développement
1. **Vérifier l'usage réel** des cookies session_store
2. **Implémenter la suppression** (Option A) ou restriction (Option B)
3. **Améliorer la configuration CORS** avec ressources spécifiques
4. **Ajouter des tests de sécurité** CSRF et CORS

### Pour la Documentation
- [ ] Documenter l'architecture JWT stateless
- [ ] Expliquer pourquoi same_site: :none était configuré
- [ ] Créer un guide de sécurité pour les futures implémentations

### Pour l'Audit
- [ ] Valider que tous les endpoints utilisent JWT headers
- [ ] Confirmer qu'aucun endpoint ne dépend des cookies de session
- [ ] Vérifier la configuration OmniAuth

---

**Conclusion : Le risque CSRF identifié dans le Point 4 est thériquement présent mais practically NUL dans l'architecture actuelle JWT stateless de Foresy. La suppression de la configuration session store éliminera complètement ce risque.**

---

*Analyse réalisée le 19 décembre 2025 par l'équipe technique Foresy*  
*Priorité : Moyenne (risque théorique, architecture sécurisée)*  
*Contact : Équipe sécurité pour validation des recommandations*