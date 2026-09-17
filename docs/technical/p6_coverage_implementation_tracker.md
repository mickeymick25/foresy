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
| **P6.1** | **Verrou anti-régression** : `minimum_coverage line: 72.5` dans `.simplecov` | Non-régression | Suite 957/0 avec verrou actif ; la CI échoue sous 72.5 % | ⬜ |
| **P6.2 — Wave 1** | Sécurité & erreurs critiques : `access_validation` (77 l., 0/46 branches !), error_handlers cras/cra_entries, `standardized_error` | **Intégration** (request specs 403/404/422/409) | Suite verte (957+ nouvelles) ; re-mesure documentée ; RuboCop 0 ; CI 6/6 | ⬜ |
| **P6.3 — Wave 2** | Extraction/formatage + rate limiting + OAuth : parameter_extractors ×3, response_formatters ×2, rate_limitables ×3, `o_auth_concern`, o_auth services | **Intégration** (429, params invalides) + **unitaire** (services OAuth) | Idem + verrou relevé à la valeur re-mesurée − 0.3 | ⬜ |
| **P6.4 — Wave 3** | Services & lib unitaires + contrôleurs + models : `CraServices::List` (filtres), `git_ledger_service`, `application_result`, `cra_errors`, models marge | **Unitaire** + intégration ledger | Idem | ⬜ |
| **P6.5 — Wave 4** | Marges fines (~40 fichiers ≤ 10 l.) → cible finale | Mixte | Cible atteinte (90 ou 95 % — décision P6.6) | ⬜ |
| **P6.6** | **Décision finale du seuil** + verrou branche éventuel | Non-régression | Décision CTO documentée au registre/chiffrage | ⬜ |
| **P6.7** | Clôture : registre/guide/README métriques finales, réindexation hub | — | Hub vérifié par requête | ⬜ |

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

1. **Verrou initial** : `minimum_coverage line: 72.5` — recommandé (baseline 72.78, marge fine)
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

## 8. Références

- Analyse P6.0 : `docs/technical/changes/2026-09-17-P6_Coverage_Gap_Analysis.md`
- Baseline & guide : `docs/technical/testing/line_coverage.md`
- Suivi D-2 (P6 hérité) : `docs/technical/d2_simplecov_implementation_tracker.md`
- Chiffrage D-2 : `docs/technical/changes/2026-09-16-D2_SimpleCov_Chiffrage.md`