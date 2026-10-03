# 🔍 Investigation #24 — Ledger `cra-ledger` : provenance des 21 commits réels, impact, options de traitement

**Date :** 28 septembre 2026 (horodatage git-clock hôte — cf. écart de datation tracé au tracker #26 §4)
**Auteur :** Zed Agent (BACKLOG **#24** — « Qualification ledger réel », création 26/09, GO CTO)
**Statut :** ✅ **Investigation + traitement traité et certifié (2026-10-03)** — réconciliation VALIDÉE CTO
(23 SHA → 23 lignes, §3 · S-9 comptage écart expliqué) → arbitrage O-B GO → **purge exécutée via le
mécanisme supporté** (`cleanup!` dev-only → re-init : 23 → 1 commit) → vérifications complètes §5.1 →
**#24 CLOSED** · suivi d'avancement : §6
**Périmètre :** dépôt local `cra-ledger/` (LEDGER_PATH du développement) · `git_ledger_repository.rb` ·
`git_ledger_service.rb` · écrivains `GIT_LEDGER_REAL` (scripts, specs, CI) · corrélations temporelles avec
les sessions du dépôt principal.

---

## 1. Conclusion en une page

| Question | Réponse démontrée |
|---|---|
| **Combien** | **23 commits** (initial + 22 verrouillages) — `git rev-list --count` = 23 (compté 28/09). *Le chiffrage « 21 » des artefacts antérieurs (fc08::014/015, docs #21) = comptage d'antériorité pris **entre** les deux runs erronés du 26/09 — les 2 commits du run isolation (18:50:52/54) sont venus après. Écart d'antériorité tracé, artefacts non réécrits (S-9§6)* |
| **Quoi** | 23 payloads `cra_<uuid>_<mois>_<année>.json` — **toutes des données de test** : descriptions E2E explicites (17/09) ou Faker (22/09, 26/09), user_id de spec (3097/3098 · 12795-13582 · 7184-7745), mois/années de fabrique y compris **2038/2039** (hors bornes service → CRAs créés **directement par fabrique** dans certaines specs) |
| **Production affectée ?** | **Non** — le ledger de production est celui de l'instance Render (path propre, jamais poussé) ; la CI redirige le vrai ledger vers `RUNNER_TEMP` (éphémère, ci.yml L376) ; le repo local est l'unique touché |
| **Origine** | **26/09 : 13/13 commits PROUVÉS issus des runs en mauvais service** (5 par croisement cra_id ↔ valeurs `got:` des échecs · 8 par fenêtre temporelle + marqueurs Faker ; mécanisme : `Rails.env.test?` faux ⇒ le `&&` de la garde court-circuite **avant** le stub ENV → chemin réel pour toute spec verrouillant) · **17/09 : 3 = E2E délibérés** (payloads « E2E Test CRA » — D-12 « preuve du vrai commit ») · **22/09 : 7 commits Faker — specs en mode réel SANS overlay** (session P7-D1 12:20-12:30 CEST — inférence de session, mécanisme non établi) · **réconciliation intégrale §3 (23 SHA → 23 lignes)** |
| **Traitement** | **Arbitrage en attente** — options O-A/O-B/O-C §5 ; `cleanup!` du service est une voie supportée (refusé en production sans force, L50) |

---

## 2. Phase 1 — Faits (structure du repo et mécanismes d'écriture)

1. **Inventaire** : 23 commits — `Initial commit` (17/09 09:46:28 UTC, `create_gitignore` L119-124) + 22 `CRA locked — cra:<uuid> — mois/année`. Suffixe = `<month>/<year>` de la payload : **9/2026 (×10) · 1/2026 (×2) · 2/2026 (×3) · 5/2038 (×1) · 11/2038 (×1) · 12/2038 (×1) · 1/2039 (×1) · 2/2039 (×1) · 3/2039 (×1) · 5/2039 (×1)** → somme 22 ✓ ; **années de fabrique 2038/2039** (hors bornes du service 2000-2031) → CRAs créés directement par fabrique dans certaines specs.
2. **Identité** : `user.name = foresy-ledger`, `email = ledger@foresy.internal` (`configure_identity`, L112-117) — aucune empreinte humaine (attendu).
3. **Immutabilité proclamée** : `receive.denyNonFastForwards = true` + garde `history_rewritten?` (Vérification : **le garde contrôle le flag de config, pas l'historique réel** — observation factuelle : la « protection » est configurationnelle, pas cryptographique).
4. **Working tree « sale » par design** : 22 payload files ` D` (delete-after-commit : `perform_commit` écrit le payload, force-add (`gitignore` exclut `cra_*.json`), commit, puis `File.delete` L144 — le payload reste dans l'historique mais disparaît du worktree ; les suppressions ne sont jamais commitées). Comportement **préexistant**, non lié à #26.
5. **Payloads échantillonnés** (origine aux marqueurs) :
   - 17/09 — `E2E Test CRA for September`, entries « E2E Entry A/B - Mission A/B », `created_by_user_id: 3097` → **données E2E scriptées, volontaires** (D-12) ;
   - 22/09 — « Quas commodi quia… » (Faker), `created_by_user_id: 12795`, 0 entries ;
   - 26/09 — « Dolorem quis ipsam… » (Faker), `created_by_user_id: 7278`, 0 entries.
6. **Écrivains du mode réel** : `ENV['GIT_LEDGER_REAL'] == 'true'` (L37) — écrivains identifiés : **serveur E2E de CI** (ci.yml L372: `GIT_LEDGER_REAL: 'true'` au niveau step + **`GIT_LEDGER_PATH` redirigé vers `RUNNER_TEMP/cra-ledger`** — ledger CI éphémère, le repo local jamais touché par la CI, INV-D12-01 explicité au niveau step) · **scripts E2E locaux** (`bin/e2e/*.sh`, légitimes par design D-12) · **specs à overlay tmpdir** (`cra_lifecycle_system_spec`, `git_ledger_integration_spec`, `scripts/test_git_ledger.rb`) · **runs hors-environnement** (Rails.env ≠ test ⇒ garde contournée — la cause du 26/09).

## 3. Phase 2 — Origine, commit par commit (réconciliation intégrale : 23 SHA → 23 lignes → 23 qualifications)

**Comptage définitif : 23** (`git rev-list --count` = 23, mesuré 28/09) — clusters : **13 (26/09) + 7 (22/09) + 3 (17/09, dont l'initial) = 23 ✓**. Le chiffrage « 21 » des artefacts antérieurs (fc08::014/015, docs #21) = comptage d'antériorité pris **entre** les deux runs erronés (les 2 commits isolation de 18:50-51 sont venus après — sans impact sur l'attribution, cf. S-9 §6).

| # | SHA | Date/heure (UTC) | cra_id — mois/année | Payload (marqueur / user_id) | Origine | Preuve |
|---|---|---|---|---|---|---|
| 1 | `6f79453` | 17/09 09:46:28 | — (initial) | — | auto-init du service (D-12) | `create_gitignore` L119-124 |
| 2 | `9341375` | 17/09 09:46:28 | f708b91b — 9/2026 | **E2E** — entries E2E A/B — user_id 3097 | **E2E délibéré** (D-12) | payload + session « preuve du vrai commit D12.3/D12.4 » |
| 3 | `ec04033` | 17/09 09:49:31 | 66dfc259 — 9/2026 | **E2E** idem — user_id 3098 | **E2E délibéré** (D-12 — rejoué ×2) | idem |
| 4 | `37b286b` | 22/09 10:20:29 | d815bed3 — 9/2026 | Faker — user_id 12795 | specs mode réel **sans overlay** (session P7-D1) — inférence | fenêtre 12:20-12:30 CEST + commit `0b780c75` 12:39 (« specs système avec Git Ledger réel ») |
| 5 | `ecbd80b` | 22/09 10:20:30 | 29455217 — 9/2026 | Faker — user_id 12796 | idem | idem |
| 6 | `0f7d600` | 22/09 10:27:56 | aa9b8900 — 1/2026 | Faker — user_id 13525 | idem | idem |
| 7 | `f5b6c9c` | 22/09 10:28:06 | 3b314e11 — 2/2026 | Faker — user_id 13540 | idem | idem |
| 8 | `2e27e2f` | 22/09 10:29:43 | e4e83c79 — 9/2026 | Faker — user_id 13554 | idem | idem |
| 9 | `bb7fc63` | 22/09 10:29:44 | ed10cbad — 9/2026 | Faker — user_id 13555 | idem | idem |
| 10 | `e091efe` | 22/09 10:30:03 | a0fb8a23 — 2/2026 | Faker — user_id 13582 | idem | idem |
| 11 | `4abaa9d` | 26/09 18:40:06 | 02be46b8 — 1/2026 | Faker — user_id 7184 | **run dev-env du close-out #26 (run plein)** | fenêtre du run (démarré ~18:38 UTC, 8 min 11 s) |
| 12 | `067427f` | 26/09 18:41:04 | 629574f0 — 2/2026 | Faker — user_id 7278 | **idem — PROUVÉ** | cra:629574f0 = échec #1 (`cra_contracts_spec:143`, `got: 067427f2…`) |
| 13 | `03efd78` | 26/09 18:44:21 | 5bc2f4f9 — 9/2026 | Faker — user_id 7574 | **idem — PROUVÉ** | échec #2 (`git_ledger_service_spec:40`, `got: 03efd784…`) |
| 14 | `aa7f901` | 26/09 18:44:24 | 890586f7 — 9/2026 | Faker — user_id 7576 | **idem — PROUVÉ** | échec #3 (`git_ledger_service_spec:48`, `got: aa7f901a…`) |
| 15 | `8429172` | 26/09 18:44:58 | 87f1dfe1 — 5/2038 | Faker — user_id 7622 | run plein — écrit réel **silencieux** (spec verrouille sans assertion du hash fake) | fenêtre du run |
| 16 | `ac24554` | 26/09 18:45:02 | 2926d0eb — 11/2038 | Faker — user_id 7630 | idem | idem |
| 17 | `a3e46bc` | 26/09 18:45:04 | 56536003 — 12/2038 | Faker — user_id 7631 | idem | idem |
| 18 | `4aad7ec` | 26/09 18:45:05 | 3f6d97f2 — 1/2039 | Faker — user_id 7632 | idem | idem |
| 19 | `152dd21` | 26/09 18:45:06 | 211d5374 — 2/2039 | Faker — user_id 7633 | idem | idem |
| 20 | `a892d59` | 26/09 18:45:07 | 5a52893b — 3/2039 | Faker — user_id 7634 | idem | idem |
| 21 | `5eb00cc` | 26/09 18:45:08 | f70138fd — 5/2039 | Faker — user_id 7636 | idem | idem |
| 22 | `ebdc7f2` | 26/09 18:50:52 | 45c27da1 — 9/2026 | Faker — user_id 7743 | **run isolation (dev-env) — PROUVÉ** | échec isolation #1 (`got: ebdc7f23…`) |
| 23 | `b1eb2f0` | 26/09 18:50:54 | 315b2afc — 9/2026 | Faker — user_id 7745 | **idem — PROUVÉ** | échec isolation #2 (`got: b1eb2f0f…`) |

**Bilan réconcilié** : **13 + 7 + 3 = 23 ✓** (1 initial + 22 verrouillages) ·
**13 prouvé(s)** (26/09 : 5 par croisement cra_id ↔ `got:` + 8 par fenêtre/marqueurs — tous des runs du close-out #26 en service dév · **0 commit E2E légitime ce jour**) · **2+1 délibérés** (17/09 : 2 verrouillages E2E + initial) · **7 inférés** (22/09 — session P7, mécanisme de l'overlay manquant non établi) ·
toutes données de test (E2E/Faker), **zéro donnée de production**.

**Mécanisme du court-circuit — complet (clôture la boucle de l'incident fc08::014)** : dans le run dév,
`Rails.env.test?` = faux → le `&&` de la garde (L37) court-circuite **avant** de lire `ENV['GIT_LEDGER_REAL']`
→ les stubs ENV des specs sont inopérants → **toute** spec verrouillant un CRA écrit en réel : 3 avec
assertion du hash fake ⇒ les 3 échecs observés ; les autres (lignes 11, 15-21) ⇒ 8 écrits réels silencieux.

## 4. Phase 3 — Impact

| Axe | Constat |
|---|---|
| Production | **Non affecté** : ledger Render distinct ; CI = ledger éphémère `RUNNER_TEMP` ; aucune configuration de remote sur le repo local (`git remote -v` vide) — l'historique est **strictement local** |
| Ledger de DEV | Historique contient 20 verrouillages de données de test (et l'invariant « immutabilité légale » rend le journal **trompeur** en tant que registre d'exemple, mais il n'est pas consommé par un système légal en dev) |
| Fonctionnel | Aucun impact courant — les tests utilisent le chemin fake par défaut ; `cra_already_committed?` ne peut collide que pour des cra_id identiques (test-id uniquement) |
| Hygiène | Working tree sale « by design » (delete-after-commit, `.gitignore` exclut les payloads) ; `cleanup!` = mécanisme supporté (`rm_rf` + re-init au prochain usage), **refusé en production sans `force: true`** (L50) — voie de nettoyage naturelle côté dev |
| Récurrence | **Ouverte tant que** les runs dev-env (mauvais service) restent possibles — cause racine = commande canonique du BRIEFING (**BACKLOG #25**) + aucune interdiction matérielle de `GIT_LEDGER_REAL=true` pour un test RSpec contre `LEDGER_PATH` par défaut |

## 5. Phase 4 — Options de traitement (arbitrage CTO — RENDU 26/09)

> **Arbitrage CTO (26/09, traitement)** : **O-B GO** — purge locale du ledger de développement via le
> **mécanisme supporté uniquement** (`GitLedgerRepository.cleanup!`, refusé en production sans `force:`)
> · **O-C hors périmètre** (prévention structurelle = sujet distinct, RED/contrat propres si ouverte — #28
> potentiel ; #25 = cause contributive, ne pas fusionner) · **O-A statu quo** = devenu non pertinent en
> tant qu'option (n'existe que comme éventuel statut documenté si décision contraire) · **réécriture Git**
> (rebase/filter-branch/suppression manuelle des 23 commits) : **NO GO** — la décision porte sur le
> **contenu du ledger de développement**, pas sur l'historique Git. S-1/S-9 **VALIDÉS** (réconciliation
> intégrale + écart de comptage S-9), S-2 reste **INFÉRÉ** (ne pas surqualifier), S-7/S-8 **hors
> blocage #24**, S-6 → conditionné à un GO séparé (#28 potentiel).

| Option | Description | Trade-off |
|---|---|---|
| **O-A — Statu quo tracé** | Le journal test-data reste (repo local sans remote, usage dev) ; le tracker #24 sert de trace d'origine | aucun risque ; « immutabilité » locale continue de contenir du bruit |
| **O-B — Purge locale via le mécanisme supporté** (dev only) : `GitLedgerRepository.cleanup!` en environnement développement → `rm_rf` + re-init au prochain usage | ledger local propre (initial commit seulement) ; mécanisme natif du service (L50-55) | perte de l'historique local (données de test — **valeur légale nulle établie**) ; n'affecte ni Render ni CI |
| **O-C — Prévention structurelle** (chantier séparé, contrat/RED) : interdi­re matériellement le mode réel des specs contre le LEDGER_PATH par défaut (ex. garde spec-level : `GIT_LEDGER_REAL=true` ⇒ `GIT_LEDGER_PATH` **doit** être overlay) + **#25** (commande BRIEFING correcte) | élimine la cause racine des 26/09 | chantier distinct, arbitrage séparé |

### 5.1 Exécution O-B — journal (traitement effectif)

| # | Événement | Horodatage | Source |
|---|---|---|---|
| J16 | Purge exécutée via le mécanisme supporté, runner dev : `GitLedgerRepository.cleanup!` → `ensure_initialized!` — avant : **23 commits** (dernier `b1eb2f0`, 26/09 18:50:54 UTC) / après : **1 commit** — `Initial commit` `141fa4e` **(Git ledger : 2026-10-03 06:03:13 +0000)** | git + session | Git (ledger) + Session |
| J17 | Vérification hôte : `cra-ledger/` = `.git` + `.gitignore` (40 o) · `git log` = 1 commit (`141fa4e`) · `receive.denyNonFastForwards` = **true** (restauré par `configure_identity`) · **working tree propre** (plus de payloads à supprimer — état contractualisé delete-after-commit vierge) | 2026-10-03 (host clock) | Session (sorties outils) |
| J18 | Specs du ledger (contrôles concernés) : 6 fichiers — **69 examples, 0 failure** (seed 31064), dont race14 contractuel GREEN ; warnings `unknown OID 2278` bénins | Session | Session (sorties outils) |
| J19 | Production / CI : **à l'écart par construction** — aucune écriture vers Render (ledger distinct) · CI = ledger éphémère `RUNNER_TEMP` · repo local sans remote · **zéro réécriture Git** (l'« historique » du ledger de dev est remplacé par mécanisme natif, conformément à la décision) | Git + Session | Session (CTO arbitrage + sorties) |

**Resultat** : ledger de développement purgé et réinitialisé proprement par le mécanisme supporté
(`cleanup!` dev-only, garde production L50) — **aucune donnée de production touchée** · working tree
conforme au comportement contractuel · contrôles verts · **zéro réécriture d'historique Git**.

---

## 6. Suivi d'avancement des sujets (traités / non traités)

| # | Sujet émis par cette investigation | Statut | Traité ou non ? | Suivi / vit où |
|---|---|---|---|---|
| S-1 | **Origine des 23 commits** (26/09 : 13 runs erronés · 17/09 : 3 E2E délibérés/initial · 22/09 : 7 inférés) | ✅ **VALIDÉE CTO (26/09)** — réconciliation intégrale (23 SHA → 23 lignes, §3) | Réconciliation validée — le traitement reste à exécuter | ce document · BACKLOG #24 |
| S-2 | **Mécanisme exact du 22/09** (overlay absent dans les itérations P7-D1 ?) | 🔎 **inference, non établie** | **Non traité** — investigation complémentaire *optionnelle*, ouverte à la demande CTO seulement | — |
| S-3 | **Traitement du journal** (**O-B exécuté via `cleanup!` + re-init**) | ✅ **traité** (§5.1 : 23 → 1 commit `141fa4e`, vérifications complètes, specs 69/0) | Traitement exécuté le 2026-10-03 par le mécanisme supporté — **zéro réécriture Git** | BACKLOG #24 (close) · §5.1 |
| S-4 | **Impact** (production / CI / fonctionnel — local uniquement) | ✅ **démontré** (§4) | Constat livré — aucun traitement requis | ce document · BACKLOG #24 |
| S-5 | **Récurrence — cause racine** (commande BRIEFING erronée · aucune interdiction matérielle du mode réel en specs) | ⬜ **Non traité** | **#25 ouvert** (passe doc dédiée) · prévention éventuelle si O-C retenu | BACKLOG #25 · mémoire fc08::014 |
| S-6 | **Prévention structurelle** (garde spec-level : `GIT_LEDGER_REAL=true` ⇒ overlay obligatoire) | ⬜ **hors périmètre #24** (O-C séparé) | conditionné à un GO séparé — ticket #28 potentiel | — (ouvert séparément si retenu) |
| S-7 | **Amendement fc08::016** (ligne « Livraison » + chemins `[DONE]_`) — **non bloquant pour #24** | ⚔️ **en attente validation CTO** | proposé 26/09 — PR `docs/memory-016-livraison` (`9fc382a0`) | hub (après merge) |
| S-8 | **Écart de datation 26/09 ↔ 28/09** — **non bloquant pour #24** | 🟡 **maintenu tel quel** (décision CTO 26/09 — déjà tracé au tracker #26 §4) | Pas d'action pour l'instant | tracker #26 · ce doc (en-tête) |
| S-9 | **Comptage « 21 » des artefacts antérieurs vs 23 final** (fc08::014/015, docs #21) | ✅ **VALIDÉ CTO (26/09)** | Écart d'antériorité expliqué (2 commits du run isolation post-comptage) — artefacts non réécrits ; aucun traitement requis | ce doc (§1/§3/§6) |

Mise à jour de cette table à chaque **état substantiel** (règle anti-drift, BACKLOG).

**Certification (2026-10-03)** : O-B exécuté (§5.1) · S-1/S-9 validés · S-3 traité · préfixe `[DONE]_` appliqué
· **#24 CLOSED** · récurrence restant prévenue par #25 et éventuellement #28 (hors périmètre).

---

## 7. Méthodologie (lecture seule)

1. `git log` intégral du repo `cra-ledger` (métadonnées author/committer/dates/messages) + `--stat` sur échantillons.
2. Lecture du code d'écriture (`git_ledger_repository.rb` L50-196 : gitignore/force-add/delete-after-commit,
   `denyNonFastForwards`, garde `history_rewritten?`, `cleanup!` avec garde production, `SAFE_ID_PATTERN`).
3. Payloads échantillonnés (17/09 · 22/09 · 26/09) — marqueurs E2E/Faker + `created_by_user_id`.
4. Recensement des écrivains `GIT_LEDGER_REAL` (specs à overlay, serveur E2E CI avec `RUNNER_TEMP`,
   scripts E2E) + corrélations temporelles avec les commits du dépôt principal.
5. Aucune exécution d'écriture, aucun nettoyage, aucun rebase — **verrou respecté**.
6. **Réconciliation intégrale** (28/09) : `git rev-list --count` (= 23) + `git log -p` extraction des
   marqueurs payload SHA par SHA (descriptions + `created_by_user_id`) → table §3.

## 8. Références

- `cra-ledger/.git/config` (identité, `denyNonFastForwards`, **pas de remote**) · `git log` 23 commits (réconciliation §3)
- `app/services/git_ledger_repository.rb` L50-196 · `app/services/git_ledger_service.rb` L35-40 (guard)
- `.github/workflows/ci.yml` L370-376 (`GIT_LEDGER_REAL=true` + `GIT_LEDGER_PATH=${RUNNER_TEMP}/cra-ledger`), L419, L432-434
- `scripts/test_git_ledger.rb` (pattern overlay tmpdir) · `bin/e2e/*` (scripts D-12)
- mémoire fc08::014 (incident dev-service) · fc08::015 · audit `[DONE]_2026_09_26_19_p0_reachability_investigation.md` · BACKLOG #24

---

**Document créé le :** 28 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Préfixe `[DONE]_` à appliquer à l'issue de l'arbitrage CTO (traitement du ledger).*