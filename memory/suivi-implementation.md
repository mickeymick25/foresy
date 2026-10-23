<!-- category: foresy -->

# Suivi d'avancement de l'implémentation

<!-- created: 2026-10-03 -->
<!-- updated: 2026-10-23 -->

## suivi_impl::001
<!-- created: 2026-10-03 -->
<!-- updated: 2026-10-23 -->
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
| suivi_impl::001 | **#28 — prévention structurelle ledger** : isolation stub_const ×6 (les overlays singleton inerts) + garde INV-D12-03 fail-fast (avant tout Git-call) + W3-D2 aligné | ✅ **CERTIFIÉE (2026-10-03)** — RED ×2 → GREEN ×2 · batch ledger 72/0 · suite 1137/0 · ledger réel inchangé (1 commit) · purge #24 non touchée | cadrage `[DONE]_2026_10_03_28_ledger_prevention_cadrage.md` (§6 journal) · fc08::020 proposée |

**Métriques de référence (2026-10-23, post mini-PR "8e65a52f")** : suite **1148/0** · couverture **86,26 % lignes / 61,03 % branches**
· RuboCop **249 files / 0** · RSwag **437 (mesuré) · audit 36/36** · Brakeman 0 · Zeitwerk OK · bundle audit 0 vulnérabilité ·
verrou 72,5 · CI 6/6 · production : **bascule #22 effective (merge "4d2985c1" — PR #77) + mini-PR mergée ("8e65a52f")** —
`main` = `origin/main` — hub : knowledge **2500 chunks** · mémoires **22**.

**Ouvert / en attente** :
- **fc08::021** (#22) — ✅ VALIDÉE (CTO 23/10) + **ENREGISTRÉE** (vérifiée Chroma 2026-10-23 : top-hit récupéré +
  suivi_impl::001 à jour) · **bascule Render ACCOMPLIE** (GO PUSH CTO · merge "4d2985c1" — PR #77, CI 6/6 ·
  sondes **S-1..S-5 100 %** · "/health" 200 ×3 · 0 "ConfigurationError" · pas de rollback ; 1er S-5 500 =
  artifact de sonne d'agent — re-sonde 401) — dossier **CLOSED, non à rouvrir (CTO 23/10)** ;
- **prochaine session — première action (recommandation CTO 23/10)** : examiner l'état Git et le **périmètre
  exact de "chore/p6-coverage-plan"** (2 commits "b5960bef"/"b0375c75" — analyse couverture 1077 lignes + gate
  déterminisme) avant de choisir le chantier — **le BACKLOG ne suffit pas à prouver l'état réel de la branche** :
  distinguer intégrés vs à absorber par lecture Git ("main..chore/p6-coverage-plan") ;
- **#22-bis** — claim standard `exp` des refresh tokens (dette C-0 tracée à #22) — **chantier indépendant** ;
- corrections cosmétiques documentaires (titres/en-têtes d'audits — la présente passe) ;
- backlog transverse historique (#1-#10, #15, #16) + `chore/p6-coverage-plan` (arbitrage P1/hygiène) —
  **#22 sorti; #13/#17 sorti (livrés — mini-PR "8e65a52f", 23/10)**.