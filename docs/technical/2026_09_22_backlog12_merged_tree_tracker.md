# BACKLOG #12 — Validation de l'arbre mergé — Tracker

**Chantier :** garantir que la CI valide l'arbre effectivement mergé, pas seulement le HEAD de chaque PR
**Décision CTO :** GO RED d'abord (22/09) — démontrer précisément ce que le pipeline actuel laisse passer **avant** de choisir le mécanisme. Aucune implémentation (merge_group / smoke / autre) sans ce RED.
**Prérequis atteint :** branch protection verrouillée (PR #43) — les 6 checks sont requis, administrateurs inclus.

---

## État des faits établis (pré-RED)

| Fait | Preuve | Conséquence |
|---|---|---|
| Push direct sur `main` impossible | Hook GH006 — « 6 of 6 required status checks are expected » (rejet réel du 22/09, commit docs refusé) | Le chemin « push direct sans CI » est **déjà fermé** — le gap résiduel n'est pas celui-là |
| Les 6 checks sont requis sur les PRs | `PUT protection` 200 · PR #43 : `blocked` pendant les checks, `clean` après 6/6 sur le SHA contrôlé | Le merge d'une PR exige sa CI verte |
| `strict: false` | Payload d'application (décision #11) | « Require branches to be up to date » est **off** — le base peut bouger entre le run CI et le merge |

## Hypothèses à démontrer (ou réfuter) — RED expérimental

### EXP-1 — Run #1 : évidence collectée (PR #45, probe)

| Champ | Valeur | Lecture |
|---|---|---|
| PR head sha | `5acb3840` | le head de la probe (A) |
| PR base sha | `cbfddb27` | main (X) |
| `GITHUB_SHA` | **`b396a976`** | **≠ head, ≠ base — le merge commit** |
| `GITHUB_REF` | **`refs/pull/45/merge`** | le merge ref |
| HEAD checkouté | `b396a976` | **= GITHUB_SHA — le checkout EST le merge result** |
| probe_marker.md | ABSENT | cohérent (X ne contient pas encore le marqueur) |

**Verdict H1 : RÉSOLU — la CI `pull_request` teste le résultat de fusion** (`base + head` au
moment du run). Le `head_sha` des check-runs (5acb3840) n'était que l'attribution d'affichage.

### EXP-1 — phase 2 (run #2 après synchronisation) — CERTIFIÉ

**Evidence brute (étape `EXP-1 evidence`, run 35741930487, SHA `a521ae09`) :**

```text
=== EXP-1 evidence (BACKLOG #12) ===
PR head sha : a521ae09cba06959aabcc69419ac7f5f7dd4a60e
PR base sha : cbfddb27fe31ff436e4ecf50e51bbbbc85a76962
GITHUB_SHA  : 8f32b7c64d1fa394fb5b1a3d1c30ab99a4db6d37
GITHUB_REF  : refs/pull/45/merge
HEAD checkouté : 8f32b7c64d1fa394fb5b1a3d1c30ab99a4db6d37
probe_marker.md : PRESENT
```

**Lecture factuelle :**

| Champ | Run #1 | Run #2 (synchronize) | Lecture |
|---|---|---|---|
| `GITHUB_SHA` | `b396a976` | **`8f32b7c6` — nouveau merge commit** | le merge ref a été **régénéré** |
| `HEAD checkouté` | `b396a976` | **`8f32b7c6` (= GITHUB_SHA)** | le checkout suit le merge ref régénéré |
| `probe_marker.md` | ABSENT | **PRESENT** | l'arbre testé contient le marqueur, qui n'existait **que sur la nouvelle base** (`95bcea6e`) |
| base déclarée dans l'event | `cbfddb27` | `cbfddb27` (stale) | **le `base.sha` de l'event est obsolète** — l'arbre testé est pourtant frais |

**Verdicts :**
1. **H1 CONFIRMÉ deux fois** — le workflow `pull_request` exécute le **merge result**, pas le head isolé ;
2. **Le mécanisme de rafraîchissement est démontré** — un événement `synchronize` régénère le
   merge ref avec la base courante : c'est exactement ce que `strict: true` ferait systématiquement ;
3. **Nuance importante** : le `base.sha` de l'événement est **stale** (`cbfddb27`) alors que l'arbre
   testé est frais (marqueur de `95bcea6e` présent) — se fier au `base.sha` de l'event serait un
   piège ; l'evidence fiable est le `GITHUB_SHA`/checkout et le contenu du fichier.

### Consequence pour #12 — le problème se reformule

Ce n'est plus « la CI teste-t-elle le head ou le merge result ? » (elle teste le merge result).
C'est : **« le merge result testé reste-t-il valide jusqu'au moment du merge, alors que
`main` avance ? »** — avec `strict: false`, la base peut bouger entre le run et le clic merge :
l'arbre qui atterrit sur `main` est alors une combinaison différente de celle qui a été testée.

## Arbitrage CTO #12 (22/09) — correction retenue : `strict: true`

| Élément | Décision | Motif |
|---|---|---|
| EXP-2 | ❌ **NON exécutée — valeur marginale nulle** | EXP-1 a produit toute la preuve nécessaire : run #1 (merge ref sur l'ancienne base) · synchronize → nouveau merge ref · run #2 (`8f32b7c6`, checkout = merge ref, marqueur PRESENT). Reproduire le mécanisme n'apporte aucune nouvelle propriété de décision — pour un mainteneur solo, le coût n'est pas justifié |
| **Mécanisme** | ✅ **`strict: true`** — correction minimale | RED (`strict: false` → la base peut avancer sans revalidation) · EXP-1 (GitHub sait reconstruire le merge ref · synchronize démontre la re-validation possible) → correction (la base doit être à jour avant merge) → les checks sont réexécutés sur le merge ref actualisé |
| merge_group | ⏸️ Différé | Capacité supplémentaire (sérialisation de merges concurrents) — non nécessaire pour le risque actuellement démontré ; réévaluer si Foresy passe à une vraie concurrence de PRs ou si le processus de merge évolue |
| Smoke post-merge | ⏸️ Chantier distinct | Répond à « CI pré-merge ≠ état réellement publié sur main » — frontière distincte, hors périmètre #12 |
| Commit/clôture | ⏸️ **Pas encore** — le GO porte sur la correction ; le GREEN réel de la protection modifiée d'abord |

### Protocole GREEN de la correction (calqué sur le protocole #11)

1. Modifier **uniquement** `strict` de `false` → `true` dans la protection de `main` —
   UI : cocher *Require branches to be up to date before merging* · API : payload `strict: true`
   + les 6 checks + `enforce_admins` (inchangés) — **aucun workflow modifié** ;
2. PR de contrôle — la chaîne comportementale attendue :
   - PR à jour → checks exécutés → `clean` → mergeable (cas nominal) ;
   - `main` avance → la PR devient **out-of-date** → merge bloqué → *Update branch* →
     **nouveau merge ref régénéré** → les checks se réexécutent sur l'arbre frais → `clean` →
     mergeable. La chaîne `out-of-date → update → nouveau merge ref → re-checks → clean`
     est la preuve comportementale de #12 ;
3. Seulement après cette preuve : #12 GREEN.

### EXP-1 — phase 2 (run #2 après synchronisation) — CERTIFIÉ (voir ci-dessus)

- [x] Merge du marqueur (`chore/backlog12-marker`) → `main = X + B` (`95bcea6e`)
- [x] Commit neutre `a521ae09` sur la probe → événement **synchronize** → merge ref régénéré
- [x] Evidence run #2 : `GITHUB_SHA = 8f32b7c6` · `HEAD checkouté = 8f32b7c6` · `marker: PRESENT`
- [x] Verdict : le mécanisme de rafraîchissement est démontré — le reste de #12 est la
      **politique** (régénérer systématiquement = `strict: true`, sérialiser = `merge_group`,
      ou observer = smoke post-merge)
- [ ] Arbitrage CTO (après lecture factuelle du run #2)

### Run #1 — evidence brute

```text
Run echo "=== EXP-1 evidence (BACKLOG #12) ==="
=== EXP-1 evidence (BACKLOG #12) ===
PR head sha : 5acb38407fd66441a27804dbc61e1909cc7d0a76
PR base sha : cbfddb27fe31ff436e4ecf50e51bbbbc85a76962
GITHUB_SHA  : b396a97684db681d7c575295470fb4bd31f09da9
GITHUB_REF  : refs/pull/45/merge
HEAD checkouté : b396a97684db681d7c575295470fb4bd31f09da9
probe_marker.md : ABSENT
```

### EXP-1 (H1) — Probe de dépendance au base, décisif en un re-run

1. Branche `chore/backlog12-probe` créée sur main @ `cbfddb27` :
   un spec temporaire `spec/docs/probe_marker_spec.rb` asserte l'existence d'un fichier
   marqueur **qui n'existe pas encore** (`docs/technical/probe_marker.md`)
   → première CI : **rouge dans les deux hypothèses** (inconclusive, attendue) ;
2. Une micro-PR ajoute le marqueur à `main` (merge) → la base avance ;
3. **Re-run all** de la CI de la PR probe (clic UI, ou API avec PAT) — GitHub régénère
   `refs/pull/N/merge` avec la base actuelle :
   - **GREEN** → le checkout teste la combinaison base+head (H1 = merge ref testé) ;
   - toujours **RED** → le checkout teste le head seul (gap plus large).

Le spec probe est temporaire — il n'est jamais mergé.

### EXP-2 (H2) — La fenêtre de staleness : arbre combiné non testé à l'arrivée sur main

**Scénario expérimental minimal** (2 branches docs, 2 merges successifs, aucune re-CI) :

```
main @ X
   ├── PR A créée (branche A : change docs/a) → CI verte sur (X + A) → clean
   ├── PR B créée (branche B : change docs/b) → CI verte sur (X + B) → clean
   ├── Merge PR A → main @ (X + A)        ← arbre testé ✓
   └── Merge PR B (sans re-run) → main @ (X + A + B)
                                    ← arbre JAMAIS testé : (A + B) combinés
```

**Evidence à collecter** : SHA des checks (associés à quelle combinaison ?), timestamps
des check-runs vs merges, arbre final de `main` (le fichier `a` ET le fichier `b` présents
sans qu'aucun run n'ait jamais exercé leur combinaison).

**Attention** : ce RED ne démontre un *risque* que si les deux changements sont
combinables-dangereux — pour des fichiers docs distincts, le merge de B est trivial.
Le RED démontre **la fenêtre**, pas un bug réel : la valeur est de quantifier ce que
`merge_group` fermerait.

### H3 — La protection a déjà fermé le chemin push-direct

**Preuve** : rejet GH006 réel (22/09). Conséquence pour #12 : l'option « smoke post-merge »
n'a plus besoin de couvrir les push directs — `main` ne bouge **que** via des PRs mergées,
dont l'arbre combiné est la seule surface restante non exercée au moment du merge.

## Options d'arbitrage (à trancher APRÈS le RED — aucune recommandation prématurée)

| Option | Ce qu'elle ferme | Coût | Ce qu'elle ne ferme pas |
|---|---|---|---|
| `merge_group` / merge queue | H2 — la CI tourne sur l'arbre combiné destiné au merge, sérialisé | file d'attente (latence) · refactor du trigger CI | l'état post-déploiement |
| Smoke post-merge sur `push: main` | l'état publié réel de main après chaque merge | job CI léger sur chaque merge | la CI pré-merge (déjà couverte) |
| `strict: true` | H2 côté PR (base à jour avant merge) | re-runs fréquents à chaque merge concurrent | reste lié au comportement de re-run |
| Combinaison merge_group + smoke | fenêtre PR + état publié | coût CI maximal | — |

## Critères de décision (règle maison)

- Le RED (H1+H2) doit **quantifier la fenêtre** : quelle proportion de merges produit un arbre non testé ?
- Correction minimale : fermer la fenêtre démontrée, pas plus.
- Pas de double mécanisme si un seul suffit.

## Statut

- [x] H1 — **résolu** : le workflow `pull_request` exécute le merge ref (2 preuves : run #1 `b396a976`, run #2 `8f32b7c6`)
- [x] EXP-2 — **non exécutée** (arbitrage CTO : valeur marginale nulle après EXP-1)
- [x] Mécanisme retenu : **`strict: true`** (arbitrage CTO — merge_group différé, smoke distinct)
- [ ] Application de la correction (`strict` false → true sur la protection de `main`)
- [ ] GREEN comportemental (PR à jour mergeable · PR out-of-date bloquée → update → re-checks → clean)
- [ ] Clôture #12 (documentation + BACKLOG)

## Références

- `ci.yml` L316 (E2E `if: pull_request`) · L3-7 (triggers push main + pull_request)
- Tracker #11 : rejet GH006 (push direct fermé) · tracker §Cas limite
- BACKLOG #12 · analyse E2E CTO 20/09