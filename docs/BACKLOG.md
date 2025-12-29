# 📋 Backlog - Foresy

**Dernière mise à jour** : 26 décembre 2025 (soir) - Platinum Level

---

## 🎯 Légende

| Priorité | Description |
|----------|-------------|
| 🔴 | Haute - À traiter rapidement |
| 🟠 | Moyenne - Planifié |
| 🟢 | Basse - Nice to have |
| ✅ | Terminé |

---

## 🧪 Tests E2E

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| Scripts smoke_test.sh | ✅ | Terminé | `bin/e2e/smoke_test.sh` |
| Scripts e2e_auth_flow.sh | ✅ | Terminé | `bin/e2e/e2e_auth_flow.sh` |
| Documentation guide E2E | ✅ | Terminé | `docs/technical/testing/e2e_staging_tests_guide.md` |
| Script e2e_revocation.sh | ✅ | Terminé (EN PRODUCTION) | `bin/e2e/e2e_revocation.sh` - Merged into main, Platinum Level, security model documented |
| Workflow GitHub Actions (e2e.yml) | 🔴 | Critique | Exécution automatique des tests E2E (gouvernance) |
| Tests E2E OAuth avec credentials | 🟢 | À faire | Nécessite credentials de test |
| OAuth E2E avec credentials | 🟠 | Important | Tests OAuth automatisés (quand credentials prêts) |
| Alerting prod minimal | 🟠 | Important | Monitoring proactif production |
| Datadog Synthetics | 🟢 | Plus tard | Monitoring externe (quand produit vit) |
| Alerting sur échec E2E | 🟢 | Plus tard | Notifications Slack/Email (quand produit vit) |

---

## 📊 Monitoring & Observabilité

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| APM Service (Datadog) | ✅ | Terminé | Configuré |
| Health check endpoint | ✅ | Terminé | `/up` |
| Dashboard monitoring E2E | 🟢 | Plus tard | Visualisation des résultats (quand produit vit) |
| Métriques YJIT performance | 🟢 | Plus tard | Tracking post-migration (quand produit vit) |
| Alertes production | 🟠 | À configurer | Seuils à définir |

---

## 🔐 Sécurité

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| Brakeman (scan vulnérabilités) | ✅ | Terminé | 0 vulnérabilités |
| Bundle audit | ✅ | Terminé | Intégré CI |
| CSRF protection | ✅ | Terminé | State validation |
| Rate limiting | ✅ | Terminé | Feature Contract 05 - Protection brute force implémentée (/login: 5/min, /signup: 3/min, /refresh: 10/min) |
| Refresh-token revocation E2E | 🟠 | Important | Extension script revocation actuel |
| Audit logs | 🟢 | Plus tard | Traçabilité actions (quand produit vit) |

---

## 🏗️ Infrastructure

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| Dockerfile multi-stage | ✅ | Terminé | 5 stages (Gold Level) |
| Docker Compose profils | ✅ | Terminé | test, tools |
| CI/CD GitHub Actions | ✅ | Terminé | Opérationnel |
| CD Render | ✅ | Terminé | Déploiement auto |
| Environment staging | 🟠 | Important | Pré-prod dédié (pour Feature Contracts) |
| Git Workflow Feature Contract | ✅ | Établi | Workflow optimal : main + feature branches temporaires |
| Repository State | ✅ | Optimal | 1 branche (main) + branches Feature Contract temporaires |
| Kubernetes migration | 🟢 | Plus tard | Si scaling nécessaire (quand produit vit) |

---

## 📚 Documentation

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| API Swagger/Rswag | ✅ | Terminé | 66 specs |
| Guide migration Rails 8 | ✅ | Terminé | `docs/technical/migrations/` |
| Plans déploiement/rollback | ✅ | Terminé | `docs/technical/deployment/` |
| Documentation OAuth flow | ✅ | Terminé | `docs/technical/guides/` |
| Guide contribution | 🟢 | Plus tard | CONTRIBUTING.md (quand équipe grandit) |
| Architecture Decision Records | 🟢 | Plus tard | ADR formels (quand produit vit) |

---

## 🚀 Features Métier (Foresy)

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| *À définir* | 🔴 | Backlog | En attente feature contracts |

> ⚠️ **Note** : Les features métier de Foresy ne sont pas encore définies. 
> Le versioning actuel (`v0.0.x`) reflète cette situation.
> La v1.0.0 sera créée lors de la première release avec features métier.
> 
> ✅ **Prêt techniquement** : Infrastructure optimale établie (main + workflow Feature Contract)
> ❌ **Pas encore prêt produit** : Absence de Feature Contract métier = risque de stagnation
> 🚀 **PROCHAINE ÉTAPE ABSOLUE** : Créer le premier Feature Contract (même trivial, même moche, mais RÉEL) |

---

## 📅 Historique des Releases

| Version | Date | Description |
|---------|------|-------------|
| v0.0.1 | 26 Dec 2025 | Rails 7.1.5.1 / Ruby 3.3.0 - Pre-migration baseline |
| v0.0.2 | 26 Dec 2025 | Rails 8.1.1 / Ruby 3.4.8 baseline |
| v0.0.3 | 26 Dec 2025 (soir) | E2E Token Revocation Script (Platinum Level) + Git cleanup |

---

## 📝 Notes

- Ce backlog est maintenu manuellement
- Les priorités sont réévaluées à chaque sprint
- Les features métier seront ajoutées via Feature Contracts