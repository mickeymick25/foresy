# 🔴 Audit FC-05 — Rate Limiting : Divergence Architecture Documentée ↔ Runtime Exécuté

**Date :** 25 septembre 2026
**Auteur :** Zed Agent (Investigation A — BACKLOG **#20**, GO CTO 24/09)
**Statut :** ✅ Investigation terminée — **causes démontrées, aucune correction exécutée**
(la chaîne exigée : observation → cause démontrée → risque → correction *éventuelle* à arbitrer)
**Périmètre :** `app/services/rate_limit_service.rb`, `app/services/rate_limit/*`,
`app/controllers/concerns/common/rate_limitable.rb`, `app/controllers/concerns/api/v1/{cras,cra_entries}/rate_limitable.rb`,
contrôleurs, `render.yaml`, `docker-compose.yml`, `ci.yml`, specs rate-limiting.
**Méthodes :** lecture directe intégrale du code · greps d'appel · **2 démonstrations runtime**
(conteneur `web`, Redis réel du compose — probe nettoyée) · grep exhaustif · specs.
**Aucun code modifié. Aucun BACKLOG modifié** (consigne #20).

---

## 1. Synthèse exécutive

L'observation initiale (« MemoryBackend observé en runtime ») est **confirmée et expliquée** —
et l'investigation a révélé un périmètre **plus large** que prévu :

| Endpoint | Mécanisme en code | **Effet réel en production** | Gravité |
|---|---|---|---|
| `auth/login`, `auth/signup`, `auth/refresh` | `RateLimitService` + `MemoryBackend` | **Actif MAIS par-processus** (non distribué — chaque instance son propre compteur) | 🔴 |
| `missions` (create/update) | `RateLimitService('missions')` | **INACTIF** — `LIMITS['missions'] = nil` → `[true, 0]` systématique | 🔴 |
| `cras` (create/update/submit/lock : 10/50/5 par heure) | `RedisRateLimiter` (concern) | **INACTIF** — compteur jamais incrémenté (`increment!` défini, **jamais appelé**) | 🔴 |
| `cra_entries` (20/50/100 par heure) | `RedisRateLimiter` (concern) | **INACTIF** — idem | 🔴 |
| création d'entries (5 / 10 min / user) | `check_entry_creation_rate_limit!` | **INACTIF** — méthode **jamais appelée** (call-site : aucun) | 🔴 |

**Résultat net** : le seul rate limiting réellement actif en production est celui des
**3 endpoints auth**, en `MemoryBackend` — **par processus**. Toutes les autres limites annoncées
par FC-05 et le README (missions, CRAs, entries) sont des **no-ops**, démontrés contre Redis réel.

> ⚠️ Ces constats sont des **causes démontrées**, pas encore des corrections. Les remédiations
> (§7) restent à arbitrer — conformément à la réserve CTO : GO investigation ≠ GO correction.

---

## 2. Méthodologie & provenance

1. **Lecture intégrale** des 5 fichiers rate-limiting + contrôleurs appelants.
2. **Greps exhaustifs** : call-sites `check_rate_limit`, `increment!`, `allow?`, `RedisBackend.new`, `REDIS_URL`.
3. **Démonstrations runtime** dans le conteneur `web` (diagnostic en lecture, probe supprimée ensuite) :
   - `RateLimitService.backend.class` **avec `REDIS_URL` présent et Redis joignable** → `RateLimit::MemoryBackend`
   - `Common::RedisRateLimiter.allow?` ×10 contre **Redis réel** → toujours `true`, compteur reste `nil`
4. Croisement hub RAG (FC-05) — historique daté, non autoritaire.
5. Specs : lecture des suites rate-limiting.

---

## 2. Axe 1 — Configuration Render / production

- `render.yaml` **L43** : `REDIS_URL` **est déclarée** dans le blueprint (service web).
- **Conclusion** : la configuration versionnée prévoit bien Redis en production. La présence
  effective de la variable côté dashboard Render reste à confirmer humainement (§8) — mais elle
  est prévue et cohérente avec docker-compose (dev : `redis://redis:6379/0` + variante db 1 pour
  le test) et la CI (`redis://localhost:6379/0` ×8).

## 3. Axe 2 — Présence et usage de `REDIS_URL`

`REDIS_URL` est **lue exactement à 2 endroits dans le code**, et **jamais** par le mécanisme de
sélection de backend :

| Lecteur | Rôle | Consommé ? |
|---|---|---|
| `RateLimitService.redis` (privé, L59-63) | Connexion **exclusivement pour `RedisBackend#redis`** (via `send`) | ❌ jamais — `RedisBackend` n'est jamais instancié |
| `Common::RedisRateLimiter#redis_connection_url` (L112-138) | Connexion du limiter parallèle | ✅ à chaque requête (GET du compteur) |

**Conclusion** : la variable d'environnement n'a **aucune influence sur la sélection du backend**.
Elle ne sert qu'à ouvrir des connexions Redis… qui ne servent qu'à lire des compteurs jamais incrémentés.

## 4. Axe 3 — Mécanisme exact de sélection du backend

`app/services/rate_limit_service.rb` **L44-46** :
```ruby
def self.backend
  @backend ||= RateLimit::MemoryBackend.new
end
```
**Inconditionnel.** `RedisBackend` n'apparaît nulle part dans la logique de sélection —
le grep `RedisBackend` sur tout `app/` ne retourne que des **définitions et commentaires**
(`backend.rb`, `redis_backend.rb`, headers de service). Aucun initializer, aucune condition
d'environnement, aucun branchement.

**Cause démontrée #1** : le commentaire L41 (« *Switches to RedisBackend when Redis is available
and needed* ») décrit un mécanisme qui **n'a jamais été écrit**. Il n'y a pas de bug dans le
sélecteur — il n'y a pas de sélecteur.

## 5. Axe 4 — Pourquoi `MemoryBackend` est sélectionné

- **Statique** : L45 (ci-dessus).
- **Runtime (conteneur, 25/09)** : `REDIS_URL` = `"redis://redis:6379/0"` **présent**, Redis
  joignable (service compose healthy) → `RateLimitService.backend.class` = **`RateLimit::MemoryBackend`**.

La cause n'est donc **pas** « Redis indisponible » ni « REDIS_URL manquante » : c'est le code
lui-même qui ignore la configuration. **Divergence doc ↔ runtime démontrée par le code.**

## 6. Axes 5-6-7 — Multi-instance, Redis indisponible, sémantique fail-open/fail-closed

### 5. Comportement multi-instance (auth)
`MemoryBackend` est **mémoïzé par processus** (`@backend ||=`, L45). Sur N instances Render :
N compteurs indépendants → un attaquant obtient ~N × limite par minute, réparti entre les
processus. Pour un mécanisme introduit comme protection brute-force (FC-05), c'est un problème
**architectural réel** — pas cosmétique.

### 6. Comportement Redis indisponible — **deux sémantiques coexistantes**
| Système | Redis down | Comportement |
|---|---|---|
| `RateLimitService` (auth) | `rescue Redis::CannotConnectError, StandardError` → `[false, 60]` | **Fail-closed 429** (L99-101) — mais **chemin mort en l'état** : avec MemoryBackend, l'erreur Redis ne peut jamais survenir ; la seule chose qui peut déclencher la rescue est un **bug interne** (StandardError) → fail-closed **masque les bugs en 429** |
| `RedisRateLimiter` (CRAs/entries) | `Redis.new` par **requête** (L90) ; **aucune rescue** dans les concerns | L'exception remonte → chaîne `rescue_from` des contrôleurs (à caractériser précisément — probablement 429 via `error_too_many_requests` ou 500 selon le rescue) |

### 7. Sémantique de sécurité
- **Auth (RateLimitService)** : fail-closed assumé et documenté en log (`rate_limit.redis_unavailable` → `fail_closed`). Cohérent en soi — mais inopérant tant que le backend est Memory.
- **RedisRateLimiter** : `allow?` ne **lève rien** par design côté compteur, mais la connexion
  est ouverte **à chaque requête** (`Redis.new` dans `initialize`, L90) → coût par requête + dépendance
  Redis en ligne de lecture, pour un mécanisme qui ne limite jamais (§ Axe incrément ci-dessous).
- **`RedisConnectionError` en prod sans `REDIS_URL`** (L118-134) : garde de boot intéressante —
  mais elle ne sert qu'au limiter parallèle, jamais au mécanisme FC-05 documenté.

### Cause démontrée #2 — le compteur jamais incrémenté
`Common::RedisRateLimiter#increment!` (INCR+EXPIRE, L98-103) est **défini une fois et appelé
nulle part** (grep exhaustif sur `app/`). Tous les call-sites font uniquement `limiter.allow?`
qui ne fait qu'un `GET`. **Preuve runtime** (Redis réel du conteneur) : 10 × `allow?` avec
`limit: 1` → toujours `true`, compteur final `nil` au lieu de 10.

**Cause démontrée #3** — `RateLimitService::LIMITS` ne contient pas `'missions'` :
`check_rate_limit('missions', ip)` → `[true, 0]` (runtime vérifié). Le before_action de
`MissionsController` existe mais est un no-op.

## 7. Axe 8 — Tests existants : ce qu'ils prouvent et ne prouvent pas

| Suite | Ce qu'elle prouve | Ce qu'elle ne prouve PAS |
|---|---|---|
| `spec/services/rate_limit_backends_spec.rb` (14) | Le comportement **individuel** des 2 backends (increment/count/purge/stale) | **La sélection du backend** : aucune spec n'assert `RateLimitService.backend` en fonction de l'env — exactement le point 9 du CTO |
| `spec/requests/api/v1/rate_limiting/cra_rate_limit_contract_spec.rb` | Le **contrat 429** (`RATE_LIMIT_EXCEEDED`, format plat) via la chaîne `handle_rate_limit_exceeded` | Le déclenchement **naturel** du limiter (il ne peut pas déclencher — compteur jamais incrémenté) |
| `rate_limiting_api_integration_spec.rb` | Le comportement 429 auth (MemoryBackend) | La distribution multi-instance |
| (absent) | — | **0 spec unitaire `Common::RedisRateLimiter`** · 0 spec du mécanisme `increment!` (mort) · 0 test de sélection prod |

**Invariant manquant** (pour le contrat FC-05) : un test qui prouve « le backend utilisé en
production est le bon » — aujourd'hui impossible à satisfaire puisque la sélection est codée en dur.

## 8. Axe 9 — Divergence documentation ↔ configuration ↔ runtime (synthèse)

| Source | Affirmation | Réalité exécutée |
|---|---|---|
| `rate_limit_service.rb` L14 + `backend.rb` L3-4 + `redis_backend.rb` L2-3 | « RedisBackend in production (distributed rate limiting) » | ❌ MemoryBackend **toujours**, toute env |
| `rate_limit_service.rb` L41 | « Switches to RedisBackend when Redis is available and needed » | ❌ aucun switch n'existe dans le code |
| README (§ Rate Limiting) | « Missions/CRAs : Protection contre attaques par force brute » | ❌ no-ops démontrés (missions : limite absente ; CRAs/entries : compteur jamais incrémenté) |
| FC-05 / hub (historique) | « Production Ready avec REDIS_URL », « fail-closed corrigé » | ⚠️ le fail-closed existe (L99-101) mais porte sur un backend qui ne peut jamais échouer à Redis |
| `render.yaml` / docker-compose / CI | `REDIS_URL` configurée partout | ✅ conforme — mais **non consommée** par la sélection |
| Redis réel (runtime) | — | ✅ vivant et joignable ; le GET du limiter parallèle l'atteint, sans jamais écrire |

**Cause racine unique (unifiée)** : le chaîne FC-05 a été construite « en deux morceaux »
(service à backends + limiter parallèle dans les concerns) et **aucun des deux ne boucle** :
le service a un sélecteur mort, le limiter a un incrément mort. Les deux commentaires d'architecture
documentent l'intention, pas l'implémentation.

---

## 9. Chaîne observation → cause démontrée → risque

1. **Observation** : `MemoryBackend` en runtime (24/09, conteneur) — *confirmé 25/09*.
2. **Cause démontrée** : sélecteur inconditionnel L45 + `increment!` jamais appelé + `LIMITS` sans `'missions'`. Trois causes **indépendantes**, chacune vérifiée ligne à ligne + runtime.
3. **Risque** :
   - 🔴 brute-force non protégé sur login/signup/refresh au-delà d'une seule instance (Render multi-instances) ;
   - 🔴 missions/CRAs/entries : **aucune** protection, contrairement à la doc (surface d'attaque non bornée) ;
   - 🟠 fail-closed masquant tout `StandardError` interne en 429 (auth) ;
   - 🟠 connexion Redis ouverte par requête pour rien (latence/ressources) ;
   - 🟢 dead code : `rate_limited_endpoint?`, `extract_endpoint`, `check_cra_rate_limit!`, `check_cra_entry_rate_limit!`, `check_entry_creation_rate_limit!`, `check_entry_bulk_operation_rate_limit!` (call-sites : aucun).

## 10. Corrections **éventuelles** — à arbitrer (GO CTO requis)

| Option | Portée | Conséquences |
|---|---|---|
| **R-1 — Réparer le mécanisme FC-05** (sélection backend : `RedisBackend` si `REDIS_URL` présent + Redis joignable, fallback Memory + log) | code + specs de sélection | Rate limiting distribué auth ; fail-closed Redis devient vivant |
| **R-2** | Brancher `increment!` dans les call-sites RedisRateLimiter (ou basculer CRAs/entries sur `RateLimitService`) | ré-active missions/CRA/entries selon les limites documentées |
| **R-3** | Ajouter `LIMITS['missions']` (décider de la valeur, ex. 30/60s) | missions protégé |
| **R-4** | Supprimer le double système (convergence sur `RateLimitService` + `RedisBackend`) | 1 mécanisme, 1 contrat, 1 chaîne de test |
| **R-5** | Corriger les headers/docs (README §Rate Limiting, headers de service) | doc = réalité |
| **R-0** | Décision « comportement volontaire » | documentation + décision explicite, pas de code |

**Recommandation de forme** (proposition, hors périmètre de cette investigation) : R-4 d'abord
(unifier avant de réparer deux systèmes), puis R-1/R-2/R-3 en cycle RED démontré — mais c'est
l'arbitrage CTO qui décide, avec la vue complète (incl. #19 S-1).

## 11. Preuves **à obtenir côté Render** (actions humaines, hors dépôt)

- [ ] Dashboard Render → service web → Variables d'environnement : `REDIS_URL` réellement injectée ? (le `render.yaml` la déclare, mais la valeur active doit être vérifiée)
- [ ] Nombre d'instances du service web (multi-instance ? — détermine la gravité du per-process)
- [ ] Si `REDIS_URL` absente côté Render : pourquoi (dérive de config vs blueprint) — et corriger l'écart doc/dashboard
- [ ] Optionnel : `docker compose exec web` en prod-like → `RateLimitService.backend.class` (déjà fait en dev : MemoryBackend)

## 12. Journal de l'investigation

| Date | Étape | Preuve |
|---|---|---|
| 25/09 | Lecture `rate_limit_service.rb` intégrale | sélecteur inconditionnel L45 identifié |
| 25/09 | Greps call-sites (`increment!`, `allow?`, `RedisBackend`) | 0 call-site d'incrément ; `RedisBackend` jamais instancié |
| 25/09 | Lecture 3 concerns + contrôleurs | missions/CRA/entries no-ops ; limiter parallèle cartographié |
| 25/09 | Runtime conteneur `web` | `REDIS_URL` présent + backend MemoryBackend ; 10×`allow?` vs Redis réel → compteur `nil` ; `missions` → `[true, 0]` |
| 25/09 | Specs (axe 8) | 14 specs backends individuels ; **0 spec de sélection** ; 0 spec RedisRateLimiter |
| 25/09 | Probe Redis nettoyée (`audit_probe_fc05`) | ✓ |

## 13. Références

- `app/services/rate_limit_service.rb` L39-63, L99-101 — sélecteur, redis, fail-closed
- `app/controllers/concerns/common/rate_limitable.rb` L22-33, L85-139 — limiter parallèle, `increment!` orphelin
- `app/controllers/concerns/api/v1/{cras,cra_entries}/rate_limitable.rb` — limites déclarées non déclenchées
- `app/controllers/api/v1/missions_controller.rb` L166-177 — `endpoint = 'missions'` sans limite
- `render.yaml` L43 · `docker-compose.yml` L85/L131/L167 · `ci.yml` ×8 — REDIS_URL partout, jamais consommée par le sélecteur
- BACKLOG **#20** (Investigation A) · étude services §4 C-5 · mémoire fc08::012

---

**Document créé le :** 25 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Convention : préfixe `[DONE]_` à ajouter lorsque les arbitrages R-0…R-5 seront tranchés et exécutés.*