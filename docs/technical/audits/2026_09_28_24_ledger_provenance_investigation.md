# 🔍 Investigation #24 — Ledger `cra-ledger` : provenance des 21 commits réels, impact, options de traitement

**Date :** 28 septembre 2026 (horodatage git-clock hôte — cf. écart de datation tracé au tracker #26 §4)
**Auteur :** Zed Agent (BACKLOG **#24** — « Qualification ledger réel », création 26/09, GO CTO)
**Statut :** ✅ Investigation terminée — **lecture seule, aucune modification** — provenance démontrée
commit par commit → arbitrage de traitement **en attente CTO** (verrou : aucun nettoyage/rebase/
filter-branch/réécriture avant arbitrage) · **suivi d'avancement des sujets : §6** (traité / non traité)
**Périmètre :** dépôt local `cra-ledger/` (LEDGER_PATH du développement) · `git_ledger_repository.rb` ·
`git_ledger_service.rb` · écrivains `GIT_LEDGER_REAL` (scripts, specs, CI) · corrélations temporelles avec
les sessions du dépôt principal.

---

## 1. Conclusion en une page

| Question | Réponse démontrée |
|---|---|
| **Combien** | **21 commits** (initial + 20 verrouillages) — identité uniforme `foresy-ledger <ledger@foresy.internal>`, branche `main`, **aucun remote** (historique local uniquement) |
| **Quoi** | 21 payloads `cra_<uuid>_<mois>_<année>.json` — **toutes des données de test** : descriptions E2E explicites (17/09) ou Faker (22/09, 26/09), user_id de spec (3097 · 12795 · 7278…), mois/années de fabrique y compris 2038/2039 (hors bornes service → CRAs créés **directement par fabrique** dans certaines specs) |
| **Production affectée ?** | **Non** — le ledger de production est celui de l'instance Render (path propre, jamais poussé) ; la CI redirige le vrai ledger vers `RUNNER_TEMP` (éphémère, ci.yml L376) ; le repo local est l'unique touché |
| **Origine** | **26/09 : 13/13 commits PROUVÉS issus des runs en mauvais service** (croisement cra_id ↔ valeurs `got:` des échecs + fenêtres temporelles : plein run 18:40-18:45 UTC = 11, isolation 18:50-18:51 = 2) · **17/09 : E2E délibérés** (payloads « E2E Test CRA » — day D-12 « preuve du vrai commit ») · **22/09 : 7 commits Faker — specs en mode réel SANS overlay** (session P7-D1 12:20-12:30 CEST — inférence de session, mécanisme précis non établi) |
| **Traitement** | **Arbitrage en attente** — options O-A/O-B/O-C §5 ; `cleanup!` du service est une voie supportée (refusé en production sans force, L50) |

---

## 2. Phase 1 — Faits (structure du repo et mécanismes d'écriture)

1. **Inventaire** : 21 commits — `Initial commit` (17/09 09:46:28 UTC) + 20 `CRA locked — cra:<uuid> — mois/année`. Suffixe = `<month>/<year>` de la payload : 9/2026 (×12), 1-2/2026 (×4), 5/2038 (×1), 11-12/2038 (×2), 1-3/2039 (×4), 5/2039 (×1) → **années de fabrique 2038/2039** (hors bornes du service 2000-2031) → CRAs de fabrique.
2. **Identité** : `user.name = foresy-ledger`, `email = ledger@foresy.internal` (`configure_identity`, L112-117) — aucune empreinte humaine (attendu).
3. **Immutabilité proclamée** : `receive.denyNonFastForwards = true` + garde `history_rewritten?` (Vérification : **le garde contrôle le flag de config, pas l'historique réel** — observation factuelle : la « protection » est configurationnelle, pas cryptographique).
4. **Working tree « sale » par design** : 22 payload files ` D` (delete-after-commit : `perform_commit` écrit le payload, force-add (`gitignore` exclut `cra_*.json`), commit, puis `File.delete` L144 — le payload reste dans l'historique mais disparaît du worktree ; les suppressions ne sont jamais commitées). Comportement **préexistant**, non lié à #26.
5. **Payloads échantillonnés** (origine aux marqueurs) :
   - 17/09 — `E2E Test CRA for September`, entries « E2E Entry A/B - Mission A/B », `created_by_user_id: 3097` → **données E2E scriptées, volontaires** (D-12) ;
   - 22/09 — « Quas commodi quia… » (Faker), `created_by_user_id: 12795`, 0 entries ;
   - 26/09 — « Dolorem quis ipsam… » (Faker), `created_by_user_id: 7278`, 0 entries.
6. **Écrivains du mode réel** : `ENV['GIT_LEDGER_REAL'] == 'true'` (L37) — écrivains identifiés : **serveur E2E de CI** (ci.yml L372: `GIT_LEDGER_REAL: 'true'` au niveau step + **`GIT_LEDGER_PATH` redirigé vers `RUNNER_TEMP/cra-ledger`** — ledger CI éphémère, le repo local jamais touché par la CI, INV-D12-01 explicité au niveau step) · **scripts E2E locaux** (`bin/e2e/*.sh`, légitimes par design D-12) · **specs à overlay tmpdir** (`cra_lifecycle_system_spec`, `git_ledger_integration_spec`, `scripts/test_git_ledger.rb`) · **runs hors-environnement** (Rails.env ≠ test ⇒ garde contournée — la cause du 26/09).

## 3. Phase 2 — Origine, commit par commit

| Cluster | N | Fenêtre (UTC) | Origine | Preuve |
|---|---|---|---|---|
| **26/09** | **13** | 18:40:06-18:45:08 (×11) + 18:50:52-54 (×2) | **Prouvée — runs du close-out #26 en service dév** (RAILS_ENV=development ⇒ `Rails.env.test?` faux ⇒ guard court-circuité) | 5 cra_id = valeurs `got:` des échecs INV-D12-01 (`629574f0`→`067427f`, `5bc2f4f9`→`03efd78`, `890586f7`→`aa7f901`, `45c27da1`→`ebdc7f2`, `315b2afc`→`b1eb2f0`) + fenêtres exactes des 2 runs (8 min 11 s puis isolation ~2 min). Les 8 autres (11 commits du run plein) : specs verrouillant des CRAs de fabrique **sans assertion du hash fake** → écrits réels silencieux. **0 commit E2E légitime ce jour** (aucun commit avant 18:40 UTC) |
| **22/09** | 7 | 10:20:29-10:30:03 | **Mode réel sans overlay — session P7-D1** (inférence) | payload Faker/user_id de spec ; fenêtre 12:20-12:30 CEST collée à la session P7-D1 (commit `0b780c75` 12:39 : «2 specs système avec **Git Ledger réel**… overlay D-12») — les itérations de développement ont écrit le repo réel avant l'ordre final des specs ; mécanisme exact (absence d'overlay dans les itérations) **inféré** |
| **17/09** | 3 | 09:46-09:49 (+ Initial) | **E2E délibéré** (D-12) | payload « E2E Test CRA for September » + entries « E2E Entry A/B » ; corrélation session D-12 (« **preuve du vrai commit** en D12.3/D12.4 », commits du dépôt principal 10:17/10:26 CEST encadrant la fenêtre 11:46-11:49 CEST) |

**Bilan** : 13/21 commits = pollution de concurrence démontrée et **imputée** (runs erronés 26/09) ;
6/21 = usage E2E/réel **deliberé** (17/09 + 22/09 à confirmer 22/09) ; l'ensemble = données de test,
**zero donnée de production** (payloads Faker/E2E exclusivement).

## 4. Phase 3 — Impact

| Axe | Constat |
|---|---|
| Production | **Non affecté** : ledger Render distinct ; CI = ledger éphémère `RUNNER_TEMP` ; aucune configuration de remote sur le repo local (`git remote -v` vide) — l'historique est **strictement local** |
| Ledger de DEV | Historique contient 20 verrouillages de données de test (et l'invariant « immutabilité légale » rend le journal **trompeur** en tant que registre d'exemple, mais il n'est pas consommé par un système légal en dev) |
| Fonctionnel | Aucun impact courant — les tests utilisent le chemin fake par défaut ; `cra_already_committed?` ne peut collide que pour des cra_id identiques (test-id uniquement) |
| Hygiène | Working tree sale « by design » (delete-after-commit, `.gitignore` exclut les payloads) ; `cleanup!` = mécanisme supporté (`rm_rf` + re-init au prochain usage), **refusé en production sans `force: true`** (L50) — voie de nettoyage naturelle côté dev |
| Récurrence | **Ouverte tant que** les runs dev-env (mauvais service) restent possibles — cause racine = commande canonique du BRIEFING (**BACKLOG #25**) + aucune interdiction matérielle de `GIT_LEDGER_REAL=true` pour un test RSpec contre `LEDGER_PATH` par défaut |

## 5. Phase 4 — Options de traitement (arbitrage CTO en attente — **aucune exécutée**)

| Option | Description | Trade-off |
|---|---|---|
| **O-A — Statu quo tracé** | Le journal test-data reste (repo local sans remote, usage dev) ; le tracker #24 sert de trace d'origine | aucun risque ; « immutabilité » locale continue de contenir du bruit |
| **O-B — Purge locale via le mécanisme supporté** (dev only) : `GitLedgerRepository.cleanup!` en environnement développement → `rm_rf` + re-init au prochain usage | ledger local propre (initial commit seulement) ; mécanisme natif du service (L50-55) | perte de l'historique local (données de test — **valeur légale nulle établie**) ; n'affecte ni Render ni CI |
| **O-C — Prévention structurelle** (chantier séparé, contrat/RED) : interdi­re matériellement le mode réel des specs contre le LEDGER_PATH par défaut (ex. garde spec-level : `GIT_LEDGER_REAL=true` ⇒ `GIT_LEDGER_PATH` **doit** être overlay) + **#25** (commande BRIEFING correcte) | élimine la cause racine des 26/09 | chantier distinct, arbitrage séparé |

---

## 6. Suivi d'avancement des sujets (traités / non traités)

| # | Sujet émis par cette investigation | Statut | Traité ou non ? | Suivi / vit où |
|---|---|---|---|---|
| S-1 | **Origine des 21 commits** (26/09 : 13/13 prouvée · 17/09 E2E délibéré · 22/09 inférée) | ✅ **démontrée** (§3) | Constat livré — aucun traitement requis tant que l'arbitrage du traitement n'est pas rendu | ce document · BACKLOG #24 |
| S-2 | **Mécanisme exact du 22/09** (overlay absent dans les itérations P7-D1 ?) | 🔎 **inference, non établie** | **Non traité** — investigation complémentaire *optionnelle*, ouverte à la demande CTO seulement | — |
| S-3 | **Traitement du journal** (O-A statu quo / O-B purge `cleanup!` / O-C prévention) | ⬜ **Non traité** | **en attente arbitrage CTO** — verrou : zéro nettoyage avant GO | BACKLOG #24 (row) |
| S-4 | **Impact** (production / CI / fonctionnel — local uniquement) | ✅ **démontré** (§4) | Constat livré — aucun traitement requis | ce document · BACKLOG #24 |
| S-5 | **Récurrence — cause racine** (commande BRIEFING erronée · aucune interdiction matérielle du mode réel en specs) | ⬜ **Non traité** | **#25 ouvert** (passe doc dédiée) · prévention éventuelle si O-C retenu | BACKLOG #25 · mémoire fc08::014 |
| S-6 | **Prévention structurelle** (garde spec-level : `GIT_LEDGER_REAL=true` ⇒ overlay obligatoire) | ⬜ **Non ouvert** | conditionné à l'arbitrage (si O-C retenu) — ticket à créer après GO | — (potentiel #28) |
| S-7 | **Amendement fc08::016** (ligne « Livraison » + chemins `[DONE]_`) | ⚔️ **en attente validation CTO** | proposé 26/09 — PR `docs/memory-016-livraison` (`9fc382a0`) | hub (après merge) |
| S-8 | **Écart de datation 26/09 ↔ 28/09** | 🟡 **maintenu tel quel** (décision CTO 26/09 — déjà tracé au tracker #26 §4) | Pas d'action pour l'instant | tracker #26 · ce doc (en-tête) |

Mise à jour de cette table à chaque **état substantiel** (règle anti-drift, BACKLOG) ; le préfixe
`[DONE]_` sera appliqué à la clôture complète du chantier (traitement arbitré puis exécuté ou statu quo
acté — pas avant).

---

## 7. Méthodologie (lecture seule)

1. `git log` intégral du repo `cra-ledger` (métadonnées author/committer/dates/messages) + `--stat` sur échantillons.
2. Lecture du code d'écriture (`git_ledger_repository.rb` L50-196 : gitignore/force-add/delete-after-commit,
   `denyNonFastForwards`, garde `history_rewritten?`, `cleanup!` avec garde production, `SAFE_ID_PATTERN`).
3. Payloads échantillonnés (17/09 · 22/09 · 26/09) — marqueurs E2E/Faker + `created_by_user_id`.
4. Recensement des écrivains `GIT_LEDGER_REAL` (specs à overlay, serveur E2E CI avec `RUNNER_TEMP`,
   scripts E2E) + corrélations temporelles avec les commits du dépôt principal.
5. Aucune exécution d'écriture, aucun nettoyage, aucun rebase — **verrou respecté**.

## 8. Références

- `cra-ledger/.git/config` (identité, `denyNonFastForwards`, **pas de remote**) · `git log` 21 commits (§3)
- `app/services/git_ledger_repository.rb` L50-196 · `app/services/git_ledger_service.rb` L35-40 (guard)
- `.github/workflows/ci.yml` L370-376 (`GIT_LEDGER_REAL=true` + `GIT_LEDGER_PATH=${RUNNER_TEMP}/cra-ledger`), L419, L432-434
- `scripts/test_git_ledger.rb` (pattern overlay tmpdir) · `bin/e2e/*` (scripts D-12)
- mémoire fc08::014 (incident dev-service) · fc08::015 · audit `[DONE]_2026_09_26_19_p0_reachability_investigation.md` · BACKLOG #24

---

**Document créé le :** 28 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Préfixe `[DONE]_` à appliquer à l'issue de l'arbitrage CTO (traitement du ledger).*