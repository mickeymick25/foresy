# Plan de mise en œuvre & Suivi d'intégration — P6 : Densification de couverture SimpleCov

**Date de création :** 17 septembre 2026
**Héritage :** P6 du suivi D-2 (`docs/technical/d2_simplecov_implementation_tracker.md`) — décision D-2.1 : baseline sans échec d'abord, **seuil à statuer après mesure** (cette mesure est faite)
**Analyse de référence :** `docs/technical/changes/2026-09-17-P6_Coverage_Gap_Analysis.md` (P6.0 — exhaustive, par typologie de tests)
**Baseline :** 72.78 % lignes (2879/3956) · 44.82 % branches (744/1660) · 67/78 fichiers avec écarts · 1 077 lignes non couvertes
**Branche de travail :** `chore/p6-coverage-plan` → PR dédiée par wave (discipline maison)
**Standard :** platinium — TDD honnête (voir §3), typologie de tests explicite (unitaire / intégration / non-régression / E2E), gates exécutées, traçabilité

---

## 1. Vue d'ensemble — phases et gates

| Phase | Contenu | Véhicule de tests | Gate | Statut |
|---|---|---|---|---|
| **P6.0** | Analyse exhaustive des manques (documentée) | — | Document d'analyse revu CTO | ✅ fait 17/09 — `2026-09-17-P6_Coverage_Gap_Analysis.md` |
| **P6.1** | **Verrou anti-régression** : `minimum_coverage line: 72.5` dans `.simplecov` — **après vérification du déterminisme** (recommandation co-CTO 17/09 : baseline mesurée ×2 sur le même commit, lignes + branches ; verrou calé sur la valeur minimale observée, pas un run unique) | Non-régression | Suite 957/0 avec verrou actif ; la CI échoue sous le seuil | ✅ **EXÉCUTÉ — verrou armé 72,0 au W1 (17-19/09), restauré 72,5 au W2 (20/09, GO CTO — marge +5,33 pts) — VIVANT à ce jour (` .simplecov` L94) · branches NON verrouillées (décision P6.6) |
| **P6.2 — Wave 1** | Sécurité & erreurs critiques : `access_validation` (77 l., 0/46 branches !), error_handlers cras/cra_entries, `standardized_error` | **Intégration** (request specs 403/404/422/409) | Suite verte (957+ nouvelles) ; re-mesure documentée ; RuboCop 0 ; CI 6/6 | ✅ **EXÉCUTÉ (PR #35, 19/09 — `2e32ddfe`, run 35447455513 6/6 verts)** — 73,21 → **76,49 lignes / 47,60 branches** · les 2 bugs d'autorisation découverts et corrigés (le soft-delete qui ne se propageait pas — RED → GREEN) |
| **P6.3 — Wave 2** | Extraction/formatage + rate limiting + OAuth : parameter_extractors ×3, response_formatters ×2, rate_limitables ×3, `o_auth_concern`, o_auth services | **Intégration** (429, params invalides) + **unitaire** (services OAuth) | Idem + verrou relevé à la valeur re-mesurée − 0.3 | ✅ **EXÉCUTÉ (PRs #36/#37/#38, 20/09)** — 10 latents supprimés · `OAuthCodeExchangeService` caractérisé (0 → 69,44 % lignes) · 7 specs requête end-to-end · **verrou restauré 72,5** · 77,18 → **77,83 lignes / 48,42 branches** (994/0) |
| **P6.4 — Wave 3** | Services & lib unitaires + contrôleurs + models : `CraServices::List` (filtres), `git_ledger_service`, `application_result`, `cra_errors`, models marge | **Unitaire** + intégration ledger | Idem | ✅ **EXÉCUTÉ (campagne P6, PRs #39-#41 — fc08::010-012)** — trajectoire : 77,83 → **86,22/60,80** (close-out #21, 26/09) |
| **P6.5 — Wave 4** | Marges fines (~40 fichiers ≤ 10 l.) → cible finale | Mixte | Cible atteinte (90 ou 95 % — décision P6.6) | ✅ **EXÉCUTÉ (PRs #39-#41 — P6.6 CLOSED)** — 86,22 → **86,26 lignes / 61,03 branches** (le verrou 72,5 franchi à chaque run) — la cible 90 % **non requise** (arbitrage CTO 21/09) |
| **P6.6** | **Décision finale du seuil** + verrou branche éventuel | Non-régression | Décision CTO documentée au registre/chiffrage | ✅ **CLOSED (21/09)** — 90 % **non requis** · le verrou branches = différé (61 % actuel — un chantier séparé le jour où l'arbitrage le retient) |
| **P6.7** | Clôture : registre/guide/README métriques finales, réindexation hub | — | Hub vérifié par requête | ✅ **EXÉCUTÉ au fil de la campagne** — les métriques README/BRIEFING harmonisées (23-24/10 : 1148/0 · 86,26/61,03 · RuboCop 249/0 · RSwag 437 · audit 36/36) · hub réindexé à chaque état substantiel (knowledge 2512 chunks, memories 22) |

## 2. Périmètre par typologie de tests (exigence CTO)

| Typologie | Rôle dans P6 | Où |
|---|---|---|
| **Unitaires** | Densification services/lib/models — Wave 3 principalement | `spec/services`, `spec/models`, `spec/lib` |
| **Intégration** | **Véhicule principal** — concerns API & contrôleurs via HTTP réel (branches d'erreur inaccessibles autrement) | Waves 1-2 : request specs + `spec/integration` (ledger) |
| **Non-régression** | Double : (1) les 957 specs existantes restent vertes à chaque wave ; (2) **verrou `minimum_coverage`** (P6.1) + relèves progressives — la couverture ne peut plus dériver | Toutes les waves |
| **E2E** | **Pas un levier de métrique** (shell = invisible SimpleCov, cf. analyse §1) — reste une **gate de parcours** : acceptance specs (déjà comptées), smoke 15/15, scripts shell (D-12 pour la CI) | Hors périmètre P6 ; consolidation uniquement |

## 3. Discipline TDD — honnête et explicitée

- Les specs de densification **caractérisent un comportement existant** : GREEN immédiat attendu — **pas de RED artificiel** (la couverture n'est pas une course aux assertions).
- **Exception réel** : si une spec révèle un **bug** (comportement incorrect ou manquant) → **RED authentique** → correction minimale → GREEN → tracé au journal (commit `fix` étiqueté, hors périmètre densification).
- Chaque spec nouvelle s'ancre au **contrat** concerné (FC-07/FC-08, contrat d'erreur §44) ou à l'invariant visé — pas de test opportuniste (exigence revue CI co-CTO : « pas de code de test opportuniste »).
- Le verrou P6.1 est de l'**outillage** (validation par exécution, pas de cycle).

## 4. Chiffrage consolidé (issu de l'analyse P6.0)

| Wave | Gain estimé | Couverture projetée | Durée indicative |
|---|---|---|---|
| P6.1 verrou | — | 72.5 % (floor) | 0,25 h |
| Wave 1 | ~130 l. | ≈ 76 % | 2,5-3 h |
| Wave 2 | ~200 l. | ≈ 81 % | 3-4 h |
| Wave 3 | ~250 l. | ≈ 87-90 % | 4-5 h |
| Wave 4 | ~300 l. | ≈ 95 % | 4-6 h |
| **Total** | **+879 l.** | **95 %** | **≈ 14-18 h** (2-3 journées effectives, PR par wave) |

## 5. Risques & mitigations

| Risque | Mitigation |
|---|---|
| Spécs caractérisant un bug caché dans les branches d'erreur jamais traversées | Attendu (probabilité réelle) → processus RED réel §3 ; chaque découverte tracée au journal |
| Verrou trop strict → CI rouge pour bruit | Marge 0.28 pt sous baseline ; relèves par paliers mesurés, jamais extrapolés |
| Dérive du seuil « opportuniste » (exclure des fichiers pour atteindre 95 %) | Zone morte = décision CTO explicite et documentée (P6.6), pas un filtre silencieux `.simplecov` |
| Branches (44.82 %) plus coûteuses que les lignes | Non verrouillées en phase 1 ; mesure après Wave 2 → décision P6.6 |
| E2E shell intégrés en CI (D-12) sans gain de métrique | Documenté (analyse §1) — D-12 reste un chantier de parcours, indépendant de P6 |

## 6. Décisions attendues du CTO (avant P6.1)

1. **Verrou initial** : `minimum_coverage line: 72.5` — recommandé, **conditionné à la mesure ×2 du déterminisme** (recommandation co-CTO 17/09 : la baseline 72.78 % doit être stable run à run avant de figer le seuil ; marge fine de 0.28 pt)
2. **Trajectoire** : waves 1→4 (95 %) ou arrêt décisionnel à 90 % après Wave 3 ?
3. **Zone morte** : couvrir `apm_service` et fichiers infra (par défaut) ou exclusion documentée ?
4. **Verrou branches** : différer à P6.6 après re-mesure (recommandé) ?

## 7. Journal d'exécution

### 2026-09-17 — [P6.0] Analyse exhaustive produite
- Script `coverage/gap_analysis.rb` (non commité) : 78 fichiers app/, 67 avec écarts, 1 077 lignes / 916 branches non couvertes
- Constat critique : concerns API FC-07 quasi sans branches couvertes (access_validation 0/46, parameter_extractors 0/56 et 1/72, list 0/36) — chemins de succès seuls exercés
- Typologie : intégration-request = véhicule principal (~430 l., waves 1-2) ; unitaire services/lib/models ~230 l. (wave 3) ; E2E shell invisible pour SimpleCov (y compris après D-12)
- Chiffrage 95 % : ≈ 14-18 h effectives, 4 waves, PR par wave
- Documents : analyse (`changes/2026-09-17-P6_Coverage_Gap_Analysis.md`) + présent plan — **en attente GO CTO avant P6.1**

## 10. EXECUTION RECORD — absorption annotée (2026-10-24, arbitrage CTO O-2)

> Le plan a été **exécuté intégralement à la suite du GO** (les Waves 1-4 + P6.6 CLOSED — PRs #35-#41 : traçabilité
> fc08::010-012) — **sans que le présent tracker et son analyse n'aient été mergés** (restés sur cette branche).
> Ce record = la réconciliation, rédigée à date de l'absorption annotée (arbitrage CTO #2 : O-2).

| Phase | Statut réel | Véhicule (PRs) | Trajectoire de couverture (lignes/branches) |
|---|---|---|---|
| P6.0 — analyse | ✅ 17/09 | ce document + l'analyse | baseline **72,78/44,82** (2879/3956 · 744/1660) — 1077 lignes de mancques |
| P6.1 — verrou | ✅ 17-20/09 | W1 PR #35 → W2 PRs #36-#38 | armé **72,0** (transitoire, marge +0,34 sur corpus CI) puis **72,5 restauré** (GO CTO 20/09, marge +5,33) — **vivant à ce jour** (` .simplecov` L94 — l'`at_exit` de plein-suite only) |
| P6.2 — Wave 1 | ✅ 19/09 | **PR #35** (`2e32ddfe`, run 35447455513 — 6/6 verts) | 73,21 → **76,49/47,60** · **2 bugs d'autorisation découverts et corrigés** (le soft-delete qui ne se propageait pas : RED → GREEN, arbitrage CTO — leçon : la couverture explore les branches jamais traversées) |
| P6.3 — Wave 2 | ✅ 20/09 | **PRs #36/#37/#38** (`025b90b2`/`f764c3e2`/`bf2a8512`) | 10 latents supprimés · `OAuthCodeExchangeService` 0 → 69,44 %(le verrou restauré 72,5) · 77,18 → **77,83/48,42** (994/0) |
| P6.4/P6.5 — Waves 3-4 | ✅ au fil de la campagne | **PRs #39-#41** (fc08::010-012 — P6.6 CLOSED 21/09) | 77,83 → **86,22/60,80** (close-out #21, 26/09) → les campagnes suivantes : 86,24/60,88 (R-1 race) · 86,30/61,16 (Q-1) → **86,26/61,03 aujourd'hui** (1148/0 : les exemples + le contrat export #17) |
| P6.6 — décision | ✅ 21/09 | arbitrage CTO | 90 % **non requis** · le verou branches = **différé** (61 % actuel — un chantier séparé si/ou quand l'arbitrage le retient) |
| P6.7 — clôture | ✅ au fil | les updates README/BRIEFING/hub | les métriques harmonisées (23-24/10 : **1148/0 · 86,26/61,03 · RuboCop 249/0 · RSwag 437 · audit 36/36**) · hub (knowledge **2512 chunks** · memories **22**) |

**Divergences plan ↔ exécution (consignées, sans réécriture d'historique)** :
1. les statuts ⬜ de la table §1 = conservés comme l'état de planification ET annotés ✅ in situ (les edits de la présente
   absorption) — l'historique = la trajectoire de campagne ci-dessus ;
2. le chiffrage initial (95 % cible ≈ 14-18 h) = **périodisé en campagne étendue** (les Waves + P6.6 CLOSED + les campagnes
   associées #21/#26/#27/#22/#29) — le 90 % **non requis** a été tranché au lieu du 95 % (décision CTO 21/09) ;
3. le verrou branches (44,82 → 61,03 %) = **toujours non verrouillé** — le chiffrage/fait au jour où l'arbitrage le retient
   (un chantier séparé : le déterminisme ×2 pré/post requis — le mécanisme P6.1-bis éprouvé) ;
4. l'outil `scripts/coverage_gap_analysis.rb` = versionné ici (P1 reproductibilité co-CTO) — usage corrigé au service
   `test` (leçon fc08::018 : jamais `web`) — prêt pour la **Wave 4.5 (#15)** et le chantier branches.

## 8. Références

- Analyse P6.0 : `docs/technical/changes/2026-09-17-P6_Coverage_Gap_Analysis.md`
- Baseline & guide : `docs/technical/testing/line_coverage.md`
- Suivi D-2 (P6 hérité) : `docs/technical/d2_simplecov_implementation_tracker.md`
- Chiffrage D-2 : `docs/technical/changes/2026-09-16-D2_SimpleCov_Chiffrage.md`