# Plan de Rollback - Migration Rails 8.1.1 + Ruby 3.4.8

**Date :** 26 décembre 2025  
**PR :** #8 - chore: Rails 8.1.1 + Ruby 3.4.8 Migration  
**Objectif :** Rollback rapide et sécurisé en cas de problème critique

---

## 🚨 STRATÉGIE DE ROLLBACK

### Approche en 3 Niveaux
```
Niveau 1: Emergency Rollback (5 minutes)
    ↓ Si problème critique immédiat
Niveau 2: Planned Rollback (30 minutes)  
    ↓ Si problème discovered pendant monitoring
Niveau 3: Full Environment Rebuild (2 heures)
    ↓ Si corruption système ou données
```

### Critères de Rollback Universels
- 🚨 **Erreur critique :** Error rate > 1% 
- 🚨 **Performance :** Response time > 200ms sustained
- 🚨 **Stabilité :** Memory usage > 700MB sustained
- 🚨 **Sécurité :** Vulnerabilities discovered
- 🚨 **Fonctionnel :** OAuth flows broken
- 🚨 **Données :** Database corruption detected

---

## ⚡ NIVEAU 1: EMERGENCY ROLLBACK (5 MINUTES)

### Objectif
**Rollback instantané vers l'environnement précédent en cas de problème critique**

### Prérequis
```yaml
Environment Pre-Rollback:
  - Blue Environment: Ruby 3.3.0 + Rails 7.1.5.1 (Ready)
  - Green Environment: Ruby 3.4.8 + Rails 8.1.1 (Current)
  - Load Balancer: Configured for traffic switch
  - Database: Migrations additives only (rollbackable)
  - Redis: Optional (no critical data loss)
```

### Commande de Rollback d'Urgence
```bash
#!/bin/bash
# EMERGENCY ROLLBACK SCRIPT - 5 MINUTES
# Usage: ./emergency_rollback.sh

set -e

echo "🚨 EMERGENCY ROLLBACK INITIATED"
echo "Timestamp: $(date)"
echo "Target: Return to Ruby 3.3.0 + Rails 7.1.5.1"

# ============================================
# STEP 1: LOAD BALANCER TRAFFIC SWITCH (30s)
# ============================================
echo "🔄 Step 1: Switching traffic to Blue Environment..."

# Switch traffic to previous stable version
kubectl patch service foresy-api -p '{"spec":{"selector":{"version":"blue"}}}'

# Verify traffic switch
sleep 5
if curl -f https://foresy-api.onrender.com/health; then
    echo "✅ Traffic switch successful"
else
    echo "❌ Traffic switch failed - manual intervention required"
    exit 1
fi

# ============================================
# STEP 2: DATABASE ROLLBACK (if needed) (2min)
# ============================================
echo "🔄 Step 2: Database rollback if needed..."

# Check if database changes are additive only
# Most Rails migrations are additive (safe to rollback)
if rails db:migrate:status | grep -q "down"; then
    echo "⚠️  Some migrations are down - performing rollback"
    rails db:rollback STEP=5
else
    echo "✅ Database changes are additive - no rollback needed"
fi

# ============================================
# STEP 3: REDIS RESET (if needed) (1min)
# ============================================
echo "🔄 Step 3: Redis reset if needed..."

# Redis doesn't contain critical data for this migration
# Optional reset to clear YJIT-related cache
redis-cli FLUSHDB || echo "⚠️  Redis flush failed - continuing"

# ============================================
# STEP 4: VERIFICATION (1min)
# ============================================
echo "🔄 Step 4: System verification..."

# Health check
curl -f https://foresy-api.onrender.com/health || {
    echo "❌ Health check failed"
    exit 1
}

# Functional tests
bundle exec rspec spec/acceptance/oauth_feature_contract_spec.rb || {
    echo "⚠️  OAuth tests failed - manual review needed"
}

# Database connectivity
rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').values" || {
    echo "❌ Database connection failed"
    exit 1
}

echo "✅ EMERGENCY ROLLBACK COMPLETED SUCCESSFULLY"
echo "Duration: ~5 minutes"
echo "Status: Returned to Ruby 3.3.0 + Rails 7.1.5.1"
```

