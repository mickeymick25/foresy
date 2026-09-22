# P7 — System Specs API Assessment

**Date :** 21 septembre 2026 · arbitrage CTO : 22 septembre 2026 (GO P7 — voir §10)
**Statut :** document de référence P7 — corrections CTO appliquées (numérotation UC, règle de stub, estimation non contractuelle)
**Diagnostic de référence :** pyramide Foresy — couches Unit/Services/Request/RSwag 🟢, System/E2E API 🟡
**Question structurante :** « Quelles sont les 5-10 choses que Foresy doit absolument savoir faire de bout en bout ? »

---

## 1. Ce que la suite actuelle teste réellement

### Niveau 1 — Unit / Model (🟢 contrats métier largement couverts)

| Ce qui est testé | Comment | Preuves |
|---|---|---|
| Validations métier | Cra, Mission, Company, User, pivots | `cra_contracts_spec`, `mission_contracts_spec`, etc. |
| Transitions d'état | draft → submitted → locked | `cra_contracts_spec` |
| Contraintes d'unicité | cra+mission+date, créateur+mois+année, provider+uid | specs modèles |
| Scopes | accessible_to, active, by_status, by_year, by_month | `cra_access_spec`, `list_spec` |
| Normalisation | siret, siren, country, currency | `company_contracts_spec` |
| Gardes pivots | exclusivité independent/client, unicité de lien | `pivot_contracts_spec` |

**Ce que ça garantit :** « Si je donne cet état au modèle, la règle locale fonctionne »

**Précision (arbitrage CTO)** : les qualificatifs des titres ci-dessous ne signifient pas 100 % de couverture SimpleCov ; ils signifient que les principaux invariants identifiés à chaque niveau sont caractérisés. Les chiffres SimpleCov précis restent dans les tableaux et dans l'assessment P6.6 (84,21 % lignes / 57,41 % branches).

### Niveau 2 — Domain / Services (🟢 contrats métier largement caractérisés)

| Ce qui est testé | Comment | Preuves |
|---|---|---|
| CraServices (CRUD + List + Lifecycle + Export) | `list_spec`, specs existantes FC-07 | service 96,92 %, create 81,63 % |
| Git Ledger | commit_cra_lock!, double lock, fail-closed, payload | `git_ledger_service_spec` — service 100 % |
| OAuth | code exchange (Google/GitHub), user service, validation | `o_auth_*_spec` — service 100 %, user 95,45 % |
| CraEntryServices | create/update/destroy/list | specs existantes FC-07 + W3-D3 |
| ApplicationResult | builders + contract | exercé transitivement par tous les services |

**Ce que ça garantit :** « Si je donne cet état au service, la règle métier fonctionne »

### Niveau 2bis — Infrastructure (🟢/🟡)

| Composant | Ce qui est testé | Ce qui manque |
|---|---|---|
| GitLedgerRepository | init, commit, verify, cleanup, fail-closed | repository 95,88 % (résidu défensif) |
| RedisBackend | incr/count/clear ZSET sur Redis réel | backend 100 %, redis_backend 100 % |
| JSON Web Token | encode/decode | json_web_token 97,14 % |
| APM (Datadog) | **non couvert** — candidat exclusion | apm_service 82,65 % (défensif) |

### Niveau 3 — Request / API (🟢 contrats HTTP caractérisés)

| Ce qui est testé | Comment | Preuves |
|---|---|---|
| HTTP → Controller → Service → Response | request specs par endpoint | `index_spec`, `cra_error_handlers_spec`, etc. |
| Gestion d'erreurs | rescue StandardError, handle_service_error (13 clés) | `cra_error_handlers_spec` |
| Rendu | ResponseFormatter.single/collection | `cra_response_formatter_spec` |
| Rate limiting | 429 par endpoint (3 concerns) | `cra_rate_limit_contract_spec` |

**Ce que ça garantit :** « Si j'envoie cette requête HTTP, le contrôleur répond correctement »

### RSwag / OpenAPI (🟢 402 specs)

| Ce qui est testé | Comment |
|---|---|
| API implémentation ↔ OpenAPI | Chaque request spec rswag génère/maintient le swagger.yaml |
| Audit exhaustivité | Route ↔ Swagger (35/35 routes) |

