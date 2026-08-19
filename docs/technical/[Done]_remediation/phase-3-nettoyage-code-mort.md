# Phase 3 — Nettoyage du Code Mort

**Phase :** P3 — Nettoyage du Code Mort
**Priorité :** 🟡 Haute
**Statut phase :** ✅ Terminée
**Date de début :** 2026-08-18
**Date de fin prévue :** 2026-08-18
**Document parent :** [`docs/technical/audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md)

---

## 🎯 Objectif

Éliminer ~2700 lignes de code mort dans `app/lib` et les concerns orphelins.

## 🧪 Méthodologie TDD + DDD + Platinum

Chaque tâche suit le cycle **🔴 RED → 🟢 GREEN → 🔵 REFACTOR** en 3 commits distincts (voir [§1.3 du document principal](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#13-méthodologie-tdd--ddd--niveau-platinum)).

- 🔴 **RED** : Test assertion d'absence — `expect { SharedResultAdapter }.to raise_error(NameError)` après suppression attendue
- 🟢 **GREEN** : Suppression effective du fichier mort
- 🔵 **REFACTOR** : Vérification que Zeitwerk autoload toujours cohérent

**DDD** : Les fichiers supprimés sont des outils de migration (hors domaine). Aucun impact métier attendu.

**Critères Platinum** : `rake zeitwerk:check` ✅ + rspec ✅ + rubocop ✅ + grep absence de références ✅.

## 📋 Tâches

| ID | Tâche | Statut | PR | Notes |
|---|---|---|---|---|
| P3.1 | Supprimer code mort `app/lib` (~2700 lignes) | ⬜ | — | 5 fichiers |
| P3.2 | Supprimer concerns modèles orphelins | ⬜ | — | 3 fichiers |

---

## 📋 Inventaire du Code Mort

### P3.1 — Fichiers `app/lib` à supprimer

| Fichier | Lignes | Références externes | Action |
|---|---|---|---|
| `Foresy/app/lib/pundit.rb` | ~20 | À vérifier avec grep | Supprimer |
| `Foresy/app/lib/shared_result_adapter.rb` | ~410 | Référence `Shared::Result` inexistant | Supprimer |
| `Foresy/app/lib/shared_result_kill_switches.rb` | ~696 | À vérifier | Supprimer |
| `Foresy/app/lib/step3_reporting_system.rb` | ~1112 | À vérifier | Supprimer |
| `Foresy/app/lib/domain_leakage_detector.rb` | ~489 | À vérifier | Supprimer (ou déplacer vers `lib/tasks/` si utile en dev) |

**Commande de vérification :**
```bash
grep -r "SharedResultAdapter\|SharedResultKillSwitches\|Step3ReportingSystem\|DomainLeakageDetector\|Pundit" app/ config/ spec/
```

### P3.2 — Concerns modèles à supprimer

| Fichier | Lignes | `include` trouvés | Action |
|---|---|---|---|
| `Foresy/app/models/concerns/domain_driven.rb` | ~145 | 0 | Supprimer |
| `Foresy/app/models/concerns/soft_deletable.rb` | ~120 | 0 | Supprimer (réintroduction en P4.2 si besoin) |
| `Foresy/app/models/concerns/validatable.rb` | ~170 | 0 | Supprimer |

---

## 📝 Journal d'Exécution (TDD)

### 🔴 RED — 2026-08-18 — P3.1

- **Test ajouté :** `spec/integration/p3_1_dead_code_removal_spec.rb` (assertion d'absence `expect { SharedResultAdapter }.to raise_error(NameError)` × 5)
- **Invariant visé :** Aucune référence aux 5 classes mortes ; aucune référence dans `app/` ou `config/`
- **Raison de l'échec :** Les 5 fichiers existent encore dans `app/lib/`
- **Commit :** `test: P3.1 caracterise la suppression des 5 classes mortes app/lib`

### 🟢 GREEN — 2026-08-18 — P3.1

- **Implémentation minimale :** Suppression des 5 fichiers morts
- **Fichiers supprimés :** `app/lib/pundit.rb`, `app/lib/shared_result_adapter.rb`, `app/lib/shared_result_kill_switches.rb`, `app/lib/step3_reporting_system.rb`, `app/lib/domain_leakage_detector.rb`
- **Test passe ✅ :** 5 examples, 0 failures
- **Commit :** `chore: P3.1 supprime 5 fichiers morts app/lib (~2727 lignes)`

### 🔴 RED — 2026-08-18 — P3.2

- **Test ajouté :** `spec/integration/p3_2_orphan_concerns_removal_spec.rb` (assertion d'absence × 3)
- **Invariant visé :** Les 3 concerns orphelins ne sont plus autoloadables
- **Raison de l'échec :** Les 3 fichiers existent encore (aucun `include` mais toujours présents)
- **Commit :** `test: P3.2 caracterise la suppression des concerns orphelins`

### 🟢 GREEN — 2026-08-18 — P3.2

- **Implémentation minimale :** Suppression des 3 fichiers concerns orphelins
- **Fichiers supprimés :** `app/models/concerns/domain_driven.rb`, `app/models/concerns/soft_deletable.rb`, `app/models/concerns/validatable.rb`
- **Test passe ✅ :** 3 examples, 0 failures
- **Commit :** `chore: P3.2 supprime 3 concerns orphelins (~435 lignes)`

### 🎯 Merge — 2026-08-18

- **PR :** Branche `phase-3-dead-code-cleanup`
- **Validation Platinum :** zeitwerk:check ✅ / rspec ✅ / rubocop ✅
- **Lignes supprimées :** ~3162 (~2727 + ~435)
- **Notes :** Aucune référence aux fichiers supprimés dans `app/` ou `config/`

---

## ✅ Critères de Fin de Phase

- [ ] `bundle exec rake zeitwerk:check` passe
- [ ] Aucun fichier supprimé n'est référencé dans `app/` ou `config/`
- [ ] ~2700 lignes supprimées du codebase
- [ ] `bundle exec rspec` passe
- [ ] `bundle exec rubocop` passe

---

## 🔗 Références

- [Tâche P3.1 — Supprimer code mort `app/lib`](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p31--supprimer-le-code-mort-dans-applib)
- [Tâche P3.2 — Supprimer concerns orphelins](../audits/2026-07-22-Architecture_Debt_Audit_and_Plan.md#p32--traiter-les-concerns-modèles-orphelins)