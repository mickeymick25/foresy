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
| Script e2e_revocation.sh | ✅ | Terminé (Platinum Level) | `bin/e2e/e2e_revocation.sh` - CTO approved, security model documented |
| Workflow GitHub Actions (e2e.yml) | 🟠 | À créer | Exécution automatique des tests |
| Tests E2E OAuth avec credentials | 🟢 | À faire | Nécessite credentials de test |
| Intégration Datadog Synthetics | 🟢 | À faire | Monitoring externe |
| Alerting sur échec E2E | 🟢 | À faire | Notifications Slack/Email |

---

## 📊 Monitoring & Observabilité

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| APM Service (Datadog) | ✅ | Terminé | Configuré |
| Health check endpoint | ✅ | Terminé | `/up` |
| Dashboard monitoring E2E | 🟢 | À faire | Visualisation des résultats |
| Métriques YJIT performance | 🟢 | À faire | Tracking post-migration |
| Alertes production | 🟠 | À configurer | Seuils à définir |

---

## 🔐 Sécurité

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| Brakeman (scan vulnérabilités) | ✅ | Terminé | 0 vulnérabilités |
| Bundle audit | ✅ | Terminé | Intégré CI |
| CSRF protection | ✅ | Terminé | State validation |
| Rate limiting | 🟠 | À faire | Protection brute force |
| Audit logs | 🟢 | À faire | Traçabilité actions |

---

## 🏗️ Infrastructure

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| Dockerfile multi-stage | ✅ | Terminé | 5 stages (Gold Level) |
| Docker Compose profils | ✅ | Terminé | test, tools |
| CI/CD GitHub Actions | ✅ | Terminé | Opérationnel |
| CD Render | ✅ | Terminé | Déploiement auto |
| Environnement staging | 🟠 | À configurer | Pré-prod dédié |
| Kubernetes migration | 🟢 | Futur | Si scaling nécessaire |

---

## 📚 Documentation

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| API Swagger/Rswag | ✅ | Terminé | 66 specs |
| Guide migration Rails 8 | ✅ | Terminé | `docs/technical/migrations/` |
| Plans déploiement/rollback | ✅ | Terminé | `docs/technical/deployment/` |
| Documentation OAuth flow | ✅ | Terminé | `docs/technical/guides/` |
| Guide contribution | 🟢 | À faire | CONTRIBUTING.md |
| Architecture Decision Records | 🟢 | À faire | ADR format |

---

## 🚀 Features Métier (Foresy)

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| *À définir* | 🔴 | Backlog | En attente feature contracts |

> ⚠️ **Note** : Les features métier de Foresy ne sont pas encore définies. 
> Le versioning actuel (`v0.0.x`) reflète cette situation.
> La `v1.0.0` sera créée lors de la première release avec features métier.

---

## 📅 Historique des Releases

| Version | Date | Description |
|---------|------|-------------|
| v0.0.1 | 26 Dec 2025 | Rails 7.1.5.1 / Ruby 3.3.0 - Pre-migration baseline |
| v0.0.2 | 26 Dec 2025 | Rails 8.1.1 / Ruby 3.4.8 baseline |

---

## 📝 Notes

- Ce backlog est maintenu manuellement
- Les priorités sont réévaluées à chaque sprint
- Les features métier seront ajoutées via Feature Contracts