**Ce que ça garantit :** « L'implémentation correspond au contrat OpenAPI »

### Niveau 4 — E2E / System (🟡 LE GAP)

**Ce qui existe aujourd'hui :**

| Script E2E | Ce qu'il teste | Ce qu'il NE teste PAS |
|---|---|---|
| `e2e_cra_lifecycle.sh` | Signup → Login → Company → Missions ×2 → CRA → Entry ×2 → Totals → Submit → **Lock (Git Ledger)** → Lock protection → Accessibility | DB state · Ledger content · domain state · rollback · composition multi-composants |
| `e2e_auth_flow.sh` | Signup → Login → Revoke → Refresh → Logout → Wrong password → Non-existent | OAuth flow · DB state après chaque step |
| `e2e_companies.sh` | Onboarding atomique · duplicate · SIREN · soft delete | Effets DB après chaque step |
| `smoke_test.sh` | 15 endpoints — HTTP status only | Aucune vérification d'état |
| D-12 job CI | **VRAI Git Ledger** (GIT_LEDGER_REAL=true) : delta commits + message du lock | Le reste de la composition (services → models → DB) |

**Le trou précis** : les E2E shell vérifient le **HTTP status** de chaque step, mais ne vérifient pas :

| Dimension | Ce qui n'est pas vérifié |
|---|---|
| **DB state** | L'enregistrement existe-t-il vraiment ? Les champs sont-ils cohérents ? |
| **Git Ledger state** | Le fichier payload a-t-il le bon contenu ? Le commit a-t-il le bon message ? |
| **Domain state** | Les associations pivots sont-elles correctes ? Les relations sont-elles cohérentes ? |
| **Transaction** | Si le Ledger échoue, le rollback DB s'applique-t-il aussi à l'entry créé ? |
| **Multi-composants** | CraServices + CraEntryServices + GitLedgerService + Cra/Entry models collaborent-ils ? |

**Ce que les request specs ne testent pas non plus** : les request specs (type: :request) passent par le controller, mais utilisent `foresy_test` — la composition est réelle. MAIS les request specs existants testent un endpoint à la fois (POST /cras, POST /entries, GET /cras/:id) — pas la composition complète.

## 2. Les 10 use cases critiques de Foresy

Je liste les scénarios métier complets que Foresy doit absolument savoir faire. Pour chacun : ce qui est couvert à chaque niveau et ce qui manque.

### UC-1 : Authentification par email/password

```
Signup → Login → JWT → Authenticated request → Logout → Revocation
```

| Layer | Couvert ? | Preuve |
|---|---|---|
| Model (User) | ✅ | validations, password_required?, uniqueness |
| Service (AuthenticationService) | ✅ 80,39 % | login, refresh, revoke |
| Controller (AuthenticationController) | ✅ 98,25 % | login, refresh, revoke_all |
| Request spec | ✅ | specs existantes |
| E2E shell | ✅ e2e_auth_flow.sh | HTTP only |
| **System (DB state + domain)** | 🟡 | **le user est-il en DB ? Le token est-il révoqué en DB ?** |

**Écart** : les E2E vérifient HTTP mais pas l'état DB après chaque step (user existe ? token révoqué en base ?).

### UC-2 : Authentification par OAuth (Google/GitHub)

```
OAuth callback → user created/linked → JWT → Authenticated request
```

| Layer | Couvert ? | Preuve |
|---|---|---|
| Service (OAuthCodeExchange) | ✅ 100 % | W3-D2 (stub Net::HTTP) |
| Controller (OauthController) | ✅ 96,30 % | W3-D3 |
| Request spec | ✅ W3-D2 | code exchange + fallback |
| E2E shell | ❌ pas de script OAuth (credentials de test absents) | |
| **System (DB state)** | 🟡 | user créé en base vérifié dans W2-D3, mais pas dans un scénario multi-step |

**Gap principal** : le flow OAuth complet (callback → user → JWT → authenticated request) n'est pas testé de bout en bout avec la vraie infrastructure (Net::HTTP réel vers Google/GitHub).

### UC-3 : Company onboarding atomique

