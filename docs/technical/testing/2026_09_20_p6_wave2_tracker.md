# Plan d'implémentation & Suivi — P6 Wave 2

**Date :** 20 septembre 2026
**Décision CTO :** GO Wave 2 (20/09) — `OAuthCodeExchangeService` : caractérisation RED/GREEN du flow code-exchange
**Campagne :** `docs/technical/testing/2026_09_17_coverage_campaign_p6.md` (§4 — Wave 2 : OAuth)
**Branche :** `feat/p6-wave2` (à créer) — base : `main` @ `025b90b2` (réévaluation Wave 1, PR #36, CI 6/6)
**Règle de campagne :** traverser les chemins de code-exchange non exercés — **pas monter un pourcentage**

---

## 1. Règles de la vague (P6.0, inchangées)

| Règle | Énoncé |
|---|---|
| Pas de tests artificiels | Caractérisation du comportement **existant** du service et du flow contrôleur ; RED uniquement sur divergence **démontrée** vs comportement attendu et documenté (`2025_12_24_oauth_flow_documentation.md`) |
| Stub réseau | Stub déterministe de **Net::HTTP uniquement** — jamais d'appel réseau réel, jamais de stub des services applicatifs aval (`OAuthUserService`, `OAuthTokenService`) dans les specs d'intégration |
| Bug découvert | Devient un vrai cycle RED → correction → GREEN, traité explicitement dans le journal — décision CTO avant correction |
| Divergence détectée | Journal + décision CTO (arbitrage), pas de correction préventive spéculative |
| Évolution du compte de specs | Les ajouts sont le **périmètre même** de la vague (caractérisation du service non testé) — chaque ajout justifié au journal, compte documenté à chaque gate |
| Mesures | Projections **non contractuelles** — la valeur de référence est celle produite par SimpleCov à chaque étape |
| Hors périmètre | Mini-PR P1 (mécanisme de détection du contexte RSpec/coverage — chantier mécanique séparé) · D3-3 (reporté post-Wave 2, conformément au tracker Wave 1 §6) · tout refactoring du service ou du contrôleur |

## 2. Cibles et état mesuré (base `025b90b2` — suite 977/0, verrou 72,0)

| Cible | État | Taux |
|---|---|---|
| `app/services/o_auth_code_exchange_service.rb` (204 lignes brutes) | **Zéro référence dans toute la suite** (grep exhaustif `spec/` : aucun match `OAuthCodeExchangeService`/`ExchangeError`) — à confirmer par mesure SimpleCov fraîche | attendu **0,00 %** |
| Flow contrôleur code-exchange (`OauthController#callback` via payload `{code, redirect_uri}`) | Specs existants stubbent **au niveau `OAuthValidationService`** (jamais le service réel) — le flow code-exchange de bout en bout n'est pas exercé | à mesurer |

**État global transmis (PR #36) :** 77,18 % lignes mesurés · 977 exemples, 0 échec · verrou CI 72,0 tenu.

## 3. Reconnaissance — flow réel cartographié (20/09)

### 3.1 Chaîne d'appel complète

```
POST /api/v1/auth/:provider/callback   body: {code, redirect_uri, state?}
 └─ OauthController#callback (rescue StandardError → error_internal 500)
     ├─ valid_provider?                        → 400 'Invalid OAuth provider'
     ├─ process_oauth_validation
     │   ├─ OAuthValidationService.validate_callback_payload
     │   │     code.blank?            → :invalid_payload → 422 INVALID_PAYLOAD
     │   │     redirect_uri.blank?    → :invalid_payload → 422
     │   ├─ OAuthValidationService.extract_oauth_data
     │   │     1. request.env['omniauth.auth'] présent → OmniAuth flow (prioritaire)
     │   │     2. sinon code/provider/redirect_uri présents
     │   │        → OAuthCodeExchangeService.exchange(...)
     │   │           rescue ExchangeError → log error → nil
     │   │     3. sinon (code/provider/redirect_uri blank) → nil
     │   │     nil → :oauth_failed → 401 UNAUTHORIZED
     │   └─ validate_oauth_data(auth)  missing_provider/uid/email → :invalid_payload → 422
     ├─ OAuthUserService.find_or_create_user_from_oauth  (find provider+uid →
     │   find email+link → create ; save! → RecordInvalid re-raised ;
     │   race → retry, sinon RecordNotFound — jamais de user non persisté retourné)
     └─ OAuthTokenService.generate_stateless_jwt → 200 {token, user}
```

### 3.2 Chemins de `OAuthCodeExchangeService` (cible de caractérisation)

| Chemin | Déclencheur | Résultat observé (code lu, non exécuté) |
|---|---|---|
| Provider non supporté | `provider ∉ {google_oauth2, github}` | `ExchangeError 'Unsupported provider: X'` |
| Google — succès | token 200 + userinfo 200 | AuthHash `{provider, uid, info{email, name, nickname, image}}` |
| Google — token sans `access_token` | réponse 2xx sans access_token | `ExchangeError 'Failed to obtain Google access token'` |
| HTTP non-success (toutes requêtes) | `parse_json_response` | `ExchangeError '… failed with status N'` + `Rails.logger.error` |
| JSON invalide | `JSON::ParserError` | `ExchangeError '… returned invalid JSON'` + log |
| GitHub — succès | token + `/user` + email présent | AuthHash (uid en `to_s`, `nickname`) |
| GitHub — fallback `/user/emails` | `user_info['email']` nil | premier email `primary && verified` |
| GitHub — aucun email | fallback nil / blank | `ExchangeError 'GitHub account has no public email'` |
| GitHub — token sans `access_token` | réponse avec `error_description` | `ExchangeError 'Failed to obtain GitHub access token: …'` |

### 3.3 Points de stub réseau (contrainte technique)

- **Google token** : `Net::HTTP.post_form(uri, …)` — ne passe PAS par `perform_https_request` (point de stub distinct)
- **GitHub token + tous les GET** (`userinfo`, `/user/emails`) : `perform_https_request` → `Net::HTTP#request` (`use_ssl: true`, timeouts 10 s)
- Credentials lus via `ENV` au moment de l'appel (`GOOGLE_CLIENT_ID/SECRET`, `LOCAL_GITHUB_CLIENT_ID/SECRET`) — `ENV.fetch(..., nil)` : le stub intercepte avant tout échange, les ENV ne sont pas requises pour la caractérisation

## 4. Séquence validée (proposée au GO CTO)

### W2-D1 — Reconnaissance & cartographie — ✅ FAIT (20/09, cette session)

RAG (`foresy__knowledge`) + lectures locales + greps exhaustifs + git — see §3. Aucun code modifié.

### W2-D2 — Caractérisation unitaire du service (stub Net::HTTP)

**Périmètre :** les 9 chemins du §3.2 — Google succès (2 requêtes enchaînées), GitHub succès (2 à 3 requêtes enchaînées), fallback email GitHub, unsupported provider, token blank (Google/GitHub), HTTP non-success, JSON invalide. Assertions : contenu de l'AuthHash (provider/uid/info), message d'`ExchangeError`, log d'erreur.

**Gates :** suite verte (compte documenté), RuboCop 0, Brakeman 0, mesure SimpleCov réelle au journal.

**Commit :** `test(p6): characterize OAuth code exchange (Google/GitHub)`

### W2-D3 — Caractérisation intégrée du flow contrôleur (end-to-end, stub Net::HTTP minimal)

**Périmètre :** specs requête `POST /auth/:provider/callback` avec payload code-exchange réel : 200 Google + 200 GitHub (utilisateur réellement créé/lié en base, JWT réel), 401 oauth_failed (ExchangeError avalé → nil), 422 missing code / missing redirect_uri, 400 provider invalide, 422 missing fields du hash échangé. **Stub Net::HTTP uniquement** — aucun stub de `OAuthValidationService`/`OAuthUserService`/`OAuthTokenService` ; `RateLimitService.check_rate_limit` stubbé selon le pattern existant des specs auth.

**Gates :** idem + toute divergence observée → journal + décision CTO (aucune correction sans arbitrage).

**Commit :** `test(p6): characterize OAuth code-exchange flow end-to-end`

### W2-D4 — Points d'arbitrage (dossier CTO) — puis décision de verrou

1. **`handle_user_error` sans définition** (appelé `OauthController` L45, zéro `def` dans `app/`) — branche `unless user.persisted?` **injoignable en pratique** : `OAuthUserService` lève (`save!` → `RecordInvalid` ; `RecordNotFound` post-race) avant de retourner un user non persisté → le `rescue StandardError` de `callback` rend 500. Divergence structurelle documentée, **aucune correction sans arbitrage CTO** (options : documenter tel quel / cycle RED → correction minimale).
2. **Décision de verrou 72,0 → 72,5** — post-gates (§6).

## 5. Journal de suivi

### 2026-09-20 — Pré-travail d'hygiène documentaire exécuté — gates verts — W2-D2 débloqué

- **Pré-travail terminé (C1+C2+C3 + E1→E3, détails au tracker d'hygiène §5) :** 148 docs de `docs/technical/` migrés vers `YYYY_MM_DD_` + `[DONE]_` vérifiés ; 109 fichiers de références croisées corrigées (665 remplacements, commentaires code inclus — **aucune modification fonctionnelle**) ; 3 branches mergées supprimées localement ; `chore/p6-coverage-plan` en attente d'audit P1 (tranche CTO 20/09).
- **Gates :** suite **977/0** sur `foresy_test` + SimpleCov **77,18 % lignes (2815/3647) inchangé** · branches 47,87 % · grep anciens noms = 0 (2 refs pré-existantes dangling consignées, hors périmètre). Premier run = 22 échecs = **piège D-10** (DATABASE_URL → dev polluée) — procédure du guide d'isolement appliquée, fausse alerte confirmée.
- **Ce tracker renommé :** `p6_wave2_tracker.md` → `2026_09_20_p6_wave2_tracker.md` (convention C1).
- **W2-D2 : GO confirmé — implémentation des specs de caractérisation (§4) peut démarrer.**

### 2026-09-20 — GO W2-D2 acquis — gated par le pré-travail d'hygiène documentaire

- **GO CTO W2-D2 (20/09)** : caractérisation unitaire du service — 9 chemins, Google/GitHub, succès + erreurs, fallback email, `ExchangeError`, logs, stub **Net::HTTP uniquement**, aucun stub des services applicatifs aval. Branche cible `feat/p6-wave2` (base `main` @ `025b90b2`). W2-D3 uniquement après validation des gates W2-D2. `handle_user_error` : **observation stricte** pendant W2-D2/D3 — pas de correction préventive ; divergence fonctionnelle démontrée en W2-D3 → cycle RED → arbitrage → GREEN.
- **Verrou** : aucun relèvement anticipé — 72,0 → 72,5 uniquement après gates W2-D2 + W2-D3 et mesure SimpleCov réelle.
- **Pré-travail documentaire demandé avant implémentation** (audit branches + préfixes datés `docs/technical/` + marqueurs `[DONE]` vérifiés) : suivi dédié dans `docs/technical/2026_09_20_documentation_hygiene_tracker.md` — 3 arbitrages en attente (format `_` vs standard maison `-`, normalisation `[Done]` → `[DONE]`, clôture des 3 branches mergées + arbitrage `chore/p6-coverage-plan`).
- **Hors périmètre confirmé :** pas de P1 en parallèle, pas de D3-3, pas de refactoring OAuth.

### 2026-09-20 — GO Wave 2 + reconnaissance complète (W2-D1)

- **Contrat de routage respecté :** requêtes hub `foresy__knowledge` (« OAuth code exchange flow », « OAuthCodeExchangeService validation erreurs ») — sources : `docs/technical/guides/2025_12_24_oauth_flow_documentation.md`, `docs/BRIEFING.md` (entrée du 20/12/2025 : création du service), `docs/technical/audits/2025_12_17_CHANGELOG_REFACTORISATION.md` ; puis lectures locales complémentaires (le hub RAG n'est jamais remplacé par ces lectures)
- **État de départ vérifié (git) :** `main` @ `025b90b2` (HEAD = origin/main), arbre propre (rspec.xml non tracké, artefact) — conforme à l'état transmis
- **Découverte structurante :** `OAuthCodeExchangeService` — **zéro référence dans toute la suite** (grep exhaustif `spec/` sur `OAuthCodeExchangeService|ExchangeError` : 0 match) ; les 4 fichiers de specs OAuth existants (`spec/acceptance/oauth_feature_contract_spec.rb`, `spec/integration/oauth/oauth_callback_spec.rb`, `spec/integration/oauth_callback_security_spec.rb`, `spec/requests/api/v1/authentication/oauth_spec.rb`) stubbent tous **au niveau `OAuthValidationService`** — le service d'échange et son flow contrôleur ne sont jamais exercés. C'est la dette tracée en mémoire `fc08::010` (« P6.1-bis clos, dette OAuth → Wave 2 »)
- **Un seul appelant en production :** `OAuthValidationService.extract_oauth_data` (L104-113) — `rescue ExchangeError → nil` (le service n'expose jamais son erreur au contrôleur : l'échec d'échange = 401 oauth_failed, pas 500)
- **Bug latent documenté :** `handle_user_error` appelé sans définition (§4/W2-D4) — injoignable dans le flow réel actuel, arbitrage CTO requis
- **Note docs :** `docs/ROADMAP.md` ne marque pas FC-08 terminé (README v0.1.1 : ✅) — drift documentaire hors périmètre de la vague, relevé pour information
- **Aucune modification de code à ce stade** — tracker créé, GO W2-D2 attendu du CTO

## 6. Critères de sortie de vague

- [ ] W2-D2 → W2-D3 : chaque étape validée (suite verte, RuboCop 0, Brakeman 0, mesure réelle au journal)
- [ ] Compte de specs : chaque ajout justifié et documenté au journal (périmètre = caractérisation OAuth)
- [ ] Divergences détectées : journalisées + arbitrées CTO (aucune correction préventive)
- [ ] `handle_user_error` : décision CTO consignée (documenté ou corrigé en cycle RED → GREEN)
- [ ] Journal complet + docs de campagne à jour (`2026_09_17_coverage_campaign_p6.md`)
- [ ] PR Wave 2 ouverte au format maison — CI 6/6 = clôture de la vague
- [ ] Décision de verrou explicitée (§7)

## 7. Décision de verrou (contractuelle — post-gates)

- **Rappels d'état :** verrou courant **72,0** (maintenu pendant Wave 1 et sa réévaluation, arbitrage 19/09) ; retour contractuel à **72,5** rattaché à Wave 2.
- **Condition de remontée :** gates W2-D2 + W2-D3 conformes (suite verte, RuboCop 0, Brakeman 0, mesure SimpleCov réelle au journal démontrant la couverture effective du service et du flow).
- **Trajectoire (rappel CTO) :** 72,5 → **90** (palier décisionnel) → **95** (P6.6). Les projections ne sont pas contractuelles — la valeur de référence est la mesure SimpleCov de chaque étape.

## 8. Références

- Plan de campagne : `docs/technical/testing/2026_09_17_coverage_campaign_p6.md`
- Tracker Wave 1 (méthode + réévaluation) : `docs/technical/testing/[DONE]_2026_09_18_p6_wave1_tracker.md`
- Contrat d'erreur : `docs/technical/guides/2026_08_18_error_contract.md`
- Flow OAuth : `docs/technical/guides/2025_12_24_oauth_flow_documentation.md`
- Mémoire : `fc08::010` (dette OAuth → Wave 2) · `fc08::011` (clôture Wave 1 — amendement unique post-Wave 2 prévu)
- Base : PR #36 / merge `025b90b2` (réévaluation Wave 1 — G1+G2+G3, fc08::005 clôturée, D3-3 reporté)