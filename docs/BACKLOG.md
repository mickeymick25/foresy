# 📋 Backlog - Foresy

**Dernière mise à jour** : 6 janvier 2026 - FC-07 CRA ✅ **100% TERMINÉ**

---

## 🎯 Légende

| Priorité | Description |
|----------|-------------|
| 🔴 | Haute - À traiter rapidement |
| 🟠 | Moyenne - Planifié |
| 🟢 | Basse - Nice to have |
| ✅ | Terminé |

---

## 🧭 Roadmap Produit

```
v0.1.0 (Fondations métier)
 ├─ Feature Contract #06 — Missions (Projets) ✅ TERMINÉ
 ├─ Feature Contract #07 — CRA mensuel ✅ TERMINÉ
 ├─ Feature Contract #08 — Entreprise de l'indépendant
 └─ Feature Contract #09 — Notifications & alertes

v0.2.x (Extension)
 ├─ Feature Contract #07 — Rôles & visions
 └─ Feature Contract #08 — Pré-facturation

v0.3+ (Optimisation)
 ├─ Feature #10 — Versioning CRA avancé
 ├─ Feature #11 — Export PDF
 └─ Feature #12 — Historique & audit métier

v1.0.0 (MVP Production)
 └─ À définir après validation des fondations
```

---

## ✅ TERMINÉ — FONDATIONS MÉTIER

### Feature Contract #06 — Missions (Projets) ✅ TERMINÉ (31 Déc 2025)

🧱 **Fondation métier** — C'est le pivot de tout (CRA, facturation, TVA, reporting)

| Aspect | Détails |
|--------|---------|
| **Statut** | ✅ **MERGÉ** - PR #12 approuvée CTO (1 janvier 2026) |
| **Scope fonctionnel** | CRUD Mission complet |
| **Architecture** | Domain-Driven / Relation-Driven (tables dédiées) |
| **Types** | time_based (TJM), fixed_price (forfait) |
| **Lifecycle** | lead → pending → won → in_progress → completed |
| **Modèles** | Mission, MissionCompany, Company, UserCompany |
| **Tests** | 30 RSpec tests (100% passing) |
| **Qualité** | RuboCop 0 offense, Brakeman 0 vulnérabilité |
| **Swagger** | 119 specs générées |

> ✅ **Feature pivot livrée — CRA implémenté**

---

### Feature Contract #07 — CRA (Compte Rendu d'Activité) ✅ TERMINÉ (6 Jan 2026)

🧱 **Fondation métier** — Gestion des déclarations d'activité mensuelles

| Aspect | Détails |
|--------|---------|
| **Statut** | ✅ **100% TERMINÉ** - TDD PLATINUM |
| **Scope fonctionnel** | CRUD CRA + CRA Entries complet |
| **Architecture** | Domain-Driven / Service-Oriented (pas de callbacks) |
| **Lifecycle** | draft → submitted → locked (immutable) |
| **Modèles** | Cra, CraEntry, CraMission, CraEntryCra, CraEntryMission |
| **Services** | CreateService, UpdateService, DestroyService, ListService |
| **Tests** | ✅ **50 tests services + 9 tests legacy = 59 tests TDD Platinum** |
| **Qualité** | Zeitwerk OK, RuboCop OK, Brakeman 0 vulnérabilité |
| **Documentation** | `docs/technical/fc07/` - Documentation complète |

**Phases Complétées (3-6 Jan 2026) :**

| Phase | Description | Tests | Status |
|-------|-------------|-------|--------|
| Phase 1 | CraEntry Lifecycle + CraMissionLinker | 6/6 ✅ | TDD PLATINUM |
| Phase 2 | Unicité Métier (cra, mission, date) | 3/3 ✅ | TDD PLATINUM |
| Phase 3A | Legacy Tests Alignment | 9/9 ✅ | TDD PLATINUM |
| Phase 3B.1 | Pagination ListService | 9/9 ✅ | TDD PLATINUM |
| Phase 3B.2 | Unlink Mission DestroyService | 8/8 ✅ | TDD PLATINUM |
| Phase 3C | Recalcul Totaux (Create/Update/Destroy) | 24/24 ✅ | TDD PLATINUM |

