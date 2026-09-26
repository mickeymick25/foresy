# 📜 Contrat FC-05 — Rate Limiting (cible v1)

**Date :** 25 septembre 2026
**Statut :** ✅ **GREEN atteint (25/09)** — arbitrages A1-A9 actés · RED 1-4 mesurés (10 échecs documentés) → implémentation minimale → GREEN (12/12) · R-4 cleanup · régression **1166/0**
**Chantier :** BACKLOG **#23** (Remediation contractuelle FC-05 — Investigation CLOSED, cf. `[DONE]_2026_09_25_fc05_rate_limiting_audit.md`)
**Specs :** `spec/services/rate_limit_service_contract_spec.rb`

---

## 1. Décisions CTO arbitrées (25/09)

| # | Question | Décision |
|---|---|---|
| A1 | Production sans `REDIS_URL` | **`RedisConfigurationError`** — pas de fallback silencieux |
| A2 | `CannotConnectError` / timeout Redis | **Fallback `MemoryBackend` + warning structuré** |
| A3 | Erreur Redis inattendue | **Pas de 429** — log `error` + erreur explicite (propagation) |
| A4 | 429 | **Uniquement** sur dépassement de limite effectivement constaté |
| A5 | Endpoints auth | Clé **IP** |
| A6 | Endpoints métier authentifiés | Clé **`user_id`** |
| A7 | Missions | **create 20/h · update 60/h** (clé `user_id`, fenêtre 1 h) — baseline contractuelle |
| A8 | CRA / entries | **Seuils repris dans §4, comme contrat initial** |
| A9 | Architecture | **R-4 : un seul mécanisme `RateLimitService` + Backend** |

