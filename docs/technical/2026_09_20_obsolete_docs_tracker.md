# Suivi — Marquage `[Obsolete]` (enquête de statut par document)

**Date :** 20 septembre 2026
**Demande CTO :** marquer `[Obsolete]` les documents dont le traitement est obsolète — après enquête document par document : l'implémentation n'est pas allée au bout **pourquoi** (annulée ? décision contraire actée ?)
**Gating :** `origin/main` @ `025b90b2` au 20/09 — **PR #37 non encore mergée** → exécution post-merge uniquement (sinon conflits garantis avec les renames C1/C2 de la PR)
**Provenance :** requêtes RAG `foresy__memories`/`foresy__knowledge` effectuées le 20/09 — **aucun chunk pertinent** sur les sujets enquêtés (dry-monads, cache OAuth, monitor, migration, BACKLOG — distances 0,48–0,64, tout le contenu retourné concernait fc08::/P6) ; **les verdicts ci-dessous reposent sur les preuves locales** (contenu des documents, `git log --follow`, code, schéma de migrations, registre de dette) et ne sont pas attribués au hub

---

## 1. Convention proposée

| Règle | Énoncé |
|---|---|
| Marqueur | `[Obsolete]_YYYY_MM_DD_<nom>.md` — même slot que `[DONE]_` : **un seul marqueur d'état par document** |
| Définition stricte | Le traitement recommandé/plannifié par le document **n'a pas été appliqué tel quel** ET son abandon est **acté** : (a) annulé, ou (b) décision contraire actée — avec **preuve source** (le document lui-même, git, registre, code) |
| Bascule `[DONE]` → `[Obsolete]` | Quand la solution a été appliquée **puis annulée/remplacée** par une décision actée — l'état final compte (un doc `[DONE]` dont le traitement n'existe plus devient `[Obsolete]`) |
| ≠ « différé » | Un traitement **différé explicitement** (pending, priorité basse, conditionnel) n'est **pas** obsolete : il reste sans marqueur (ex. `oauth_caching_strategy`) |
| ≠ « référence historique » | Les références/analyses livrées dont la conclusion reste valide ne sont pas obsolete (ex. `ANALYSE_TECHNIQUE_FORESY`) |

## 2. Méthode d'enquête

1. Requêtes hub RAG (memories + knowledge) — cf. provenance ci-dessus : rien de pertinent sur les candidats
2. Lecture du document (statut auto-déclaré, décision, alternative)
3. `git log --follow` (dernière évolution, contexte des commits)
4. Vérification du code/état réel : Gemfile, `scripts/`, `db/migrate/`, registre de dette, README
5. Croisement avec les docs de résolution cités (changes/, corrections/)

## 3. Classification (enquête du 20/09)

