# 📊 Analyse : Stratégie de Cache OAuth - Foresy API

**Date :** 24 décembre 2025  
**Type :** Analyse technique  
**Statut :** Évalué - Implémentation différée  
**Priorité :** Basse

---

## 📋 Contexte

L'analyse de la PR a identifié l'absence de cache pour les appels aux providers OAuth (Google, GitHub) comme un point d'amélioration potentiel pour les performances.

> "Pas de cache des informations utilisateur → chaque callback fait une requête HTTP aux providers. Peut être optimisé avec Rack::Cache ou Redis."

---

## 🔍 Analyse du flux OAuth actuel

### Appels HTTP effectués par callback

| Étape | Endpoint | Cacheable ? | Raison |
|-------|----------|-------------|--------|
| 1. Token exchange | `/oauth/token` | ❌ Non | Code à usage unique |
| 2. User info | `/userinfo` | ⚠️ Limité | Données peuvent changer |
| 3. Emails (GitHub) | `/user/emails` | ⚠️ Limité | Données peuvent changer |

### Contraintes OAuth

1. **Codes d'autorisation** : Usage unique, expirent en ~10 minutes
2. **Access tokens** : Temporaires, ne doivent pas être stockés (politique Foresy)
3. **Infos utilisateur** : Peuvent changer (email, nom, photo)

---

## 🎯 Options évaluées

### Option A : Cache Redis des infos utilisateur

```ruby
# Pseudo-code
def fetch_user_info_cached(provider, uid)
  cache_key = "oauth:user:#{provider}:#{uid}"
  
  Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
    fetch_user_info_from_provider(provider, uid)
  end
end
```

**Avantages :**
- Réduit les appels HTTP pour les reconnexions rapides
- Améliore la latence

**Inconvénients :**
- Données potentiellement obsolètes
- Complexité ajoutée
- Redis non configuré actuellement
- Cas d'usage rare (reconnexion < 5 min)

**Verdict : ❌ Non retenu**

---

### Option B : Cache des configurations OAuth

```ruby
# Cache des endpoints et scopes par provider
PROVIDER_CONFIG = {
  google_oauth2: {
    token_url: 'https://oauth2.googleapis.com/token',
    userinfo_url: 'https://www.googleapis.com/oauth2/v2/userinfo',
    scopes: 'email profile'
  },
  github: {
    token_url: 'https://github.com/login/oauth/access_token',
    userinfo_url: 'https://api.github.com/user',
    scopes: 'user:email'
  }
}.freeze
```

**Verdict : ✅ Déjà implémenté** (constantes dans `OAuthCodeExchangeService`)

---

### Option C : Rate limiting avec Redis

```ruby
# Limiter les appels OAuth par IP/user
class OAuthRateLimiter
  def self.allow?(ip_address)
    key = "oauth:rate:#{ip_address}"
    count = Redis.current.incr(key)
    Redis.current.expire(key, 60) if count == 1
    count <= 10 # Max 10 tentatives/minute
  end
end
```

**Avantages :**
- Protection contre les abus
- Réduit la charge sur les providers

**Inconvénients :**
- Nécessite Redis
- Complexité opérationnelle

**Verdict : ⏳ À considérer pour le futur**

---

## 📊 Impact performance actuel

### Mesures typiques (sans cache)

| Opération | Latence moyenne |
|-----------|-----------------|
| Token exchange Google | ~200-400ms |
| User info Google | ~100-200ms |
| Token exchange GitHub | ~300-500ms |
| User info GitHub | ~150-250ms |

### Fréquence des appels

- **Login initial** : 2 appels HTTP (token + userinfo)
- **Reconnexion** : Idem (pas de cache)
- **Refresh JWT** : 0 appels HTTP (interne)

### Conclusion performance

Le temps total d'un callback OAuth (~500-700ms) est acceptable pour une opération d'authentification qui :
- Se produit rarement (1x par session de 7 jours)
- N'est pas sur le chemin critique des requêtes API
- Est perçue comme "normale" par les utilisateurs (redirect OAuth)

---

## ✅ Décision

### Court terme (actuel)
**Pas d'implémentation de cache OAuth**

Raisons :
1. Impact performance négligeable (opération rare)
2. Risque de données obsolètes
3. Complexité d'infrastructure (Redis non configuré)
4. Politique de non-stockage des tokens OAuth respectée

### Moyen terme (si nécessaire)
Si le volume d'authentifications OAuth augmente significativement :

1. **Ajouter Redis** au stack
2. **Implémenter rate limiting** pour protéger les providers
3. **Monitorer** les latences OAuth avec Datadog/APM

### Indicateurs de besoin de cache

- Latence OAuth > 2 secondes (providers saturés)
- Volume > 1000 authentifications OAuth/heure
- Erreurs 429 (rate limit) des providers

---

## 📁 Références

- `app/services/o_auth_code_exchange_service.rb` - Service d'échange OAuth
- `docs/technical/guides/oauth_flow_documentation.md` - Documentation flux OAuth
- [Google OAuth Rate Limits](https://developers.google.com/identity/protocols/oauth2/limits)
- [GitHub API Rate Limits](https://docs.github.com/en/rest/rate-limit)

---

## 📋 Checklist pour implémentation future

Si le cache devient nécessaire :

- [ ] Ajouter `redis` gem au Gemfile
- [ ] Configurer Redis dans `config/environments/`
- [ ] Créer `OAuthCacheService`
- [ ] Implémenter rate limiting par IP
- [ ] Ajouter monitoring des hit/miss
- [ ] Documenter le TTL et la stratégie d'invalidation
- [ ] Tests de performance avant/après