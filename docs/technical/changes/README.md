# 📝 Technical Changes Log

**Répertoire** : `docs/technical/changes/`  
**Objectif** : Historique chronologique des changements techniques majeurs  
**Dernière mise à jour** : 7 janvier 2026

---

## 🎯 Vue d'Ensemble

Ce dossier contient la documentation détaillée de tous les changements techniques significatifs apportés au projet Foresy. Chaque fichier documente un changement spécifique avec son contexte, son implémentation et ses impacts.

---

## 📅 Changements Récents (Janvier 2026)

| Date | Fichier | Description | Status |
|------|---------|-------------|--------|
| 2026-01-07 | [FC07_Mini-FC-02_CSV_Export](./2026-01-07-FC07_Mini-FC-02_CSV_Export.md) | Export CSV des CRAs | ✅ TERMINÉ |
| 2026-01-03 | [FC07_CRA_Implementation](./2026-01-03-FC07_CRA_Implementation.md) | Implémentation FC-07 CRA | ✅ TERMINÉ |
| 2026-01-03 | [Concerns_Architecture_Refactoring](./2026-01-03-Concerns_Architecture_Refactoring.md) | Refactoring architecture concerns | ✅ TERMINÉ |

---

## 📅 Changements Décembre 2025

### Feature Contracts

| Date | Fichier | Description | Status |
|------|---------|-------------|--------|
| 2025-12-31 | [FC06_Missions_Implementation](./2025-12-31-FC06_Missions_Implementation.md) | Implémentation FC-06 Missions | ✅ MERGED |
| 2025-12-28 | [FC05_Rate_Limiting_PR_Description](./2025-12-28-FC05_Rate_Limiting_PR_Description.md) | Rate Limiting FC-05 | ✅ TERMINÉ |

### Migration Rails 8.1.1

| Date | Fichier | Description | Status |
|------|---------|-------------|--------|
| 2025-12-26 | [Rails_8_1_1_Migration_Complete](./2025-12-26-Rails_8_1_1_Migration_Complete.md) | Migration Rails 8.1.1 | ✅ TERMINÉ |
| 2025-12-26 | [E2E_Revocation_Script](./2025-12-26-E2E_Revocation_Script.md) | Script E2E token revocation | ✅ TERMINÉ |
| 2025-12-25 | [Rails_8_1_1_Migration_Plan](./2025-12-25-Rails_8_1_1_Migration_Plan.md) | Plan de migration | ✅ TERMINÉ |

### Sécurité & OAuth

| Date | Fichier | Description | Status |
|------|---------|-------------|--------|
| 2025-12-24 | [Production_Errors_500_Fix](./2025-12-24-Production_Errors_500_Fix.md) | Fix erreurs 500 production | ✅ TERMINÉ |
| 2025-12-23 | [OmniAuth_Session_Middleware_Fix](./2025-12-23-OmniAuth_Session_Middleware_Fix.md) | Fix middleware OmniAuth | ✅ TERMINÉ |
| 2025-12-23 | [CI_Rubocop_Standards_Configuration_Fix](./2025-12-23-CI_Rubocop_Standards_Configuration_Fix.md) | Fix CI/RuboCop | ✅ TERMINÉ |
| 2025-12-22 | [Datadog_APM_Standardization_Resolution](./2025-12-22-Datadog_APM_Standardization_Resolution.md) | Standardisation Datadog APM | ✅ TERMINÉ |

### Infrastructure & CI/CD

| Date | Fichier | Description | Status |
|------|---------|-------------|--------|
| 2025-12-20 | [Migrations_Consolidation](./2025-12-20-Migrations_Consolidation.md) | Consolidation migrations | ✅ TERMINÉ |
| 2025-12-20 | [Security_Gems_Update](./2025-12-20-Security_Gems_Update.md) | Mise à jour gems sécurité | ✅ TERMINÉ |
| 2025-12-19 | [Zeitwerk_OAuth_Services_Rename](./2025-12-19-Zeitwerk_OAuth_Services_Rename.md) | Renommage services OAuth | ✅ TERMINÉ |
| 2025-12-18 | [CI_Fix_Resolution](./2025-12-18-CI_Fix_Resolution.md) | Résolution problèmes CI | ✅ TERMINÉ |

---

## 📁 Organisation des Fichiers

### Convention de Nommage

```
YYYY-MM-DD-Description_Courte.md
```

Exemples :
- `2026-01-07-FC07_Mini-FC-02_CSV_Export.md`
- `2025-12-31-FC06_Missions_Implementation.md`
- `2025-12-26-Rails_8_1_1_Migration_Complete.md`

### Structure d'un Changelog

Chaque fichier doit contenir :
1. **Résumé** : Description courte du changement
2. **Contexte** : Pourquoi ce changement était nécessaire
3. **Implémentation** : Détails techniques
4. **Tests** : Tests ajoutés/modifiés
5. **Impact** : Effets sur le système
6. **Validation** : Commandes pour vérifier

---

## 🏷️ Tags de Catégorie

| Tag | Description |
|-----|-------------|
| `FC-XX` | Feature Contract (numéroté) |
| `Mini-FC` | Enhancement d'un FC existant |
| `Migration` | Migration Rails ou DB |
| `Security` | Changement de sécurité |
| `CI/CD` | Infrastructure CI/CD |
| `Fix` | Correction de bug |
| `Refactor` | Refactoring technique |

---

## 📊 Statistiques

| Période | Nombre de changements |
|---------|----------------------|
| Janvier 2026 | 3+ |
| Décembre 2025 | 20+ |
| Total | 23+ |

---

## 🔗 Références

- [BRIEFING.md](../../BRIEFING.md) - État actuel du projet
- [BACKLOG.md](../../BACKLOG.md) - Roadmap produit
- [FC-07 Documentation](../fc07/README.md) - Documentation CRA

---

*Index créé : 7 janvier 2026*