| Document | Verdict | Preuve d'enquête | Suivi |
|---|---|---|---|
| `corrections/2026_01_05_TECH-DEBT-dry-monads-missing.md` | **[Obsolete]** | **Décision contraire actée dans le document même** : « Statut : ✅ RÉSOLU · Résolution : Suppression de Dry::Monads, migration vers exceptions métier FC07 · **Décision CTO : Exceptions métier > Dry::Monads** » (5 raisons : paradigme isolé, non aligné FC07, friction ActiveRecord, dette cognitive, adoption partielle) ; alternative appliquée (`CraErrors`, 9 services refactorés, Zeitwerk OK) ; dry-monads absent du Gemfile = conséquence de la décision, pas un oubli | ⏳ TODO |
| `docs/BACKLOG.md` (racine docs/ — hors docs/technical) | **ARCHIVE + RELANCE** : `[Obsolete]_2025_12_26_BACKLOG.md` = archive de l'ancien backlog (le verdict [Obsolete] demeure pour l'ANCIEN contenu) ; **nouveau `docs/BACKLOG.md` vivant créé le 20/09** | Décision 2.2 (10/09) : ROADMAP.md canonique → ancien contenu périmé archivé (850 tests vs 977 actuels, créé le 2025-12-26) ; **demande CTO 20/09 : conserver un BACKLOG** — relance en backlog **transverse** (chantiers non couverts par ROADMAP/registre/campagne + pointeurs, règles anti-drift dans le fichier) | ✅ FAIT |
| `analysis/[DONE]_2025_12_19_google_oauth_service_mock_solution.md` | **[DONE] → [Obsolete]** (GO CTO 20/09) | La solution implémentée a été **annulée** : `GoogleOAuth2Service` supprimé le 21/12/2025 (`changes/[DONE]_2025_12_21_GoogleOAuth2Service_Removal_Resolution.md` — point 2 PR) ; le traitement documenté n'existe plus dans l'architecture finale. **Chaîne historique conservée dans le tracker** | ⏳ TODO |
| `changes/[DONE]_2025_12_18_GoogleOauthService_Fix_Resolution.md` | **[DONE] → [Obsolete]** (GO CTO 20/09) | Fix Zeitwerk `GoogleOauthService` **supersédé le 21/12** par la suppression du service — même chaîne d'annulation | ⏳ TODO |
| `analysis/[DONE]_2025_12_19_csrf_security_analysis_same_site_none.md` | **[Obsolete]** (GO CTO 20/09) | La proposition (SameSite=None) n'est pas restée différée : la stratégie d'architecture a changé — **suppression complète des sessions le 22/12** (stateless). La solution décrite n'est pas celle qui a été livrée ; le document est conservé comme **trace historique** | ⏳ TODO |
| `analysis/2025_12_24_oauth_caching_strategy.md` | **PAS obsolete** | Statut in-doc : « **Évalué - Implémentation différée**, Priorité Basse » ; nature conditionnelle (« Si le cache devient nécessaire » checklist) ; **aucune annulation ni décision contraire trouvée** (RAG + git + registre) — différé ≠ obsolete | ✅ FAIT (verdict) |
| `guides/2026_02_02_github-workflows-monitor-improvements.md` | **[DONE]** (requalification) | Doc : « Améliorations **Implémentées** » (v2.0) ; vérifié au code : `scripts/github-workflows-monitor.sh` présent sur main avec le pattern Bearer documenté (L108-109) — traitement allé au bout | ⏳ TODO |
| `guides/2026_08_18_migration_strategy.md` | **[DONE]** (requalification) | Décision « squash complet » **appliquée et vérifiée** : `db/migrate/` = `20260101000000_initial_schema.rb` (13 tables, 6 enums, 14 FK) + FC-08 post-doc ; le traitement est l'état actuel persistant | ⏳ TODO |
| `changes/2026_09_17_D12_LEDGER_PATH_Chiffrage.md` | **[DONE]** (requalification — erreur de mon classement initial) | **D-12 RÉSOLUE** le 17/09 et **mergée** : commit `a551f7e7` « merge(d12): LEDGER_PATH configurable + vrai Git Ledger en CI — D-12 résolue (PR #33, GREEN FOR MERGE) » sur main ; registre D-12 : « ✅ Résolue » | ⏳ TODO |
| `fc07/enhancements/2026_01_06_FC07-Future-Enhancements.md` | **PAS obsolete** | Les items non livrés (versioning CRA avancé, export PDF) sont **actifs en roadmap** (v0.3+, `docs/ROADMAP.md`) — traitement différé officiellement planifié | ✅ FAIT (verdict) |
| `analysis/[DONE]_2025_12_19_omniauth_oauth_configuration_solution.md` | À vérifier à l'exécution | Solution « templates + robustesse » — appliquée telle quelle ou remplacée par `OAuth_Services_Elegant_Solution` (23/12) ? Lecture + git à l'exécution | ⏳ TODO (vérification) |

## 4. Corrections des classements du tracker d'hygiène (transparence)

L'enquête révèle **3 requalifications** de `2026_09_20_documentation_hygiene_tracker.md` (erreurs de mon enquête initiale — cause : vérification incomplète à l'époque : Gemfile seul, registre lu partiellement) :

