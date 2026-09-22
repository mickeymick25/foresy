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
| Campagne couverture P6 (verrou, trajectoire) | `docs/technical/testing/[DONE]_2026_09_17_coverage_campaign_p6.md` |
| Contrat système P7 (system specs, CLOSED) | `docs/technical/testing/[DONE]_2026_09_22_p7_tracker.md` |
| Historique des états | hub RAG local (`foresy__knowledge` / `foresy__memories`) — index, pas backlog |

## Chantiers ouverts (état au 2026-09-22)

| # | Chantier | Priorité | Suivi / source |
|---|---|---|---|
| 1 | Mini-PR **P1** — specs du mécanisme de détection du contexte RSpec/coverage | 🟠 recommandée, non bloquante | tracker hygiène §2 · campagne P6 |
| 2 | Audit `chore/p6-coverage-plan` (`scripts/coverage_gap_analysis.rb` absent de main) — absorber dans P1 ou fermer | 🟠 arbitrage CTO en attente | tracker hygiène §2 |
| 3 | **D3-3** — couches d'erreur vivantes des contrôleurs (~76 lignes, ~15-20 specs requête) | 🟠 reporté post-Wave 4 | tracker Wave 1 §6 G4 |
| 4 | Verrou couverture **72,5 maintenu** — trajectoire 90 (palier décisionnel) → 95 (P6.6) — **90 % non requis, arbitrage CTO 21/09** | 🟠 contractuel | campagne P6 · tracker Wave 4 §P6.6 |
| 5 | Arbitrage **`handle_user_error`** (observation stricte — pas de cycle RED, divergence non démontrée) | 🟢 documenté | tracker Wave 2 §4/W2-D4 |
| 6 | **E2E OAuth** avec credentials de test (nécessite credentials de test) | 🟠 important | archive BACKLOG 2025-12-26 §Tests E2E |
| 7 | **Alerting production** minimal / monitoring proactif | 🟠 | archive BACKLOG 2025-12-26 §Tests E2E |
| 8 | Chore **link-rot** — réparation des ~114 liens pré-existants (réorganisation 2026-01) | 🟢 recommandé | tracker hygiène §5 (E3-bis) |
| 9 | Performance — < 100 ms sur les endpoints authentifiés | 🟢 | BRIEFING Future Improvements |
| 10 | Monitoring avancé Prometheus/Grafana ; Datadog Synthetics | 🟢 | BRIEFING Future Improvements · archive BACKLOG |
| 12 | **Hardening CI — validation de l'arbre mergé** : RED EXP-1 exécuté (2 preuves : la CI `pull_request` teste le **merge result** ; synchronize régénère le merge ref avec la base courante) → arbitrage CTO : correction **`strict: true`** appliquée via UI (22/09) — GREEN comportemental en cours | 🟠 hardening — **en cours de certification** | `docs/technical/2026_09_22_backlog12_merged_tree_tracker.md` · `ci.yml` L316/L483 |
| 13 | **OAuth callback — divergence contrat ↔ schéma RSwag** : `format_success_response` inclut `name` dans le payload user (découvert par W2-D3, caractérisé sans correction produit) — le schéma RSwag `oauth_spec.rb` ne le déclare pas. **Arbitrage ultérieur** : soit `name` fait partie du contrat → RSwag corrigé, soit la réponse production est modifiée — ne pas laisser les deux contrats diverger durablement | 🟠 correction de contrat | revue CTO 20/09 (PR #39) · tracker Wave 2 (3) |
| 14 | **`Cra#validate_uniqueness` inerte à la création** : à la création, le pivot `user_cras` (rôle créateur) n'existe pas encore (créé post-insert par la factory/le flux) → `creator_user_id` nil → le garde Ruby ne s'exerce pas ; il ne protège qu'à la re-validation/update. Comportement démontré et documenté (W3-D4). **Point d'architecture** : le nom du garde laisse croire qu'il protège la création ; traiter séparément (contrainte DB ou recalage de l'ordre pivot/validation) | 🟡 WARNING / dette architecture | revue CTO PR #40 · tracker Wave 3 |
| 15 | **Wave 4.5** — ~280 lignes contrôleur/concerns (~30-40 specs estimées) — dette de couverture quantifiée (P6.6 Assessment §5), distincte, non bloquante | 🟢 distinct | assessment P6.6 §5-§7 · arbitrage CTO 21/09 |

## Chantiers livrés (référence)

| # | Chantier | Clôture | Source de vérité |
|---|---|---|---|
| — | **Branch protection** (ex-#11 de cette table, ex-#13 de la numérotation P6) — 6 checks requis + `enforce_admins: true` sur `main` · PR de contrôle #43 (`blocked` → `clean` certifié, 6/6 SUCCESS) | 22/09/2026 | `docs/technical/[DONE]_2026_09_22_backlog13_branch_protection_tracker.md` |

## Métriques de qualité (état au 2026-09-22 — post PR #42, P7 mergée)

- **Suite RSpec : 1154 exemples, 0 échec** (mesuré 22/09, `foresy_test`)
- **SimpleCov : 84,37 % lignes (3121/3699) · 57,74 % branches (902/1562)** — verrou CI 72,5 armé
- **RuboCop 0 offense · Brakeman 0 warning** (CI 6/6 sur PR #42)
- **Contrat système** : 4 system specs (P7 CLOSED — bug de composition mission_id corrigé, 3 propriétés caractérisées)

## Règle anti-drift

1. Ce fichier **pointe** les sources canoniques, il ne les recopie pas.
2. Toute métrique est **datée** ; toute entrée cite sa source de suivi.
3. Mise à jour à chaque **état substantiel** (règle mémoire du projet) ; les items livrés
   quittent la table (l'historique vit dans git + le hub).
4. Le hub RAG indexe ce fichier — le garder court et frais protège la qualité de l'index.