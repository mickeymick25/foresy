# Plan de Migration Rails 8.1.1
Historique / état au 2025-12-25


**Date de création:** 25 décembre 2025  
**Date de complétion:** 26 décembre 2025  
**Status:** ✅ **COMPLÉTÉ**

---

## ⚠️ CE PLAN A ÉTÉ EXÉCUTÉ AVEC SUCCÈS

La migration vers Rails 8.1.1 a été complétée le 26 décembre 2025.

Voir le document de complétion : [[DONE]_2025_12_26_Rails_8_1_1_Migration_Complete.md](./[DONE]_2025_12_26_Rails_8_1_1_Migration_Complete.md)

### Résumé des résultats

| Critère | Résultat |
|---------|----------|
| **Ruby** | 3.3.0 → 3.4.8 ✅ |
| **Rails** | 7.1.5.1 → 8.1.1 ✅ |
| **Tests RSpec** | 221 exemples, 0 failures ✅ |
| **Rubocop** | 82 fichiers, 0 offenses ✅ |
| **Brakeman** | 0 vulnérabilités ✅ |
| **Docker Build** | OK ✅ |
| **Health Check** | OK ✅ |

---

# PLAN ORIGINAL (ARCHIVÉ)

Le contenu ci-dessous est conservé à titre de référence historique.

---

# Monitoring des authentifications OAuth
Rails.event.notify("oauth.login", user_id: user.id, provider: "google", success: true)
Rails.event.notify("jwt.revocation", user_id: user.id, token_type: "access")

# Audit de sécurité pour RGPD
Rails.event.tagged("security") do
  Rails.event.notify("auth.attempt", email: email, ip: ip_address, user_agent: user_agent)
end

# Observabilité des performances
Rails.event.notify("api.response", endpoint: "/api/v1/auth/login", response_time: 150, status: 200)
```

#### 2. **Active Job Continuations** (PRIORITÉ HAUTE)
```ruby
# Jobs OAuth sync interrompus et reprendables
class OAuthSyncJob < ApplicationJob
  include ActiveJob::Continuable
  
  def perform(oauth_provider)
    step :fetch_users do |step|
      users = User.where(provider: oauth_provider)
      users.find_each(start: step.cursor) do |user|
        sync_user_oauth_data(user)
        step.advance! from: user.id  # Reprend depuis cette position
      end
    end
    step :update_last_sync
  end
end
```

#### 3. **Local CI Enhancement** (PRIORITÉ HAUTE)
```ruby
# config/ci.rb - CI optimisée pour Foresy
CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Style: Ruby", "bin/rubocop"
  
  step "Security: Brakeman", "bin/brakeman --quiet --no-pager --exit-on-warn"
  step "Security: Bundle audit", "bundle audit check --update"
  
  step "Tests: RSpec Core", "bin/rails test"
  step "Tests: OAuth Integration", "bundle exec rspec spec/acceptance/oauth_feature_contract_spec.rb"
  
  step "Tests: E2E Auth Flow", "bin/e2e/e2e_auth_flow.sh"
  step "Tests: Smoke Test", "bin/e2e/smoke_test.sh"
  
  if success?
    step "✅ All systems go. Ready for deploy.", "echo 'Migration validation passed'"
  else
    failure "❌ CI failed. Fix issues before proceeding.", "echo 'Migration blocked'"
  end