| Doc | Classement hygiène (erroné) | Classement corrigé (preuves §3) |
|---|---|---|
| `TECH-DEBT-dry-monads-missing` | ❌ « dette ouverte » | **[Obsolete]** — décision contraire actée |
| `2026_09_17_D12_LEDGER_PATH_Chiffrage` | ❌ « D-12 ouverte » | **[DONE]** — PR #33 mergée (`a551f7e7`) |
| `github-workflows-monitor-improvements` + `migration_strategy` | « statut à vérifier » | **[DONE]** — implémentations vérifiées |

→ Les corrections seront appliquées au tracker d'hygiène **dans la branche `[Obsolete]` post-merge** (PR #37 non modifiée).

## 5. Plan d'exécution (gated merge PR #37)

### Mapping O1 (armé — 8 renames)

| Ancien (état main post-PR #37) | Cible |
|---|---|
| `docs/technical/corrections/2026_01_05_TECH-DEBT-dry-monads-missing.md` | `[Obsolete]_2026_01_05_TECH-DEBT-dry-monads-missing.md` |
| `docs/technical/analysis/[DONE]_2025_12_19_google_oauth_service_mock_solution.md` | `[Obsolete]_2025_12_19_google_oauth_service_mock_solution.md` |
| `docs/technical/changes/[DONE]_2025_12_18_GoogleOauthService_Fix_Resolution.md` | `[Obsolete]_2025_12_18_GoogleOauthService_Fix_Resolution.md` |
| `docs/technical/analysis/[DONE]_2025_12_19_csrf_security_analysis_same_site_none.md` | `[Obsolete]_2025_12_19_csrf_security_analysis_same_site_none.md` |
| `docs/BACKLOG.md` | `[Obsolete]_2025_12_26_BACKLOG.md` (traitement séparé, même branche) |
| `docs/technical/guides/2026_02_02_github-workflows-monitor-improvements.md` | `[DONE]_2026_02_02_github-workflows-monitor-improvements.md` (requalification) |
| `docs/technical/guides/2026_08_18_migration_strategy.md` | `[DONE]_2026_08_18_migration_strategy.md` (requalification) |
| `docs/technical/changes/2026_09_17_D12_LEDGER_PATH_Chiffrage.md` | `[DONE]_2026_09_17_D12_LEDGER_PATH_Chiffrage.md` (requalification) |

| Phase | Contenu | Suivi |
|---|---|---|
| O0 | Merge PR #37 (CI 6/6 verte vérifiée le 20/09 — run 35527003605, checks API) → nouvelle base `main` **f764c3e2** (fast-forward, 180 fichiers) | ✅ FAIT (20/09) |
| O1 | Branche `chore/docs-obsolete` créée depuis `f764c3e2` — **8 renames exécutés** (`git mv`, mapping §5 exact) | ✅ FAIT (20/09) |
| O2 | Références croisées — script single-pass `tmp/update_obsolete_refs.rb` : **14 fichiers, 41 remplacements** (README ×3, index.md ×20, BRIEFING, ROADMAP, RELEASE_NOTES, registres d'audit, changes) ; incident passe-2 README corrigé (3 doubles préfixes, cf. journal) + corrections des 5 verdicts au tracker d'hygiène | ✅ FAIT (20/09) |
| O3 | Gates : doubles préfixes **= 0** (hors prose historique) · anciens noms **= 0** (hors mapping du présent tracker) · liens : 632 cibles vérifiées, les +8 MANQUANT = table de mapping du présent tracker (noms anciens volontaires) ; **résidu inchangé : 119** (114 link-rot pré-existant + 2 wildcards + 3 danglings) — le rename a cassé **zéro lien** · suite **977/0** (`foresy_test`, 2 min 27) · SimpleCov **77,18 % (2815/3647) inchangé** · branches 47,87 % | ✅ FAIT (20/09) |
| O4 | Journal de ce tracker à jour + commit + push + PR dédiée | ⏳ EN COURS |
| O4 | Journal de ce tracker + PR → CI 6/6 | ⏳ TODO |

**Périmètre maintenu : strictement documentaire — aucune modification fonctionnelle ; W2-D2 reste sur sa branche dédiée, sans mélange.**

## 6. Journal de suivi

### 2026-09-20 (quinquies) — Relance du BACKLOG transverse (demande CTO) — réponse « doublon hub RAG ? »

- **Demande CTO :** conserver un BACKLOG dans `docs/` — est-ce un doublon du hub RAG ? **Réponse : non** — rôles complémentaires : le hub est un **index sémantique** (recherche d'états/décisions, mémoires `fc08::xxx`), le BACKLOG est un **document d'action curaté** (quoi faire ensuite, priorités, pointeurs) ; le hub indexe le BACKLOG — le garder court/daté protège l'index (l'ancien BACKLOG du 18/08 avait été indexé avec des métriques périmées comme « état courant »)
- **Décision appliquée :** archive conservée (`[Obsolete]_2025_12_26_BACKLOG.md` — le verdict [Obsolete] demeure pour l'ANCIEN contenu) + **nouveau `docs/BACKLOG.md` vivant** : backlog transverse — 13 chantiers ouverts datés (W2-D2 actif, P1, audit chore/p6-coverage-plan, D3-3, verrou 72,5, handle_user_error, E2E OAuth credentials, alerting, réindexation hub, link-rot, drift ROADMAP/FC-08, performance, monitoring), sources canoniques pointées (ROADMAP · registre dette · campagne P6), **règles anti-drift** (pointe sans recopier, métriques datées, MAJ à chaque état substantiel)
- **ROADMAP.md prose alignée** (décision 2.2 évoluée le 20/09) ; références README/index/BRIEFING/audits/changes réalignées sur le BACKLOG vivant
- **Réindexation du hub RAG requise post-merge** (les renames PR #37 + obsolete ont déplacé tous les chemins indexés) — ajoutée au BACKLOG (#9)

### 2026-09-20 (quater) — Exécution O0→O3 complète — gates verts — O4 en cours

- **O0 :** PR #37 mergée par le CTO (titre/description fournis) — `main` fast-forward `025b90b2 → f764c3e2` (180 fichiers) ; branche locale `chore/docs-hygiene` supprimée (-d, mergée)
- **O1 :** branche `chore/docs-obsolete` créée depuis `f764c3e2` ; 8 renames exécutés exactement selon le mapping §5 (4 `[Obsolete]_` bascules + BACKLOG + 3 `[DONE]_` requalifications) — statut vérifié `git status` : 8 × `R`
- **O2 :** 14 fichiers, 41 remplacements de références croisées ; **incident passe-2 corrigé (transparent)** : README.md matché 2× (doublon de globs `README.md` + `*.md` — même cause que E2) → la seconde passe a re-préfixé des sous-chaînes déjà renommées (`[DONE]_[DONE]_2026_08_18_…` ×2, `[Obsolete]_…[Obsolete]_…BACKLOG` ×1) — **3 doubles réparés** ; leçon enregistrée : dédupliquer la liste de fichiers et interdire les candidats dont l'ancien nom est une sous-chaîne du nouveau (gate regex élargie à toutes les formes de doubles)
- **O3 :** gates vertes (cf. §5 O3) — SimpleCov **77,18 % lignes (2815/3647) inchangé**, suite **977/0**, grep doubles **= 0**, anciens noms **= 0**, liens : **zéro lien cassé par le rename** (résidu 119 = pré-existant, inchangé)
- **Corrections tracker d'hygiène appliquées (§4) :** 5 verdicts requalifiés (TECH-DEBT → [Obsolete] · D12 chiffrage → [DONE] · google_oauth_service_mock_solution → [Obsolete] · csrf_same_site_none → [Obsolete] · workflows-monitor + migration_strategy → [DONE])
- **O4 :** commit + push + PR dédiée — en cours

### 2026-09-20 (ter) — Arbitrages tranchés (GO O1/O2/O3) — exécution armée

- **Arbitrages CTO consignés :** (a) **GO** bascules `[DONE]→[Obsolete]` ×2 GoogleOAuth2Service — fait déterminant : état final du code (solution appliquée puis service supprimé le 21/12) ; (b) **GO** `[Obsolete]` pour `csrf_same_site_none` — la voie analysée a été remplacée par la décision architecturale du 22/12 (document conservé comme trace historique) ; (c) **GO** `[Obsolete]` pour `docs/BACKLOG.md` **hors docs/technical** — traitement explicite séparé, artefact distinct de la campagne des 148 docs
- **Mapping O1 armé (8 renames, §5)** — date de création `BACKLOG.md` récupérée : 2025-12-26 (git --follow)
- **CI PR #37 revérifiée verte le 20/09** (API check-runs, run 35527003605 : 6/6 success sur `c35ca981`) — merge humain en attente ; `origin/main` toujours @ `025b90b2`
- Exécution O1→O4 dès le signal post-merge

### 2026-09-20 — Enquête de statut complète (7 documents investigués, 2 arbitrages CTO requis)

- **Contrat de routage respecté :** requêtes hub `foresy__memories` (dry-monads, cache OAuth, monitor, BACKLOG/ROADMAP) et `foresy__knowledge` — aucun chunk pertinent (distances 0,48–0,64, contenu fc08::/P6 uniquement) ; **aucune information ci-dessus n'est attribuée au hub** — preuves locales uniquement
- **`origin/main` vérifié :** `025b90b2` — PR #37 non mergée au moment de l'enquête → exécution gated (conflits renames sinon)
- **Découvertes structurantes :**
  1. `TECH-DEBT-dry-monads-missing` : la « dette » est **résolue par décision contraire actée** (documentée dans le doc même, validée CTO) — mon classement hygiène « dette ouverte » était faux (je n'avais vérifié que le Gemfile)
  2. `D12_LEDGER_PATH_Chiffrage` : D-12 **résolue et mergée** (PR #33, `a551f7e7`) — mon classement « D-12 ouverte » était faux (registre lu partiellement)
  3. `migration_strategy` + `github-workflows-monitor-improvements` : traitements **allés au bout** (vérifiés : schéma de migrations, script v2.0 au code) — `[DONE]`, pas obsolete
  4. `oauth_caching_strategy` : **différé explicitement** (« Évalué - Implémentation différée », conditionnel) — non annulé, non contredit → pas obsolete
  5. `BACKLOG.md` : supersession **actée** (décision 2.2, 10/09 — ROADMAP.md canonique) + contenu périmé → candidat `[Obsolete]` (scope racine docs/ à arbitrer)
- **Arbitrages CTO attendus :** (a) bascules `[DONE]`→`[Obsolete]` des 2 docs GoogleOAuth2Service (solution annulée le 21/12) ; (b) cas `csrf_security_analysis` (traitement remplacé par décision renforcée) ; (c) scope BACKLOG.md (hors docs/technical)
- **Aucune modification de fichier à ce stade** — tracker créé (non commité), exécution gated O0

## 7. Références

- Tracker d'hygiène (conventions C1/C2, mécanique d'exécution) : `docs/technical/2026_09_20_documentation_hygiene_tracker.md`
- Tracker Wave 2 (W2-D2, branche dédiée séparée) : `docs/technical/testing/[DONE]_2026_09_20_p6_wave2_tracker.md`
- Décisions citées : `changes/[DONE]_2025_12_21_GoogleOAuth2Service_Removal_Resolution.md` · `changes/[DONE]_2025_12_22-…Datadog` (timeline BRIEFING 22/12 stateless) · registre `fc08_debt_register.md` (D-12) · `docs/ROADMAP.md` (décision 2.2)
- Scripts de vérification : `tmp/check_doc_links.rb` (liens), mécanique renames : `tmp/rename_technical_docs.rb`