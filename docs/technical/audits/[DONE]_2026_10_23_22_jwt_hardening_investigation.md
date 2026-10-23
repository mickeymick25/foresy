# 🔍 Investigation #22 — Hardening JWT (clé de signature & épinglage d'algorithme)

**Date :** 23 octobre 2026
**Auteur :** Zed Agent (BACKLOG **#22** — mandat CTO : « *investigation en lecture seule, sans modification, sans présumer
qu'une vulnérabilité existe* ; correction uniquement après RED démontré et arbitrage »)
**Statut :** ✅ Chantier **#22 LIVRÉ ET CERTIFIÉ (23/10)** — O-1 (clé dédiée `JWT_SECRET` + fail-fast prod
boot/call + `HS256` explicite) — RED publics mesurés (seed 59372) → GREEN ×2 (contrat 6/0, seeds 55409/41245) →
**suite complète 1143/0 (seed 64073, +6 exemples de contrat)** · RuboCop 248/0 · Brakeman 0 · Zeitwerk OK ·
bundle audit 0 vulnérabilité · couverture 86,26 % lignes / 61,03 % branches (verrou 72,5 armé, franchi) —
**condition de release** : re-login général à annoncer + boot/health Render vérifiés à la bascule (§6.3) ·
mémoire `fc08::021` **proposée** (en attente validation CTO — §7 T7)
**Périmètre :** `app/services/json_web_token.rb` · `app/controllers/concerns/authenticatable.rb` ·
`app/services/authentication_service.rb` · `app/concerns/authentication_validation_concern.rb` (+
logging/metrics en traversée) · `app/services/o_auth_token_service.rb` · greps `JWT_SECRET` (app/config/CI) ·
`Gemfile.lock` (jwt **2.10.3**) · source gem `jwt-2.10.3` (`lib/jwt/decode.rb`, conteneur test) ·
`docker-compose.yml` (env services) · probes exécutées sur le **service `test`** uniquement
**Discipline (CTO) :** un code dangereux en théorie n'est pas un défaut atteignable — la chaîne doit être démontrée
(règle #19/#21). *Investigation → preuve → arbitrage → modification*. Probes runtime : lecture seule, base
`foresy_test`, `GIT_LEDGER_REAL` non activé (garde INV-D12-03 respectée, aucun appel Git), **secrets jamais imprimés**.

---

## 1. Conclusion en une page

| Élément | Qualification |
|---|---|
| **C-2 — clé de signature = `secret_key_base`** (`json_web_token.rb` L28) | ✅ **Démontrée** (statique + runtime) |
| **C-2bis — `JWT_SECRET` configurée mais jamais consommée** | ✅ **Démontrée** — 0 lecture dans `app/` ; CI « Validate secrets » valide une variable morte (« théâtre de config ») |
| **C-1 — HS256 implicite, algorithme non épinglé** (encode/decode sans option) | ✅ démontrée comme « non-explicité » · ❌ **sans défaut au runtime** : jwt 2.10.3 épinglée l'algorithme autorisé par son défaut (HS512 et `none` rejetés — `JWT::IncorrectAlgorithm`) |
| **C-0 — Refresh token sans `exp` standard** (validité 30 j portée par le claim custom `refresh_exp`) | ✅ **Démontrée** (runtime) — robustesse dépendante du service-level ; à tracer (sous-item), conforme au design actuel |
| **P-4 — Access token utilisable comme refresh token** | ✅ **Non atteignable** — rejeté par absence d'`refresh_exp` (`validate_refresh_exp`, concern L42-49) — fermer |
| **D-1 — duplication de contrôle** (`validate_token_expiration` duplique littéralement `validate_refresh_exp`) + triple `User.find_by` | Constat architectural (pattern #21) — impact prod nul, hors périmètre |
| Confusion d'algorithmes (`alg: none`, HS384/HS512) | ❌ **Rejetés** par le gem — défense incidente mais réelle |
| **Faille sécurité démontrable** | ❌ **Aucune** — la valeur de #22 est une mise en conformité configuration/posture, pas une correction de vulnérabilité |

**Correction maintenant : EN ATTENTE D'ARBITRAGE CTO** (options §6 ; recommandation O-1, dépendances de
déploiement à arbitrager — Render + invalidation des sessions à la release).

---

## 2. Méthode & preuves

### 2.1 Lecture statique (lecture seule)
- `app/services/json_web_token.rb` — service pivot (168 LOC) : `SECRET_KEY = Rails.application.secret_key_base` (L28) ;
  `encode` L32-48 (`JWT.encode(payload, SECRET_KEY)` L36 — **aucune option `alg`**) ;
  `refresh_token` L50-69 (payload `{user_id, refresh_exp}` L51-54, `JWT.encode(payload, SECRET_KEY)` L57 —
  **aucun `exp` standard, aucune option `alg`**) ;
  `decode` L71-93 (`JWT.decode(token, SECRET_KEY)[0]` L74 — **aucune option `algorithm:`/`algorithms:`**).
- `app/controllers/concerns/authenticatable.rb` — flux d'accès : `decode_token` → `JsonWebToken.decode` (L69-75) ;
  `valid_payload?` (L92-100) exige `user_id` + `session_id` ; session active requise, sliding via
  `current_session.refresh!` (L47).
- `app/services/authentication_service.rb` — `login` L13-32 (access `{user_id, session_id}` + refresh
  `{user_id, refresh_exp}`) ; `refresh` L34-63 → `decode_and_validate_refresh_token` L65-88.
- `app/concerns/authentication_validation_concern.rb` — `perform_validations` L36-40 :
  `validate_refresh_exp` L42-49 (**exige `refresh_exp` présent, sinon nil**) ;
  `validate_token_expiration` L51-55 (**duplication littérale** du contrôle précédent) ;
  `validate_user_and_session` L14-34 — session_id absent ⇒ **fallback "dernière session active"** (L24-29),
  cohérent avec le modèle user-bound documenté (E2E revocation, déc. 2025).
- `app/services/o_auth_token_service.rb` L16-29 — JWT OAuth `{user_id, provider, exp=15 min}` (sans `session_id`,
  donc non consommable par `Authenticatable` — design stateless documenté).
- Greps de surface : `JWT_SECRET` → **0 occurrence** dans `app/**` · 12 occurrences (env `ci.yml` — noms de
  variables, jamais de valeurs) · présent dans `.env.example` / `.env.test.example` (27/12/2025, placeholders)
  · absent des env des services compose `web`/`test` (fourni localement par `.env` via dotenv).
- `Gemfile.lock` : `jwt (2.10.3)` (contrainte `~> 2.7`) — le RAG citait 2.10.1 (déc. 2025) : version montée depuis.

### 2.2 Probes runtime (service `test`, 23/10/2026 — pure cryptographie, aucun write repo)

| Probe (résumé) | Résultat mesuré |
|---|---|
| `JsonWebToken::SECRET_KEY == Rails.application.secret_key_base` | **true** |
| `ENV['JWT_SECRET'].present?` dans l'env du service test | **true** (fournie — et **non consommée** : signature toujours `secret_key_base`) |
| Header `alg` d'un token produit par `JsonWebToken.encode` | **HS256** (implicite) |
| `JWT.encode({...même clé...}, 'HS512')` → `JsonWebToken.decode` | **rejeté — `JWT::IncorrectAlgorithm`** |
| `JWT.encode({user_id: 1}, '', 'none')` → `JsonWebToken.decode` | **rejeté — `JWT::IncorrectAlgorithm`** |
| Access token passé à `AuthenticationService.validate_refresh_exp` | **rejeté** (retour nil : `refresh_exp` absent) |
| `JsonWebToken.refresh_token(1)` décodé : `exp` standard / `refresh_exp` | **absent / présent** |

### 2.3 Mécanisme gem (source `jwt-2.10.3`, `lib/jwt/decode.rb`)
`verify_signature` L46-52 → `verify_algo` L54-59 : `'An algorithm must be specified' if allowed_algorithms.empty?`
(L55) · `'Expected a different algorithm' if allowed_and_valid_algorithms.empty?` (L58) — la liste autorisée est
**config-dérivée** (défaut du gem = HS256 pour une clé HMAC), **pas header-dérivée** (L69-71). Conséquence :
l'« épinglage » existe au runtime **incident** (défaut du gem), pas **explicite** (aucune option dans le code) —
un changement de défaut du gem lors d'une upgrade silencieuse modifierait l'acceptation.

---

## 3. Constat code — chaîne complète

```
CrasController/MissionsController (before_action)                    (acces tokens)
  └─ Authenticatable#authenticate_access_token! (L37-48)
       └─ decode_token (L69-75) → JsonWebToken.decode (L71-93)
            └─ JWT.decode(token, SECRET_KEY)[0]                      ← clé secret_key_base · alg non passé
valid_payload? (L92-100) : user_id + session_id requis → session active → refresh! (sliding)

POST /auth/login  → AuthenticationService.login (L13-32)
  ├─ JsonWebToken.encode(user_id:, session_id:)  → exp=15 min (défaut L29)
  └─ JsonWebToken.refresh_token(user.id)         → {user_id, refresh_exp=30 j} — SANS exp standard (L50-69)
POST /auth/refresh → AuthenticationService.refresh (L34-63)
  └─ decode_and_validate_refresh_token (L65-88) → JsonWebToken.decode (même clavier que l'access)
       ├─ validate_refresh_exp  (concern L42-49)   ← exiger refresh_exp ⇒ access rejeté incident
       ├─ validate_token_expiration (L51-55)       ← DUPLICATION littérale
       ├─ validate_user_id (L57-65)                ← 1er User.find_by
       └─ validate_user_and_session (L14-34)       ← 2e User.find_by + fallback dernière session active
POST /auth/:provider/callback → OAuthTokenService.generate_stateless_jwt (L16-29)
  └─ {user_id, provider, exp=15 min} — sans session_id ⇒ non consommable par Authenticatable (design)
```

Points d'écart relevés (hors défauts atteignables) :
- `refresh` sans session dans le payload ⇒ ré-ancrage sur la **dernière session active** (concern L24-29) — design
  « user-bound » documenté (E2E revocation 26/12/2025) : non-anomalie, mais à connaître pour #22 (les nouveaux
  tokens post-rotation invalideront les refresh liés à l'ancienne clé — totalité des refresh, donc).
- `revocation` : sessions `active: false` ⇒ fallback `sessions.where(active: true)` vide ⇒ refresh 401.
  Conforme au modèle Model A / `revoke_all` — vérifié E2E (déc. 2025), non re-qualifié ici.

---

## 4. Qualification complète des propriétés

| ID | Propriété | Preuve (statique/runtime) | Qualification | Conséquence sécurité |
|---|---|---|---|---|
| **C-2** | Clé de signature JWT = `secret_key_base` (jamais `JWT_SECRET`) | L28 (statique) + probe `keybase_match=true` ; 0 lecture `JWT_SECRET` dans `app/` | **Démontrée** | Couplage de rotation JWT ↔ secrets Rails ; divergence avec la configuration documentée/partagée (CI, `.env` templ.) ; rotation de `JWT_SECRET` inopérante |
| **C-2bis** | `JWT_SECRET` validée en CI (`Validate secrets`, env dans 4 jobs — 12 occurrences) mais **jamais lue** | grep (0 dans `app/`) + probe | **Démontrée** | Théâtre de config — *analogie exacte `REDIS_URL` pré-FC-05 (fc08::013)* |
| **C-1** | Algorithme implicite (encode/decode sans option) | L36/L57/L74 + probes HS512/none rejetés ; gem config-dérivé | **Démontrée (non-explicité) / non atteignable (défau)** | Épinglage incident du gem ; risque de *drift* à l'upgrade, pas de faille actuelle |
| **C-0** | Refresh tokens sans `exp` standard (30 j via `refresh_exp` custom) | `refresh_token` L51-57 + probe | **Démontrée** (design actuel conforme service-level) | Protection de validité portée par un seul chemin de validation ; tout futur consommateur standard du refresh le traiterait comme non-expirant |
| **P-4** | Access token ≥ refresh token | probe `access_token_as_refresh_rejected=true` | **Non atteignable** (fermer) | — |
| **D-1** | Duplication validation `refresh_exp` + triple `User.find_by` | concern L36-65 (statique) | Constat architectural | Impact prod nul (pattern #21) |
| **Doc-1** | Guide OAuth (24/12) : « access 1 h / refresh 7 j » vs code **15 min / 30 j** | RAG `2025_12_24_oauth_flow_documentation.md` vs `json_web_token.rb` L29-30 | Divergence documentaire périmée | Documentaire — incluse dans le lot « mini-PR documentaire » (§7 T6) |

**Lecture d'ensemble :** le motif C-2/C-2bis reproduit fidèlement le motif de l'audit FC-05 25/09
(« REDIS_URL configurée partout mais non consommée par la sélection ») : la configuration proclamée n'est pas
la configuration consommée. C'est le seul point de #22 porteur d'un **RED possible par point d'entrée public**
(spec de contrat assertant une signature issue de `JWT_SECRET` → got : `secret_key_base`).

---

## 5. Contexte documentaire (hub RAG — non réécrit)

- `BACKLOG.md::7` (L41-43) : « **Hardening JWT** — HS256 implicite + clé de signature = `secret_key_base`
  (algorithme explicite + clé dédiée) — sujet séparé, non prioritaire » · étude services §5.7 · CTO 24/09.
- Docs déc. 2025 (`[DONE]_2025_12_19_jsonwebtoken_exceptions_improvement.md`,
  `...JWT_Robustness_Improvements_Complete.md`) : l'usage de `secret_key_base` y est **documenté comme design
  acquis** (« VERSION ACTUELLE » citée verbatim) — C-2 n'est donc **pas une régression** récente, c'est le statu quo
  historique que #22 propose de durcir.
- `2026_09_24_services_layer_homogeneity_study.md::5` : « JWT séparé (#22) » — décision CTO 24/09.
- E2E revocation (26/12/2025) : modèle A session-scoped/user-bound — confirmé au code (§3).

---

## 6. Options de correction (pour arbitrage — rien d'engagé)

| Option | Portée | Conséquences & risques | Condition |
|---|---|---|---|
| **O-1 — Clé dédiée + épinglage explicite** (full #22) | `JsonWebToken` lit `JWT_SECRET` au boot ; **fail-fast prod** si absente ; fallback `secret_key_base` dev/test ; `algorithm: 'HS256'` explicite ×2 (encode/decode) ; 2 specs de contrat (RED public clé) | 🔴 **Dépendance déploiement : `JWT_SECRET` sur Render requise AVANT merge** · ⚠️ rotation de clé = **invalidation globale des sessions/refresh** à la release (à annoncer aux utilisateurs) · valeur : découplage rotation, consommation réelle de la config proclamée, fermeture du théâtre CI | Variante **O-1bis** : fallback + `Rails.logger.warn` en prod (pas de fail-fast) — dépendance retirée, posture moindre |
| **O-2 — Épinglage explicite seul** | `algorithm: 'HS256'` ×2 + 1 spec | ~3 lignes · **sans RED** → seulement justifiable comme durcissement assumé (règle : pas de correction sans anomalie atteignable·démontrée) | arbitrage libre |
| **O-3 — Clé dédiée seule** | C-2 sans l'alg explicite | l'alg reste incident | combinable avec O-2 |
| **O-0 — Statu quo tracé** | #22 documenté (ce doc) ; C-0 en sous-item ; doc-metrics mini-PR à la place | recevable : **aucune faille démontrée** ; mais le théâtre de config CI (C-2bis) persiste, en contradiction avec la posture établie par FC-05 | GO mini-PR doc à la place |
| **Sous-item #22-bis (toute option)** | `exp` standard sur le refresh (30 j) + éventuel claim `typ` access/refresh | évolution de contrat FC-02 + specs — **changement de design**, pas un durcissement minimal | arbitrage produit séparé |

**Recommandation :** O-1 (C-2 est à lui seul qualifié « anomalie ↔ configuration proclamée » — le RED public
correspondant est mesurable sans modification de code ; C-1 est un durcissement défensif de 2 lignes emporté au
passage). Le périmètre **C-0 reste hors #22** (sous-item).

### 6.1 Vérification Render (précondition 1, CTO 23/10) — résultat côté dépôt
- **`render.yaml` L33-34 : `JWT_SECRET` est déjà déclarée au blueprint avec `generateValue: true`** — la variable
  est générée par Render au provisionnement/applicaiton du blueprint, jamais transportée dans le dépôt. Le service
  `foresy-api` tourne en production, preuve *réduite* que l'infrastructure blueprint est appliquée (à minima
  historiquement).
- **Reste à confirmer (action CTO unique, dashboard Render → Environment)** : présence effective de `JWT_SECRET`
  sur le service déployé — lecture de présence, **aucun secret à afficher/exposer**. Inaccessible depuis le dépôt
  (aucun credential Render en périmètre) — c'est la seule vérification non automatisable ici.
- Si la variable est absente (service créé avant la ligne du blueprint) : l'ajouter via dashboard/CLI.
  **La pré-pose est sans effet** : `JWT_SECRET` est consommée par AUCUN code à ce jour (démontrée §4) — le service
  redémarre identique ; la bascule n'a lieu qu'au déploiement du merge (T4).
- **Indice git (23/10 — non probant, plausibilité)** : `render.yaml` crée **en une seule fois le 20/12/2025**
  (`86ae5a63` — « feat(deploy): add Render configuration for CD ») et **`JWT_SECRET` y est présente dès l'origine**
  (pickaxe `log -S "JWT_SECRET"` : même commit) — pas un ajout tardif. Si le service `foresy-api` a été provisionné
  via ce blueprint, la variable a été générée à sa création → présence hautement plausible. Ne tranche pas si le
  service a été créé manuellement avant le commit : seul le dashboard fait foi (§6.1, action CTO).
- **Runbook de vérification (CTO, dashboard Render — 23/10, action manuelle requise)** :
  0. Connexion https://dashboard.render.com (compte du projet).
  1. **Voie A — gestion Blueprint (confirmation structurelle, sans valeur)** : sidebar → **Blueprints** → l'instance
     du blueprint Foresy liste-t-elle `foresy-api` comme service **géré par le blueprint** ? Si oui, les `envVars`
     déclarées (dont `JWT_SECRET`, `generateValue`) ont été appliquées au provisionnement → présence quasi
     certaine. Si `foresy-api` est hors blueprint (créé manuellement avant le commit `86ae5a63`) → seule la voie B
     fait foi.
  2. **Voie B — lecture directe (présence seule)** : Sidebar → Services → `foresy-api` (runtime docker) → onglet
     **Environment** → la liste suit l'ordre du blueprint : `DATABASE_URL` · `RAILS_ENV` · `RAILS_LOG_TO_STDOUT` ·
     `RAILS_SERVE_STATIC_FILES` · `SECRET_KEY_BASE` · **`JWT_SECRET`** · `GOOGLE_CLIENT_ID` … → recherche
     navigateur « JWT_SECRET » suffit. Les valeurs sont **masquées par défaut** : vérifier la présence de la clé,
     **ne pas cliquer le bouton révélant (œil)** ni copier quoi que ce soit.
  3. **Cas présent** → signal « Render préparé — GO T3 ».
     **Cas absent** → *Environment → Add Environment Variable*, key `JWT_SECRET`, valeur générée **hors session**
     (`openssl rand -hex 64` en terminal local) → la page marque les changements **pending (requires manual
     deploy)** → **ne pas cliquer « Manual Deploy »** : la variable reste **posée dormante**. Rappel sans-risque :
     la variable n'est consommée par AUCUN code à ce jour (§4) — tout redéploiement éventuel (manuel OU auto
     sur push `main`) reboote le service à l'identique ; l'activation réelle n'a lieu qu'au déploiement du merge
     (T4). Éviter simplement toute poussée volontaire entre pré-pose et merge.
  4. Signaler le résultat — **RÉALISÉ (23/10)** : capture dashboard CTO — onglet Environment de `foresy-api` :
     **`JWT_SECRET` PRÉSENTE** (clé listée entre `GOOGLE_CLIENT_SECRET` et `LOCAL_GITHUB_CLIENT_ID` ; valeurs entières
     masquées, jamais révélées — lecture de présence conforme) ; liste visible : DATABASE_URL · GOOGLE_CLIENT_ID ·
     GOOGLE_CLIENT_SECRET · **JWT_SECRET** · LOCAL_GITHUB_CLIENT_ID · LOCAL_GITHUB_CLIENT_SECRET · RAILS_ENV ·
     RAILS_LOG_TO_STDOUT · RAILS_MASTER_KEY (+ « Show more »). Protocole CTO : présence = **« Render préparé —
     GO T3 »** acté → T3 autorisé (correction T4 toujours sous arbitrage RED).
  5. **Option avancée (si CLI/API déjà authentifiés — sinon ne JAMAIS créer de credential pour ça)** : API REST
     `GET /v1/services/{serviceId}/env-vars` (token : Account Settings → API Keys) — filtrer la liste sur la
     **clé** `JWT_SECRET`, ne jamais afficher les valeurs. Dashboard = voie recommandée, aucune clé additionnelle
     requise.
- `entrypoint.sh` L94-96 : hors production, `SECRET_KEY_BASE` est auto-générée si absente ; **en production aucune
  génération** (boot échoue si absente). Le fail-fast JWT suivra le miroir exact : verification d'absence **au
  boot** (constante) → déploiement Render échoue visiblement (health check `/health` jamais atteint) si la
  variable n'est pas posée — aucun trafic signé par une clé accidentelle.

### 6.2 Comportement attendu par environnement (précondition 2, design cible T4)
| Environnement | Comportement cible |
|---|---|
| dev / docker / test | `JWT_SECRET` **présence** → utilisée ; sinon **fallback `secret_key_base`** (probes : `.env` local fournit déjà la variable — `jwt_secret_set=true`) |
| CI | `JWT_SECRET` fournie par secrets + step « Validate secrets » existant (`ci.yml` L59-66, env ×4 jobs) — consommée réellement dès T4 |
| **production** | `JWT_SECRET` **requise** — raise au boot si absente (miroir `RateLimit::RedisConfigurationError`, contrat A1 FC-05) — **fail-closed** |
| Contrat d'encodage | `JWT.encode(payload, SECRET_KEY, 'HS256')` / `JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })` + 2 specs de contrat (clé + épinglage) |

### 6.3 Bascule & invalidation des sessions (précondition 3, CTo 23/10 — acceptée, plan)
1. **Pré-pose** de `JWT_SECRET` sur Render (§6.1) — sans effet (variable non consommée), zéro risque.
2. **Merge + deploy** → boot avec `JWT_SECRET` → **tous les access tokens** (15 min) signés avec l'ancienne clé
   rejetés dès la bascule (401) ; **tous les refresh tokens** (30 j) rejetés au refresh → **re-login général**.
3. Annonce unique à utilisateur ; **pas de fenêtre de maintenance requise** (401 → récupérable par re-login).
4. **Pas de stratégie double-clé/fenêtre de transition** : impact = re-login, service free plan, la complexité
   (vérification double-clefs temporaire) est disproportionnée — arbitrage « bascule simple » assumé et tracé.
   Repli échéancé **O-1bis** (fallback + warning + échéance + ticket de suppression) reste disponible si le CTO
   le préfère (non recommandé : maintient la dépendance `secret_key_base`).

---

## 7. 📊 Suivi d'implémentation (T1-T7) — source de progression de #22

> Règle anti-drift : mise à jour à chaque état substantiel ; **aucun statut `[DONE]_` n'est posé sur ce document
> avant la certification complète (T5) et la validation CTO**.

| T | Étape | Entrée requise | Statut | Preuve attendue |
|---|---|---|---|---|
| **T1** | Investigation lecture seule (périmètre §2 + probes §2.2) | mandat CTO (23/10) | ✅ **TERMINÉE (23/10)** — ce document ; 0 modification de code ; ledger inchangé (`141fa4e`, 1 commit) | audits `2026_10_23_22_jwt_hardening_investigation.md` (§1-§5) |
| **T2** | Arbitrage CTO — retenir O-1/O-1bis/O-2/O-3/O-0 · question Render (`JWT_SECRET`) · question invalidation sessions | §6 | 🟡 **GO CONDITIONNEL reçu (23/10)** : O-1 fail-fast préféré · **préconditions en cours (§6.1-§6.3)** — présence dashboard Render **à confirmer (CTO)** | décision CTO 23/10 · BACKLOG #22 mis à jour (23/10) |
| **T3** | **RED public** — spec de contrat JWT (clé dédiée : `JsonWebToken::SECRET_KEY` vs `JWT_SECRET` ; épinglage : alg non-HS256 → rejet) | ✅ **TERMINÉE (23/10)** — précondition Render levée par capture CTO (présence confirmée) puis spec écrite et exécutée sur service `test` : **6 examples, 3 failures, seed 59372** — RED mesurés : R-1 signe toujours avec `secret_key_base` (`VerificationError` au décodage `JWT_SECRET`) · R-1bis validé par `secret_key_base` malgré `JWT_SECRET` présente (« nothing was raised ») · R-2 aucun fail-fast prod (« nothing was raised ») — verrous R-3 (fallback) / R-4 ×2 (HS512, none → `IncorrectAlgorithm`) **verts** ; verrou SimpleCov non armé (run ciblé, design P6.1 respecté) | `spec/services/json_web_token_signature_contract_spec.rb` (sortie outil, seed 59372) |
| **T4** | Correction minimale — **O-1 exécutée** (GO CTO 23/10 + 2 ajustements : blank explicite sans `.presence` ; `HS256` explicite sans constante nouvelle) | GO + RED | ✅ **TERMINÉE (23/10)** — service : `ConfigurationError` (miroir FC-05 A1) · `signature_key` lu **à l'appel** (fetch explicite) · **garde boot prod** (absente OU vide ⇒ échec au démarrage, eager-load) · `HS256` explicite encode/decode/refresh · `rescue ConfigurationError` **en tête** ×3 (survit aux catch-all) · 15 sites de 5 spec files convertis à la clé dédiée (rails_helper `JWT_SECRET` déterministe) · `rubocop -a` : 13 `Style/FetchEnvVar` corrigées → **0 offense** · stubs `fetch` ajoutés R-2/R-3 (sinon la vraie valeur `.env` fuyait dans les exemples) | GREEN ×2 : contrat **6/0** (seeds 55409 · 41245) |
| **T5** | Certification — specs ciblées → **suite complète** (service `test`, base `foresy_test`) · RuboCop 0 · Brakeman 0 · Zeitwerk · bundle audit · couverture ≥ verrou 72,5 | T4 GREEN | ✅ **TERMINÉE (23/10)** | **mesuré** : contrat **6/0 ×2** (seeds 55409 · 41245) · suite **1143/0** (seed 64073, 3m12 = cible annoncée +6) · couverture **86,26 % lignes (3020/3501) / 61,03 % branches (885/1450)** · verrou 72,5 **armé & franchi** · RuboCop **248 files / 0** · Brakeman **0** · Zeitwerk **OK (All is good!)** · bundle audit **0 vulnérabilité** |
| **T6** | Docs & métriques — BACKLOG #22 → close · doc `→ [DONE]_…` · divergence doc-1 (guide OAuth 1 h/7 j) vers le lot mini-PR documentaire | T5 certifié | ✅ **TERMINÉE (23/10)** — ce fichier renommé `[DONE]_` · BACKLOG #22 → ✅ close · référence spec alignée · doc-1 **resté au lot mini-PR documentaire** (périmètre distinct, refusé comme prétendue vulnérabilité C-1) | docs/hub resynchronisés (reindex post-rename, vérifié Chroma ci-dessous) |
| **T7** | Mémoire `fc08::021` (#22) — proposition → validation CTO → Git → **vérification Chroma** puis déclaration « ENREGISTRÉE » + reindex hub | T6 | 🕓 **EN COURS — DRAFT PROPOSÉE au CTO (23/10)** | top-hit Chroma vérifié (date consignée) après validation

**Métriques de référence au lancement de T1 (23/10/2026, exécutions réelles de ce thread) :** suite **1137/0**
(seed variable) · couverture **86,32 % lignes (3012/3489) / 60,94 % branches (880/1444)** · RuboCop **247 files / 0** ·
Brakeman **0** (3 ignored) · bundle audit **0 vulnérabilité** · verrou SimpleCov **72,5** (lignes) · CI **6/6** ·
RAG `foresy__knowledge` **2448 chunks** · `foresy__memories` **21 entrées**.

**Journal :**
- 2026-10-23 — T1 livrée en lecture seule : statique (6 fichiers du chemin JWT + greps + gem source) + probes
  runtime (§2.2) ; qualification §4 ; doc + pointeur BACKLOG #22 + reindex hub ; **mémoires volontairement non
  créées** (gouvernance : après arbitrage/correction/certification).
- 2026-10-23 — T2 : arbitrage CTO reçu — **GO conditionnel O-1 (fail-fast prod)** · O-2/O-3 non retenues · O-0
  repli recevable · O-1bis échéancé si Render impossible. Vérification précondition Render côté dépôt (§6.1) :
  blueprint **déclare déjà `JWT_SECRET`** (`render.yaml` L33-34, `generateValue: true`) — présence sur le service
  **à confirmer dashboard (CTO, lecture de présence)** ; invalidation sessions acceptée, plan §6.3 (re-login
  général, pas de double-clé). Docs uniquement (§6.1-§6.3 + §7 + BACKLOG) — **0 changement de code avant
  confirmation explicite de la précondition de déploiement** (règle CTo 23/10).
- 2026-10-23 — T2-bis : complément d'évidence côté dépôt — blueprint daté (git) : `render.yaml` créé 20/12/2025
  (`86ae5a63`) avec `JWT_SECRET` dès l'origine (pickaxe) → indice de présence hautement plausible (non probant,
  dashboard requis). Agent : **aucun accès Render possible** (pas de credentials en périmètre, pas de
  contournement par token — garde-fou secrets). T2 reste ouvert sur l'unique confirmation dashboard (CTO).
- 2026-10-23 — T2 clôturée : capture dashboard CTO = **`JWT_SECRET` PRÉSENTE** sur `foresy-api` (lecture de
  présence, valeurs masquées) → protocole CTO : « Render préparé — GO T3 » acté.
- 2026-10-23 — T3 : RED publics mesurés — spec `json_web_token_signature_contract_spec.rb` écrite (4 familles
  R-1/R-2/R-3/R-4, stubs infra seuls) ; run service `test` : **6 examples, 3 failures, seed 59372** — R-1×2 (clé
  dédiée non consommée : signature reste `secret_key_base`) + R-2 (aucun garde prod) rouges ; R-3/R-4 verrous
  verts. **Correction T4 sous arbitrage** (diff minimal proposé dans le message GO).
- 2026-10-23 — T4 exécutée (GO CTO + 2 ajustements) : `ConfigurationError` + `signature_key` appel-time (fetch
  explicite) + garde boot prod + `HS256` ×3 + `rescue ConfigurationError` en tête ×3 ; conversion 15 sites
  (5 spec files, clé déterministe rails_helper) ; `rubocop -a` 13 FetchEnvVar → 0 ; **bug détecté et corrigé** :
  le catch-all `StandardError` de `encode` ré-emballait l'erreur de configuration en RuntimeError générique —
  solution : clause dédiée EN TÊTE des rescues (ordre séquentiel Ruby) · stubs `fetch` R-2/R-3 (sinon la valeur
  réelle `.env` fuyait via la surface fetch) · **GREEN** : contrat 6/0 (seeds 55409 · 41245).
- 2026-10-23 — T5 certifiée : suite **1143/0** (seed 64073, 3m12) · couverture 86,26/61,03 · RuboCop 248/0 ·
  Brakeman 0 · Zeitwerk OK · bundle audit 0 vuln · verrou 72,5 armé & franchi. T6 : clôture documentaire
  (rename `[DONE]_` + BACKLOG close + référence spec à jour + reindex + vérification Chroma). T7 : mémoire
  `fc08::021` **proposée** — écriture après validation CTO, déclaration « ENREGISTRÉE » après vérification Chroma.

---

## 8. Règles appliquées (traçabilité)

- Lecture seule : **aucune** modification de code/config/spec ; aucun commit.
- Probes uniquement sur le service `test` (jamais `web` — incident fc08::014), `GIT_LEDGER_REAL` non activé :
  aucun appel Git, garde INV-D12-03 respectée.
- **Secrets jamais imprimés** : seule la présence (`present?`) de `JWT_SECRET` a été testée, jamais sa valeur.
- Aucune réécriture d'historique ; écarts de datation tracés et maintenus.
- Le présent document suit la nomenclature datée `YYYY_MM_DD_` sans marqueur `[DONE]_` (clôture = T5/T6).

---

## 9. Références

**Code :** `app/services/json_web_token.rb` (L28, L32-48, L50-69, L71-93) · `app/controllers/concerns/authenticatable.rb`
(L37-48, L69-75, L92-100) · `app/services/authentication_service.rb` (L13-32, L34-63, L65-88) ·
`app/concerns/authentication_validation_concern.rb` (L14-34, L36-55, L57-65) · `app/services/o_auth_token_service.rb`
(L16-29) · `Gemfile.lock` (L158 : `jwt (2.10.3)`).
**Gem :** `jwt-2.10.3/lib/jwt/decode.rb` (L46-59, L69-71) — lu dans le conteneur `test`.
**Config/CI :** `.env.example` / `.env.test.example` (placeholders `JWT_SECRET`) · `.github/workflows/ci.yml`
(step « Validate secrets » + env `JWT_SECRET` ×4 jobs) · `docker-compose.yml` (env `web`/`test` sans `JWT_SECRET`).
**RAG (chunks) :** `BACKLOG.md::7` (#22) · `technical/audits/2026_09_24_services_layer_homogeneity_study.md::5` ·
`technical/analysis/[DONE]_2025_12_19_jsonwebtoken_exceptions_improvement.md::0-3` ·
`technical/changes/[DONE]_2025_12_19_JWT_Robustness_Improvements_Complete.md::0-1` ·
`technical/guides/2025_12_24_oauth_flow_documentation.md::9` (doc-1) ·
`technical/changes/[DONE]_2025_12_26_E2E_Revocation_Script.md::4` (modèle A).
**Métriques :** exécutions réelles du 23/10/2026 (suite via service `test`, seed consignée à l'époque du run ;
couverture SimpleCov HTML/Cobertura).

---
*Investigation #22 — 0 modification de code · 0 mémoire · arbitrage T2 en attente — règle « investigation → preuve → arbitrage → modification » (règle #21) appliquée.*