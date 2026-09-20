# 🔒 Stratégie de Token Revocation - Foresy API

**Version :** 1.0  
**Date :** 24 décembre 2025  
**Statut :** Production Ready

---

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Endpoints de revocation](#endpoints-de-revocation)
3. [Cas d'utilisation](#cas-dutilisation)
4. [Architecture](#architecture)
5. [Exemples d'intégration](#exemples-dintégration)
6. [Sécurité](#sécurité)
7. [FAQ](#faq)

---

## Vue d'ensemble

Foresy implémente une stratégie de **token revocation** permettant aux utilisateurs d'invalider leurs tokens JWT de manière proactive. Cette fonctionnalité est essentielle pour :

- **Déconnexion sécurisée** : Invalider immédiatement un token après logout
- **Compromission de token** : Révoquer un token potentiellement volé
- **Changement de mot de passe** : Invalider toutes les sessions existantes
- **Déconnexion de tous les appareils** : Sécuriser le compte sur tous les devices

### Principes clés

| Principe | Description |
|----------|-------------|
| **Session-based** | La revocation s'appuie sur le modèle Session en base de données |
| **Immédiate** | L'invalidation prend effet instantanément |
| **Granulaire** | Possibilité de révoquer une session ou toutes les sessions |
| **Auditée** | Toutes les revocations sont loggées |

---

## Endpoints de revocation

### 1. Révoquer le token actuel

```
DELETE /api/v1/auth/revoke
```

Révoque uniquement la session associée au token utilisé pour la requête.

#### Headers requis

```
Authorization: Bearer <access_token>
Content-Type: application/json
```

#### Réponse succès (200 OK)

```json
{
  "message": "Token revoked successfully",
  "revoked_at": "2025-12-24T10:30:00Z"
}
```

#### Réponses d'erreur

| Status | Description |
|--------|-------------|
| 401 | Token invalide, expiré, ou absent |

---

### 2. Révoquer toutes les sessions

```
DELETE /api/v1/auth/revoke_all
```

Révoque **toutes** les sessions actives de l'utilisateur, sur tous les appareils.

#### Headers requis

```
Authorization: Bearer <access_token>
Content-Type: application/json
```

#### Réponse succès (200 OK)

```json
{
  "message": "All tokens revoked successfully",
  "revoked_count": 5,
  "revoked_at": "2025-12-24T10:30:00Z"
}
```

| Champ | Type | Description |
|-------|------|-------------|
| `message` | string | Message de confirmation |
| `revoked_count` | integer | Nombre de sessions révoquées |
| `revoked_at` | string (ISO8601) | Timestamp de la revocation |

#### Réponses d'erreur

| Status | Description |
|--------|-------------|
| 401 | Token invalide, expiré, ou absent |

---

## Cas d'utilisation

### 1. Déconnexion standard

L'utilisateur se déconnecte d'un appareil spécifique.

```bash
# Utiliser logout (équivalent à revoke pour la session courante)
curl -X DELETE https://api.foresy.com/api/v1/auth/logout \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..."
```

### 2. Token potentiellement compromis

L'utilisateur suspecte que son token a été volé.

```bash
# Révoquer toutes les sessions immédiatement
curl -X DELETE https://api.foresy.com/api/v1/auth/revoke_all \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..."
```

### 3. Changement de mot de passe

Après un changement de mot de passe, invalider toutes les sessions existantes.

```javascript
// Après le changement de mot de passe réussi
async function changePasswordAndLogoutAll(newPassword, currentToken) {
  // 1. Changer le mot de passe
  await fetch('/api/v1/users/password', {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${currentToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ password: newPassword })
  });

  // 2. Révoquer toutes les sessions
  await fetch('/api/v1/auth/revoke_all', {
    method: 'DELETE',
    headers: { 'Authorization': `Bearer ${currentToken}` }
  });

  // 3. Rediriger vers login
  window.location.href = '/login';
}
```

### 4. Déconnexion de tous les appareils (UI)

Bouton "Déconnecter tous les appareils" dans les paramètres utilisateur.

```javascript
async function logoutAllDevices() {
  const token = localStorage.getItem('token');
  
  const response = await fetch('/api/v1/auth/revoke_all', {
    method: 'DELETE',
    headers: { 'Authorization': `Bearer ${token}` }
  });

  if (response.ok) {
    const data = await response.json();
    alert(`${data.revoked_count} session(s) déconnectée(s)`);
    
    // Se déconnecter localement aussi
    localStorage.removeItem('token');
    window.location.href = '/login';
  }
}
```

---

## Architecture

### Modèle de données

```
┌─────────────────────────────────────────────────────────────┐
│                         sessions                            │
├─────────────────────────────────────────────────────────────┤
│ id            │ bigint       │ PK                           │
│ user_id       │ bigint       │ FK → users                   │
│ token         │ string       │ UNIQUE, session identifier   │
│ expires_at    │ datetime     │ Expiration timestamp         │
│ last_activity │ datetime     │ Dernière activité            │
│ ip_address    │ string       │ IP de création               │
│ user_agent    │ string       │ Browser/device info          │
└─────────────────────────────────────────────────────────────┘
```

### Flux de revocation

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Client  │     │   API    │     │ Session  │     │   User   │
│          │     │          │     │  Model   │     │  Model   │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │
     │ DELETE /revoke │                │                │
     │ ─────────────> │                │                │
     │                │                │                │
     │                │ Validate JWT   │                │
     │                │ ─────────────> │                │
     │                │                │                │
     │                │ Find session   │                │
     │                │ ─────────────> │                │
     │                │                │                │
     │                │ Update         │                │
     │                │ expires_at     │                │
     │                │ = now          │                │
     │                │ ─────────────> │                │
     │                │                │                │
     │ 200 OK         │                │                │
     │ <───────────── │                │                │
     │                │                │                │
```

### Flux de revoke_all

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  Client  │     │   API    │     │   User   │     │ Sessions │
│          │     │          │     │  Model   │     │          │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │
     │ DELETE         │                │                │
     │ /revoke_all    │                │                │
     │ ─────────────> │                │                │
     │                │                │                │
     │                │ Get user       │                │
     │                │ ─────────────> │                │
     │                │                │                │
     │                │ invalidate_    │                │
     │                │ all_sessions!  │                │
     │                │ ─────────────> │                │
     │                │                │                │
     │                │                │ UPDATE all     │
     │                │                │ active sessions│
     │                │                │ ─────────────> │
     │                │                │                │
     │ 200 OK         │                │                │
     │ {count: N}     │                │                │
     │ <───────────── │                │                │
     │                │                │                │
```

---

## Exemples d'intégration

### React Hook

```javascript
// hooks/useTokenRevocation.js
import { useState } from 'react';

export function useTokenRevocation() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const revokeCurrentToken = async () => {
    setLoading(true);
    setError(null);

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/v1/auth/revoke', {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (!response.ok) throw new Error('Revocation failed');

      localStorage.removeItem('token');
      localStorage.removeItem('refresh_token');
      return true;
    } catch (err) {
      setError(err.message);
      return false;
    } finally {
      setLoading(false);
    }
  };

  const revokeAllTokens = async () => {
    setLoading(true);
    setError(null);

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/v1/auth/revoke_all', {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (!response.ok) throw new Error('Revocation failed');

      const data = await response.json();
      localStorage.removeItem('token');
      localStorage.removeItem('refresh_token');
      return data;
    } catch (err) {
      setError(err.message);
      return null;
    } finally {
      setLoading(false);
    }
  };

  return { revokeCurrentToken, revokeAllTokens, loading, error };
}
```

### Vue.js Composable

```javascript
// composables/useTokenRevocation.js
import { ref } from 'vue';

export function useTokenRevocation() {
  const loading = ref(false);
  const error = ref(null);

  const revokeAll = async () => {
    loading.value = true;
    error.value = null;

    try {
      const token = localStorage.getItem('token');
      const response = await fetch('/api/v1/auth/revoke_all', {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (!response.ok) throw new Error('Revocation failed');

      const data = await response.json();
      localStorage.clear();
      return data;
    } catch (err) {
      error.value = err.message;
      return null;
    } finally {
      loading.value = false;
    }
  };

  return { revokeAll, loading, error };
}
```

---

## Sécurité

### Bonnes pratiques implémentées

| Mesure | Description |
|--------|-------------|
| ✅ Authentification requise | Seul le propriétaire peut révoquer ses tokens |
| ✅ Invalidation immédiate | `expires_at` mis à `Time.current` |
| ✅ Logging sécurisé | User ID loggé, jamais le token |
| ✅ Isolation utilisateur | Un user ne peut pas révoquer les tokens d'un autre |

### Logs générés

```
[Auth] Token revoked for user 123
[Auth] All tokens revoked for user 123 (5 sessions)
```

### Recommandations

1. **Après compromission** : Toujours utiliser `revoke_all`
2. **Changement de mot de passe** : Appeler `revoke_all` systématiquement
3. **Activité suspecte** : Implémenter une UI pour voir les sessions actives
4. **Tokens côté client** : Toujours supprimer les tokens locaux après revocation

---

## FAQ

### Quelle est la différence entre `logout` et `revoke` ?

Techniquement identiques pour la session courante. `revoke` est plus explicite sémantiquement pour les cas de sécurité.

### Le token peut-il être réutilisé après revocation ?

Non. La session est immédiatement marquée comme expirée. Toute requête avec ce token retournera 401.

### Que se passe-t-il si j'appelle `revoke_all` ?

Toutes vos sessions sur tous les appareils sont invalidées. Vous devrez vous reconnecter partout.

### Les refresh tokens sont-ils aussi révoqués ?

Oui. Le refresh token est lié à la session. Une session expirée empêche le refresh.

### Comment voir mes sessions actives ?

Cette fonctionnalité est prévue pour une future version (endpoint `GET /api/v1/auth/sessions`).

---

## Changelog

| Date | Version | Description |
|------|---------|-------------|
| 2025-12-24 | 1.0 | Implémentation initiale avec `revoke` et `revoke_all` |