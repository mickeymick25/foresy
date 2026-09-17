# D-12 — Chiffrage : industrialisation des E2E shell en CI (LEDGER_PATH configurable)

**Date :** 17 septembre 2026
**Dette :** D-12 (registre `docs/technical/fc08_debt_register.md`, créée le 16/09 — revue CI co-CTO PR #29, P1b) : « `e2e_cra_lifecycle.sh` / `e2e_auth_flow.sh` ne sont pas exécutés dans le job E2E de la CI »
**Exigence co-CTO (17/09, correction d'ordre)** : D-12 **avant** P6 — « chiffrage précis : comprendre exactement ce qui empêche les E2E shell d'être exécutables avec un LEDGER_PATH configurable », puis implémentation en PR dédiée, CI verte, merge, checkpoint, **ensuite seulement P6.1**
**Méthode :** lecture du code (4 fichiers) + greps specs/scripts — **aucune modification de code à ce stade**

---

## 1. Constat technique exact (vérifié au code, ligne par ligne)

### 1.1 Les quatre couches du problème

| # | Constat | Preuve (code) | Impact |
|---|---|---|---|
| 1 | **Chemin codé en dur** : `GitLedgerRepository::LEDGER_PATH = '/app/cra-ledger'` | `app/services/git_ledger_repository.rb` L14 — utilisé partout (`chdir: LEDGER_PATH`, `mkdir_p`) | Inexistant/non créable sur les runners GitHub (`/` non inscriptible par l'utilisateur runner) |
| 2 | **Constante morte** : `GitLedgerService::LEDGER_PATH = '/app/cra-ledger'` | `app/services/git_ledger_service.rb` L17 — **0 usage** (grep : aucun `GitLedgerService::LEDGER_PATH` dans le code) ; le service délègue au repository | Nettoyage à inclure (le commentaire L16 cite le contrat FC-07 « Local path: /app/cra-ledger ») |
| 3 | **Court-circuit en test** : `return fake_commit(cra) if Rails.env.test?` | `app/services/git_ledger_service.rb` L35 — s'exécute **AVANT** tout appel au repository | Le ledger n'est **jamais touché** en env test |
| 4 | **Serveur du job E2E CI en `-e test`** | `ci.yml` — `bundle exec rails server -e test -p 3000` | En CI, le lock renvoie 200 avec commit **factice** |

### 1.2 Comment chacun contourne `/app` aujourd'hui

| Contexte | Mécanisme | Preuve |
|---|---|---|
| Specs d'intégration ledger (13/0) | Patch de constante vers un tmpdir : `GitLedgerRepository.singleton_class.const_set(:LEDGER_PATH, tmpdir)` | `spec/integration/git_ledger_integration_spec.rb` L16-21 |
| Request specs lock (FC-07) | **Aucun stub** — env test → `fake_commit` (couche #3) | `spec/requests/api/v1/cras/lock_spec.rb` (before : fixtures + RateLimitService seulement) |
| CI (jobs tests + E2E) | Env test → fake partout → `/app` jamais créé | CI verte depuis toujours |
| Local conteneur (dev) | Bind mount `.:/app` → `/app/cra-ledger` existe et fonctionne — **vrai ledger** | E2E shell PASSED ×3/×2 en HTTP réel |

### 1.3 Ce que font réellement les scripts shell

- `e2e_cra_lifecycle.sh` (17 étapes / 19 assertions) : parcours HTTP complet — signup → onboarding atomique FC-08 → 2 missions → CRA → 2 entries → **submit → lock (200) → modification = 409** → totaux vérifiés. **Aucune interaction filesystem** : le step 10 « Verify Git Ledger Commit » se contente de l'assertion HTTP du lock (commentaire in-situ L415-417) — le ledger est côté serveur.
- `e2e_auth_flow.sh` : parcours auth — aucun lien avec le ledger.

### 1.4 Reformulation du « bloqueur » (nuance importante)

Le constat initial (« `LEDGER_PATH` codé en dur → intégration CI impossible ») était **incomplet** : grâce au court-circuit `Rails.env.test?` (couche #3), **les scripts shell passeraient en CI dès aujourd'hui** — le lock renvoie 200 avec commit factice, sans jamais toucher `/app`. Le « bloqueur » réel ne porte pas sur l'**exécution** des scripts, mais sur l'**exercice du vrai Git Ledger en CI** : intégrés tels quels, ils rejoueraient le parcours HTTP (valeur réelle : le cycle complet à chaque PR) mais avec un ledger **factice** — l'élément différenciant de D-4/D-12 ne serait pas testé.

## 2. Options de périmètre

| Option | Contenu | Valeur | Durée |
|---|---|---|---|
| **A — minimale** | Intégrer les 2 scripts au job E2E CI **en l'état** (env test → ledger factice) | Parcours HTTP lifecycle complet rejoué à chaque PR ; mais le Git Ledger reste factice (comme les acceptance specs actuelles) — D-12 partiellement résolue | **≈ 0,5 h** |
| **B — réelle (recommandée)** | `LEDGER_PATH` **configurable** (ENV) + **gate explicite** du fake-commit + CI câblée pour exercer le **vrai** ledger + scripts intégrés | L'industrialisation couvre ce que D-4 a réparé : le lock **avec Git Ledger réel** en CI ; la CI attrape aussi les régressions ledger côté parcours | **≈ 2,5-3,5 h** |

**Recommandation : Option B** — c'est l'intention de la dette (les scripts D-4 valident précisément le lock avec Git Ledger ; les exécuter avec un commit factice n'ajoute que le parcours HTTP, déjà couvert par les acceptance specs). L'option A reste un fallback documenté.

## 3. Plan d'implémentation — Option B (PR dédiée, sans mélange avec SimpleCov/P6)

| Phase | Contenu | Gate | Durée |
|---|---|---|---|
| **D12.0** | Ce chiffrage | Revu CTO → GO | ✅ ce document |
| **D12.1** | **RED** — specs du nouveau comportement : (1) `GitLedgerRepository::LEDGER_PATH` lit `ENV['GIT_LEDGER_PATH']` avec fallback `/app/cra-ledger` ; (2) `commit_cra_lock!` → fake **par défaut** en test (non-régression des 957 specs), **vrai commit** si `ENV['GIT_LEDGER_REAL'] == 'true'` | Specs RED qui échouent pour la bonne raison | 30-45 min |
| **D12.2** | **GREEN** — `LEDGER_PATH = ENV.fetch('GIT_LEDGER_PATH', '/app/cra-ledger')` (repository) ; gate : `return fake_commit(cra) if Rails.env.test? && ENV['GIT_LEDGER_REAL'] != 'true'` ; suppression de la constante morte `GitLedgerService::LEDGER_PATH` (+ commentaire contrat ajusté : fallback préservé, override documenté) | Specs vertes ; suite 957/0 (défaut inchangé) ; RuboCop 0 ; Brakeman 0 | 15-20 min |
| **D12.3** | **CI** — job E2E : env du serveur `GIT_LEDGER_PATH: ${{ runner.temp }}/cra-ledger` + `GIT_LEDGER_REAL: 'true'` ; invocation des 2 scripts après le smoke ; YAML validé | CI PR : 6/6 verts, scripts PASSED | 20-30 min |
| **D12.4** | **Validation non-régression** — suite complète sur `foresy_test` (957/0, défaut fake préservé) ; rejeu local des scripts ×2 (serveur dev → vrai ledger à `/app/cra-ledger` — chemin par défaut **inchangé**) ; specs ledger 13/0 + 10/0 re-exécutées | Toutes gates vertes, rejeux ×2 | 45-60 min |
| **D12.5** | **Docs** — registre D-12 → ✅ résolue (avec la reformulation §1.4) ; note environnement (env vars `GIT_LEDGER_PATH`/`GIT_LEDGER_REAL`) au registre/guide CI ; journal | Hub réindexé | 30 min |
| **D12.6** | Merge → checkpoint global post-D-12 (co-CTO) → **P6.1 autorisé** | — | — |

**Total ≈ 2,5-3,5 h effectives.**

## 4. Analyse des risques (Option B)

| Risque | Mitigation |
|---|---|
| Le gate actuel `Rails.env.test?` protège les 957 specs de toute écriture ledger | Le nouveau gate préserve le **défaut** (fake en test sans flag) — non-régression prouvée par la suite complète (D12.4) |
| Écrire un vrai ledger depuis les specs si le flag fuit | Flag explicite `GIT_LEDGER_REAL` (jamais défini dans les environnements de spec) — spec RED le prouve |
| Sécurité du chemin via ENV | Trust ops (même niveau que `DATABASE_URL`) ; usage exclusif via `chdir:` d'`Open3` (aucun shell) + `FileUtils.mkdir_p` — aucune nouvelle surface d'attaque ; les specs p6_1 (argv, `SAFE_ID_PATTERN`, anti-backticks) restent valentes |
| Contrat FC-07 (« Local path: /app/cra-ledger ») | Fallback par défaut **inchangé** ; override = déviation documentée au registre (env de CI), pas une rupture contractuelle |
| Specs d'intégration ledger (patch `const_set`) | Compatible : la constante reste une constante de module simple, lisible depuis ENV au boot et surchargeable en spec |
| Chemin CI éphémère | `${{ runner.temp }}/cra-ledger` — nettoyé par GitHub, pas d'artefact parasite |

## 5. Décisions attendues du CTO (avant D12.1)

1. **Périmètre** : Option B — réel (recommandée) ou Option A — minimale ?
2. **Gate** : flag `GIT_LEDGER_REAL` (recommandé — explicite, jamais présent en spec) ou autre mécanisme ?
3. **Chemin CI** : `${{ runner.temp }}/cra-ledger` (recommandé) ou workspace ?

## 6. Références

- Registre : `docs/technical/fc08_debt_register.md` (D-12)
- Rapport de vérification (constat initial P1b) : `docs/technical/changes/2026-09-16-D1-D11_Debt_Verification_Report.md`
- Code : `app/services/git_ledger_repository.rb` (L14, L177), `app/services/git_ledger_service.rb` (L17, L35), `.github/workflows/ci.yml` (job e2e)
- P6 (chantier suivant, différé — P6.0 validée) : `docs/technical/changes/2026-09-17-P6_Coverage_Gap_Analysis.md` · `docs/technical/p6_coverage_implementation_tracker.md`