**Décision Architecturale Clé :**
- ❌ **Callbacks ActiveRecord** → Rejeté
- ✅ **Services Applicatifs** → Adopté

La logique de recalcul des totaux (`total_days`, `total_amount`) est orchestrée dans les services, pas dans les callbacks du modèle.

**Leçons Apprises :**
1. **Services > Callbacks** pour la logique métier complexe
2. **RSpec lazy `let`** : toujours forcer l'évaluation avant `reload`
3. **Montants financiers** : toujours en centimes (integer)

> ✅ **Feature CRA 100% TERMINÉE — Peut être mergée, livrée et maintenue sans honte**

**Commande de validation :**
```bash
docker compose exec web bundle exec rspec spec/services/cra_entries/ spec/models/cra_entry_lifecycle_spec.rb spec/models/cra_entry_uniqueness_spec.rb --format progress
# Résultat attendu : 50 examples, 0 failures
```

---

## 🟡 PROCHAINE ÉTAPE — CRÉATION DE VALEUR IMMÉDIATE

### Feature Contract #08 — Entreprise de l'indépendant

🏛️ **Base fiscale & légale** — Conditionne TVA, statuts fiscaux

| Aspect | Détails |
|--------|---------|
| **Pourquoi maintenant ?** | Indispensable avant facturation, fort levier de différenciation |
| **Scope fonctionnel** | Création d'une entreprise, SIREN/SIRET |
| **Récupération données** | API à définir (forme juridique, régime fiscal, TVA oui/non) |

> ⚠️ Pas encore de logique comptable

---

## 🟠 PRIORITÉ MOYENNE — SÉCURISATION MÉTIER

### Feature Contract #09 — Validation & verrouillage CRA

🔒 **Confiance & conformité**

| Aspect | Détails |
|--------|---------|
| **Scope** | Validation CRA par l'indépendant, CRA verrouillé en écriture |
| **Dérogation** | Modification → double approbation (plus tard) |

---

### Feature Contract #10 — Rôles & visions

👥 **Rôles utilisateur** — Les rôles émergent naturellement des cas concrets

| Rôle | Description |
|------|-------------|
| `independent` | Utilisateur principal |
| `client_representative` | Lecture CRA |
| `admin` | Plus tard |

---

### Feature Contract #11 — Pré-facturation

💰 **Préparation cash**

| Aspect | Détails |
|--------|---------|
| **Calcul automatique** | TJM × jours travaillés, forfait proratisé |
| **Limitations** | Pas encore d'édition de facture, export data only |

---

## 🟢 PRIORITÉ BASSE — OPTIMISATION & SCALE

| Feature | Description |
|---------|-------------|
| Feature #10 — Versioning CRA avancé | NoSQL ? |
| Feature #11 — Export PDF | Génération documents |
| Feature #12 — Historique & audit métier | Traçabilité |
| Feature #13 — Multi-entreprises / multi-clients | Scale |

---

## ✅ Features Techniques Terminées

### 🔐 Sécurité

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| Brakeman (scan vulnérabilités) | ✅ | Terminé | 0 vulnérabilités |
| Bundle audit | ✅ | Terminé | Intégré CI |
| CSRF protection | ✅ | Terminé | State validation |
| Rate limiting | ✅ | Terminé | Feature Contract 05 - Protection brute force implémentée (/login: 5/min, /signup: 3/min, /refresh: 10/min) |
| Refresh-token revocation E2E | 🟠 | Important | Extension script revocation actuel |
| Audit logs | 🟢 | Plus tard | Traçabilité actions (quand produit vit) |

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

### 🏗️ Infrastructure

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

### 📚 Documentation

