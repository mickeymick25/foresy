# 🔍 Investigation #26 — Race #14 : garde SELECT sans protection concurrente de l'invariant (créateur, mois, année)

**Date :** 26 septembre 2026
**Auteur :** Zed Agent (BACKLOG **#26** — investigation séparée issue de #19, arbitrage CTO 26/09)
**Statut :** ✅ Investigation terminée — scénario **reproduit de façon déterministe** — **5/5 points démontrés** —
qualification **VALIDÉE CTO 26/09 : bug confirmé de concurrence** (violation mesurée du contrat #14) —
remède **R-1 GO** (advisory lock transactionnel, lock **avant** la garde, même transaction) · R-2/R-3 **NO GO** —
chaîne TDD lancée : contrat #14 renforcé → RED concurrentiel → R-1 minimal → GREEN → suite complète → certification
**Périmètre :** `CraServices::Create#check_duplicate_entry` (garde SELECT) · `Cra#validate_uniqueness` ·
`db/schema.rb` (cras, user_cras) · expérience de concurrence orchestrée (conteneur `test`, base jetable `foresy_test`)
**Cadrage CTO (#26)** : caractériser le scénario concurrent → déterminer s'il est reproductible → démontrer ou
réfuter la violation de l'invariant → mesurer l'impact → arbitrage → **seulement ensuite** éventuel RED/correction.
**Discipline :** aucun correctif préventif avant la preuve.

---

## 1. Conclusion en une page

| Point exigé par le gate #26 | Fait démontré | Preuve |
|---|---|---|
| ① Deux créations concurrentes passent la garde simultanément | `guards_passed_both: true` — 2 SELECT de garde exécutés **avant toute écriture**, tous deux à `false` | expérience §3 (barrière) |
| ② Les transactions poursuivent leur création | `both_creations_success: true` — les deux `CraServices::Create.call` terminent en success | expérience §3 |
| ③ Aucune protection concurrente modèle/schéma | les 2 INSERT acceptés — statiquement : lien créateur = pivot créé **après** l'insert ; index uniques partiels portent sur `(cra_id, …)` → pas de collision ; `Cra#validate_uniqueness` inerte à la création | §2 + expérience |
| ④ Les deux CRAs peuvent être persistés | `cras_count: 2` | expérience §3 |
| ⑤ Violation effective du contrat #14 | `contract14_violated: true` — 2 CRAs pour le même (créateur, mois, année) | expérience §3 |
| **Impact** | **Doublon persisté + verrou fonctionnel** : tout appel ultérieur retourne 409 `:cra_already_exists` — l'utilisateur ne peut plus créer son CRA pour ce mois tant que le doublon n'est pas supprimé manuellement | 3ᵉ appel §3 |

**Conclusion (constat)** : la race est **réelle, atteignable et reproduite** — le garde applicatif (SELECT
pré-build) n'est couvert par **aucun mécanisme de sérialisation** ; la fenêtre TOCTOU (check-then-act) est
ouverte entre le SELECT et l'INSERT. **Qualification VALIDÉE (CTO 26/09) : bug confirmé de concurrence**
(viol contractuel démontré). **Distinction à conserver (CTO)** : #14 était un invariant **applicatif nominal** ;
#26 démontre qu'il n'est **pas** un invariant **concurrentiel** — conclusion plus forte que la simple présence
d'une TOCTOU. Remède : **R-1 GO** (lock avant garde, même transaction) · R-2/R-3 **NO GO**.

---

## 2. Phase 1 — Faits statiques (lecture directe)

1. **Garde pré-build** : `check_duplicate_entry` (cra_services/create.rb L200-212) = `SELECT … WHERE
   user_cras.user_id = current_user.id AND role='creator' AND month/year/deleted_at: nil … .exists?` —
   exécuté **avant** `build_cra` (L57-58) → 409 si exists.
2. **Check-then-act (TOCTOU)** : aucune instruction ne sérialise le SELECT et l'INSERT — pas de lock, pas de
   contrainte : la fenêtre entre le SELECT et `cra.save!` est **ouverte**.
3. **Lien créateur = pivot, créé après l'insert** : `create_user_cra_relation!` (L294-312) insère `UserCra`
   **après** `cra.save!` → à l'instant de l'INSERT cra, l'invariant ne peut être couvert par aucune contrainte
   de la table `cras` (aucune colonne user, aucun index unique (créateur, mois, année) — `cras` L129+).
4. **Index uniques partiels non-protecteurs** : `idx_user_cras_cra_creator` `(cra_id, role='creator')` et
   `idx_user_cras_unique_creator` `(user_id, cra_id, role='creator')` (schema L190/L192) portent sur le
   **cra_id** — deux CRAs distincts ont des cra_id distincts → **deux pivots créateur coexistent** sans collision.
5. **`Cra#validate_uniqueness` inerte à la création** (cra.rb L337-341) : lit le pivot → nil → `return` précoce.
6. **Fenêtre de production** : aucune sérialisation applicative ; les interleavings sont produits par le
   scheduler/double-clic/retry réseau/onglets multiples — le garde et l'INSERT étant découplés, tout scheduler
   peut produire l'ordre `garde_A, garde_B, insert_A, insert_B`.

---

## 3. Phase 2 — Reproduction (expérience déterministe, base jetable)

### 3.1 Protocole (falsifiable, rejouable)

Conteneur `test` (RAILS_ENV=test, `foresy_test` — jetable, **données nettoyées à la fin, `cleanup_ok: true`**),
`rails runner` inline — **aucun fichier de code créé, aucune modification du dépôt** :

1. Setup : `User` + `Company` (SIREN unique) + `UserCompany` role `independent` (pré-requis du
   `check_user_permissions` du service).
2. **2 threads**, chacun avec sa propre connexion (pool = `RAILS_MAX_THREADS` = 5, database.yml L4) :
   - chaque thread exécute le **SELECT de garde** (même requête que `check_duplicate_entry`) → `false` ;
   - barrière (`Mutex` + `ConditionVariable`) : les deux gardes sont terminées **avant** toute écriture ;
   - chaque thread exécule le chemin réel `CraServices::Create.call(cra_params:, current_user:)` (mois 1 / 2030).
3. Mesure : comptage `Cra.joins(:user_cras)…(user_id, role: 'creator', month, year)`.
4. Impact : 3ᵉ appel `CraServices::Create.call` après le doublon.
5. Cleanup : destruction des CRAs/pivots/UserCompany/Company/User + vérification `count == 0`.

### 3.2 Résultat exact (26/09)

```
{guards_passed_both: true, both_creations_success: true, cras_count: 2,
 contract14_violated: true,
 third_call: "#<ApplicationResult::ResultObject … @success=false, @status=:conflict,
              @error=:cra_already_exists, @message=\"A CRA already exists for this user, month, and year\">"}
{cleanup_ok: true}
```

**L'interleaving démontré** (les deux gardes avant les deux writes) est un interleaving **non sérialisé** par
l'application — atteignable en production par timing naturel (double-clic, retry réseau, onglets multiples).
La barrière rend la démonstration **déterministe** ; elle démontre la fenêtre, pas un hasard de scheduling.

---

## 4. Phase 3 — Impact (mesuré)

| Impact | Fait |
|---|---|
| Doublon de données | **2 CRAs** (même créateur, mois 1, année 2030) persistés avec leurs pivots créateur — état DB viole le contrat #14 |
| **Verrou fonctionnel utilisateur** | tout appel ultérieur → **409 `:cra_already_exists`** : l'utilisateur ne peut plus créer son CRA pour ce mois tant que le doublon n'est pas supprimé **manuellement** |
| Cohérence des pivots | 2 pivots créateur distincts (cra_id différents) — aucune anomalie pivot (la violation est au niveau **métier**, pas au niveau pivot) |
| Ledger | non affecté par `Create` (le Git Ledger n'intervient qu'au `lock!`) |
| Périmètre FC-07 | l'invariant « un seul CRA par (créateur, mois, année) » est la règle FC-07 fondamentale — sa violation est un incident de données métier |

**Répétition/concurrence** : c'est précisément un problème de concurrence — la fenêtre existe à chaque création ;
probabilité non mesurée (trafic inconnu), mais l'interleaving est atteignable **déterministement** (démontré).

---

## 5. Phase 4 — Qualification proposée (arbitrage CTO en attente)

**Proposition : bug confirmé de concurrence** — atteignable, reproduit, 5/5 points démontrés, impact fonctionnel
réel (doublon + verrou 409). Ce n'est plus une « odeur architecturale » : la violation du contrat est mesurée.

Options de remède (**pour arbitrage — aucune implémentée**) :

| Option | Principe | Trade-off |
|---|---|---|
| **R-1 — Advisory lock PostgreSQL** (`pg_advisory_xact_lock(hash(user_id, month, year))` **dans la même transaction** que la garde + insert) | sérialise les créations concurrentes sur la clé métier ; pattern Rails standard | pas de changement de schéma ; lock applicatif à documenter (contrat) |
| R-2 — Contrainte DB dérivée (colonne créateur dénormalisée + unique partial sur (creator, month, year)) | protection DB absolue | contraire à l'architecture pivot pure (DDD) — à arbitrer |
| R-3 — Isolation `SERIALIZABLE` sur la transaction de création | détection de sérialisation anormale | coût/complexité + erreurs 40001 à gérer |

Chaîne prévue si GO : contrat → **RED mesuré** (test de concurrence contractuel — l'expérience §3 en est le
prototype) → correction minimale → GREEN → régression complète.

---

## 5. Traçabilité de l'expérience

- Environnement : conteneur `test` (`docker-compose --profile test run --rm test bundle exec rails runner`),
  base `foresy_test` (jetable) — écritures de setup + cleanup vérifié (`cleanup_ok: true`, comptes à 0).
- Marqueurs de test : `race26-<hex>@example.com` / SIREN `999269999` — **aucune donnée résiduelle**.
- 2 runs antérieurs échoués (paramétrage setup : `unknown attribute 'active'` sur Company ; email en collision)
  ont laissé un user résiduel → **nettoyé** au début du run réussi (`User.where("email LIKE ?",
  "race26-%").destroy_all`) et vérifié en fin.
- Aucun fichier de code créé/modifié (runner inline).

## 6. Références

- `app/services/cra_services/create.rb` L57-58, L200-212 (garde #14), L242-312 (save + pivot)
- `app/models/cra.rb` L337-351 (`validate_uniqueness` inerte à la création)
- `db/schema.rb` L185-195 (user_cras + index uniques partiels L190/L192), L234-235 (FK)
- Audit d'origine : `[DONE]_2026_09_26_19_p0_reachability_investigation.md` §4-4 (observation initiale)
- BACKLOG **#26** · mémoire fc08::015 · arbitrage CTO 26/09 (cadrage #26)

---

**Document créé le :** 26 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Préfixe `[DONE]_` à appliquer à l'issue de l'arbitrage CTO (qualification + éventuel contrat/correction).*