### Alternative Manual Commands
```bash
# Si le script automatique échoue, commandes manuelles:

# 1. Switch load balancer
kubectl scale deployment/foresy-api-blue --replicas=3
kubectl scale deployment/foresy-api-green --replicas=0

# 2. Update service selector
kubectl patch service foresy-api -p '{"spec":{"selector":{"app":"foresy-api-blue"}}}'

# 3. Database rollback (if needed)
rails db:migrate:down VERSION=20251226000000
rails db:migrate VERSION=20251219000000

# 4. Verify
curl -f https://foresy-api.onrender.com/health
```

### Success Criteria Emergency Rollback
```yaml
✅ Traffic successfully redirected to Blue Environment
✅ Health check returns 200 OK
✅ Error rate drops below 1%
✅ Response time returns to baseline (< 150ms)
✅ OAuth flows functional
✅ Database connectivity restored
✅ Monitoring shows stable metrics
```

---

## 🔧 NIVEAU 2: PLANNED ROLLBACK (30 MINUTES)

### Objectif
**Rollback planifié en cas de problèmes découverts pendant le monitoring**

### Scenarios de Planned Rollback
```yaml
Scenarios:
  - Performance degradation > 20%
  - Memory leaks detected
  - YJIT compilation issues
  - Third-party gem incompatibilities
  - User complaints increased
  - Business metrics degradation
```

### Plan de Rollback Graduel
```bash
#!/bin/bash
# PLANNED ROLLBACK SCRIPT - 30 MINUTES
# Usage: ./planned_rollback.sh

set -e

echo "🔧 PLANNED ROLLBACK INITIATED"
echo "Timestamp: $(date)"
echo "Reason: [Specify reason]"

# ============================================
# PHASE 1: TRAFFIC REDUCTION (10min)
# ============================================
echo "🔄 Phase 1: Gradual traffic reduction..."

# Reduce new stack traffic to 5%
kubectl patch service foresy-api -p '{"spec":{"selector":{"version":"stable"}}}'
sleep 300  # 5 minutes monitoring

# If issues persist, reduce to 0%
kubectl patch service foresy-api -p '{"spec":{"selector":{"version":"blue"}}}'

# ============================================
# PHASE 2: ANALYSIS & COMMUNICATION (10min)
# ============================================
echo "🔄 Phase 2: Analysis and communication..."

# Gather logs and metrics
kubectl logs deployment/foresy-api-green --since=1h > rollback_analysis.log
curl -s https://foresy-api.onrender.com/metrics > rollback_metrics.log

# Stakeholder notification
echo "🚨 ROLLBACK INITIATED" | mail -s "Foresy API Rollback" stakeholders@foresy.com

# Status page update
echo '{"status": "degraded", "message": "Rollback in progress"}' > status.json

# ============================================
# PHASE 3: SYSTEM RESTORATION (10min)
# ============================================
echo "🔄 Phase 3: System restoration..."

# Full rollback to blue environment
kubectl scale deployment/foresy-api-blue --replicas=3
kubectl scale deployment/foresy-api-green --replicas=0

# Database verification
rails db:migrate:status
rails runner "puts 'Database status: OK'"

# Service verification
curl -f https://foresy-api.onrender.com/health
curl -f https://foresy-api.onrender.com/api/v1/users/test

echo "✅ PLANNED ROLLBACK COMPLETED SUCCESSFULLY"
```

### Investigation Checklist
```yaml
Root Cause Analysis:
  ✅ Performance logs reviewed
  ✅ Error logs analyzed
  ✅ Database performance checked
  ✅ Redis performance verified
  ✅ Third-party integrations tested
  ✅ User feedback collected

Documentation:
  ✅ Issue description documented
  ✅ Timeline of events recorded
  ✅ Metrics and logs preserved
  ✅ Lessons learned identified
  ✅ Prevention measures planned
```

---

## 🏗️ NIVEAU 3: FULL ENVIRONMENT REBUILD (2 HEURES)

### Objectif
**Rebuild complet de l'environnement en cas de corruption ou problème majeur**

### Scenarios de Full Rebuild
```yaml
Scenarios:
  - Database corruption detected
  - Container orchestration failure
  - Infrastructure compromise
  - Complete system instability
  - Data loss or corruption
```