| Tâche | Priorité | Statut | Notes |
|-------|----------|--------|-------|
| API Swagger/Rswag | ✅ | Terminé | 89 specs |
| Guide migration Rails 8 | ✅ | Terminé | `docs/technical/migrations/` |
| Plans déploiement/rollback | ✅ | Terminé | `docs/technical/deployment/` |
| Documentation OAuth flow | ✅ | Terminé | `docs/technical/guides/` |
| Guide contribution | 🟢 | Plus tard | CONTRIBUTING.md (quand équipe grandit) |
| Architecture Decision Records | 🟢 | Plus tard | ADR formels (quand produit vit) |

---

## 📅 Historique des Releases

| Version | Date | Description |
|---------|------|-------------|
| v0.0.1 | 26 Dec 2025 | Rails 7.1.5.1 / Ruby 3.3.0 - Pre-migration baseline |
| v0.0.2 | 26 Dec 2025 | Rails 8.1.1 / Ruby 3.4.8 baseline |
| v0.0.3 | 29 Dec 2025 | Rate Limiting (FC-05) - Platinum Level |
| v0.0.4 | 31 Dec 2025 | Missions (FC-06) - Merged |
| v0.0.5 | 6 Jan 2026 | CRA (FC-07) - TDD Platinum Complete |

---

## 🚀 Axes d'Amélioration (State-of-the-Art)

> Améliorations pour atteindre le niveau des startups en forte croissance

### 📊 Observabilité Avancée

| Tâche | Priorité | Statut | Impact |
|-------|----------|--------|--------|
| OpenTelemetry (Rails instrumentation) | 🟠 | À faire | Traces distribuées, métriques détaillées (latence, erreurs, requêtes/endpoint) |
| Grafana + Prometheus | 🟠 | À faire | Dashboards SLO/SLA, détection rapide des incidents |

### 🔐 Sécurité Avancée

| Tâche | Priorité | Statut | Impact |
|-------|----------|--------|--------|
| Rotation des secrets JWT | 🟠 | À faire | Job `jwt_secret_rotation` (cron), invalidation via denylist |
| Trivy (scan vulnérabilités Docker) | 🟠 | À faire | Protection contre CVE images Docker |
| Dependency-check (bundler-audit) | 🟠 | À faire | Protection contre CVE dépendances |

### 🔄 API Evolution

| Tâche | Priorité | Statut | Impact |
|-------|----------|--------|--------|
| API versioning (`Accept-Version` ou path) | 🟢 | À faire | Évolution sans casser les clients existants |
| Feature-flags (Flipper/Rollout) | 🟠 | À faire | Déploiements progressifs, rollback instantané |
| Documentation OpenAPI exhaustive | 🟠 | À faire | Enrichir erreurs, générer SDKs clients (OpenAPI-Generator) |

### ⚡ Performance & Scale

| Tâche | Priorité | Statut | Impact |
|-------|----------|--------|--------|
| Cache de lecture (Rails cache + Redis) | 🟢 | À faire | Améliore latence, réduit charge DB sur listes missions |
| Load-testing (k6/locust) | 🟢 | À faire | Valider limites rate-limiting, scalabilité JWT |
| Composite unique indexes | ✅ | Fait | `(mission_id, role)` — intégrité à grande échelle |

### 🏗️ Architecture Event-Driven

| Tâche | Priorité | Statut | Impact |
|-------|----------|--------|--------|
| Domain Events (RailsEventStore/Kafka) | 🟢 | À faire | `MissionCreated`, `MissionStatusChanged` — découplage services |
| Event sourcing pour CRA | 🟢 | À faire | Audit, reporting sans toucher au core |

### 🧪 Tests & CI Hardening

| Tâche | Priorité | Statut | Impact |
|-------|----------|--------|--------|
| Intégration E2E dans CI (GitHub Actions) | 🔴 | Critique | `e2e_missions.sh`, `e2e_auth_flow.sh` en pipeline |
| Deploy Preview (Render/Fly) | 🟠 | À faire | Preview-environnements par PR, validation PO accélérée |

---

## 📝 Notes

- Ce backlog est maintenu manuellement
- Les priorités sont réévaluées à chaque sprint
- Les features métier suivent le workflow Feature Contract
- La v0.1.0 sera créée après FC #06 à #09
- La v1.0.0 (MVP Production) sera définie après validation des fondations