end
```

---

## 4️⃣ **PLAN DE MIGRATION PROGRESSIVE**

### **📅 PHASE 1 : Migration 7.1.5.1 → 8.0.x (CRITIQUE)**
**Timeline :** 2-3 semaines  
**Objectif :** Éliminer le warning Brakeman EOL et restaurer le support de sécurité  
**Priorité :** 🔴 **CRITIQUE**

#### **Process Obligatoire - Étapes 1-3**

**1️⃣ Git :**
```bash
git checkout -b chore/upgrade-rails-8-1-1
```

**2️⃣ Pré-analyse (OBLIGATOIRE) :**
- [ ] **Identifier les breaking changes Rails 8** (lecture release notes)
- [ ] **Lister les gems incompatibles** (audit Gemfile)
- [ ] **Analyser les impacts Docker** (Dockerfile, docker-compose)
- [ ] **Proposer un plan d'action** détaillé
- [ ] **Sauvegarde complète** de la production

**❗ NE PAS modifier le code tant que cette analyse n'est pas faite.**

**3️⃣ Upgrade Rails :**
```ruby
# Gemfile
gem 'rails', '~> 8.0.0'

# Bundle update ciblé
bundle update rails railties actionpack activerecord activesupport
```

#### **Validation Phase 1**
- [ ] **Rails 8.0.x** démarre sans erreur
- [ ] **Tests de régression** complets (221 tests minimum)
- [ ] **Docker build** fonctionne
- [ ] **Endpoints OAuth/JWT** opérationnels
- [ ] **Performance maintenue** (< 100ms response time)

---

### **📅 PHASE 2 : Migration 8.0.x → 8.1.1 (MAJEURE)**
**Timeline :** 3-4 semaines  
**Objectif :** Bénéficier des nouvelles fonctionnalités critiques  
**Priorité :** 🟡 **HAUTE**

#### **Process Obligatoire - Étapes 4-5**

**4️⃣ Fix Incremental Loop :**
Pour chaque erreur ou warning :
```bash
# Fix minimal
→ bundle exec rspec
→ bundle exec rubocop
→ bundle exec brakeman
→ rails zeitwerk:check
→ docker-compose build
```

**Règles strictes :**
- ✅ Pas de refactoring non nécessaire
- ✅ Pas de suppression de tests
- ✅ Pas de workaround sale
- ✅ Fix minimal et contrôlé

**5️⃣ Validation Technique :**
```bash
# Validation systématique
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
rails zeitwerk:check
docker-compose up --build
curl -f http://localhost:3000/health
```

#### **Validation Phase 2**
- [ ] **Rails 8.1.1** entièrement fonctionnel
- [ ] **Structured Event Reporting** opérationnel
- [ ] **Active Job Continuations** implémentées
- [ ] **Local CI** configuré et testé
- [ ] **Documentation** mise à jour

---

### **📅 PHASE 3 : Implémentation Avancée (OPTIMISATION)**
**Timeline :** 2-3 semaines  
**Objectif :** Tirer parti de toutes les nouvelles capacités  
**Priorité :** 🟢 **MOYENNE**

#### **Process Obligatoire - Étapes 6-8**

**6️⃣ Documentation :**
- [ ] **Mise à jour README.md** (Rails 8.1.1, Ruby 3.3.0)
- [ ] **Création docs/upgrade/rails-8.1.1.md**
- [ ] **Documentation breaking changes** rencontrés
- [ ] **Documentation fix appliqués**
- [ ] **Points de vigilance** futurs

**7️⃣ Commits :**
```bash
git commit -m "chore: upgrade Rails to 8.1.1"
git commit -m "fix(deps): update incompatible gems"
git commit -m "docs(tech): document rails 8.1 upgrade"
```

**8️⃣ Pull Request :**
```markdown
## Upgrade
Rails 7.1.5.1 → Rails 8.1.1

## Validation
- [x] RSpec
- [x] Rubocop
- [x] Brakeman
- [x] Zeitwerk

## Functional impact
- None

