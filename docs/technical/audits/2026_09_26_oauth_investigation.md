# 🔍 Investigation #21 — OAuth : Chemin Réel, Duplication, Sort du Concern, ApmService

**Date :** 26 septembre 2026
**Auteur :** Zed Agent (Investigation B — BACKLOG **#21**, GO CTO 26/09, cadrage renforcé)
**Statut :** ✅ Investigation terminée — **aucune modification de code** — chaîne falsifiable produite
(chemin réel → appelants → faits démontrés → écarts éventuels → causes → impact → arbitrage CTO)
**Périmètre :** `app/concerns/o_auth_concern.rb` · `app/controllers/api/v1/oauth_controller.rb` ·
`app/services/o_auth_{code_exchange,token,user,validation}_service.rb` · routes · appelants ·
`app/services/apm_service.rb` (uniquement après l'établissement du chemin OAuth)
**Discipline (CTO) :** duplication confirmée ≠ défaut — une anomalie supposée ne devient pas un bug
par simple présence dans le code ; correction seulement si comportement + impact démontrés.

---

## 1. Chaîne falsifiable — conclusion en une page

| Point sensible exigé par le gate | Fait démontré | Preuve |
|---|---|---|
| **Chemin réel exécuté** | OmniAuth callback → `POST /api/v1/auth/:provider/callback` → **`OauthController#callback`** → `process_oauth_validation` → `OAuthValidationService` (validate/extract, appelle `OAuthCodeExchangeService` en interne pour le flow code-exchange) → **`OAuthUserService.find_or_create_user_from_oauth`** → `OAuthTokenService` → 200 | `routes.rb` L24 · `oauth_controller.rb` L64-127 · grep call-sites |
| **Transaction** | **PRÉSENTE** dans le chemin réel : `OAuthUserService.find_or_create_user_from_oauth` enveloppe `ActiveRecord::Base.transaction` | lecture directe `o_auth_user_service.rb` L29-36 |
| **Portée exacte** | Transaction sur l'ensemble find-or-create-or-update (provider+uid → email-link → build) ; rescue `RecordNotUnique` → **retry anti-race** ; rescue `RecordInvalid` → log + re-raise | lecture directe L24-58 (header + implémentation) |
| **Concurrence (anti-race)** | **Protégée dans le chemin réel** — scénario documenté dans le service (« another request won the race » → retry lookup). **Scénario reproductible** : la spec `o_auth_user_service_spec.rb` (5 examples, race condition) exerce le retry | header + spec |
| **OAuthConcern — appelants** | **0 call-site** : `oauth_callback`, `find_or_create_user_from_auth`, `perform_oauth_login`, `extract_auth_data` n'apparaissent que dans le fichier du concern (grep exhaustif `app/`) | grep `app/controllers/ app/concerns/` |
| **OAuthConcern — include** | `include ::OAuthConcern` dans `AuthenticationController` L9 : **vestigial** — aucune méthode du concern n'y est appelée ; le `include StandardizedError` du concern est redondant (`ApplicationController` L11 l'inclut pour toute la hiérarchie) | greps + `application_controller.rb` L11 |
| **Duplication — nature exacte** | `extract_info_field` : **identique verbatim** (8 lignes, concern L85-93 ≡ `o_auth_validation_service.rb` L112-119) · `extract_provider/uid/info` (service) ≡ `extract_provider_and_uid/extract_info_data` (concern) : même logique, regroupement différent (~12 lignes) · find-or-create : logique similaire (concern L37-46 + L95-110 ≈ UserService) | lecture comparée ligne à ligne |
| **Impact de la duplication** | **Zéro en production** : le côté concern est **mort** (0 appelant) → la différence transactionnelle/anti-race n'est **pas exploitable** — la race sans transaction du concern ne peut pas se produire | C-2 du grep + logique du chemin réel |
| **ApmService — rôle / appelants** | Wrapper APM (Datadog/NewRelic) **jamais appelé** (re-grep : 0 occurrence hors son fichier) · `ApmService::TestHelpers` (57 LOC de support RSpec) embarquées en code de production · `enabled?` = false (ni datadog ni newrelic présents) | grep re-vérifié 26/09 |

**Conclusion (constat, pas bug)** : la duplication OAuth est réelle mais **unilatéralement morte** —
le chemin risqué (concern sans transaction/anti-race) n'a **aucun appelant**. Impact production : nul.
La correction est un **décision de nettoyage (arbitrage)**, pas un bug à corriger.

---

## 2. Méthodologie

1. Lecture intégrale `o_auth_concern.rb` (111 LOC) · `oauth_controller.rb` (chaîne callback) ·
   `o_auth_user_service.rb` (transaction/anti-race) · `o_auth_validation_service.rb` (extract/validate).
2. Greps exhaustifs des call-sites : `oauth_callback`, `find_or_create_user_from_auth`,
   `perform_oauth_login`, `extract_oauth_data`, `find_or_create_user_from_oauth`,
   `OAuth{Validation,User,CodeExchange,Token}Service.`, `ApmService`, `include StandardizedError`.
3. Croisement avec le hub RAG (fc08::010 : CodeExchangeService actif 0 % ; étude services §4-§5).
4. **Aucune modification de code.** Aucun test lancé (read-only, consigne).

---

## 2. Faits démontrés

### 2.1 Le chemin OAuth réel (falsifiable, preuve code)

```
Provider (browser) → OmniAuth → POST /api/v1/auth/:provider/callback   (routes.rb L24)
  → OauthController#callback
      → process_oauth_validation (L65-80)
          → validate_callback_payload (code/redirect_uri/state)
          → extract_oauth_data (L83-90)
              → OAuthValidationService.extract_oauth_data(request, provider:, code:, redirect_uri:)
                  → OmniAuth flow: request.env['omniauth.auth'] (browser)
                  → OU code-exchange flow: OAuthCodeExchangeService.exchange(...) (L105)
                     rescue ExchangeError → nil
          → validate_oauth_data (champs provider/uid/email)
      → find_or_create_user (L116-118)
          → OAuthUserService.find_or_create_user_from_oauth
              → TRANSACTION + rescue RecordNotUnique (anti-race) + retry lookup
              → rescue RecordInvalid → log + re-raise
      → generate_oauth_token (OAuthTokenService.generate_stateless_jwt)
      → render_success_response (format_success_response → 200)
  → GET /auth/failure → oauth#failure (contrat FC)
```

**Ce chemin est le SEUL** : grep exhaustif des call-sites OAuth dans `app/` — aucun autre contrôleur
n'invoque le flow OAuth. `AuthenticationController` ne traite que login/logout/refresh/revoke (JWT).

### 2.2 `OAuthConcern` — le constat « code mort » (falsifiable)

| Fait | Preuve |
|---|---|
| **0 call-site des 4 méthodes publiques** (`oauth_callback` L14, `extract_oauth_data` L24, `perform_oauth_login` L28, `find_or_create_user_from_auth` L37) | grep `oauth_callback|find_or_create_user_from_auth|perform_oauth_login` sur `app/controllers/ app/concerns/` → occurrences dans le fichier du concern UNIQUEMENT |
| L'`include ::OAuthConcern` dans `AuthenticationController` L9 est **vestigial** | aucune méthode du concern appelée dans ce contrôleur ; les helpers `error_*` viennent de `StandardizedError` inclus dans **`ApplicationController`** L11 (héritage commun) |
| Les helpers privés (`extract_auth_data`, `extract_provider_and_uid`, `extract_info_field`, …) ne servent que les méthodes mortes | lecture : usage interne au concern uniquement |
| Historique cohérent | les call-sites historiques vivaient dans `Api::V1::CraEntries::*` et l'ancien flow callback — supprimés lors de la migration services (jan 2026), jamais reportés |

**Sort démontré** : le concern est **du code mort de production** — son rôle historique (callback OAuth
pré-services) a été repris par `OauthController` + `OAuth*Service` (jan 2026). Impact actuel : nul
fonctionnellement ; coût : 111 LOC mortes + **risque de confusion** (deux implémentations OAuth
coexistantes, l'une sans anti-race, l'autre protégée — exactement la divergence qui a motivé #21).

### 2.3 Duplication — caractérisation précise

| Bloc | Concern (mort) | Service (vivant) | Verdict |
|---|---|---|---|
| `extract_info_field` | L85-93 (8 lignes) | L112-119 (`extract_info_field`, self) | **identique verbatim** |
| provider/uid | `extract_provider_and_uid` L64-71 | `extract_provider` + `extract_uid` (self) | même logique, 2 signatures |
| info | `extract_info_data` | `extract_info` | même logique |
| find-or-create | L37-46 + L95-110 (find_or_initialize + save non-bang, **pas de transaction, pas d'anti-race**) | `OAuthUserService` (transaction + rescue RecordNotUnique + retry) | **sémantiquement divergent** — mais côté concern **mort** |

**Total duplication réelle** : ~25-30 LOC d'extraction (+ ~40 LOC de find-or-create divergent).
Le « ~60 LOC » de l'étude englobait l'ensemble du concern mort.

**Discipline appliquée** : duplication confirmée → **constat architectural** ; l'impact concret
démontré est « code mort + risque de confusion », **pas** « race exploitable » — le chemin risqué
est mort, donc la race **ne peut pas se produire**.

### 2.4 ApmService (après établissement du chemin OAuth — per cadrage)

| Point | Fait démontré | Preuve |
|---|---|---|
| Rôle | Wrapper APM (Datadog/NewRelic : `tag`, `add_attributes`, `track_operation`) — **jamais branché** : ni gem `datadog` ni `newrelic` dans le Gemfile | `apm_service.rb` L1-60 + Gemfile |
| Appelants effectifs | **0** — grep `ApmService` sur `app/ config/ lib/` : son fichier seul | grep exhaustif (re-fait 26/09) |
| Statut | **Code mort de production** (254 LOC) incl. `ApmService::TestHelpers` (57 LOC de support RSpec embarqué) | lecture |
| Cohérence historique | Le hub (fc08::010, P6.1-bis) trace une dette « service 0 % confirmé par grep — examen avant exclusion » : cet examen est **fait** (cette investigation) | hub |

**Impact** : nul fonctionnellement (inerte) ; coût : 254 LOC mortes dont 57 de test-support en prod.

---

## 3. Écarts → causes → impact (chaîne falsifiable)

1. **Écart 1** — deux implémentations OAuth coexistent (concern + services).
   **Cause** : migration services jan 2026 — le callback a été réécrit sur les services ; le
   concern legacy n'a pas été supprimé (les call-sites historiques vivaient dans les contrôleurs
   refondus). **Impact démontré** : nul en production (chemin mort) ; impact latent = confusion
   (deux chaînes documentées, l'une sans anti-race) + 111 LOC mortes.
2. **Écart 2** — `ApmService` orphelin avec support de test embarqué.
   **Cause** : la standardisation APM a été centralisée dans `JsonWebToken` (déc 2025, hub)
   en laissant `ApmService` orphelin. **Impact** : 254 LOC mortes + 34 specs testant du code mort.
3. **Hors écarts** : le chemin OAuth réel **n'a montré aucun écart** — transaction ✓, anti-race ✓,
   logging ✓, secrets via ENV ✓, SSL+timeouts ✓ (Wave 2, déjà caractérisé).

## 3. Arbitrage CTO proposé (aucune correction exécutée)

| Option | Portée | Recommandation |
|---|---|---|
| **O-1 — Supprimer `OAuthConcern`** (111 LOC mortes, include vestigial) | cleanup R-4 | 🟢 recommandé — code mort démontré, 0 appelant, duplication résolue par suppression |
| **O-2 — Supprimer `ApmService`** (254 LOC + TestHelpers + 34 specs) + config/commentaires associés | mini-PR dédiée | 🟢 recommandé (Phase 2 de fc08::010 — après le chemin OAuth établi, ce qui est fait) |
| **O-3** — Conserver un wrapper APM épuré si une intention APM future est documentée | arbitrage produit | nécessite une intention documentée — aucune trouvée |
| **O-0 — Statu quo** | — | ❌ écarté par cohérence (même logique que R-0 FC-05 : code mort démontré ≠ comportement volontaire) |

**Principe (rappel CTO, appliqué)** : la duplication confirmée est un **constat architectural** ;
la suppression est justifiée ici par le **code mort démontré** (0 appelant ×2), pas par la
duplication elle-même.

## 4. Gate de sortie #21 — chaîne falsifiable produite

```
Chemin réel (établi : routes + contrôleur + services, §2.1)
  → appelants (0 pour le concern ; services = chaîne unique vivante, §2.1-2.2)
  → faits démontrés (transaction + anti-race présents côté vivant ; concern mort, §2.2-2.3)
  → écarts éventuels (duplication exacte caractérisée, §2.3 · ApmService orphelin, §2.4)
  → causes (migration services jan 2026 sans suppression du vestige, §3)
  → impact (zéro production — code mort · coûts : 365 LOC mortes + specs de code mort)
  → arbitrage CTO (O-1/O-2 suppression recommandée — §3, GO requis avant tout cleanup)
```

**Aucune correction engagée** — conformément à la discipline : duplication ≠ défaut, et le sort
des codes morts est une décision de nettoyage arbitrée, pas un correctif.

## 5. Références

- `app/concerns/o_auth_concern.rb` (111 LOC, intégrale) — methods publiques L14-46, privées L49-110
- `app/controllers/api/v1/oauth_controller.rb` L55-130 — chaîne callback réelle
- `app/services/o_auth_user_service.rb` L24-58 — transaction + anti-race (header + implémentation)
- `app/services/o_auth_validation_service.rb` L96-160 — extract (OmniAuth OU code-exchange) + helpers dupliqués
- `app/services/o_auth_code_exchange_service.rb` L24 — appelé par ValidationService L105
- `app/services/apm_service.rb` — 0 call-site (grep 26/09) · Gemfile (pas de gem APM)
- `app/controllers/application_controller.rb` L11 — StandardizedError hérité (include du concern redondant)
- Historique RAG : fc08::010 (0 % CodeExchange confirmé par grep Wave 2-3), étude services §4 (C-6) · §5.6
- BACKLOG **#21** · étude services (24/09)

---

**Document créé le :** 26 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Convention : préfixe `[DONE]_` à l'issue de l'arbitrage CTO (O-1/O-2) et de l'éventuel cleanup.*