> ⚠️ **Réserve de traçabilité (CTO)** : les seuils Missions/CRA/Entries sont les **seuils
> contractuels FC-05 retenus à ce jalon** — ils ne sont **pas** des valeurs historiquement
> garanties par le code (l'audit établit qu'elles n'étaient pas déclenchées).

## 2. Contrat de sélection du backend (6 états)

| # | Situation | Comportement contractuel |
|---|---|---|
| 1 | `REDIS_URL` absente, **dev/test** | `MemoryBackend` |
| 2 | `REDIS_URL` absente, **production** | **`RedisConfigurationError`** levée (config manquante = erreur explicite) |
| 3 | `REDIS_URL` présente + Redis **joignable** | `RedisBackend` (protection **distribuée**) |
| 4 | `REDIS_URL` présente + Redis **indisponible** | Fallback `MemoryBackend` + **warning structuré** (tag `rate_limit.backend_fallback`) |
| 5 | **Timeout** Redis | Idem état 4 (même contrat de dégradation) |
| 6 | **Erreur Redis inattendue** | Log `error` + **erreur explicite propagée** — **jamais** `RATE_LIMIT_EXCEEDED` |

**Propriété de dégradation (obligatoire)** :
- Redis disponible → protection **distribuée** ;
- Redis indisponible → protection **locale par processus** + warning + signal d'alerting ;
- Redis revenu → retour au backend distribué ;
- **Redis error ≠ RATE_LIMIT_EXCEEDED** — un `StandardError` interne n'est **jamais** transformé en 429.

## 3. Contrat compteur (RED 2 — figé)

Via **`RateLimitService.check_rate_limit`** (mécanisme réel de l'application) :
`limit = 1` → requête 1 **autorisée** → requête 2 **refusée** (`[false, …]` / 429 `RATE_LIMIT_EXCEEDED`,
`Retry-After` présent) — et le compteur vit dans le **backend sélectionné** (Redis en état 3).

## 4. Seuils contractuels

| Endpoint (clé LIMITS) | Clé | Fenêtre | Limite |
|---|---|---|---|
| `auth/login` | IP | 60 s | 5 *(existant, inchangé)* |
| `auth/signup` | IP | 60 s | 3 *(existant)* |
| `auth/refresh` | IP | 60 s | 10 *(existant)* |
| `missions:create` | `user_id` | 1 h | **20** |
| `missions:update` | `user_id` | 1 h | **60** |
| `cras:create` | `user_id` | 1 h | **10** |
| `cras:update_destroy` | `user_id` | 1 h | **50** |
| `cras:submit_lock` | `user_id` | 1 h | **5** |
| `cra_entries:create` | `user_id` | 1 h | **20** |
| `cra_entries:create_burst` | `user_id` | 10 min | **5** |
| `cra_entries:update_destroy` | `user_id` | 1 h | **50** |

Au dépassement : `[false, window]` → HTTP **429** `RATE_LIMIT_EXCEEDED` + header `Retry-After`.

## 5. Invariants R-4 (architecture cible)

1. **Un seul mécanisme** : `RateLimitService` → `Backend` (Strategy). `RedisRateLimiter` et les
   méthodes mortes des concerns sont supprimés — **après** les GREEN, jamais avant.
2. **Une seule configuration** : `LIMITS[endpoint]` → limite (Integer, table §4) ·
   `WINDOWS[endpoint]` → fenêtre (défaut 60 s) · clé : IP pour auth / `user_id` pour les
   endpoints métier (A5/A6). *(Correction d'implémentation 25/09 : les RED figent LIMITS en
   valeurs entières — la fenêtre vit dans WINDOWS, pas dans LIMITS.)*
3. **Une sémantique d'erreur explicite** par classe d'incident (table §2 + A3/A4).
4. **Une seule chaîne de test** : intégration via `RateLimitService.check_rate_limit` + sélection
   du backend par situation — les backends isolés restent testés en complément, jamais à la place.

## 6. Correspondance RED ↔ contrat

| RED | Exemples de contrat couverts |
|---|---|
| RED 1 — sélection | États 1→6 de la table §2 (dont production sans REDIS_URL, dégradation, jamais-429-sur-erreur-interne) |
| RED 2 — compteur end-to-end | §3 (enforcement + compteur dans le backend **sélectionné**) |
| RED 3 — missions | Table §3 : clés `missions:*`, end-to-end 21ᵉ requête refusée |
| RED 4 — CRA/entries | Table §3 : clés `cras:*`/`cra_entries:*`, end-to-end au seuil |

**Journal du RED** : cf. §7.

## 8. Journal GREEN (25/09/2026)

| Étape | Résultat |
|---|---|
| Implémentation minimale (sélecteur 6 états + `RateLimit::RedisConfigurationError` + WINDOWS par endpoint + sémantique A3/A4 + fallback par processus) | ✅ |
| RED 1-4 | ✅ **12/12 verts** |
| Régression (avant R-4) | ✅ 1167/0 — 3 mises à jour de specs vers le contrat A2 arbitré (anciens tests fail-closed 429) · `reset_storage!` ajouté (support de test) |
| R-4 cleanup | ✅ `Common::RedisRateLimiter`/`RedisConnectionError` supprimés · concerns `Cras`/`CraEntries` supprimés · `Common::RateLimitable` réduit à l'extraction d'IP · contrôleurs missions/cras/entries unifiés sur `RateLimitService` (clé `user_id`) |
| Régression finale | ✅ **1166/0** (−1 exemple : spec de la méthode morte `extract_endpoint` supprimée avec elle) · couverture 85,36 % lignes / 60,23 % branches (verrou 72,5 ✓) · RuboCop 0 (15 fichiers) · Zeitwerk ✓ |

**Reste avant certification** : CI 6/6 sur la PR · vérifications Render (REDIS_URL injectée + nb d'instances).

## 7. Journal du RED (mesuré 25/09/2026, conteneur `web`, RAILS_ENV=test)

**Résultat : 12 exemples — 10 échecs (tous pour raisons documentées) · 2 verts (comportements figés).**

| # | Exemple | Échec constaté | Cause mappée |
|---|---|---|---|
| 1 | état 2 — prod sans REDIS_URL | aucune erreur levée | C-1 (sélecteur ignore la config) — A1 |
| 2 | état 3 — Redis joignable | `got: MemoryBackend` (RedisBackend attendu) | **C-1** |
| 3 | état 4 — Redis down | pas de warning `rate_limit.backend_fallback` | contrat de dégradation absent |
| 4 | état 5 — timeout | pas de warning | idem |
| 5 | état 6 — erreur interne | **masquée en `[false, 60]`** (429) au lieu d'être propagée | défaut A3/A4 (StandardError → 429) |
| 6 | RED 2 — compteur dans le backend sélectionné | **compteur Redis : `nil`** après 3 requêtes | **C-1/C-2** |
| 7 | RED 3 — LIMITS missions | clés `missions:*` absentes | **C-3** |
| 8 | RED 3 — end-to-end 21ᵉ | refusée mais `retry_after: 60` (fenêtre globale) au lieu de `3600` (fenêtre par endpoint) | C-3 + fenêtres non paramétrées |
| 9 | RED 4 — LIMITS cras/entries | 6 clés absentes | **C-3** |
| 10 | RED 4 — end-to-end rafale | 6ᵉ refusée avec `retry_after: 60` au lieu de `600` | C-3 + fenêtres |

Exemples verts (2) — comportements actuels figés en régression : état 1 (MemoryBackend en dev/test)
· enforcement local limite 1 via `check_rate_limit` (MemoryBackend).

---

**Document créé le :** 25 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Statut : contrat v1 — toute évolution de seuil = nouvel arbitrage CTO tracé ici.*