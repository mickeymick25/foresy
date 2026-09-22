# BACKLOG #11 (ex-#13) — Branch Protection — Tracker

**Chantier :** rendre contraignante la règle « CI verte = merge » sur `main`
**Décision CTO :** GO 22/09/2026 — première étape de la séquence gouvernance (#11 → #12 → #14)
**Rôle :** protection transversale de tous les futurs développements · indépendant de P6/P7
**Prérequis technique :** l'application exige un accès admin du dépôt (UI GitHub ou API authentifiée) — l'agent prépare, l'humain applique, puis l'agent certifie le GREEN.

## Journal de certification

### 2026-09-22 — Application par API (Option B), exécutée par l'agent via le PAT admin du mainteneur

| Étape | Résultat |
|---|---|
| Token | `tmp/.admin_pat` (chmod 600, ignoré par Git, jamais affiché) — à supprimer après certification |
| GET protection | HTTP 200 — les **6 checks requis étaient déjà posés** (apposés via UI par le mainteneur ; app_id 15368 = GitHub Actions) |
| PUT n°1 | **422 documenté** : le payload mélangeant `contexts: []` et `checks: [...]` viole le `oneOf` du schéma — la configuration exige **un seul** des deux mécanismes (contexts XOR checks) |
| PUT corrigé (checks seul) | **200 — `enforce_admins: enabled: true`** · les 6 checks requis conservés :
  `🎨 Code Quality` · `📖 API Contracts` · `🔒 Security Audit` · `🚀 Quality Gate` · `🧪 End-to-End Tests` · `🧪 Tests & Coverage` |

**Le seul écart de la règle initiale (exemption admin) est désormais levé** : la protection de
branche est techniquement imposée, administrateurs inclus.

### Certification GREEN — PR de contrôle

- **Statut : en cours** — micro-PR docs (`chore/backlog11-control-pr`) créée pour démontrer
  le comportement attendu : `mergeable_state: blocked` pendant les checks, puis `clean` après 6/6
  sur le dernier SHA de la PR.
- Preuve primaire déjà enregistrée : les 6 entrées dans `required_status_checks.checks`
  (sorties API ci-dessus).

---

## RED — constat à frais (API GitHub, 22/09/2026)

`GET /repos/mickeymick25/foresy/branches/main` → `main` @ `a40a453a` :

```json
"protected": true,
"protection": {
  "enabled": true,
  "required_status_checks": {
    "enforcement_level": "off",
    "contexts": [],
    "checks": []
  }
}
```

**Interprétation** : la règle existe en forme (`protected: true`) mais n'impose rien —
`contexts: []` / `checks: []` (aucun check requis) et `enforcement_level: "off"`.
Toute PR est donc mergeable indépendamment de la CI : « CI verte » est une gouvernance
**par la pratique**, pas par contrainte. Preuves historiques : BACKLOG #11 (analyse 20/09),
PR #35-#42 mergées avec des checks verts mais non exigés.

## Checks requis (noms exacts — correspondance obligatoire avec `ci.yml`)

| # | Nom du job (`name:` dans `ci.yml`) | Job key |
|---|---|---|
| 1 | `🧪 Tests & Coverage` | `tests` |
| 2 | `🔒 Security Audit` | `security` |
| 3 | `🎨 Code Quality` | `lint` |
| 4 | `📖 API Contracts` | `contracts` |
| 5 | `🧪 End-to-End Tests` | `e2e` (bloquant sur PR — `if: pull_request`) |
| 6 | `🚀 Quality Gate` | `quality-gate` |

⚠️ Les emojis font partie du nom : la correspondance GitHub est exacte, sans normalisation.

## Application (étape humaine — admin)

### Option A — UI GitHub

1. `Settings` → `Branches` → `main` → `Edit` (règle existante).
2. Cocher **Require status checks to pass before merging**.
3. Sélectionner les 6 checks ci-dessus (ils apparaissent car ils ont déjà tourné sur les PR récentes).
4. **Ne PAS cocher** « Require branches to be up to date before merging » (`strict: false`) —
   la validation de l'arbre mergé est l'objet du chantier #12, pas de celui-ci.
5. **Enforcement : inclure les administrateurs** (UI : décocher l'exemption admin / API : `enforce_admins: true`) —
   mainteneur unique : sans cette option, la règle n'impose rien à la seule personne qui merge.
6. Sauvegarder.

### Option B — API authentifiée (admin)

```bash
curl -X PUT \
  -H "Authorization: Bearer <ADMIN_PAT>" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/mickeymick25/foresy/branches/main/protection \
  -d '{
    "required_status_checks": {
      "strict": false,
      "contexts": [],
      "checks": [
        {"context": "🧪 Tests & Coverage"},
        {"context": "🔒 Security Audit"},
        {"context": "🎨 Code Quality"},
        {"context": "📖 API Contracts"},
        {"context": "🧪 End-to-End Tests"},
        {"context": "🚀 Quality Gate"}
      ]
    },
    "enforce_admins": true,
    "required_pull_request_reviews": null,
    "restrictions": null,
    "required_linear_history": false,
    "allow_force_pushes": false,
    "allow_deletions": false
  }'
```

**Mécanisme `checks` (recommandé)** — GitHub documente désormais `checks` comme le mécanisme
fin de `required_status_checks` pour les nouveaux réglages ; `contexts` reste supporté mais
est signalé comme destiné à être remplacé. Avantages : chaque check peut être associé
explicitement à son GitHub App via `app_id` ; en l'absence de `app_id`, GitHub sélectionne
automatiquement la source appropriée.

Décisions embarquées dans ce payload : pas de review obligatoire (solo mainteneur),
pas de `strict` (#12 décidera), pas de force-push/delete, admins inclus.

## GREEN — protocole de certification (après application)

1. **Preuve primaire — la protection** : `GET /repos/mickeymick25/foresy/branches/main/protection` →
   les **6 entrées** sont présentes dans `required_status_checks.checks`.
2. **PR de contrôle** : ouvrir une micro-PR docs → tant qu'un des checks requis est
   `pending`/non réussi, la PR est **bloquée** (merge refusé).
3. **Conclusions des six checks** : chaque check requis doit terminer avec un état autorisant
   le merge (`successful`, `skipped` ou `neutral` selon les règles GitHub).
4. **Convergence GitHub** : `GET /repos/mickeymick25/foresy/pulls/<n>` →
   `mergeable_state` converge vers `clean` après recalcul GitHub.
5. **⚠️ Ne pas considérer `clean` seul comme preuve des checks** : la preuve primaire est la
   protection + les conclusions des six checks ; `clean` est l'observation finale attendue.
6. **Correspondance SHA** : les checks requis doivent être associés au **dernier SHA** de la
   PR (GitHub exige la correspondance exacte — vérifier `head_sha` des check-runs si doute).
7. **Journal** : consigner ici le SHA de la PR de contrôle + les sorties API (protection + check-runs).

## Cas limite connu (documenté, non bloquant)

- `e2e` est `if: github.event_name == 'pull_request'` → **skipped** hors PR. Sur le chemin
  PR (le seul que la protection gouverne), il s'exécute — pas d'ambiguïté pour le merge.
  Le chemin **push direct sur main** reste possible pour l'admin et n'exerce pas l'E2E :
  c'est exactement le chantier **#12** (merge_group / smoke post-merge), hors périmètre ici.
- Les PRs Dependabot : workflow tolérant (secrets optionnels `|| ''`) — à observer sur la
  première PR dependabot après application.

## Rollback

`DELETE /repos/mickeymick25/foresy/branches/main/protection` (PAT admin) ou désélection
des checks dans l'UI. En cas de blocage injustifié, décocher le check fautif plutôt que
supprimer la protection entière.

## Références

- BACKLOG #11 (anciennement #13 dans la numérotation P6) — analyse E2E CTO 20/09
- `ci.yml` L13-468 — noms des 6 jobs
- PR #40/#41/#42 : `mergeable_state: clean` vérifié via API sur des merges non exigés (précédent RED)