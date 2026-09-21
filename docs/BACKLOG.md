ÉTAT COURANT

# 📋 Backlog transverse — Foresy

**Rôle (décision CTO du 2026-09-20, évoluant la décision 2.2 du 2026-09-10)** : le BACKLOG
reprend un rôle de **backlog transverse** — les chantiers actionnables non couverts par les
sources canoniques ci-dessous. L'ancien backlog (2025-12-26) est archivé :
`[Obsolete]_2025_12_26_BACKLOG.md`.

## Sources canoniques (ce fichier ne les duplique pas)

| Domaine | Source de vérité |
|---|---|
| Roadmap produit (versions, Feature Contracts) | `docs/ROADMAP.md` (décision 2.2, 2026-09-10) |
| Dette technique (D-1…D-12) | `docs/technical/2026_09_14_fc08_debt_register.md` |
| Campagne couverture P6 (verrou, trajectoire) | `docs/technical/testing/2026_09_17_coverage_campaign_p6.md` |
| Historique des états | hub RAG local (`foresy__knowledge` / `foresy__memories`) — index, pas backlog |

## Chantiers ouverts (état au 2026-09-20)

| # | Chantier | Priorité | Suivi / source |
|---|---|---|---|
| 1 | **Wave 2** — caractérisation `OAuthCodeExchangeService` (W2-D2 GO) | 🔴 active | `docs/technical/testing/2026_09_20_p6_wave2_tracker.md` |
| 2 | Mini-PR **P1** — specs du mécanisme de détection du contexte RSpec/coverage | 🟠 recommandée, non bloquante | tracker hygiène §2 · campagne P6 |
| 3 | Audit `chore/p6-coverage-plan` (`scripts/coverage_gap_analysis.rb` absent de main) — absorber dans P1 ou fermer | 🟠 arbitrage CTO en attente | tracker hygiène §2 |
| 4 | **D3-3** — couches d'erreur vivantes des contrôleurs (~76 lignes, ~15-20 specs requête) | 🟠 reporté post-Wave 2 | tracker Wave 1 §6 G4 |
| 5 | Verrou couverture **72,0 → 72,5** (post-gates W2-D2+D3) → trajectoire 90 (palier décisionnel) → 95 (P6.6) | 🟠 contractuel | campagne P6 · tracker Wave 2 §7 |
| 6 | Arbitrage **`handle_user_error`** (observation stricte pendant W2-D2/D3 ; cycle RED si divergence démontrée) | 🔴 conditionnel | tracker Wave 2 §4/W2-D4 |
| 7 | **E2E OAuth** avec credentials de test (nécessite credentials de test) | 🟠 important | archive BACKLOG 2025-12-26 §Tests E2E |
| 8 | **Alerting production** minimal / monitoring proactif | 🟠 | archive BACKLOG 2025-12-26 §Tests E2E |
| 9 | Chore **link-rot** — réparation des ~114 liens pré-existants (réorganisation 2026-01) | 🟢 recommandé | tracker hygiène §5 (E3-bis) |
| 10 | Drift doc — `ROADMAP.md` ne marque pas FC-08 ✅ (README v0.1.1 : terminé, PR #24) | 🟢 sync doc | relevé session 20/09 |
| 11 | Performance — < 100 ms sur les endpoints authentifiés | 🟢 | BRIEFING Future Improvements |
| 12 | Monitoring avancé Prometheus/Grafana ; Datadog Synthetics | 🟢 | BRIEFING Future Improvements · archive BACKLOG |
| 13 | **Hardening CI — branch protection** : `main` protégée mais `required_status_checks` vide + `enforcement_level: off` (API GitHub vérifiée 20/09) — configurer les 6 checks requis pour rendre la règle « CI verte = merge » contraignante | 🟠 gouvernance | API `branches/main` · analyse E2E CTO 20/09 |
| 14 | **Hardening CI — validation de l'arbre mergé** : l'E2E est `skipped` hors PR (`ci.yml` L316) → l'arbre réellement mergé n'est jamais testé E2E en combinaison (précédent D-8). Options CTO : (1) `merge_group`/merge queue — préféré, (2) smoke post-merge léger sur push main (health + auth + non-destructif + alerte), (3) E2E complet sur main (cher, arbitrage explicite requis) | 🟠 hardening | analyse E2E CTO 20/09 · `ci.yml` L316/L483 |

## Métriques de qualité (état au 2026-09-20 — post PR #37, PR obsolete en cours)

- **Suite RSpec : 977 exemples, 0 échec** (mesuré 20/09, `foresy_test`)
- **SimpleCov : 77,18 % lignes (2815/3647) · 47,87 % branches (756/1579)** — verrou CI 72,0
- **RuboCop 0 offense · Brakeman 0 warning** (gates Wave 1 du 19/09, CI 6/6 sur PR #37)

## Règle anti-drift

1. Ce fichier **pointe** les sources canoniques, il ne les recopie pas.
2. Toute métrique est **datée** ; toute entrée cite sa source de suivi.
3. Mise à jour à chaque **état substantiel** (règle mémoire du projet) ; les items livrés
   quittent la table (l'historique vit dans git + le hub).
4. Le hub RAG indexe ce fichier — le garder court et frais protège la qualité de l'index.