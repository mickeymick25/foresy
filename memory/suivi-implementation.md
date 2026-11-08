<!-- category: foresy -->

# Suivi d'avancement de l'implémentation

<!-- created: 2026-10-03 -->
<!-- updated: 2026-10-25 -->

## suivi_impl::001
<!-- created: 2026-10-03 -->
<!-- updated: 2026-10-25 -->
Suivi d'avancement consolidé de l'implémentation — **fichier vivant**, mis à jour à chaque état substantiel
(règle anti-drift). Les entrées `fc08::NNN` de la source principale restent la vérité ; cette table est
l'index de progression. Le fichier est délimité par une entrée atomique : toute mise à jour se fait
**dans cette entrée** (pas de nouvelle entrée sauf bascule de phase).

| Bloc | Sujet | Statut | Chantier / source de vérité |
|---|---|---|---|
| fc08::001-005 | FC-08 Companies : invariants, onboarding atomique, SIREN, soft-delete | ✅ livré (PR #24 → tag v0.1.1) | `[DONE]_2026_08_31_fc08_implementation_tracker.md` |
| fc08::006-009 | Vague dette D-1→D-11 + SimpleCov + durcissement CI | ✅ livré (PRs #25-#29) | trackers `d1_d11` / `d2_simplecov` |
| fc08::010-012 | Campagne P6 : couverture (verrou 72,5), Waves 1-4, étude services | ✅ livré (PRs #34-#41) | trackers P6 testing |
| fc08::013 | FC-05 remediation certifiée (rate limiting distribué) | ✅ certifié (PR #56) | contrat `[DONE]_2026_09_25_fc05_rate_limiting_contract.md` |
| fc08::014/015 | #21 OAuth / code mort + #19 P0 reachability | ✅ CLOSE (O-1/O-2 + aucun P0) — séquence régularisée | audits `[DONE]_2026_09_26_oauth_investigation.md` · `[DONE]_2026_09_26_19_p0_reachability_investigation.md` |
| fc08::016 | #26 race #14 — R-1 advisory lock (contrat #14 renforcé) | ✅ CERTIFIÉE (RED → GREEN ×2 — merge `4fb4063b`) | contrat `[DONE]_2026_09_26_14_invariant_concurrent_contract.md` · tracker `[DONE]_2026_09_26_26_race14_r1_implementation_tracker.md` |
| fc08::017 | #24 ledger — qualification + purge O-B (23 → 1 commit, mécanisme supporté) | ✅ CERTIFIÉ (2026-10-03, merge `a557ad2e`) | audit `[DONE]_2026_09_28_24_ledger_provenance_investigation.md` §5.1 |
| fc08::018/019 | #25 commandes BRIEFING (vérifiées par exécution) + #27 Q-1 (422 :invalid_client_company) | ✅ CLOSED + leçons validées (merge `1ce7c5b3`) | analyses `[DONE]_2026_10_03_25_briefing_commands_analysis.md` / `[DONE]_2026_10_03_27_ux_error_mapping_analysis.md` |
| fc08::021 | **#22 hardening JWT** — clé dédiée `JWT_SECRET` consommée + fail-fast prod (boot : absent OU vide) + `HS256` explicite | ✅ **CERTIFIÉ + BASCULÉ (23/10)** — contrat 6/0 ×2 · suite **1143/0** · RuboCop 248/0 · Brakeman 0 · Zeitwerk OK · audit 0 · 86,26/61,03 · verrou franchi · **bascule Render : merge `4d2985c1` (PR #77, CI 6/6) · `/health` 200 ×3 · sondes S-1 200 / S-2 200 / S-3 401 ×2 / S-4 200 / S-5 401** — re-login généré (tokens pré-bascule invalides), pas de rollback ; 1er S-5 500 = artifact de sonne d'agent (body malformé), re-sonde 401 — produit sain | audit `[DONE]_2026_10_23_22_jwt_hardening_investigation.md` (T1-T7) · runbook `[DONE]_2026_10_23_22_render_jwt_cutover_runbook.md` · fc08::021 |
| fc08::022 | **incident-CI 24/10** — scripts Ruby versionnés = périmètre Quality Gates applicables au dépôt (Brakeman exit 7 + RuboCop 26 offenses F sur un parse error du script) | ✅ **VALIDÉE (CTO 24/10) + ENREGISTRÉE** (vérifié Chroma 25/10 : `fc08_022.md::fc08::022` top-1 à d=0,28, contenu = fichier versionné) — fix `aedd70e4` (CI 6/6, run 40121939127) · archivé tracker P6 §7 (PR #83, `4928d00`) · renumérotation fc08::019→022 (collision #27 + catégorie indexeur — PRs #84/#85, `81726806`) | tracker P6 §7 (L78+) · `memory/fc08_022.md` |
| suivi_impl::001 | **#28 — prévention structurelle ledger** : isolation stub_const ×6 (les overlays singleton inerts) + garde INV-D12-03 fail-fast (avant tout Git-call) + W3-D2 aligné | ✅ **CERTIFIÉE (2026-10-03)** — RED ×2 → GREEN ×2 · batch ledger 72/0 · suite 1137/0 · ledger réel inchangé (1 commit) · purge #24 non touchée | cadrage `[DONE]_2026_10_03_28_ledger_prevention_cadrage.md` (§6 journal) · fc08::020 proposée |

**Métriques de référence (2026-10-24, post zéro-warnings merge `679ea3ad` — crass 1.0.8 + les configs zéro-warnings en prod)** : suite **1148/0** · couverture **86,26 % lignes / 61,03 % branches**
· RuboCop **249 files / 0** · RSwag **437 (mesuré) · audit 36/36** · Brakeman 0 · Zeitzeitwerk OK · bundle audit 0 vulnérabilité (DB 1269, commit `03da937a9e17`) ·
verrou 72,5 (intact) · CI 6/6 · production **vérifiée post-merge** (`/health` 200 ×5 après les 000 ×3 du build — le pic d'indisponibilité free tier est documenté) ·
hub : knowledge **2544 chunks** · mémoires **23** (25/10 — les réindexations post-absorption, bullet Hub au tracker P6 §7).

**Ouvert / en attente** :
- **fc08::021** (#22) — ✅ VALIDÉE (CTO 23/10) + **ENREGISTRÉE** (vérifiée Chroma 2026-10-23 : top-hit récupéré +
  suivi_impl::001 à jour) · **bascule Render ACCOMPLIE** (GO PUSH CTO · merge "4d2985c1" — PR #77, CI 6/6 ·
  sondes **S-1..S-5 100 %** · "/health" 200 ×3 · 0 "ConfigurationError" · pas de rollback ; 1er S-5 500 =
  artifact de sonne d'agent — re-sonde 401) — dossier **CLOSED, non à rouvrir (CTO 23/10)** ;
- **prochaine session — première action (recommandation CTO 23/10)** : examiner l'état Git et le **périmètre
  exact de "chore/p6-coverage-plan"** (2 commits "b5960bef"/"b0375c75" — analyse couverture 1077 lignes + gate
  déterminisme) avant de choisir le chantier — **le BACKLOG ne suffit pas à prouver l'état réel de la branche** :
  distinguer intégrés vs à absorber par lecture Git ("main..chore/p6-coverage-plan") ;
- **cadre de reprise VALIDÉ CTO (23/10, clôture session)** : ordre d'ouverture = (1) gouvernance Git — fetch,
  compare, vérification de "270e5474", **push si l'état observé le justifie** + vérifier le re-déploiement Render
  (documentaire, attendu) — (2) investigation lecture seule "chore/p6-coverage-plan" vs "main" — (3) arbitrage CTO
  sur preuves ; **carte de candidats après ouverture** : #16 (priorité CTO historique)
  vs **#22-bis** (prolonge JWT — RED public → fix → certification) **en concurrence** pour le prochain créneau
  (pas de départage avant les contrôles Git) · #3 (D-3-3 — design à arbitrer) · #15 (Wave 4.5 — périmètre à
  délimiter) · #7-#10 (distinguer besoins démontrés vs non-mesurés) · **FC-09** : décision à partir de
  "docs/ROADMAP.md" + valeur métier, jamais un pourcentage · hygiènes/options : passe cosmétique documentaire +
  mini-audit #18 ;
- **#29 — passe « zéro-warnings » (O-2) — ✅ CLOSED (24/10)** : les 20 renames + les runners ubuntu-24.04 + le variant_processor — le merge `679ea3ad`, le health 200 ×5 ; **R-2 SimpleCov différé = un chantier séparé** (le verrou P6.1 intact — le déterminisme ×2 sera exigé avant/après si l'arbitrage retient le chantier) ;
- **#2 — absorption chore/p6-coverage-plan** : ✅ **CLOSED (24-25/10)** — arbitrage **O-2** rendu ; absorption mergée PR #82 (`97d85eec`) · incident-CI corrigé `aedd70e4` (CI 6/6, run 40121939127) et archivé (tracker P6 §7 — PR #83, `4928d00`) · mémoire fc08::022 (PR #85, `81726806`) · réconciliation docs (#86, `4b3781fb`) · réconcils trackers 20/09 en cours (la présente passe) — détail : BACKLOG #2 + tracker P6 §7 ;
- **#22-bis** — claim standard `exp` des refresh tokens (dette C-0 tracée à #22) — **chantier indépendant** ;
- corrections cosmétiques documentaires (titres/en-têtes d'audits — la présente passe) ;
- backlog transverse historique (#1, #3, #4, #5, #6, #7-#10, #15, #16, #18) —
  **#22 sorti ; #13/#17 sortis (livrés — mini-PR "8e65a52f", 23/10)**.