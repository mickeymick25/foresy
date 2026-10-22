# 📐 Cadrage #28 — Prévention structurelle du ledger réel : contrat, reachability, protections, RED

**Date :** 2026-10-03 (horodatage git-clock hôte)
**Chantier :** BACKLOG **#28** — « prévention structurelle du ledger (mode réel hors overlay) » — **cadrage lecture
seule** (GO CTO 2026-10-03 : ouverture non automatique, aucun patch avant démonstration du défaut
+ nouvel arbitrage)
**Statut :** ✅ Cadrage terminé — conclusions qualifiées (démontrés / inferrés / indéterminés) —
**options O-1 / O-2 / O-0 soumises à arbitrage** · suivi : §6
**Verrou** : la purge `cleanup!` certifiée en **#24 n'est pas touchée** dans aucune option · aucun patch,
aucune modification de spec/contrat dans ce cadrage.

---

## 1. Conclusion en une page

| Question du cadrage | Réponse | Qualification |
|---|---|---|
| **1. Contrat attendu de `GIT_LEDGER_REAL=true`** | Actuel : active le chemin réel (test: explicite nécessaire ; dev/prod : toujours réel — la garde ne protège pas le dév) ; **aucune obligation d'overlay n'est appliquée** — l'overlay est une convention D-12 sans enforcement | démontré (L37 + écrivains) |
| | **Attendu (proposé)** : en test, réel ⇒ `LEDGER_PATH ≠ '/app/cra-ledger'` (overlay env au boot **ou** `const_set`), sinon **refus fail-fast** (`INV-D12-03`) ; dev/prod inchangés (réel = leur raison d'être) | proposition → arbitrage |
| **2. Conditions imposant un overlay** | (a) toute spec RSPéc en mode réel (INV-D12-01 : sinon le réel est interdit aux tests par défaut) — overlay = `const_set` tmpdir (convention éprouvée W3) **ou** `GIT_LEDGER_PATH` résolu au boot (serveur E2E CI) · (b) E2E local : réel **sans overlay délibéré** (usage légitime, contexte dév) · (c) prod : réel obligatoire | démontré |
| **3. Chemins d'écriture réels hors overlay TODAY** | **Dev** : runner/serveur dev/`rails runner` — **DÉMONTRÉ** (13/23 commits #24 — la garde fail-open) · **Test** : un spec oubliant l'overlay écrirait le réel — aucun écrivain actuel sans overlay trouvé (grep : les 4 écrivains overlay) mais **historiquement produit** (7 payloads Faker 22/09 — mécanisme exact non établi) · **E2E local** : délibéré/légitime (17/09) | dev = démontré · test sans overlay actuel = **aucun trouvé (démontré)** · historique 22/09 = inféré · e2e = délibéré |
| **4. Protections existantes / limites** | 7 protections (§5) — limites structurantes : garde fail-open en dév · overlay = convention sans enforcement · teardowns const repositionnés sur le **défaut** (pas la valeur d'origine) · `history_rewritten?` ne vérifie **que la config**, pas l'historique | démontré (code) |
| **5. RED déterministe** | Proposition §5.1 : **INV-D12-03** — spec : `Rails.env=test` + `GIT_LEDGER_REAL='true'` + `LEDGER_PATH == défaut` + CRA **invalide** (non-soumis) ⇒ post-fix : `GitLedgerError('Real ledger without overlay')` levé **avant toute écriture/initialisation** ; pré-fix : message générique différent (`Git Ledger commit failed…`) + **l'assertion du message échoue = RED**, **zéro contact utile avec le réel** (`ensure_initialized!` no-op car le repo existe, `validate_cra!` échoue avant tout git-write) | proposition → arbitrage |
| **6. Périmètre minimal** | **O-1** : garde service (~8 lignes) + spec INV-D12-03 · **O-2** : uniquement la spec de contrat (documentation exécutable, sans enforcement) · **O-0** : statu quo tracé (issue recevable — cf. vos garde-fous) · purge #24 : **hors périmètre** | options → arbitrage |

---

## 2. Le contrat — actuel (démontré) vs attendu (proposé)

### 2.1 Actuel — `git_ledger_service.rb` L33-48

```ruby
return fake_commit(cra) if Rails.env.test? && ENV['GIT_LEDGER_REAL'] != 'true'
# sinon (dev / prod / test+explicit-'true') :
validate_cra!(cra) ; GitLedgerRepository.ensure_initialized! ; …execute_commit
```

| Environnement | Effet de la garde |
|---|---|
| `test` + `GIT_LEDGER_REAL` absent / accidentel | **fake** — INV-D12-01 (spec'd, INV-D12-03 absent) |
| `test` + `GIT_LEDGER_REAL == 'true'` | **réel** — overlay **non exigé** (aucun check du chemin cible) |
| `development` | **réel TOUJOURS** (le `&&` fail-ouvre) — cause des 13 commits de #24 |
| `production` | réel (voulu) — protections : `cleanup!` refusé sans force (L50), `SAFE_ID_PATTERN` (D-5), `denyNonFastForwards` |

### 2.2 Attendu (proposition, arbitrage requis)

- **INV-D12-03 (nouveau)** : en **test**, `GIT_LEDGER_REAL='true'` **implique** que la cible
  n'est **pas** le chemin contractuel par défaut (`'/app/cra-ledger'`) — sinon `GitLedgerError`
  dédié, **avant** `ensure_initialized!`/`validate_cra!`.
  - Overlay légitime : `GIT_LEDGER_PATH` résolu **au boot** (serveur E2E CI — le const lit l'env au load, L16)
    **ou** overlay `const_set` au runtime (convention W3).
  - Effets vérifiés au code : chaque écrivain test actuel passe par l'un des deux (§3) ⇒ l'INV-D12-03 est
    **additive** (aucun comportement actuel légitime ne casse) — **à re-vérifier par la suite complète au
    moment de l'implémentation (T5)**.
- Dév/prod : **inchangés** (réel = usage légitime par design D-12/E2E/prod).
- **Purge #24 non touchée** (aucune option ne modifie `cleanup!`).

> ⚠️ Subtilité documentée : la constante `LEDGER_PATH` lit l'env **au chargement du module** (bootsnap actif —
> `ENV` au boot). Changer `ENV['GIT_LEDGER_PATH']` **après** le boot est **sans effet** sur le const (seul
> `const_set` le modifie) — cf. INV-D12-02. Toute extension d'overlay par la suite devra respecter
> cette mécanique (elle est tracée/spec'd aujourd'hui).

---

## 3. Overlay obligatoire — mécanique actuelle (démontrée)

| Écrivain (test, mode réel) | Overlay | Teardown |
|---|---|---|
| `spec/system/cra_lifecycle_system_spec.rb` (ENV 'true' restauré, around/ensure L21-25) | `const_set` tmpdir (L37-52) | rétablit `'/app/cra-ledger'` **défaut** (pas la valeur d'origine) |
| `spec/integration/git_ledger_integration_spec.rb` | const_set tmpdir (L15-21) | idem (défaut) |
| `spec/services/git_ledger_service_spec.rb` — « commits to the REAL repository when GIT_LEDGER_REAL == true » (L58-81) | const_set tmpdir | rétablit le défaut (L81-82) |
| `scripts/test_git_ledger.rb` | const_set tmpdir | — |
| CI — serveur E2E du job `e2e` (L370-376) | `GIT_LEDGER_PATH=${RUNNER_TEMP}/cra-ledger` **au boot du serveur** → const résolu à l'éphémère | n/a (runner jeté) |
| bin/e2e local (scripts shell) | **aucun** — réel délibéré via le contexte **dév** du serveur local (17/09, D-12) | n/a |

---

## 4. Reachability (qualifiée)

| Chemin | Défaut atteignable ? | Qualification |
|---|---|---|
| Dev-env (runner/serveur/web-dev) | réel **sans aucun contrôle** en mode dev ⇒ « runs erronés » (classe fc08::014) | **démontré** — preuve historique : 13/23 commits (#24) |
| Test + `GIT_LEDGER_REAL='true'` sans overlay | le spéc-writer oubliant l'overlay écrirait le réel (aucun écrivain actuel sans overlay — 4/4 vérifiés) | mécanique **démontrée** au code (pas d'interdiction) ; occurrence réelle **historique** (7 payloads 22/09) = **inférée** (mécanisme exact non établi) |
| Test + absent → fake | INV-D12-01 tenu | démontré (spec'd) |
| Prod / E2E local | réel par design | légitime (D-12) |

**Bilan** : deux chemins de défaut **atteignables et démontrés au mécanisme** (dev fails-open · test sans
enforcement d'overlay) — c'est la base factuelle d'une prévention **viable** ; l'arbitrage reste souverain
(O-1 / O-2 / O-0).

---

## 5. Protections existantes — activation / limites

| # | Protection | Activation | Limite / observation |
|---|---|---|---|
| 1 | Garde fake (L37) | `Rails.env.test?` + `GIT_LEDGER_REAL != 'true'` | **fail-open en dév** (le `&&`) ; couvre uniquement le test |
| 2 | INV-D12-01 (spec) | suite complète | épine le fake **nominal** — n'épine **pas** « réel ⇒ overlay » (INV-D12-03 absente) |
| 3 | Overlay (const_set / env-au-boot) | convention W3, appliquée par les écrivains | **aucun enforcement** ; teardowns replaçant le **défaut** (et non la valeur précédente) — latent mineur |
| 4 | `history_rewritten?` (L148-157) | chaque `perform_commit` | vérifie **uniquement** `denyNonFastForwards` (config) — **pas** l'intégrité réelle de l'historique (claim configurationnel) |
| 5 | `denyNonFastForwards = true` (L116) | re-config à chaque create_commit | push-side seulement ; repo local sans remote — portée pratique limitée |
| 6 | `cleanup!` garde production (L50) | `Rails.env.production? && !force` | protège prod ; **n'interdit rien en dev** (voie O-B #24 — certifiée) |
| 7 | `SAFE_ID_PATTERN` (D-5, L23) | chaque lookup | injection-grep safe — orthogonal au sujet d'overlay |

---

## 5.1 RED déterministe (proposition — post-arbitrage uniquement)

**Scénario INV-D12-03** (spec/runner, `Rails.env=test`, **sans modifier le réel**) :
1. `ENV['GIT_LEDGER_REAL'] = 'true'` (stub) + `LEDGER_PATH` = défaut (réel, **existant** — `ensure_initialized!`
   no-op) + `cra` **invalide** (non-soumis).
2. `GitLedgerService.commit_cra_lock!(cra)` :
   - **Pré-fix (RED)** : garde absente → `validate_cra!` échoue (CRA invalide) → `GitLedgerError('Git Ledger
     commit failed…')` — l'assertion du **message** (`'Real ledger without overlay…'`) échoue — **aucune
     écriture git** (l'échec précède tout write) ;
   - **Post-fix (GREEN)** : la garde lève `GitLedgerError('Real ledger without overlay (INV-D12-03)')`
     **avant** tout git call — assertion passée ;
3. invariant vérifié en lecture : `GitLedgerRepository.info[:commit_count]` **inchangé** avant/après.
**Déterminisme** : message exact + compteur de commits lu (pas de timing ni de mock fragiles).

---

## 6. Suivi des sujets (traités / non traités / arbitrage)

| # | Sujet | Statut | Traité ou non ? | Où |
|---|---|---|---|---|
| T1 | Cadrage #28 (contrat / reachability / protections / RED / options) | ✅ fait (2026-10-03) | fait (ce doc) | BACKLOG #28 (row formalisée) |
| T2 | **Arbitrage : O-1bis GO conditionnel** (l'isolation d'abord, puis la garde) | ✅ fait (2026-10-03) | traité | arbitrage CTO |
| T3 | **RED re-joué ×2** (seeds 60736/8777) : got « Git Ledger commit failed: CRA must be locked » — échec AVANT toute écriture Git, compteur du ledger inchangé | ✅ fait | traité | commit eb787c01 + sorties |
| T4 | Isolation (O-1bis étapes 1-3) : migration stub_const ×6 sites (service-spec ×4, integration, system, cra_contracts) + suppression des teardowns eigenclass + « GitLedgerRepository.ledger_path » (l'access eigenclass-compatible) + gardes W3-D2 alignées (les messages INV) + retrait de « cleanup!(force:) » de l'after d'intégration (le ledger réel n'est plus touché) | ✅ fait | traité | specs migrées (4 fichiers) + repository/service |
| T5 | La garde fail-fast (en tête de branche réelle, avant validate_cra!) : refus du défaut via ledger_path | ✅ fait | traité | git_ledger_service.rb |
| T6 | **GREEN ×2 + suite 1137/0** (seed 64208 — 86,33/60,94 · verrou 72,5) + battery ledger **72/0** + RuboCop 247/0 + Brakeman 0 + Zeitwerk OK + ledger réel inchangé (1 commit) | ✅ fait | traité | gates |
| T7 | `[DONE]_` + BACKLOG #28 close + fc08::020 proposée | ✅ fait | traité | BACKLOG/doc |
| T8 | Merge + réindexation hub + verification Chroma de fc08::020 | ⬜ post-merge | — | hub |

**Découvertes d'implémentation (journal T4)** :
1. **L'overlay singleton_class.const_set est INERTE pour les lectures externes** `GitLedgerRepository::LEDGER_PATH`
   (la table d'éigenclass n'est pas consultée par le lookup Module::CONST — probe : eigen tmp, module défaut) —
   MAIS **visible depuis les méthodes du module** (class << self : run_git/info/cleanup — le probe method = tmp ;
   le run intégration 13/0 laissé le ledger réel inchangé : les écrits sont allés au tmpdir) ;
2. **`stub_const` (rspec-mocks) remplace la table réelle du module** — restauré automatiquement : l'isolation
   devient effective ET visible par la méthode « ledger_path » (couplage cohérent avec les git-calls) ;
3. Les teardowns eigenclass (« const_set(:LEDGER_PATH, défaut) ») fuyaient un const eigen persistant —
   supprimés (la restauration = stub_const) ;
4. La spec statique p6_1 interdit les backticks dans git_ledger_repository.rb — commentaire de « ledger_path »
   réécrit sans backticks ;
5. Le fichier repository : la seule addition = la méthode « ledger_path » (12 lignes) — INV-D12-02/purge/ensure
   **non touchés** (purge #24 certifiée intacte).

---

## 7. Options (arbitrage CTO)

| Option | Portée | Trade-off |
|---|---|---|
| **O-1 — Prévention structurelle** (garde `INV-D12-03` fail-fast dans `commit_cra_lock!` + spec de contrat) | ~8 lignes service + 1 spec RED→GREEN ; dev/prod inchangés ; **purge #24 non touchée** | enforcement réel de la règle D-12 ; fail-fast doit laisser passer les overlays légitimes (2 mécaniques, vérifiées) |
| **O-2 — Documentation exécutable seule** (INV-D12-03 en spec de support sans garde) | 1 spec | zéro code de prod ; mais le défaut reste atteignable (pas de prévention effective) — semi-statut |
| **O-0 — Statu quo tracé** | doc uniquement | recevable (vos garde-fous) si vous jugez le risque résiduel accepté (dev fails-open restant assumé) |

---

## 8. Références

- `app/services/git_ledger_service.rb` L33-48 (garde/légende)
- `app/services/git_ledger_repository.rb` L13-23 (constantes/SAFE_ID), L43-55 (ensure/cleanup + garde),
  L112-157 (identité/commit/history_rewritten?)
- Écrivains (overlay) : `spec/system/cra_lifecycle_system_spec.rb` L21-52 · `spec/integration/git_ledger_integration_spec.rb`
  L15-21 · `spec/services/git_ledger_service_spec.rb` L58-81 · `scripts/test_git_ledger.rb` ·
  `.github/workflows/ci.yml` L370-376
- Preuves historiques : audit `[DONE]_2026_09_28_24_ledger_provenance_investigation.md` (23/23 · §3 · §5.1) ·
  mémoire fc08::014 (incident) · D-12 chiffrage/changer
- Suivi : `memory/suivi-implementation.md` (`suivi_impl::001`) · BACKLOG #28

---

**Document créé le :** 2026-10-03
**Propriétaire :** Équipe technique Foresy
*Préfixe `[DONE]_` à appliquer à l'issue de l'arbitrage (option retenue) + éventuelle implémentation (T3-T6).*