## Risks
- Documented
```

#### **Livrables Phase 3**
- [ ] **Application stable** en Rails 8.1.1
- [ ] **Tests 100% verts** (221+ tests)
- [ ] **Documentation complète** et claire
- [ ] **PR validée** et prête à merger

---

## 5️⃣ **CRITÈRES D'ACCEPTATION (GHERKIN)**

### **Feature: Rails Framework Upgrade to 8.1.1**

#### **Scenario 1: Application boots successfully in Docker**
```gherkin
Given the application is built using the Dockerfile
When the container starts
Then the Rails server starts without errors
And the /health endpoint returns HTTP 200
```

#### **Scenario 2: Test suite passes**
```gherkin
Given the Rails version is 8.1.1
When the RSpec suite is executed
Then all 221+ tests pass successfully
```

#### **Scenario 3: Linting and security checks pass**
```gherkin
When Rubocop and Brakeman are executed
Then no blocking issues are reported
And 0 violations Rubocop detected
And 0 vulnerabilities Brakeman critical
```

#### **Scenario 4: API behavior is unchanged**
```gherkin
Given an existing authenticated endpoint
When it is called with a valid JWT
Then the response is identical to Rails 7.1 behavior
And OAuth Google/GitHub authentication works
And JWT token revocation works
```

#### **Scenario 5: Documentation is updated**
```gherkin
When the README is reviewed
Then the Rails version 8.1.1 is documented
And upgrade notes are present
And migration guide exists in docs/upgrade/
```

---

## 6️⃣ **ÉTAPES TECHNIQUES DÉTAILLÉES**

### **🔧 Process de Migration Standardisé**

#### **Étape 1: Préparation**
```bash
# Création branche dédiée
git checkout -b chore/upgrade-rails-8-1-1

# Sauvegarde état actuel
git tag backup-rails-7.1.5.1

# Audit pré-migration
bundle outdated
gem list | grep rails
```

#### **Étape 2: Mise à jour Rails**
```ruby
# Gemfile - Version cible progressive
# Phase 1: gem 'rails', '~> 8.0.0'
# Phase 2: gem 'rails', '~> 8.1.1'

# Bundle update ciblé
bundle update rails railties actionpack activerecord activesupport
```

#### **Étape 3: Configuration Rails**
```bash
# Mise à jour des defaults
rails app:update

