# BACKLOG #12 — Validation de l'arbre mergé — Tracker [DONE]

**Chantier :** garantir que la CI valide l'arbre effectivement mergé, pas seulement le HEAD de chaque PR
**Décision CTO :** GO RED d'abord (22/09) — démontrer précisément ce que le pipeline actuel laisse passer **avant** de choisir le mécanisme.
**Prérequis atteint :** branch protection verrouillée (PR #43) — les 6 checks sont requis, administrateurs inclus.
**Statut : ✅ CLOSED / GREEN — 22/09/2026 · `strict: true` certifié comportementalement.**

> **Note de lecture** — ce document est clôturé. Les sections 1 à 3 portent le résultat final
> et les preuves ; la section 4 est l'**historique du protocole** (hypothèses, scénarios,
> options — état d'avancement figé à la clôture). Les cases `[ ]` qu'elle contient reflètent
> l'état du protocole pendant la campagne, **pas des tâches ouvertes**.

---

## 1. Résultat final

### Certification GREEN (22/09) — preuve comportementale

La protection modifiée (`strict: true`) a été **sauvegardée explicitement** puis testée sur
la PR de contrôle #48 :

| Élément | État |
|---|---|
| Require status checks to pass before merging | ✅ ON — les 6 checks exacts (capture UI) |
| Require branches to be up to date before merging | ✅ ON — **sauvegardé explicitement** (Save changes) |
| PR #48 | 6/6 checks `completed/success` sur le head `d714c9f3` |
| `main` | avancé à `4f61a3a4` — **la PR est derrière la base**, non resynchronisée |
| Comportement GitHub | **« This branch is out-of-date with the base branch »** — merge bloqué, demande de fusion des dernières modifications de `main` |

**La fenêtre de staleness démontrée en EXP-1 est fermée** : des checks verts ne suffisent plus —
GitHub exige une branche à jour et réexécute les checks sur le merge ref actualisé avant le merge.

Le `mergeable_state: clean` observé transitoirement (3 sondages API) était un état non recalculé
avant la prise en compte effective de la règle — **pas** une preuve que le strict requirement
était inactif. L'evidence decisive est le message UI de blocage de merge, indépendant du cache
`mergeable_state`.

### La pyramide de confiance CI après #12

| Couche | Mécanisme | Preuve |
|---|---|---|
| Push direct sur `main` | Bloqué (GH006 — checks requis absents) | rejet réel du 22/09 |
| PR — checks requis | 6/6 exacts, `enforce_admins: true` | PR #43 : `blocked` → `clean` |
| PR — branche à jour | `strict: true` | PR #48 : out-of-date → bloquée malgré checks verts |
| Merge result testé | `refs/pull/N/merge` | EXP-1 : 2 preuves (`b396a976`, `8f32b7c6`) |

## 2. Arbitrage CTO (22/09) — correction retenue : `strict: true`

| Élément | Décision | Motif |
|---|---|---|
| EXP-2 | ❌ **NON exécutée — valeur marginale nulle** | EXP-1 a produit toute la preuve nécessaire : run #1 (merge ref sur l'ancienne base) · synchronize → nouveau merge ref · run #2 (`8f32b7c6`, checkout = merge ref, marqueur PRESENT). Reproduire le mécanisme n'apporte aucune nouvelle propriété de décision — pour un mainteneur solo, le coût n'est pas justifié |
| **Mécanisme** | ✅ **`strict: true`** — correction minimale | RED (`strict: false` → la base peut avancer sans revalidation) · EXP-1 (GitHub sait reconstruire le merge ref · synchronize démontre la re-validation possible) → correction (la base doit être à jour avant merge) → les checks sont réexécutés sur le merge ref actualisé |
| merge_group | ⏸️ Différé | Capacité supplémentaire (sérialisation de merges concurrents) — non nécessaire pour le risque actuellement démontré ; réévaluer si Foresy passe à une vraie concurrence de PRs ou si le processus de merge évolue |
| Smoke post-merge | ⏸️ Chantier distinct | Répond à « CI pré-merge ≠ état réellement publié sur main » — frontière distincte, hors périmètre #12 |

Le protocole d'application exécuté (calqué sur le protocole #11) : modification **uniquement** de
`strict` (false → true) dans la protection de `main` — aucun workflow modifié, aucun nouveau job —
puis certification comportementale sur PR de contrôle (section 3).

## 3. Preuves EXP-1 — le merge result est testé

### Run #1 — ouverture de la PR probe (PR #45, jamais mergée)

| Champ | Valeur | Lecture |
|---|---|---|
| PR head sha | `5acb3840` | le head de la probe (A) |
| PR base sha | `cbfddb27` | main (X) |
| `GITHUB_SHA` | **`b396a976`** | **≠ head, ≠ base — le merge commit** |
| `GITHUB_REF` | **`refs/pull/45/merge`** | le merge ref |
| HEAD checkouté | `b396a976` | **= GITHUB_SHA — le checkout EST le merge result** |
| probe_marker.md | ABSENT | cohérent (X ne contient pas encore le marqueur) |

### Run #2 — synchronize (commit neutre `a521ae09`) — merge ref régénéré

```text
=== EXP-1 evidence (BACKLOG #12) ===
PR head sha : a521ae09cba06959aabcc69419ac7f5f7dd4a60e
PR base sha : cbfddb27fe31ff436e4ecf50e51bbbbc85a76962
GITHUB_SHA  : 8f32b7c64d1fa394fb5b1a3d1c30ab99a4db6d37
GITHUB_REF  : refs/pull/45/merge
HEAD checkouté : 8f32b7c64d1fa394fb5b1a3d1c30ab99a4db6d37
probe_marker.md : PRESENT
```

### Verdicts

1. **H1 CONFIRMÉ deux fois** — le workflow `pull_request` exécute le **merge result**, pas le head isolé ;
2. **Le mécanisme de rafraîchissement est démontré** — un événement `synchronize` régénère le
   merge ref avec la base courante : c'est exactement ce que `strict: true` ferait systématiquement ;
3. **Nuance importante** : le `base.sha` de l'événement est **stale** (`cbfddb27`) alors que l'arbre
   testé est frais (marqueur de `95bcea6e` présent) — se fier au `base.sha` de l'event serait un
   piège ; l'evidence fiable est le `GITHUB_SHA`/checkout et le contenu du fichier.

### Consequence — le problème #12 reformulé

Ce n'est plus « la CI teste-t-elle le head ou le merge result ? » (elle teste le merge result).
C'est : **« le merge result testé reste-t-il valide jusqu'au moment du merge, alors que
`main` avance ? »** — avec `strict: false`, la base peut bouger entre le run et le clic merge :
l'arbre qui atterrit sur `main` est alors une combinaison différente de celle qui a été testée.
→ fermé par `strict: true` (certification ci-dessus).

## 4. Historique du protocole (figé à la clôture)

> **Note** : sections historiques — hypothèses, scénarios et options tels que formulés
> pendant la campagne. Les cases `[ ]` reflètent l'état d'avancement du protocole à ce stade,
> pas des tâches ouvertes. Le résultat final est en sections 1-3.

### État des faits établis (pré-RED)

| Fait | Preuve | Conséquence |
|---|---|---|
| Push direct sur `main` impossible | Hook GH006 — « 6 of 6 required status checks are expected » (rejet réel du 22/09, commit docs refusé) | Le chemin « push direct sans CI » est **déjà fermé** — le gap résiduel n'est pas celui-là |
| Les 6 checks sont requis sur les PRs | `PUT protection` 200 · PR #43 : `blocked` pendant les checks, `clean` après 6/6 sur le SHA contrôlé | Le merge d'une PR exige sa CI verte |
| `strict: false` | Payload d'application (décision #11) | « Require branches to be up to date » est **off** — le base peut bouger entre le run CI et le merge |

### EXP-1 (H1) — Probe de dépendance au base, décisif en un re-run

1. Branche `chore/backlog12-probe` créée sur main @ `cbfddb27` :
   un spec temporaire (`spec/probe/exp1_probe_spec.rb`) échoue volontairement en embarquant
   l'évidence (`GITHUB_SHA` / `GITHUB_REF` / présence du marqueur)
   → première CI : **rouge dans les deux hypothèses** (inconclusive, attendue) ;
2. Une micro-PR ajoute le marqueur à `main` (merge) → la base avance ;
3. Un événement **synchronize** (commit neutre sur la probe) — GitHub régénère
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
`merge_group` fermerait. **Non exécutée** — arbitrage CTO (voir section 2).

### H3 — La protection a déjà fermé le chemin push-direct

**Preuve** : rejet GH006 réel (22/09). Conséquence pour #12 : l'option « smoke post-merge »
n'a plus besoin de couvrir les push directs — `main` ne bouge **que** via des PRs mergées,
dont l'arbre combiné est la seule surface restante non exercée au moment du merge.

### Options d'arbitrage initiales (formulées avant le RED)

| Option | Ce qu'elle ferme | Coût | Ce qu'elle ne ferme pas |
|---|---|---|---|
| `merge_group` / merge queue | H2 — la CI tourne sur l'arbre combiné destiné au merge, sérialisé | file d'attente (latence) · refactor du trigger CI | l'état post-déploiement |
| Smoke post-merge sur `push: main` | l'état publié réel de main après chaque merge | job CI léger sur chaque merge | la CI pré-merge (déjà couverte) |
| `strict: true` | H2 côté PR (base à jour avant merge) | re-runs fréquents à chaque merge concurrent | reste lié au comportement de re-run |
| Combinaison merge_group + smoke | fenêtre PR + état publié | coût CI maximal | — |

### Critères de décision (règle maison, formulés avant le RED)

- Le RED (H1+H2) doit **quantifier la fenêtre** : quelle proportion de merges produit un arbre non testé ?
- Correction minimale : fermer la fenêtre démontrée, pas plus.
- Pas de double mécanisme si un seul suffit.

## Références

- `ci.yml` L316 (E2E `if: pull_request`) · L3-7 (triggers push main + pull_request)
- Tracker #11 : rejet GH006 (push direct fermé) · tracker §Cas limite
- BACKLOG #12 · analyse E2E CTO 20/09
- PR #43 (protection) · PR #45 (probe, close) · PR #46 (marqueur) · PR #47 (C1) · PR #48 (contrôle strict, close) · PR #49 (cette clôture)