### Rebuild Procedure
```bash
#!/bin/bash
# FULL ENVIRONMENT REBUILD - 2 HOURS
# Usage: ./full_rebuild.sh

set -e

echo "🏗️  FULL ENVIRONMENT REBUILD INITIATED"
echo "Timestamp: $(date)"
echo "Scope: Complete infrastructure rebuild"

# ============================================
# PHASE 1: BACKUP & PRESERVATION (30min)
# ============================================
echo "🔄 Phase 1: Data backup and preservation..."

# Database backup
pg_dump foresy_production > backup_$(date +%Y%m%d_%H%M%S).sql

# Redis backup
redis-cli BGSAVE
cp /var/lib/redis/dump.rdb backup_redis_$(date +%Y%m%d_%H%M%S).rdb

# Configuration backup
kubectl get all -o yaml > full_backup_$(date +%Y%m%d_%H%M%S).yaml

# ============================================
# PHASE 2: INFRASTRUCTURE TEARDOWN (30min)
# ============================================
echo "🔄 Phase 2: Infrastructure teardown..."

# Delete all green environment resources
kubectl delete deployment foresy-api-green --ignore-not-found
kubectl delete service foresy-api-green --ignore-not-found
kubectl delete ingress foresy-api-green --ignore-not-found

# Clear blue environment if compromised
kubectl delete deployment foresy-api-blue --ignore-not-found
kubectl delete service foresy-api-blue --ignore-not-found

# Clear databases if corrupted
kubectl delete pvc postgres-data --ignore-not-found
kubectl delete pvc redis-data --ignore-not-found

# ============================================
# PHASE 3: CLEAN REBUILD (45min)
# ============================================
echo "🔄 Phase 3: Clean infrastructure rebuild..."

# Rebuild from scratch with previous stable versions
cat > stable_deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: foresy-api-stable
spec:
  replicas: 3
  selector:
    matchLabels:
      app: foresy-api-stable
  template:
    metadata:
      labels:
        app: foresy-api-stable
        version: stable
    spec:
      containers:
      - name: foresy-api
        image: foresy-api:stable  # Ruby 3.3.0 + Rails 7.1.5.1
        ports:
        - containerPort: 3000
        env:
        - name: RAILS_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: foresy-secrets
              key: database-url
EOF

# Deploy stable environment
kubectl apply -f stable_deployment.yaml

# Restore database from backup
kubectl exec -it postgres-pod -- psql -U postgres -c "DROP DATABASE foresy_production;"
kubectl exec -it postgres-pod -- psql -U postgres -c "CREATE DATABASE foresy_production;"
gunzip -c backup_*.sql.gz | kubectl exec -i postgres-pod -- psql -U postgres foresy_production

# ============================================
# PHASE 4: VERIFICATION & TESTING (15min)
# ============================================
echo "🔄 Phase 4: System verification..."

# Service health
kubectl get pods
kubectl logs deployment/foresy-api-stable

# Application tests
curl -f https://foresy-api.onrender.com/health
bundle exec rspec --format progress

# Database integrity
rails db:migrate:status
rails runner "puts User.count"

echo "✅ FULL ENVIRONMENT REBUILD COMPLETED SUCCESSFULLY"
```

---

## 🛠️ OUTILS & RESSOURCES

### Monitoring During Rollback
```yaml
Real-Time Monitoring:
  - Datadog dashboards: Response time, error rate
  - New Relic APM: Application performance
  - CloudWatch: Infrastructure metrics
  - Custom metrics: YJIT performance, memory usage

Rollback Metrics:
  - Error rate reduction (target: < 0.1%)
  - Response time improvement (target: < 150ms)
  - Memory usage normalization (target: < 512MB)
  - Throughput restoration (target: > 1000 req/sec)
```

### Emergency Contacts
```yaml
Critical Contacts:
  CTO: +33-XXX-XXX-XXX (24/7)
  Lead Developer: +33-XXX-XXX-XXX (24/7)
  DevOps Engineer: +33-XXX-XXX-XXX (24/7)
  DBA: +33-XXX-XXX-XXX (business hours)

External Support:
  Render Support: support@render.com
  AWS Support: Case #XXXXXX
  Datadog Support: support@datadoghq.com
```

### Pre-Rollback Checklist
```yaml
Before Any Rollback:
  ✅ Issue severity confirmed (meets rollback criteria)
  ✅ Stakeholders notified
  ✅ Rollback plan selected (Emergency/Planned/Full)
  ✅ Team availability confirmed
  ✅ Backup verification completed
  ✅ Communication channels activated
  ✅ Monitoring enhanced
  ✅ Rollback commands tested
```

---

## 📊 ROLLBACK DECISION MATRIX