# Comparaison配置文件 (IMPORTANT)
# Comparer config/application.rb
# Comparer config/environments/*.rb
# NE PAS écraser aveuglément
```

#### **Étape 4: Vérifications Docker**
```bash
# Le Dockerfile ne doit pas changer structurellement
# Vérifier:
docker-compose build
bundle install OK
rails server OK
healthcheck OK
```

#### **Étape 5: Tests de Validation**
```bash
# Suite complète de validation
bundle exec rspec                    # Tests fonctionnels
bundle exec rubocop                  # Qualité code
bundle exec brakeman                 # Sécurité
rails zeitwerk:check                # Autoloading
docker-compose up --build           # Docker validation
curl -f http://localhost:3000/health # Health check
```

---

## 7️⃣ **GESTION DES RISQUES & MITIGATION**

### **⚠️ RISQUES IDENTIFIÉS**

| Risque | Probabilité | Impact | Mitigation | Responsable |
|--------|-------------|--------|------------|-------------|
| **Changement Zeitwerk** | Moyenne | Élevé | Validation zeitwerk:check à chaque étape | Lead Developer |
| **Breaking Changes Rails 8** | Moyenne | Élevé | Lecture exhaustive release notes + tests | Backend Developer |
| **Gems incompatibles** | Moyenne | Moyen | Update ciblé, pas global + alternatives | Backend Developer |
| **Dépréciations** | Élevée | Moyen | Activer logs de warnings + traitement | Lead Developer |
| **Docker build lent** | Faible | Moyen | Cache bundler inchangé + optimisation | DevOps Engineer |
| **Performance Regression** | Faible | Moyen | Benchmarking continu + optimisation | DevOps Engineer |
| **Test flakiness** | Moyenne | Élevé | Fix ciblé, jamais suppression de tests | QA Engineer |
| **Fonctionnalités OAuth Cassées** | Faible | Élevé | Tests OAuth spécifiques + validation | QA Engineer |

### **🔄 Plan de Rollback Détaillé**

#### **Rollback Phase 1 (Rails 7.1.5.1)**
```bash
# Retour rapide version stable
git reset --hard backup-rails-7.1.5.1
bundle install
docker-compose up --build
```

#### **Rollback Phase 2 (Rails 8.0.x)**
```bash
# Branch de sécurité Rails 8.0.x stable
git checkout -b hotfix/rollback-8.1.1-to-8.0.x
# Migration rollback vers 8.0.x
# Préservation données Structured Event Reporting
```

---

## 8️⃣ **DÉFINITION OF DONE (DOD)**

### **✅ Critères Techniques**
- [ ] **Rails 8.1.1** installé et fonctionnel
- [ ] **Toutes les dépendances** compatibles Rails 8.1.1
- [ ] **Tests 100% verts** (221+ exemples, 0 failure)
- [ ] **Rubocop & Brakeman OK** (0 violations, 0 vulnérabilités critiques)
- [ ] **Zeitwerk validation** sans erreur
- [ ] **Docker build OK** multi-stage fonctionnel
- [ ] **Performance maintenue** (< 100ms response time)

### **✅ Critères Fonctionnels**
- [ ] **Aucun changement** de comportement API
- [ ] **OAuth Google/GitHub** 100% opérationnels
- [ ] **JWT authentication** (login, refresh, revocation) fonctionnel
- [ ] **Endpoints existants** répondent identique à Rails 7.1
- [ ] **Swagger documentation** inchangée (hors version technique)

### **✅ Critères Documentation**
- [ ] **README.md** mis à jour (Rails 8.1.1, Ruby 3.3.0)
- [ ] **docs/upgrade/rails-8.1.1.md** créé et complet
- [ ] **Breaking changes** rencontrés documentés
- [ ] **Fix appliqués** documentés
- [ ] **Points de vigilance** futurs documentés

### **✅ Critères Process**
- [ ] **PR validée** avec template complet
- [ ] **Tests bloquants** respectés
- [ ] **Code review** effectuée
- [ ] **Migration stable** en production

---

## 9️⃣ **PROCESS DE VALIDATION**

### **🔍 Validation Continue**

#### **À chaque étape du process :**
```bash
# Validation technique systématique
bundle exec rspec
bundle exec rubocop
bundle exec brakeman
rails zeitwerk:check

# Validation Docker
docker-compose build
docker-compose up -d
curl -f http://localhost:3000/health

