# 🧹 Cadrage — Passe « Zéro-Warnings » (R-1…R-5)

**Date :** 24 octobre 2026
**Auteur :** Zed Agent (mandat CTO 24/10 : « *la CI est verte, mais je vois beaucoup de warnings dans les logs ; j'aimerai qu'on corrige* » + « *documente ton plan d'action, intègre s'y un suivi d'avancement, mets à jour la documentation* »)
**Statut :** 🕓 **CADRAGE PRÉSENTÉ — exécution après arbitrage option (T2)** — quantification mesurée, périmètres
qualifiés, verrou P6.1 identifié comme la seule contrainte délicate
**Périmètre autoritaire :** mesure locale des sorties de runs (24/10) · ci.yml (6 jobs) · `.simplecov` (verrou P6.1)
· inventaire greps exacts des usages
**Règle (CTO, héritée) :** les corrections = mécaniques/sans changement fonctionnel ; le verrou P6.1 de couverture
doit sortir INTACT de toute migration (preuve : déterminisme ×2).

---

## 1. Quantification mesurée (les 5 familles)

| # | Famille | Volume mesuré | Source précise | Type |
|---|---|---|---|---|
| **R-1** | RSpec/Rack : `:unprocessable_entity` → `:unprocessable_content` (matchers `have_http_status`) | **35 usages / 16 files** (inventaire §1.1) + **60 usages app/config** (à qualifier : renders/runtime vs helpers) | `grep -rc` — 16 spec files listés ; app/config 60 hits | Déprecation Rack 3.x — les 422 fonctionnels identiques |
| **R-2** | SimpleCov configuration dépréciée dans `.simplecov` | **10 warnings par boot** : `SimpleCov.start` ×1 + `add_filter` ×6 + `add_group` ×3 — ×3 jobs CI qui bootent RSpec | `.simplecov` L12-30 | API migration (`start` → coverage_boot ; `add_filter` → `skip` ; `add_group` → `group`) |
| **R-3** | Runner GitHub migrant | **1 notice/job (×6)** : « ubuntu-latest → Ubuntu 26 dès le 19/10/2026 » | ci.yml : 6× `runos-on: ubuntu-latest` | figer → `ubuntu-24.04` (6 edits) — **suspecte n°1 de la fragilité du job security 24/10** |
| **R-4** | ActiveStorage notice | 1/boot : « image_processing gem missing » | runtime notice | 1 ligne : `config.active_storage.variant_processor = :disabled` (API-only, inutilisé) |
| **R-5** | dotenv notices (Set/Loaded) | 3-4/boot | informatifs — pas silenciables sans désactiver dotenv | **hors périmètre** (légitime, consigné) |

## 1.1 Inventaire exact des 16 spec files (R-1)

```
spec/requests/api/v1/cras/cra_error_handlers_spec.rb        (6)
spec/requests/api/v1/companies/companies_spec.rb            (4)
spec/lib/cra_errors_spec.rb                                 (4)
spec/services/mission_services/update_spec.rb               (4)
spec/requests/api/v1/authentication/oauth_code_exchange_spec.rb (3)
spec/services/cra_services/lifecycle_spec.rb                (2)
spec/requests/api/v1/user_companies/user_companies_spec.rb  (2)
spec/requests/api/v1/cras/create_spec.rb                    (2)
spec/requests/api/v1/cra_entries/update_spec.rb             (1)
spec/requests/api/v1/cra_entries/create_spec.rb             (1)
spec/requests/api/v1/cras/update_spec.rb                    (1)
spec/requests/api/v1/cras/submit_spec.rb                    (1)
spec/requests/api/v1/cras/uniqueness_creation_invariant_spec.rb (1)
spec/requests/api/v1/missions/create_client_company_error_spec.rb (1)
spec/system/cra_multi_missions_system_spec.rb               (1)
spec/integration/test_support_routes_security_spec.rb       (1)
```

## 2. Options pour arbitrage (T2)

| Option | Périmètre | Risque | Verrou P6.1 |
|---|---|---|---|
| **O-1 — Passe complète** (recommandée) | R-1 (35 renames) + R-2 (migration `.simplecov` complète) + R-3 (runner figé ×6) + R-4 (1 ligne config) | moyen — le verrou = le point délicat | **préservé par migration contrôlée** : `.simplecov` = config only ; le `SimpleCov.start` migre dans `spec/coverage_boot.rb` ; le bloc `at_exit` **reste dans `.simplecov`** (évalué au `require 'simplecov'`, AVANT le start ⇒ l'ordre LIFO documenté du verrou est **préservé mécaniquement** : le at_exit verrou s'enregistre toujours APRÈS celui de SimpleCov, il s'exécute toujours AVANT) ; preuve = déterminisme ×2 |
| **O-2 — Mécanique seule** | R-1 + R-3 + R-4 | très faible | non touché (le verrou reste tel quel) ; **R-2 reste** (10 warnings/boot) — migration reportée à un chantier dédié |
| **O-0 — Statu quo tracé** | rien | nul | intacts ; mais les ruptures à venir restent (SimpleCov futur, Rack futur) |

**Sub-question arbitrage (R-1bis)** : les **60 usages app/config** : qualifier si les symbol renders émettent
aussi le warning Rack au runtime (les spec : l'utilisateur des matchers = certain) — si oui : le renamement
s'étend à app (le rendu = les mêmes 422) ; si non : hors périmètre (le code app = inchangé). Qualification =
T3 première mesure (le run ciblé avant/après).

## 3. 📊 Suivi d'implémentation (T1-T6) — source de progression « zéro-warnings »

> Règle anti-drift : mise à jour à chaque état substantiel ; statut `[DONE]_` du document = seulement après la
> certification complète (T4) et le re-deploy vérifié (T5) + la vérification Chroma (T6).

| T | Étape | Entrée requise | Statut | Preuve attendue |
|---|---|---|---|---|
| **T1** | Quantification des familles (les 5 types + les inventaires exacts) | mandat CTO 24/10 | ✅ **TERMINÉE (24/10)** — ce document (§1, §1.1) | les greps + les runs mesurés |
| **T2** | **Arbitrage CTO** : option (O-1/O-2/O-0) + le sort de R-1bis (app/config : s'étendre ou pas) | ce cadrage | 🕓 **EN ATTENTE** | décision tracée ici + suivi_impl::001 + BACKLOG |
| **T3** | Exécution selon option **O-2 (GO CTO 24/10)** : renames ×20 matchers (les 35 quantifiés = 20 matchers + 7 eq/keys intacts + 8 textes — le blind-rename écarté par qualification) · runners ×6 → ubuntu-24.04 · variant_processor ×3 (l'absence d'usage confirmée : 0 app · 0 table — les 3 hits = les configs storage seuls) · **SimpleCov différé (O-2)** | GO T2 ✅ | ✅ **TERMINÉE (24/10)** — commit `28748ef3` sur `chore/zero-warnings` (depuis origin/main — le commit doc `a38787e1` non mélangé ✓) | diff 17 files (+35/−26 : 20 renames + 6 runners + 9 config) · les old matchers = 0 · les eq/keys = 7 intacts |
| **T4** | Certification : la suite complète · RuboCop 0 · brakeman 0 · **les warnings R-1 = 0** | T3 | ✅ **TERMINÉE (24/10)** | suite **1148/0** (seed 36475, 5m41) · couverture **86,26/61,03 inchangée** · RuboCop **249 files / 0** · le run ciblé post-fix : **0 ligne `:unprocessable_entity`** (avant = les 2 warnings/2 usages — le ratio 1/usage démontré) · les notices résiduelles = les R-2 différés (10/boot) + l'OID `pg_advisory_xact_lock` (informatif, hors périmètre) + dotenv (légitime) |
| **T5** | Push branche → PR → CI 6/6 → **merge (CTO)** → sync local → re-deploy Render **vérifié** (`/health` 200) | T4 | 🟡 **EN COURS** — branche `chore/zero-warnings` poussée (`28748ef3`) · PR = à ouvrir par le CTO (URL : /pull/new/chore/zero-warnings) | merge SHA + health réel |
| **T6** | Docs + hub : le BACKLOG #29 close · suivi_impl::001 · ce doc → `[DONE]_` · reindex hub + **vérification Chroma** | T5 | ⏸ **NON LANCÉE** | top-hit Chroma (date consignée) |

## 4. Rouges (non négociables)

- Le verrou P6.1 : le bloc `at_exit` (`.simplecov` L78-94) **ne bouge pas** — la comparaison des garde-fous
  (`--pattern`, files explicites, filtres) = la mécanique éprouvée ; la migration = le `start`/`filter`/`group`
  seuls, JAMAIS l'at_exit.
- Aucun changement fonctionnel : les 422 restent des 422 ; la CI reste 6/6 exigés ; RuboCop reste 0 offense.
- Le déterminisme ×2 du verrou (run complet ×2 avant / ×2 après = la même mesure) = la preuve de non-régression.
- Pas de Gemfile/lockfile touché (le crass bump = déjà livré et mergé — périmètre clos).

## 5. Références

- Fichiers : `.simplecov` (L12-30 config · L78-94 verrou) · `spec/coverage_boot.rb` · `.github/workflows/ci.yml` (6× runs-ons) · les 16 specs (§1.1) · `app/concerns/standardized_error.rb` (les codes) · `config/environments/test.rb`
- Runs de mesure : les exécutions locales 24/10 (les counts ci-dessus = greps + sorties de runs réels)
- Le contexte : la CI verte sur `1d80980d` (bump crass) · la notice runner Ubuntu 26 = 19/10/2026 (le suspect de la fragilité du job security du 24/10)

---
*Cadrage zéro-warnings — 0 modification de code à ce jour · T1 livrée · T2 = l'arbitrage CTO attendu.*