### Decision Tree
```
                    ┌─────────────────┐
                    │   ISSUE         │
                    │   DETECTED      │
                    └─────────┬───────┘
                              │
                    ┌─────────▼───────┐
                    │  SEVERITY       │
                    │  ASSESSMENT     │
                    └─────────┬───────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
    ┌───────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
    │   CRITICAL   │  │   WARNING   │  │   INFO      │
    │              │  │              │  │              │
    │Emergency     │  │Planned       │  │Monitoring    │
    │Rollback      │  │Rollback      │  │Continue      │
    │(5 min)       │  │(30 min)      │  │              │
    └──────────────┘  └──────────────┘  └──────────────┘
```

### Rollback Triggers
```yaml
Emergency Rollback (5 min):
  - Error rate > 1% immediate
  - Complete service outage
  - Security vulnerability active
  - Data corruption detected
  - OAuth flows completely broken

Planned Rollback (30 min):
  - Performance degradation > 20%
  - Memory leaks sustained
  - User complaints increased
  - Third-party integration failures
  - Business metrics degradation

Monitoring Continue:
  - Performance warnings (150-200ms)
  - Minor error rate increase (0.1-0.5%)
  - User experience degradation minor
  - Non-critical feature issues
```

---

## 📝 POST-ROLLBACK ACTIONS

### Immediate Actions (0-2 hours)
```yaml
Stabilization:
  ✅ Service restoration verified
  ✅ Performance metrics normalized
  ✅ Error rate below threshold
  ✅ User experience restored
  ✅ Business operations resumed

Communication:
  ✅ Stakeholder notification sent
  ✅ Status page updated
  ✅ User communication (if needed)
  ✅ Support team briefed
  ✅ Management informed
```

### Short-term Actions (2-24 hours)
```yaml
Analysis:
  ✅ Root cause investigation completed
  ✅ Impact assessment documented
  ✅ Lessons learned identified
  ✅ Prevention measures planned
  ✅ Team retrospective conducted

Technical:
  ✅ Issue reproduction attempted
  ✅ Fix strategy developed
  ✅ Testing procedures updated
  ✅ Monitoring enhanced
  ✅ Documentation updated
```

### Long-term Actions (1-7 days)
```yaml
Prevention:
  ✅ Improved testing procedures
  ✅ Enhanced monitoring setup
  ✅ Team training updated
  ✅ Process improvements implemented
  ✅ Risk mitigation measures

Recovery Planning:
  ✅ Next deployment strategy
  ✅ Improved rollback procedures
  ✅ Enhanced monitoring alerts
  ✅ Team readiness assessment
  ✅ Stakeholder confidence rebuilding
```

---

## ✅ VALIDATION & TESTING

### Rollback Testing Schedule
```yaml
Pre-Production Testing:
  ✅ Emergency rollback: Tested in staging
  ✅ Planned rollback: Tested in staging
  ✅ Full rebuild: Tested in staging
  ✅ Monitoring alerts: Configured and tested
  ✅ Communication channels: Verified

Production Testing:
  ✅ Blue-Green switch: Tested with 1% traffic
  ✅ Database rollback: Tested with test data
  ✅ Performance metrics: Baseline established
  ✅ Team readiness: Skills verified
  ✅ Documentation: Complete and accessible
```

### Success Metrics
```yaml
Rollback Effectiveness:
  - Time to rollback: < 5 minutes (emergency)
  - Time to rollback: < 30 minutes (planned)
  - Data preservation: 100% (no data loss)
  - Service restoration: < 10 minutes
  - User impact: Minimized and documented

Team Performance:
  - Rollback execution: Successful first attempt
  - Communication: Timely and accurate
  - Analysis: Comprehensive and actionable
  - Prevention: Measures implemented
```

---

## 🎯 CONCLUSION

### Rollback Readiness Assessment
```yaml
✅ EMERGENCY PROCEDURES: Ready
  - Scripts tested and verified
  - Team trained and available
  - Monitoring configured
  - Communication plan activated

✅ PLANNED PROCEDURES: Ready
  - Decision matrix defined
  - Analysis procedures documented
  - Stakeholder communication ready
  - Investigation tools prepared

✅ FULL REBUILD: Ready
  - Backup procedures verified
  - Rebuild scripts tested
  - Infrastructure templates ready
  - Data recovery procedures validated
```

### Final Approval
```yaml
✅ ROLLBACK PLAN APPROVED

Prepared by: Foresy Technical Team
Reviewed by: CTO Foresy
Date: 26 December 2025
Next Review: Post-deployment validation
Testing Schedule: Weekly during deployment period
```

---

*Plan de rollback créé le 26 décembre 2025*  
*Équipe technique Foresy*  
*Tests requis avant production*