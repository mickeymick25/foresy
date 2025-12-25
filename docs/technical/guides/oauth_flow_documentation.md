# 🔐 Documentation du Flux OAuth - Foresy API

**Version :** 1.0  
**Date :** 24 décembre 2025  
**Statut :** Production Ready

---

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Providers supportés](#providers-supportés)
3. [Architecture du flux](#architecture-du-flux)
4. [Endpoints API](#endpoints-api)
5. [Paramètre State (CSRF Protection)](#paramètre-state-csrf-protection)
6. [Scopes OAuth](#scopes-oauth)
7. [Format des réponses](#format-des-réponses)
8. [Gestion des erreurs](#gestion-des-erreurs)
9. [JWT Token](#jwt-token)
10. [Refresh Token](#refresh-token)
11. [Exemples d'intégration](#exemples-dintégration)
12. [Sécurité](#sécurité)
13. [Troubleshooting](#troubleshooting)

---

## Vue d'ensemble

Foresy utilise OAuth 2.0 pour permettre aux utilisateurs de s'authentifier via des providers externes (Google, GitHub) sans créer de mot de passe local.

### Principes clés

- **Stateless JWT** : Pas de session serveur, authentification via JWT
- **Code Exchange Flow** : Le frontend gère la redirection OAuth, l'API échange le code
- **Pas de stockage des tokens OAuth** : Seuls les identifiants utilisateur sont persistés
- **Création automatique de compte** : Premier login = création du compte

---

## Providers supportés

| Provider | Identifiant API | Scopes |
|----------|-----------------|--------|
| Google | `google_oauth2` | `email`, `profile` |
| GitHub | `github` | `user:email` |

### Configuration requise

```bash
# Google OAuth2 (Google Cloud Console)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# GitHub OAuth (GitHub Developer Settings)
LOCAL_GITHUB_CLIENT_ID=your_github_client_id
LOCAL_GITHUB_CLIENT_SECRET=your_github_client_secret
```

---

## Architecture du flux

### Diagramme de séquence

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ Frontend │     │ Provider │     │ Foresy   │     │ Database │
│  (SPA)   │     │ (Google/ │     │   API    │     │          │
│          │     │  GitHub) │     │          │     │          │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │
     │ 1. Redirect    │                │                │
     │ ─────────────> │                │                │
     │                │                │                │
     │ 2. User Login  │                │                │
     │ <───────────── │                │                │
     │                │                │                │
     │ 3. Callback    │                │                │
     │    (code +     │                │                │
     │     state)     │                │                │
     │ <───────────── │                │                │
     │                │                │                │
     │ 4. Verify state (local)         │                │
     │ ─────────────────────────────── │                │
     │                │                │                │
     │ 5. POST /auth/:provider/callback│                │
     │    {code, redirect_uri}         │                │
     │ ───────────────────────────────>│                │
     │                │                │                │
     │                │ 6. Exchange    │                │
     │                │    code        │                │
     │                │ <─────────────>│                │
     │                │                │                │
     │                │                │ 7. Find/Create │
     │                │                │    User        │
     │                │                │ ─────────────> │
     │                │                │ <───────────── │
     │                │                │                │
     │ 8. Response {token, user}       │                │
     │ <─────────────────────────────── │                │
     │                │                │                │
```

### Étapes détaillées

1. **Frontend → Provider** : Redirection vers l'URL d'autorisation OAuth
2. **Provider → User** : L'utilisateur se connecte et autorise l'application
3. **Provider → Frontend** : Redirection vers `redirect_uri` avec `code` et `state`
4. **Frontend** : Vérifie que le `state` retourné correspond au `state` envoyé (CSRF)
5. **Frontend → API** : Envoie le `code` à l'API Foresy
6. **API → Provider** : Échange le `code` contre un access token et récupère les infos utilisateur
7. **API → Database** : Trouve ou crée l'utilisateur
8. **API → Frontend** : Retourne un JWT Foresy

---

## Endpoints API

### OAuth Callback

```
POST /api/v1/auth/:provider/callback
```

#### Paramètres URL

| Paramètre | Type | Requis | Description |
|-----------|------|--------|-------------|
| `provider` | string | Oui | `google_oauth2` ou `github` |

#### Body (JSON)

```json
{
  "code": "authorization_code_from_provider",
  "redirect_uri": "https://your-frontend.com/auth/callback",
  "state": "optional_csrf_state_token"
}
```

| Champ | Type | Requis | Description |
|-------|------|--------|-------------|
| `code` | string | Oui | Code d'autorisation OAuth |
| `redirect_uri` | string | Oui | URI de redirection utilisée |
| `state` | string | Non | Token CSRF (recommandé) |

#### Headers

```
Content-Type: application/json
```

### OAuth Failure (optionnel)

```
GET /api/v1/auth/failure
```

Endpoint pour gérer les erreurs OAuth côté provider.

---

## Paramètre State (CSRF Protection)

### Pourquoi le state est important

Le paramètre `state` protège contre les attaques CSRF (Cross-Site Request Forgery) où un attaquant pourrait forcer un utilisateur à s'authentifier avec le compte de l'attaquant.

### Responsabilité du Frontend

Dans le flow **API Code Exchange**, c'est le **frontend** qui doit :

1. **Générer** un `state` aléatoire avant la redirection OAuth
2. **Stocker** le `state` localement (sessionStorage, localStorage)
3. **Vérifier** que le `state` retourné par le provider correspond
4. **Envoyer** le `code` à l'API uniquement si le `state` est valide

### Exemple de génération du state

```javascript
// Générer un state cryptographiquement sécurisé
function generateState() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
}

// Stocker avant la redirection
const state = generateState();
sessionStorage.setItem('oauth_state', state);

// Construire l'URL OAuth
const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
authUrl.searchParams.set('client_id', GOOGLE_CLIENT_ID);
authUrl.searchParams.set('redirect_uri', REDIRECT_URI);
authUrl.searchParams.set('response_type', 'code');
authUrl.searchParams.set('scope', 'email profile');
authUrl.searchParams.set('state', state);

window.location.href = authUrl.toString();
```

### Vérification au retour

```javascript
// Après le callback OAuth
const urlParams = new URLSearchParams(window.location.search);
const returnedState = urlParams.get('state');
const storedState = sessionStorage.getItem('oauth_state');

if (returnedState !== storedState) {
  throw new Error('CSRF validation failed: state mismatch');
}

// State valide, envoyer le code à l'API
const code = urlParams.get('code');
await fetch('/api/v1/auth/google_oauth2/callback', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ code, redirect_uri: REDIRECT_URI, state: returnedState })
});
```

### Audit côté API

L'API Foresy **logge** la présence du paramètre `state` pour audit :

```
[OAuth] State parameter received (CSRF token present)
```

ou

```
[OAuth] No state parameter (frontend should verify CSRF)
```

---

## Scopes OAuth

### Google OAuth2

| Scope | Description | Données récupérées |
|-------|-------------|-------------------|
| `email` | Adresse email | `email`, `verified_email` |
| `profile` | Profil public | `name`, `picture`, `locale` |

### GitHub OAuth

| Scope | Description | Données récupérées |
|-------|-------------|-------------------|
| `user:email` | Emails (y compris privés) | `email` (primary, verified) |

---

## Format des réponses

### Succès (200 OK)

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxMjM0...",
  "user": {
    "id": 1234,
    "email": "user@example.com",
    "provider": "google_oauth2",
    "provider_uid": "123456789012345678901"
  }
}
```

### Structure du user

| Champ | Type | Description |
|-------|------|-------------|
| `id` | integer | ID interne Foresy |
| `email` | string | Email de l'utilisateur |
| `provider` | string | Provider OAuth utilisé |
| `provider_uid` | string | ID unique chez le provider |

---

## Gestion des erreurs

### Codes d'erreur

| HTTP Status | Code | Description |
|-------------|------|-------------|
| 400 | `invalid_provider` | Provider non supporté |
| 401 | `oauth_failed` | Échec OAuth (provider down, code invalide) |
| 422 | `invalid_payload` | Données manquantes (code, redirect_uri, email, uid) |
| 500 | `internal_error` | Erreur interne (JWT encoding, etc.) |

### Exemples de réponses d'erreur

#### Provider non supporté (400)

```json
{
  "error": "invalid_provider"
}
```

#### Échec OAuth (401)

```json
{
  "error": "oauth_failed"
}
```

#### Données manquantes (422)

```json
{
  "error": "invalid_payload"
}
```

#### Erreur interne (500)

```json
{
  "error": "internal_error",
  "message": "JWT encoding failed"
}
```

---

## JWT Token

### Structure du token

Le JWT retourné par OAuth contient les claims suivants :

| Claim | Type | Description |
|-------|------|-------------|
| `user_id` | integer | ID de l'utilisateur |
| `exp` | integer | Timestamp d'expiration |

### Durée de validité

- **Access Token** : 1 heure
- **Refresh Token** : 7 jours (voir section suivante)

### Utilisation du token

```bash
curl -X GET https://api.foresy.com/api/v1/protected-endpoint \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..."
```

---

## Refresh Token

### Comportement

Foresy utilise son propre système de refresh token JWT, **indépendant** des tokens OAuth :

1. À l'authentification OAuth, un `token` (access) et un `refresh_token` sont générés
2. Le `refresh_token` permet d'obtenir un nouveau `token` sans ré-authentification OAuth
3. Si le `refresh_token` expire (7 jours), l'utilisateur doit refaire le flow OAuth

### Endpoint de refresh

```
POST /api/v1/auth/refresh
```

```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

### Réponse

```json
{
  "token": "new_access_token",
  "refresh_token": "new_refresh_token"
}
```

### Note importante

Les tokens OAuth des providers (Google, GitHub) ne sont **jamais stockés**. Ils sont utilisés une seule fois pour récupérer les informations utilisateur, puis jetés.

---

## Exemples d'intégration

### React / Next.js

```javascript
// hooks/useOAuth.js
import { useState } from 'react';

const GOOGLE_CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID;
const REDIRECT_URI = process.env.NEXT_PUBLIC_OAUTH_REDIRECT_URI;

export function useOAuth() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const loginWithGoogle = () => {
    const state = crypto.randomUUID();
    sessionStorage.setItem('oauth_state', state);

    const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
    authUrl.searchParams.set('client_id', GOOGLE_CLIENT_ID);
    authUrl.searchParams.set('redirect_uri', REDIRECT_URI);
    authUrl.searchParams.set('response_type', 'code');
    authUrl.searchParams.set('scope', 'email profile');
    authUrl.searchParams.set('state', state);
    authUrl.searchParams.set('prompt', 'select_account');

    window.location.href = authUrl.toString();
  };

  const handleCallback = async (code, state) => {
    setLoading(true);
    setError(null);

    const storedState = sessionStorage.getItem('oauth_state');
    if (state !== storedState) {
      setError('CSRF validation failed');
      setLoading(false);
      return null;
    }

    try {
      const response = await fetch('/api/v1/auth/google_oauth2/callback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code, redirect_uri: REDIRECT_URI, state })
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'OAuth failed');
      }

      const data = await response.json();
      localStorage.setItem('token', data.token);
      return data;
    } catch (err) {
      setError(err.message);
      return null;
    } finally {
      setLoading(false);
      sessionStorage.removeItem('oauth_state');
    }
  };

  return { loginWithGoogle, handleCallback, loading, error };
}
```

### Vue.js

```javascript
// composables/useOAuth.js
import { ref } from 'vue';

export function useOAuth() {
  const loading = ref(false);
  const error = ref(null);

  const loginWithGitHub = () => {
    const state = crypto.randomUUID();
    sessionStorage.setItem('oauth_state', state);

    const authUrl = new URL('https://github.com/login/oauth/authorize');
    authUrl.searchParams.set('client_id', import.meta.env.VITE_GITHUB_CLIENT_ID);
    authUrl.searchParams.set('redirect_uri', import.meta.env.VITE_OAUTH_REDIRECT_URI);
    authUrl.searchParams.set('scope', 'user:email');
    authUrl.searchParams.set('state', state);

    window.location.href = authUrl.toString();
  };

  const handleCallback = async (provider, code, state) => {
    loading.value = true;
    error.value = null;

    const storedState = sessionStorage.getItem('oauth_state');
    if (state !== storedState) {
      error.value = 'CSRF validation failed';
      loading.value = false;
      return null;
    }

    try {
      const response = await fetch(`/api/v1/auth/${provider}/callback`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code,
          redirect_uri: import.meta.env.VITE_OAUTH_REDIRECT_URI,
          state
        })
      });

      if (!response.ok) throw new Error('OAuth failed');

      const data = await response.json();
      localStorage.setItem('token', data.token);
      return data;
    } catch (err) {
      error.value = err.message;
      return null;
    } finally {
      loading.value = false;
    }
  };

  return { loginWithGitHub, handleCallback, loading, error };
}
```

---

## Sécurité

### Bonnes pratiques implémentées

| Mesure | Description |
|--------|-------------|
| ✅ Stateless JWT | Pas de session serveur |
| ✅ HTTPS only | Cookies secure en production |
| ✅ State CSRF | Protection contre CSRF (frontend) |
| ✅ Pas de stockage tokens OAuth | Tokens provider jetés après usage |
| ✅ Index unique (provider, uid) | Pas de doublons utilisateur |
| ✅ Transaction DB | Protection race condition |
| ✅ Logs sans secrets | Pas de tokens dans les logs |

### Recommandations pour le frontend

1. **Toujours vérifier le `state`** avant d'envoyer le code à l'API
2. **Utiliser HTTPS** en production
3. **Stocker le token** de manière sécurisée (httpOnly cookie ou memory)
4. **Ne pas exposer** les secrets OAuth côté client
5. **Implémenter le refresh** avant expiration du token

### Variables d'environnement

Ne jamais commiter les secrets. Utiliser :
- `.env` local (gitignored)
- GitHub Secrets pour la CI
- Variables d'environnement Render pour la production

---

## Troubleshooting

### Erreur "invalid_provider"

**Cause** : Le provider dans l'URL n'est pas supporté.

**Solution** : Utiliser `google_oauth2` ou `github` uniquement.

### Erreur "oauth_failed"

**Causes possibles** :
- Code expiré (les codes OAuth sont à usage unique et expirent rapidement)
- `redirect_uri` ne correspond pas à celle configurée chez le provider
- Provider temporairement indisponible

**Solution** : 
- Vérifier que le code est utilisé immédiatement
- Vérifier la configuration du `redirect_uri` chez Google/GitHub

### Erreur "invalid_payload"

**Causes possibles** :
- `code` manquant dans la requête
- `redirect_uri` manquant
- Le provider n'a pas retourné d'email (compte sans email vérifié)
- Le provider n'a pas retourné d'UID

**Solution** :
- Vérifier le body de la requête
- S'assurer que l'utilisateur a un email vérifié chez le provider

### Token JWT invalide après OAuth

**Cause** : Le `JWT_SECRET` a changé entre la génération et la vérification.

**Solution** : S'assurer que `JWT_SECRET` est constant en production.

### Race condition "User not found after retry"

**Cause** : Problème de base de données ou contrainte violée.

**Solution** : Vérifier les logs pour plus de détails, vérifier l'intégrité de la DB.

---

## Références

- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [GitHub OAuth Documentation](https://docs.github.com/en/developers/apps/building-oauth-apps)
- [RFC 6749 - OAuth 2.0](https://tools.ietf.org/html/rfc6749)
- [OWASP CSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)

---

## Changelog

| Date | Version | Description |
|------|---------|-------------|
| 2025-12-24 | 1.0 | Documentation initiale |