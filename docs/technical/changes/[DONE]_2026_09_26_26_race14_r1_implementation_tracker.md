# 📋 Tracker #26 — Implémentation R-1 (advisory lock) — traçabilité rétroactive

**Date de production :** 28 septembre 2026 (horodatage Git hôte : `2026-09-28 20:27 UTC`)
**Chantier :** BACKLOG **#26** — race #14 · implémentation R-1 (`pg_advisory_xact_lock`)
**Statut :** ✅ R-1 livrée et certifiée (merge `4fb4063b`, CI 6/6 sur `ba99b937`)

> **Nature du document :** tracker de traçabilité **rétroactive** — produit **post-certification** pour
> documenter l'exécution effective de R-1. Il ne constitue **pas** un plan ayant précédé l'implémentation ;
> la conception contractualisée (contrat A1-A9) précède bien le code, et cette chronologie est démontrée
> par les horodatages Git ci-dessous. Contenu strictement fondé sur les artefacts existants (commits Git,
> sorties d'outils) — aucune mesure ni qualification nouvelle.

---

## 1. Besoin et arbitrage #26

| Élément | Source |
|---|---|
| Observation initiale (race #14, 5 points à démontrer) | audit `[DONE]_2026_09_26_19_p0_reachability_investigation.md` §4-4 · BACKLOG #26 (création) |
| Investigation/reproduction | `[DONE]_2026_09_26_26_race14_concurrency_investigation.md` (5/5, déterministe, commit `0cdd946b`) |
| Arbitrage CTO : qualification VALIDÉE (bug confirmé de concurrence) · R-1 GO · R-2/R-3 NO GO | mémoire fc08::016 · commit `a68756fb` |
| Distinction (CTO) | #14 était un invariant **applicatif nominal** ; #26 démontre qu'il n'est **pas** un invariant **concurrentiel** |

## 2. Conception contractualisée (AVANT l'implémentation — démontré par les horodatages Git)

Le contrat `[DONE]_2026_09_26_14_invariant_concurrent_contract.md` + la spec contractuelle sont commités
dans `e4f97acc` (2026-09-28 20:54 +0200), **avant** le commit d'implémentation `f5225ee8` (21:20 +0200) —
la chaîne *contrat → RED → correction* est démontrée par l'ordre des commits, pas seulement déclarée.

Clauses A1-A9 : invariant sous concurrence (A1) · clé du lock `user_id * 1_000_000 + (year − 2000) * 100
+ month` (A2, distincte par utilisateur/période, bornée par `validate_date_range`) · **ordre imposé
lock → check → insert, même transaction** (A3 — CTO) · sérialisation concurrentielle (A4) · confinement
des clés (A5) · pas de breaking change (A6) · lock transaction-scoped, pas d'évolution de schéma
(A7 — R-2/R-3 NO GO) · spec permanente bloquante (A8) · gates (A9).

**Exécuté à l'implémentation** : le commit `f5225ee8` porte le code minimal — `ActiveRecord::Base.transaction
{ take_race14_lock! ; check_duplicate_entry ; build_cra ; save_cra }` dans `call` + méthode privée
`take_race14_lock!` (interpolation initiale de la clé entière) — ~19 lignes modifiées, aucune autre
modification (C-1/C-2 non touchées — dette latente, NO GO).

## 3. Discipline de test concurrentielle (A8)

`use_transactional_tests = false` — démontrée par les artefacts : le fichier
`spec/services/cra_services/create_race14_contract_spec.rb` (commit `e4f97acc`) contient la déclaration
au niveau du groupe + cleanup robuste (`after` : destruction CRAs/pivots/UserCompany/Company/User,
défensif) — la concurrence réelle exige des connexions séparées (pool = `RAILS_MAX_THREADS` = 5,
`database.yml` L4). Aucune donnée résiduelle observée après runs (base `foresy_test`, jetable).

## 4. Journal d'exécution (horodaté)

**Sources d'horodatage** : les heures listées ci-dessous sont les **métadonnées Git** (`%ci`) sauf mention
`(Session)` — les durées d'exécution d'outils et les seeds de runs proviennent des **sorties de session**
(et, sauf mention contraire, sont reprises dans le message du commit correspondant, donc Git-traçables).
**Écart de datation signalé** : les documents du chantier portent la mention 26/09 (convention des échanges) ;
les horodatages Git réels des commits #26 sont du **2026-09-28** (17:00 → 22:17 +0200) — écart tracé ici
sans réécriture des documents.

| # | Événement | Horodatage | Source |
|---|---|---|---|
| J1 | Investigation #26 reproduite (5/5, déterministe — barrière 2 threads) + doc + BACKLOG #26 ouvert | commit `0cdd946b` — 2026-09-28 17:00:23 +0200 | Git |
| J2 | Arbitrage CTO (qualification VALIDÉE, R-1 GO) — fc08::016 écrite | commit `a68756fb` — 2026-09-28 20:52:11 +0200 | Git |
| J2-bis | Contrat + spec committés (`e4f97acc`) | 2026-09-28 20:54:34 +0200 | Git |
| J3 | **RED mesuré** (Session — sortie outil ; seed 1699 **non repris au message de commit**) : `expected: 1, got: 2` — 2 CRAs persistés, 2 success, 1 example / 1 failure | run avant commit `e4f97acc` | Session (le message de commit reprend le résultat, pas la seed) |
| J4 | **R-1 implémentée** (transaction + `take_race14_lock!`, interpolation initiale de la clé) | commit `f5225ee8` — 2026-09-28 21:20:39 +0200 | Git |
| J5 | **GREEN ×2** (Session, seeds 16729 et 28994) : 1 success + 1 conflict `:cra_already_exists`, exactement 1 CRA | runs avant commit `f5225ee8` | Session (repris au message) |
| J6 | **Suite complète** : 1133/0 (seed 11258 — **non reprise au message de commit** ; 8 min 40 s) — couverture 86,24 % lignes (2997/3475) / 60,87-88 % branches (873/1434) | run avant commit `f5225ee8` | Session (les compteurs 1133/86,24 sont repris au message) |
| J7 | Zeitwerk OK · RuboCop : 3 offenses détectées (newline finale spec + 2 parenthésages `Lint/AmbiguousOperatorPrecedence`) | avant commit `f5225ee8` | Session |
| J8 | Correctifs de style (parenthésage édité ; newline via shell + `rubocop -a` — mécanique) ; vérification 0 offense sur les 2 fichiers | avant commit `f5225ee8` | Session |
| J9 | **Certification documentaire** (contrat T1-T8 ✅ · `[DONE]_` renames · BACKLOG #26 close · README/BRIEFING 1133) | commit `18e0ed9f` — 2026-09-28 21:26:04 +0200 | Git |
| J10 | **Incident CI rouge** — signalé CTO (« La CI est rouge ! ») | post-push `18e0ed9f` | Session |
| J11 | **Cause reproduite localement** : Brakeman 7.1.2 — SQL Injection (High) sur `take_race14_lock!` L225, exit 3, 1 warning (run Session ; la sortie Brakeman affiche « Scan Date: 2026-09-28 19:57:11 +0000 » — horloge conteneur) | reproduction avant commit `ba99b937` | Session (sortie outil) |
| J12 | **Durcissement** : `sanitize_sql_array` (aucune interpolation brute) | commit `ba99b937` — 2026-09-28 22:09:42 +0200 | Git |
| J13 | **Re-mesure post-durcissement** : Brakeman **0 warning** (3 ignored préexistants, exit 0) · spec GREEN (seed 10164) · RuboCop 0 (fichier) · **suite complète 1133/0** (seed 34758, 8 min 56 s) — couverture 86,24-25 % lignes (2998/3476) / 60,88 % branches (873/1434) | runs avant commit `ba99b937` | Session (repris au message) |
| J14 | **CI 6/6 verte sur `ba99b937`** — verdict CTO | après push `ba99b937` | Session (CTO) |
| J15 | **Merge** + auto-delete branche | merge `4fb4063b` — 2026-09-28 22:17:16 +0200 | Git (action CTO) |

## 5. Gates de certification (état final, re-mesuré à `ba99b937`)

| Gate | Résultat |
|---|---|
| Suite complète | **1133/0** (seed 34758, 8 min 56 s) |
| Couverture | **86,25 % lignes (2998/3476) / 60,88 % branches (873/1434)** — verrou 72,5 tenu |
| Brakeman | **0 warning** (3 ignored préexistants) |
| Spec contractuelle #14 | **GREEN** (seed 10164) — RED → GREEN ×2 documentés (seeds 1699 · 16729 · 28994) |
| RuboCop | 0 offense (244 files) |
| Zeitwerk | OK |

## 6. Commits et merge

| Commit | Date Git (ci) | Contenu |
|---|---|---|
| `0cdd946b` | 2026-09-28 17:00:23 +0200 | Investigation #26 reproduite + BACKLOG #26 ouvert |
| `a68756fb` | 2026-09-28 20:52:11 +0200 | Arbitrage acté (VALIDÉE · R-1 GO · R-2/R-3 NO GO) + mémoire fc08::016 |
| `e4f97acc` | 2026-09-28 20:54:34 +0200 | Contrat #14 renforcé (A1-A9) + spec contractuelle — RED mesuré |
| `f5225ee8` | 2026-09-28 21:20:39 +0200 | R-1 minimal — GREEN ×2 · suite 1133/0 · Zeitwerk/RuboCop 0 |
| `18e0ed9f` | 2026-09-28 21:26:04 +0200 | Certification documentaire (`[DONE]_` · BACKLOG · README/BRIEFING) |
| `ba99b937` | 2026-09-28 22:09:42 +0200 | Durcissement Brakeman (`sanitize_sql_array`) — re-mesure complète |
| **merge `4fb4063b`** | 2026-09-28 22:17:16 +0200 | Merge PR #26 (CI 6/6, action CTO) |

## 7. Description de la PR (récapitulatif)

8 fichiers, +356/−34 · code : `take_race14_lock!` + transaction autour garde/build/save + spec
contractuelle (83 lignes) · docs : contrat (A1-A9 + T1-T9) · audit #26 `[DONE]_` · BACKLOG (#26 close +
row livrés) · README/BRIEFING (métriques 1133) · mémoire fc08::016. Titre de merge :
« merge(#26): race #14 — R-1 advisory lock (contrat #14 renforcé) — RED mesuré → GREEN ×2, suite 1133/0 ».

## 8. Leçons et cohérence documentaire

- **Leçon (fc08::016, validée CTO)** : un SELECT de garde applicatif ne garantit pas un invariant sous
  concurrence sans mécanisme de sérialisation — la fenêtre TOCTOU côté client (double-clic, retry) est
  absorbée par le service via le lock transactionnel.
- **Leçon opérationnelle (Brakeman)** : toute construction SQL doit passer par un canal de sanitisation —
  une clé dérivée d'entiers Ruby n'échappe pas au check SQL de Brakeman (comportement voulu du mode strict).
- **Cohérence vérifiée** (règle anti-drift) : le tracker cite uniquement les valeurs présentes dans
  le contrat `[DONE]` (A1-A9, T1-T9, Notes), l'audit `[DONE]_…26_race14…md`, le BACKLOG (#26 close,
  métriques 1133) et fc08::016. Aucun écart introduit.
- **Suivi mémoire** : amendement fc08::016 (ligne « Livraison » + chemins `[DONE]_` post-certification)
  **proposé** le 26/09 — en attente de validation CTO (non intégré ici pour ne pas créer de contenu
  non validé).
- **Écart de datation** : documents du chantier mentionnés « 26/09 » (convention des échanges) vs
  horodatages Git 28/09 — tracé au §4, aucune réécriture en masse décidée (à arbitrer si souhaité).

## 9. Restes ouverts (hors #26, CLOSE)

- **#24** — qualification ledger (21 commits réels) — prochaine investigation (GO en attente).
- **#25** — correction commande canonique BRIEFING (passe doc dédiée).
- **#27** — mapping UX (client_company_id inconnu → 500 · RuntimeError défensif).

---

**Document créé le :** 28 septembre 2026 (tracker rétroactif post-certification)
**Propriétaire :** Équipe technique Foresy
*Sources : artefacts Git (commits listés §6, messages contenant les mesures au moment du commit) et
sorties d'outils de session identifiées `(Session)` au §4. Aucune donnée inventée.*