# Validation fonctionnelle
bundle exec rspec spec/acceptance/oauth_feature_contract_spec.rb
bin/e2e/smoke_test.sh
bin/e2e/e2e_auth_flow.sh
```

#### **Points de Contrôle Obligatoires :**
- **Phase Gate 1** : Validation Rails 8.0.x avant passage 8.1.1
- **Phase Gate 2** : Validation fonctionnalités nouvelles avant implémentation
- **Go/No-Go Final** : Validation complète avant merge production

### **📊 Métriques de Succès**

#### **Métriques Techniques :**
- **Tests Coverage** : 100% (221+ tests)
- **Performance** : Response time < 100ms maintenu
- **Security** : 0 vulnérabilités critiques
- **Quality** : 0 violations Rubocop

#### **Métriques Business :**
- **Temps d'arrêt** : < 2h total migration
- **Fonctionnalités** : 100% disponibles
- **ROI** : Positif sur 6 mois
- **Developer Experience** : Significativement améliorée

---

## 🔟 **RESSOURCES & RESPONSABILITÉS**

### **👥 Équipe Core (Phase 1-2)**

#### **CTO (Michael Boitin)**
- [ ] Validation stratégie migration
- [ ] Approbation go/no-go phases
- [ ] Supervision budget et timeline
- [ ] Communication stakeholders

#### **Lead Developer**
- [ ] Coordination équipe technique
- [ ] Exécution migration Rails
- [ ] Validation breaking changes
- [ ] Formation équipe sur nouvelles features

#### **Backend Developer**
- [ ] Migration code Rails 8.x
- [ ] Implémentation Structured Event Reporting
- [ ] Migration Active Jobs vers Continuations
- [ ] Tests de régression

#### **DevOps Engineer**
- [ ] Configuration environnements migration
- [ ] Déploiement staging/production
- [ ] Monitoring performance
- [ ] Configuration Local CI

#### **QA Engineer**
- [ ] Tests de régression complets
- [ ] Validation nouvelles fonctionnalités
- [ ] Tests performance
- [ ] Documentation tests

---

## 📞 **SUIVI & RÉVISION**

### **📅 Planning de Révision**
- **Révision quotidienne** : Avancement technique
- **Révision hebdomadaire** : Phase gate et risques
- **Révision bi-hebdomadaire** : Communication stakeholders
- **Révision mensuelle** : ROI et ajustements stratégie

### **📋 Documentation et Communication**
- [ ] **Mise à jour** ce document à chaque phase
- [ ] **Guide migration** pour futures versions Rails
- [ ] **Formation équipe** sur Rails 8.1 features
- [ ] **Communication** clients sur améliorations

---

## 🎯 **PROCHAINES ÉTAPES IMMÉDIATES**

### **Actions Semaine du 26 Décembre 2025**
1. **Lancement officiel** du projet de migration Rails 8.1.1
2. **Constitution équipe** dédiée avec responsabilités claires
3. **Audit initial gems** et dépendances pour Phase 1
4. **Préparation environnement** de test Rails 8.0.x
5. **Communication** stakeholders et équipe sur plan d'action

### **Validation Requise (Avant Démarrage)**
- [ ] **CTO Approval** : Validation stratégie et timeline
- [ ] **Team Availability** : Ressources dédiées confirmées
- [ ] **Environment Ready** : Environnements de test prêts
- [ ] **Backup Strategy** : Plans de sauvegarde validés
- [ ] **Rollback Plan** : Procédures documentées et testées

---

## 🏆 **CONCLUSION ET APPROBATION**

### **✅ Résumé Exécutif**
Ce plan de migration progressive vers Rails 8.1.1 représente une **opportunité stratégique majeure** pour Foresy. L'intégration du feature contract amélioré garantit une approche méthodologique stricte qui maximise les bénéfices tout en minimisant les risques.

### **🎯 Décision Finale**
**✅ APPROUVÉ** : Migration progressive Rails 8.1.1 en 3 phases avec process obligatoire en 8 étapes

### **🚀 Prêt pour Exécution**
Le plan est détaillé, les risques sont identifiés et mitigés, les ressources sont définies. **L'équipe est prête à commencer la Phase 1 avec la pré-analyse obligatoire.**

---

**📋 Document créé par :** CTO Foresy  
**📅 Date de création :** 25 décembre 2025  
**🔄 Dernière mise à jour :** 25 décembre 2025  
**✅ Statut :** Approuvé - Prêt pour exécution  
**🎯 Priorité :** Critique - Démarrage immédiat recommandé

---

## 📋 HISTORIQUE D'EXÉCUTION

### 26 Décembre 2025 - Migration Complétée
- ✅ Ruby upgradé : 3.3.0 → 3.4.8
- ✅ Rails upgradé : 7.1.5.1 → 8.1.1
- ✅ Bundler upgradé : 2.x → 4.0.3
- ✅ Dockerfile mis à jour
- ✅ docker-compose.yml optimisé avec bundle_cache
- ✅ .ruby-version synchronisé
- ✅ .rubocop.yml mis à jour (TargetRubyVersion 3.4)
- ✅ Tous les tests passent (221)
- ✅ Rubocop 0 offense
- ✅ Brakeman 0 vulnérabilité
- ✅ Documentation mise à jour

---

*Ce document est archivé. Voir [[DONE]_2025_12_26_Rails_8_1_1_Migration_Complete.md](./[DONE]_2025_12_26_Rails_8_1_1_Migration_Complete.md) pour les détails de la migration effectuée.*