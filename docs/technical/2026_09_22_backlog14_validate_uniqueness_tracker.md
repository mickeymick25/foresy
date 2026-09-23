# BACKLOG #14 — `Cra#validate_uniqueness` inerte à la création — Tracker

**Chantier :** vérifier empiriquement si l'invariant d'unicité (créateur + mois + année) est protégé à la création
**Décision CTO :** GO #14 — investigation RED uniquement. Aucun correctif avant d'avoir établi la violation ou l'absence de violation. Si le RED échoue parce que l'invariant est déjà garanti, #14 se clôt sans correction.
**Méthode :** flow réel HTTP → controller → service → model → DB. Aucun mock/stub métier.

---

## Statut : 🔴 RED DÉMONTRÉ (22/09/2026) — la violation est établie

---

## 1. État du code avant le RED (lecture, trois couches)

| Couche | Garde existant ? | Détail |
|---|---|---|
| **Model** — `Cra#validate_uniqueness` (L335-351) | Inerte à la création | Lit `user_cras.find_by(role: 'creator')&.user_id` puis `return if creator_user_id.nil?` — or le pivot est créé **post-insert** par le service → à la validation de création, `creator_user_id` = nil → garde skippé |
| **Service** — `CraServices::Create#call` | Aucun check de doublon | Flow : params → permissions → build → save. Le `rescue` "already exists" (L226-240) ne peut se déclencher que si la validation modèle tire — ce qu'elle ne fait pas à la création |
| **DB** — `db/schema.rb` | Aucune contrainte | `cras` : index simples (deleted_at, locked_at, month, status, year) — **pas d'index d'unicité impliquant le créateur** (le créateur n'est même pas une colonne — relation-driven via pivot). Les index uniques de `user_cras` protègent d'autres invariants : `idx_user_cras_cra_creator` (un créateur **par CRA**) et `idx_user_cras_unique_creator` (un pivot par user+CRA) — aucun ne empêche deux CRAs (cra_id différents) pour le même user + mois + année |

**Conclusion de lecture** : aucune des trois couches ne protège l'invariant à la création.

## 2. RED expérimental — preuve au niveau HTTP (flow réel)

**Spec :** `spec/requests/api/v1/cras/uniqueness_creation_invariant_spec.rb`
Asserte **l'invariant attendu** (le doublon est refusé) — son échec démontre la violation.

**Evidence (run local, `foresy_test`, 22/09) :**

```text
1) BACKLOG #14 — invariant unicité créateur+mois+année à la création
     refuse un second CRA identique (créateur + mois + année) — invariant attendu
     Failure/Error:
       expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:conflict)

          expected the response to have status code :unprocessable_entity (422)
          but it was :created (201)
       ...or:
          expected the response to have status code :conflict (409)
          but it was :created (201)
```

**Lecture** : le **deuxième** `POST /api/v1/cras` (même utilisateur, même mois, même année)
a retourné **201 Created** — le doublon a été créé. L'invariant est **violé** sur le chemin
de création en conditions réelles (HTTP → controller → service → model → DB, aucun mock).

## 3. Analyse de cause — pourquoi le garde est inerte

```
CraServices::Create#save_cra
  └── ActiveRecord::Base.transaction
        ├── cra.save!                    ← validation tourne ICI : pivot absent
        │     └── validate_uniqueness    ← creator_user_id = nil → return (skip)
        └── create_user_cra_relation!    ← pivot créé APRÈS l'insert
```

Le garde n'est **actif que sur la re-validation/update** (quand le pivot existe déjà) :
`Cra#update` sur un CRA existant vérifie alors les autres CRAs du créateur — protection
**asymétrique** (l'ancien bloque l'édition du nouveau, mais rien ne bloque la création du nouveau).

## 4. Options de correction (pour l'arbitrage — après validation CTO du RED)

| Option | Mécanisme | Avantages | Inconvénients |
|---|---|---|---|
| **A — Garde service-level** | Dupliquer le pattern éprouvé `CraEntryServices::Create#check_duplicate_entry` : `CraServices::Create` vérifie `Cra.joins(:user_cras).where(user_cras: { user_id: current_user.id, role: 'creator' }, month:, year:, deleted_at: nil).exists?` **avant** `save_cra` → `ApplicationResult.conflict(:cra_already_exists)` → 409 (le `rescue` du service mappe déjà ce cas) | Correction minimale, cohérente avec le pattern entry · `current_user` est connu du service (pas de dépendance pivot) · le garde modèle reste actif sur update | La protection reste applicative (pas de garantie DB) |
| **B — Contrainte DB** | Trigger ou contrainte d'exclusion PostgreSQL couvrant (user, month, year) via le pivot | Garantie DB absolue | Le créateur est via pivot (pas de colonne) — exige un trigger ; la migration DDD a **supprimé irréversiblement** `created_by_user_id` (précédent architectural lourd) |
| **C — Recalage pivot/validation** | Créer le pivot avant `save!` | Le garde modèle tirerait naturellement | Le pivot a besoin de `cra.id` — le CRA doit être persisté d'abord (UUID) — le recalage est structurellement impossible sans re-travailler le design relation-driven |

**Lecture de l'arbitrage en attente** : l'option A est cohérente avec le pattern existant
(`check_duplicate_entry` de CraEntryServices) et la correction minimale. L'option B est la
solution de fond mais touche l'architecture DDD (pivot post-insert). Le CTO tranche.

## 5. Statut

- [x] RED — démontré empiriquement (HTTP 201 sur le doublon — spec `uniqueness_creation_invariant_spec.rb`)
- [x] Cause établie : garde modèle inerte (pivot post-insert) + pas de garde service + pas de contrainte DB
- [ ] **Arbitrage CTO** : correction A (garde service-level) vs B (contrainte DB) vs C (recalage)
- [ ] Correction minimale → GREEN (le spec RED passe)
- [ ] Certification (suite complète + gates) + documentation

## Références

- `app/models/cra.rb` L335-351 (`validate_uniqueness`) · `creator_user_id` (L132-136)
- `app/services/cra_services/create.rb` — `save_cra` (L218-230) · `create_user_cra_relation!` (L268-284)
- `db/schema.rb` — `cras` (pas d'index créateur) · `user_cras` (index uniques autres invariants)
- Tracker #11/#12 (gouvernance PR) · BACKLOG #14