```
POST /companies → Company + UserCompany créés (atomique) → user lié
```

| Layer | Couvert ? | Preuve |
|---|---|---|
| Service (CompanyServices::Create) | ✅ 83,33 % | specs existantes FC-08 |
| Controller (CompaniesController) | ✅ 87,23 % | specs existantes FC-08 |
| Request spec | ✅ | specs existantes + E2E companies |
| **System (DB state)** | 🟡 | l'E2E companies vérifie HTTP mais pas l'état DB (company + user_company en base ?) |

### UC-4 : CRA lifecycle complet (le use case le plus critique)

```
Authenticate → POST /cras → CRA créé
  → POST entries (×2) → entries liées aux missions
  → Totals recalculés (serveur)
  → POST submit → status=submitted, totals recalculés
  → POST lock → status=locked + Git Ledger commit
  → PATCH entry → 409 (protection)
  → GET /cras/:id → état cohérent
```

| Layer | Couvert ? | Preuve |
|---|---|---|
| Model (Cra) | ✅ 96,06 % | W3-D4 — transitions, validations, atomicité lock |
| Services (List/Create/Update/Destroy/Lifecycle/Export) | ✅ 82-97 % | W3-D1 + specs FC-07 |
| Controller (CrasController) | ✅ 78,18 % | specs existantes + W4-D1 |
| Request spec | ✅ | specs existantes FC-07 |
| E2E shell | ✅ e2e_cra_lifecycle.sh | HTTP only (13 steps) |
| **System (composition complète)** | 🟡 | **le E2E vérifie HTTP mais pas la composition multi-composants** |

**Ce qui manque spécifiquement dans ce use case :**
1. **DB state après chaque step** — l'E2E vérifie HTTP mais pas : "l'entry existe-t-il vraiment en base après POST ?" / "le CRA a-t-il le bon total en base après submit ?"
2. **Git Ledger content** — le D-12 job CI vérifie le delta de commits, mais ne vérifie pas le contenu du payload
3. **Associations pivots** — les user_cras/cra_missions/cra_entry_missions sont-ils correctement créés par le flow ?
4. **Transaction rollback** — si le Ledger échoue au lock, l'entry créé et le CRA submitted sont-ils vraiment rollbackés ?

### UC-5 : CRA avec entries multi-missions

```
CRA → Entry A (Mission A, 0.5j) → Entry B (Mission B, 0.5j)
  → Totals = 1.0j / 65000
  → Submit → Lock
```

L'E2E `e2e_cra_lifecycle.sh` couvre **exactement ce scénario** (13 steps). C'est le use case le mieux couvert en E2E.

Mais : **il ne vérifie pas les effets secondaires en DB** (pivot cra_entry_cras, cra_entry_missions, user_cras).

### UC-6 : Token revocation + re-authentification

```
Login → JWT → Revoke → Token invalide → Login → nouveau JWT
```

| Layer | Couvert ? |
|---|---|
| Request spec | ✅ |
| E2E shell | ✅ e2e_auth_flow.sh |

Ce use case est bien couvert.

### UC-7 : Rate limiting (429)

```
Login ×6 → 429
```

| Layer | Couvert ? |
|---|---|
| Request spec | ✅ (FC-05) |
| Concern (RateLimitable) | ✅ W4-D2 |
| E2E | ✅ |

Ce use case est bien couvert.

### UC-8 : Export CSV

```
CRA locked → GET /export → CSV
```

| Layer | Couvert ? |
|---|---|
| Service (Export) | ✅ 95,45 % |
| Request spec | ✅ |
| **Vérification du contenu CSV** | 🟡 — le contenu est-il conforme au payload Git Ledger ? |

### UC-9 : Git Ledger — atomicité complète

```
Lock CRA → Git commit → succès (CRA locked + commit existant)
lock → Git échec → ROLLBACK (CRA reste submitted + pas de commit)
```

