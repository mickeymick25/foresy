# 📜 Contrat #14 renforcé — Invariant (créateur, mois, année) SOUS CONCURRENCE — R-1

**Date :** 26 septembre 2026
**Chantier :** BACKLOG **#26** (race #14 — investigation `2026_09_26_26_race14_concurrency_investigation.md`)
**Statut :** v1.0 **CERTIFIÉ (26/09)** — qualification VALIDÉE (bug confirmé de concurrence) · R-1 GO · R-2/R-3 NO GO · chaîne **exécutée** : RED mesuré → R-1 implémentée → GREEN ×2 → suite 1133/0 → Zeitwerk/RuboCop 0
**Discipline :** RED mesuré avant implémentation · pas de breaking change · pas d'évolution de schéma
**Distinction (CTO)** : #14 était un invariant **applicatif nominal** ; #26 démontre qu'il n'est **pas** un invariant **concurrentiel**.

---

## 1. Contexte

L'invariant FC-07 « un seul CRA par (créateur, mois, année) » est protégé en nominal par le garde
service-level `check_duplicate_entry` (SELECT pré-build, tracker #14) — mais **aucun mécanisme de
sérialisation** ne couvre la fenêtre TOCTOU (SELECT → INSERT) : la race a été reproduite de façon
déterministe le 26/09 (5/5 points, audit #26 §3) — 2 CRAs persistés + verrou fonctionnel 409.

## 2. Clauses contractuelles

| # | Clause |
|---|---|
| **A1** | Invariant : **un seul CRA actif** (`deleted_at: nil`) par **(créateur, mois, année)** — y compris **sous concurrence** |
| **A2** | Mécanisme R-1 : **advisory lock transactionnel** PostgreSQL `pg_advisory_xact_lock(key)` — clé dérivée déterministe de `(current_user.id, year, month)` : `user_id * 1_000_000 + (year − 2000) * 100 + month` (mois 1-12 / année 2000-2031+ bornées par `validate_date_range` → clé distincte par utilisateur et par période) |
| **A3** | **Ordre imposé (CTO)** : `transaction { lock → check_duplicate → build → save! → pivot }` — le lock **précède la garde** et vit dans la **même transaction** que l'insert (libéré à COMMIT/ROLLBACK). Un ordre « check → lock → insert » est **non conforme** (fenêtre TOCTOU subsistante) |
| **A4** | Concurrence même clé : deux appels concurrents → **sérialisation** → exactement **1 success (201)** + **1 conflict (409 `:cra_already_exists`)** + **exactement 1 CRA persisté** — y compris si les deux clients ont déjà traversé une pré-vérification (la fenêtre TOCTOU **côté client** — double-clic, retry réseau, onglets — est absorbée par le service) |
| **A5** | Clés différentes : ne se bloquent pas (confinement de la section critique) |
| **A6** | Comportements nominaux inchangés : 201 / 409 (garde préexistante) / 422 / 403 / 400 — pas de breaking change |
| **A7** | Lock **transaction-scoped** : libéré à COMMIT **et à ROLLBACK** (exception, validation) — pas de leak de session ; pas d'évolution de schéma (R-2 NO GO) ; pas de SERIALIZABLE (R-3 NO GO) |
| **A8** | Spec contractuelle permanente **bloquante dans la suite** : `spec/services/cra_services/create_race14_contract_spec.rb` — transformée du runner d'investigation #26 (barrière déterministe · `use_transactional_tests = false` · cleanup robuste — **zéro pollution** `foresy_test`) |
| **A9** | Gates de certification : suite complète **≥ 1133/0** · verrou SimpleCov 72,5 tenu · Zeitwerk OK · RuboCop 0 |

## 3. RED attendu (avant implémentation)

La spec contractuelle (A8) échoue : **2 CRAs persistés, 2 success** — reproduisant la race démontrée
(les deux pré-vérifications client passent, aucun mécanisme ne sérialise les inserts).

## 4. GREEN attendu (après implémentation)

La même spec passe : **1 success + 1 conflict** — le second appel, bloqué sur le lock jusqu'au COMMIT du
premier, exécute sa garde **après** le commit → voit le CRA existant → **409 contractuel** ; exactement
1 CRA persisté. La sérialisation est **déterministe** (le lock, pas le timing).

## 5. Suivi T1-T9 — CERTIFIÉ 26/09

| # | Étape | Statut |
|---|---|---|
| T1 | Contrat v1 écrit (ce document) | ✅ |
| T2 | Spec contractuelle + **RED concurrentiel mesuré** : `expected 1, got 2` (2 CRAs, 2 success — seed 1699) | ✅ |
| T3 | Implémentation R-1 minimale : `take_race14_lock!` — `pg_advisory_xact_lock(user_id, year, month)` AVANT la garde, même transaction (`cra_services/create.rb`) | ✅ |
| T4 | GREEN concurrentiel **×2** (seeds 16729 / 28994) : 1 success + 1 conflict `:cra_already_exists`, exactement 1 CRA | ✅ |
| T5 | Suite complète **1133/0** (seed 11258, 8 min 40 s) — couverture **86,24 % lignes (2997/3475) / 60,88 % branches (873/1434)**, verrou 72,5 tenu | ✅ |
| T6 | Zeitwerk OK · RuboCop **0 offense (244 files)** | ✅ |
| T7 | BACKLOG #26 close + métriques README/BRIEFING 1133 | ✅ |
| T8 | Docs `[DONE]_` (contrat + audit #26) | ✅ |
| T9 | Merge → hub réindexé (doc + mémoire fc08::016 servis) | ⬜ post-merge |

**Notes** : warnings `unknown OID 2278` (pg_advisory_xact_lock traité comme String par AR) — bénins, sans impact ; autocorrect RuboCop limité à une newline finale (mécanique, sémantique inchangée — GREEN mesuré sur le contenu identique).

---

**Document créé le :** 26 septembre 2026
**Propriétaire :** Équipe technique Foresy
*Préfixe `[DONE]_` à appliquer à la certification (T1-T9).*