| Layer | Couvert ? |
|---|---|
| Service spec (GitLedgerService) | ✅ (échec git init → GitLedgerError) |
| Model spec (Cra#lock! atomicité) | ✅ W3-D4 |
| **System (vraie DB + vrai ledger + rollback complet)** | 🟡 — le spec W3-D4 test l'atomicité au niveau model, mais pas le flow complet HTTP → Controller → Service → Model → Ledger → DB |

### UC-10 : OAuth complet avec vraie infrastructure

```
Net::HTTP réel vers Google/GitHub → token → userinfo → user créé → JWT
```

Ce chemin est testé avec stub Net::HTTP dans les request specs (W2-D3). L'E2E shell ne teste pas le flow OAuth (credentials de test absents).

**Gap** : le flow OAuth avec une vraie infrastructure HTTP est testé avec stubs seulement. Un vrai test system OAuth exigerait des credentials de test pour Google/GitHub.

## 3. Synthèse des lacunes

| # | Gap | Criticité | Coût |
|---|---|---|---|
| 1 | **Vérification DB state après chaque step du lifecycle CRA** (cra existe ? entries existent ? pivots corrects ?) | 🔴 haute | ~5-8 specs system |
| 2 | **Vérification Git Ledger content** (pas seulement delta de commits — le payload JSON) | 🟠 moyenne | ~3-5 specs |
| 3 | **Vérification rollback complet** (DB + Ledger après échec) | 🟠 moyenne | ~3-4 specs |
| 4 | **Multi-composants composition** (controller → service → model → DB → Ledger dans un seul test) | 🔴 haute | ~5-8 specs |
| 5 | **Multi-utilisateur** (user A crée, user B ne voit pas ; user B lié à une mission voit) | 🟠 moyenne | ~3-5 specs |
| 6 | **OAuth flow avec vraie infrastructure** | 🟢 basse (credentials absents — différé) | différé |
| 7 | **Rate limiting end-to-end** (incr → limite atteinte → 429 → reset) | 🟢 basse (partiellement couvert) | ~2-3 specs |

## 4. Proposition de structure — System Specs API

**Pas de Playwright.** Le format est : request specs `type: :request` avec vérifications **DB + Ledger + domain state** en plus des assertions HTTP.

### Caractéristiques

| Élément | Choix |
|---|---|
| Framework | RSpec `type: :request` (même engine que les request specs existants) |
| Isolation | `foresy_test` (D-10) — base propre |
| Dépendances métier | **Aucun mock/stub des composants métier** — CraServices, GitLedger, models réels |
| Redis | Réel (RedisBackend, comme W4-D2) — ou MemoryBackend selon la config test |
| Git Ledger | **Réel** (GIT_LEDGER_REAL=true, overlay tmpdir — pattern D-12 éprouvé) |
| Injection d'échec | Déterministe, au niveau infrastructure/configuration (ex. `LEDGER_PATH` non inscriptible) — jamais `allow(Service).to receive(...).and_raise` |
| Net::HTTP | Stub maintenu pour OAuth (UC-2) — le OAuth infrastructurel réel est hors P7 (arbitrage CTO) |
| Vérifications | HTTP + DB state + Git Ledger state + domain state (associations pivots) |

### Structure proposée

```
spec/system/
├── cra_lifecycle_system_spec.rb       # UC-4 + UC-5 (phare — P0)
├── cra_ledger_rollback_system_spec.rb # UC-9 — rollback (P0)
├── company_onboarding_system_spec.rb  # UC-3 (P0)
├── oauth_login_system_spec.rb         # UC-2 (P2 — stub Net::HTTP maintenu)
└── rate_limiting_system_spec.rb       # UC-7 (P1 — si pertinent)
```

### Le principe

**Chaque system spec = un use case complet + vérification des effets secondaires.**

Pas 100 specs. Pas un Playwright. Pas un nouveau framework.

Juste quelques specs qui traversent le système de bout en bout et vérifient que l'état final (DB + Ledger + domain) est cohérent avec l'entrée.

**Critère de justification (arbitrage CTO)** — une system spec est justifiée uniquement lorsqu'elle vérifie une propriété de composition **non garantie** par les tests unitaires/services/request existants. Le chiffre 10-15 est une estimation, pas un quota.

**State, pas implémentation** — on vérifie les invariants métier observables, pas les attributs internes :

```ruby
# ❌ Teste l'implémentation
expect(cra.attributes).to eq({ ... 25 colonnes ... })

# ✅ Vérifie les invariants métier observables
expect(cra).to be_locked
expect(cra.entries.count).to eq(2)
expect(cra.total_days).to eq(1.0)
expect(cra.mission_ids).to contain_exactly(mission_a.id, mission_b.id)
expect(ledger_payload).to match_contract(...)
```

**Complémentarité avec l'E2E shell (rôles distincts, les deux conservés)** :
- Shell E2E : « un environnement réel peut-il effectuer ce parcours HTTP ? »
- System spec : « ce parcours produit-il exactement l'état métier attendu ? »

## 5. Ce que je ne ferais pas

| Anti-pattern | Pourquoi |
|---|---|
| 100 system specs | Chaque spec system est coûteuse (serveur réel, DB, ledger) — la pyramide exige peu de specs en haut |
| Playwright / navigateur | Inutile pour une API — pas de frontend à tester |
| Duplicer les request specs existants | Les request specs testent déjà les endpoints individuellement |
| Tester chaque service individuellement en system | C'est le rôle des specs unitaires/services (déjà 83,10 %) |
| Mocker un service métier (`allow(GitLedgerService).to receive(:lock!).and_raise`) | Le D-12 a prouvé que le vrai ledger est exercé — les échecs se provoquent par infrastructure/configuration déterministe (ex. `LEDGER_PATH` non inscriptible), pas en mockant le composant métier |
| Lancer OAuth réel (Google/GitHub) dans P7 | Credentials, réseau, quotas, rotation de secrets — le contrat applicatif est déjà couvert par les stubs ; le vrai OAuth infrastructurel est un contract/infrastructure test dédié, si la valeur le justifie |

## 6. Le contrat système (le 3e contrat)

| Contrat | Outil | Ce qu'il garantit |
|---|---|---|
| **Contrat interne** | RSpec unit/services | Service → Domain : la règle métier fonctionne |
| **Contrat HTTP** | RSpec Request + RSwag | Client → API : l'endpoint répond correctement |
| **Contrat système (LE MANQUE)** | System Specs API | Use Case → API → DB → Ledger → **état final cohérent** |

Le 3e contrat est le seul qui peut attraper :
- les erreurs de composition (chaque composant fonctionne, pas ensemble)
- les side effects manquants (le service réussit mais le DB state est incohérent)
- les rollback incomplets (le Ledger est écrit mais le DB ne l'est pas, ou vice versa)

## 7. Ce que P6.6 révèle sur ce trou

L'assessment P6.6 montre :
- models : 96-100 % (les invariants locaux sont verrouillés)
- services : 82-100 % (les règles métier sont caractérisées)
- controllers : 64-98 % (les couches d'erreur/dispatch sont caractérisées)
- **mais le système composé n'est pas testé en tant que tel**

Le trou n'est pas dans les composants individuels — c'est dans leur **composition**.

Et c'est précisément le type de bug que les 2 bugs production corrigés (GET /cras 500, ISO3166 NameError) ont révélé : chaque composant fonctionnait individuellement, mais leur composition échouait silencieusement.

## 8. Estimation

| Paramètre | Estimation |
|---|---|
| Specs system | **10-15 specs — estimation non contractuelle** (arbitrage CTO : pas un quota) |
| Sous-étapes | 2 proposées (P7-D1 : use cases P0, P7-D2 : side effects + rollback) — ajustables à la mesure |
| Vague | **P7 — branche dédiée `feat/p7-system-specs`, PR dédiée** (arbitrage CTO : P6 fermé, pas d'intégration Wave 4) |
| Verrou | 72,5 inchangé (les system specs n'augmentent pas le corpus mesuré — elles testent l'intégration) |
| Effort | ≈ équivalent à W3-D2 (16 specs, une session) |

## 9. Ce qui change méthodologiquement

Après P6, la question n'est plus :

« Quel pourcentage de couverture ? »

mais :

« Quels sont les scénarios métier complets où la composition des composants doit être vérifiée ? »

C'est une question de **RDD** (Relation-Driven Design) : tester les **relations** entre les composants, pas seulement les composants individuels.

Le hub RAG peut aider à identifier ces scénarios : les invariants INV-01 à INV-22 du registre FC-08 définissent déjà les invariants métier qui doivent être maintenus de bout en bout.

## 10. Décision CTO (arbitrage du 22 septembre 2026)

La proposition ci-dessus (options A-D) est conservée pour l'historique de décision. **Décision rendue : GO P7 — System Specs API, avec trois corrections méthodologiques.**

| Option | Arbitrage CTO |
|---|---|
| **A — P7 System Specs API** | ✅ **GO** — le gap de composition est réel et différent du gap de couverture traité en P6 |
| **B — Wave 4.5 (couche contrôleur)** | ❌ NON — dette quantifiée distincte, non bloquante, non lancée |
| **C — P6.6 tel quel** | ✅ CLOSED — aucune réouverture |
| **A + B combinés (palier 90 %)** | ❌ NON — 90 % n'est pas un objectif ; la couverture reste un instrument de mesure |

### Corrections méthodologiques CTO (appliquées à ce document)

1. **Numérotation UC corrigée** — le document initial contenait des doublons (UC-2 ×2, UC-5 ×2). Renumérotation séquentielle UC-1 → UC-10 appliquée. Correspondance avec les références de l'arbitrage CTO (qui suivaient l'ancienne numérotation) : Git Ledger = UC-9, export = UC-8, rate limiting = UC-7, revocation = UC-6.
2. **Règle de stub affinée** — « aucun stub » n'est pas absolu : aucun mock/stub des composants métier et services internes ; les défaillances (rollback Ledger) sont provoquées de façon déterministe au niveau infrastructure/configuration (ex. `LEDGER_PATH` non inscriptible), jamais via `allow(GitLedgerService).to receive(:lock!).and_raise`.
3. **10-15 = estimation, pas quota** — le livrable P7 est un contrat système démontré, pas un nombre de specs. Chaque system spec doit démontrer une propriété de composition non garantie par les couches inférieures.

### Priorité P7

| Priorité | Use case | Pourquoi |
|---|---|---|
| 🔴 P0 | UC-4 — CRA lifecycle complet | composition maximale + Ledger + transactions |
| 🔴 P0 | UC-9 — Git Ledger / rollback | frontière critique et atomicité |
| 🔴 P0 | UC-3 — Company onboarding | atomicité + association UserCompany |
| 🟠 P1 | UC-5 — multi-missions / pivots | intégrité relationnelle |
| 🟠 P1 | UC-1 + UC-6 — auth / revocation | état DB et sécurité |
| 🟠 P1 | UC-7 — rate limiting | Redis + comportement temporel |
| 🟡 P2 | UC-2 — OAuth (stub Net::HTTP) | contrat applicatif seulement |
| 🟡 P2 | UC-8 — export | moins critique pour démontrer la composition |
| ⚪ Différé | UC-10 — OAuth infrastructure réelle | hors P7 — credentials absents ; candidat contract/infrastructure test dédié si la valeur le justifie |

### Scénario phare

CRA lifecycle + Git Ledger + rollback (UC-4 + UC-9) : il concentre le plus grand nombre de frontières critiques et constitue le premier livrable de référence de P7.

### Critère de réussite

Pas : « nous avons ajouté 15 specs ».

Mais : « les use cases critiques disposent d'un contrat système démontrant que leur état métier final est cohérent après traversée réelle de l'API et des composants ».

### Exécution

- Branche dédiée `feat/p7-system-specs` depuis `main` — PR dédiée (P6 fermé, pas d'intégration Wave 4).
- Méthode : RED → test système minimal → GREEN → caractérisation → mesure.
- Playwright : NON nécessaire.

## Références

- Registre FC-07 : invariants INV-01 à INV-22 · registre FC-08 : INV-01 à INV-22 (contrat, L1606-1694)
- E2E shell : `bin/e2e/e2e_cra_lifecycle.sh` (13 steps, HTTP only) · `bin/e2e/e2e_companies.sh` (13 scénarios FC-08)
- D-12 job CI : vrai Git Ledger (GIT_LEDGER_REAL=true, LEDGER_PATH RUNNER_TEMP)
- Guide E2E : `docs/technical/testing/[DONE]_2025_12_24_e2e_staging_tests_guide.md`