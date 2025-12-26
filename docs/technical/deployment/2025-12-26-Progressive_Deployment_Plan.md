# Plan de Déploiement Progressif - Migration Rails 8.1.1 + Ruby 3.4.8

**Date :** 26 décembre 2025  
**PR :** #8 - chore: Rails 8.1.1 + Ruby 3.4.8 Migration  
**Objectif :** Déploiement sécurisé avec monitoring intensif et rollback rapide

---

## 🎯 STRATÉGIE DE DÉPLOIEMENT

### Approche Progressive en 3 Phases
```
Phase 1: Staging Validation (24h)
    ↓ ✅ Success Criteria Met
Phase 2: Production Canary (48h) - 10% traffic
    ↓ ✅ Success Criteria Met  
Phase 3: Full Production (72h) - 100% traffic
```

### Critères de Succès Universels
- ✅ **Erreurs critiques :** 0 tolérance
- ✅ **Performance :** Pas de dégradation vs baseline
- ✅ **Memory usage :** +10% overhead maximum (YJIT)
- ✅ **Tests :** Tous les tests automatiques passent
- ✅ **Monitoring :** Dashboards configurés + alertes

---

## 📋 PHASE 1: STAGING VALIDATION

### Objectif
**Valider la migration complète en environnement de staging avec charge simulée**

### Timeline
**Durée :** 24 heures  
**Début :** Immédiat après merge  
**Fin :** J+1 09:00 (horaire business)

### Environnement & Configuration
```yaml
Environment: staging
URL: https://foresy-api-staging.onrender.com
Stack: Ruby 3.4.8 + Rails 8.1.1 + PostgreSQL 16-alpine + Redis 7-alpine

Services Active:
  - Database: PostgreSQL 16-alpine
  - Cache: Redis 7-alpine  
  - Monitoring: Datadog APM + custom metrics
  - Logging: Structured logs + YJIT statistics
```

### Tests & Validation

#### 1. Tests Fonctionnels Complets (J+0, 2h)
```bash
# Tests automatisés
bundle exec rspec                          # 221 tests
bundle exec rswag                          # 66 examples
bundle exec rubocop                        # 0 offenses
bundle exec brakeman                       # 0 vulnerabilities
bundle exec rails test                     # Integration tests

# Tests manuels critiques
1. User registration & login (email/password)
2. OAuth authentication (Google + GitHub)
3. JWT token generation & validation
4. API endpoints (CRUD operations)
5. Error handling & validation
```

#### 2. Performance Benchmarks (J+0, 4h)
```ruby
# Métriques à collecter:

Response Time (95th percentile):
  - Baseline (Rails 7.1.5.1): 150ms
  - Target (Rails 8.1.1): < 115ms (-23% YJIT)
  - Alert threshold: > 200ms

Throughput:
  - Baseline: 1000 req/sec
  - Target: 1300 req/sec (+30% YJIT)
  - Alert threshold: < 800 req/sec

Memory Usage:
  - Baseline: 512MB
  - Target: 563MB (+10% YJIT overhead)
  - Alert threshold: > 700MB
```

#### 3. Load Testing (J+0, 8h)
```bash
# Test de charge progressive avec Apache Bench:

Phase 1 - Light Load (1h):
  ab -n 10000 -c 10 https://foresy-api-staging.onrender.com/health
  # Objectif: Validation base functionality

Phase 2 - Medium Load (2h):
  ab -n 50000 -c 50 https://foresy-api-staging.onrender.com/api/v1/users
  # Objectif: Database + Redis integration

Phase 3 - Stress Load (3h):
  ab -n 100000 -c 100 https://foresy-api-staging.onrender.com/api/v1/auth/login
  # Objectif: OAuth + JWT performance
```

#### 4. Security & Compliance (J+1, 6h)
```bash
# Sécurité:
bundle audit                              # Vulnerabilities
brakeman -A                               # Security scan
sslscan foresy-api-staging.onrender.com   # SSL/TLS validation

# OAuth providers test:
1. Google OAuth: Flow complet fonctionnel
2. GitHub OAuth: Flow complet fonctionnel  
3. Token revocation: DELETE /revoke endpoints
4. JWT validation: Signature + expiration
```

### Monitoring & Alerting
```yaml
# Datadog Configuration:
Metrics:
  - Response time (p50, p95, p99)
  - Throughput (requests/sec)
  - Memory usage (heap + YJIT)
  - Database connection pool
  - Redis connection + cache hit rate
  - Error rate by endpoint
  - YJIT compilation statistics

Alerts:
  - Error rate > 1%: CRITICAL
  - Response time > 200ms: WARNING
  - Memory usage > 700MB: WARNING
  - YJIT compilation failures: CRITICAL
  - Database connection failures: CRITICAL
  - Redis connection failures: WARNING
```

### Success Criteria Phase 1
```yaml
✅ All automated tests passing (221 RSpec + 66 Rswag)
✅ Manual functional tests: 100% success rate
✅ Performance benchmarks: Within target ranges
✅ Load testing: No degradation vs baseline
✅ Security scan: 0 critical vulnerabilities
✅ Monitoring: All dashboards + alerts functional
✅ Error rate: < 0.1% throughout testing period
```

### Rollback Criteria Phase 1
```yaml
❌ ANY of the following triggers immediate rollback:
  - Critical error rate > 1%
  - Response time > 200ms sustained
  - Memory usage > 700MB sustained
  - Database connection failures
  - OAuth flows broken
  - Security vulnerabilities discovered
  - YJIT compilation failures
```

### Actions Phase 1
```bash
# Si SUCCESS → Procéder Phase 2
# Si FAILURE → Rollback + Analysis

Rollback Commands:
  git revert HEAD~1..HEAD           # Revert changes
  rails db:migrate VERSION=xxx      # Database rollback if needed
  kubectl rollout undo deployment   # Container rollback
```

---

## 📋 PHASE 2: PRODUCTION CANARY

### Objectif
**Déployer en production avec 10% du trafic pour validation en conditions réelles**

### Timeline
**Durée :** 48 heures  
**Début :** J+1 09:00 (après validation Phase 1)  
**Fin :** J+3 09:00

### Configuration Canary
```yaml
Production Environment:
  URL: https://foresy-api.onrender.com
  Traffic Split:
    10% Ruby 3.4.8 + Rails 8.1.1 (NEW)
    90% Ruby 3.3.0 + Rails 7.1.5.1 (LEGACY)
  
Load Balancer Configuration:
  - Sticky sessions: Disabled (stateless JWT)
  - Health checks: Enhanced monitoring
  - Failover: Automatic if error rate > 1%
  
Monitoring:
  - Real-time metrics comparison
  - User experience tracking
  - A/B performance analysis
  - Business metrics preservation
```

### Canary Deployment Strategy

#### 1. Blue-Green Setup (J+1, 2h)
```bash
# Configuration Load Balancer:
Blue Environment (90% traffic):
  - Ruby 3.3.0 + Rails 7.1.5.1
  - Current production stack
  - Proven stability

Green Environment (10% traffic):  
  - Ruby 3.4.8 + Rails 8.1.1
  - New stack validation
  - Enhanced monitoring
```

#### 2. Traffic Routing (J+1, 4h)
```yaml
# Progressive traffic increase:

Hour 1-6: 1% traffic (validation of deployment)
Hour 7-12: 5% traffic (extended monitoring)  
Hour 13-24: 10% traffic (full validation)
Hour 25-36: 10% traffic (sustained load)
Hour 37-48: 10% traffic (final validation)

Routing Rules:
  - User ID hash modulo 10: 0 = Green (new), 1-9 = Blue (legacy)
  - Consistent routing per user session
  - Health check integration
  - Automatic failover triggers
```

### Enhanced Monitoring Phase 2

#### Real-Time Metrics Dashboard
```ruby
# Comparaison Blue vs Green:

Performance Comparison:
  Response Time:
    Blue (Rails 7.1.5.1): 150ms baseline
    Green (Rails 8.1.1): Target < 115ms
    Alert: Green > Blue + 20%
    
  Throughput:
    Blue: 1000 req/sec baseline  
    Green: Target > 1300 req/sec
    Alert: Green < Blue - 10%
    
  Error Rate:
    Blue: < 0.1% baseline
    Green: Target < 0.1%
    Alert: Green > 1%

User Experience:
  - OAuth success rate (Google/GitHub)
  - Login/logout flow completion
  - API response consistency
  - Mobile vs desktop performance
```

#### Business Metrics Tracking
```yaml
# Impact business monitoring:

Authentication Metrics:
  - Login success rate: Maintain > 99.5%
  - OAuth completion rate: Maintain > 98%
  - Token validation speed: Target improvement
  - Session creation time: Target < 500ms

API Performance:
  - User registration: Target < 2s
  - Profile updates: Target < 500ms
  - Data retrieval: Target < 200ms
  - Bulk operations: Target < 5s
```

### Success Criteria Phase 2
```yaml
✅ Performance: Green stack meets or exceeds Blue stack
✅ Reliability: Error rate < 0.1% on both stacks  
✅ User Experience: No degradation in OAuth flows
✅ Business Metrics: All KPIs maintained or improved
✅ Monitoring: Real-time comparison dashboard functional
✅ Scalability: Load handling consistent across stacks
✅ Security: All security metrics maintained
```

### Rollback Criteria Phase 2
```yaml
❌ IMMEDIATE ROLLBACK if:
  - Error rate > 1% on Green stack
  - Performance degradation > 20% vs Blue
  - OAuth flows broken or degraded
  - Database performance issues
  - Memory leaks or instability
  - User complaints > baseline
  - Business metrics degradation
```

### Actions Phase 2
```bash
# Monitoring every 4 hours:
1. Metrics review (performance + error rates)
2. User feedback analysis
3. Business impact assessment
4. Technical team standup

# Decision Points:
Hour 12: Go/No-Go for sustained 10% traffic
Hour 24: Go/No-Go for Phase 3 full deployment
Hour 36: Final validation before Phase 3

# Emergency Rollback (if needed):
kubectl patch service foresy-api -p '{"spec":{"selector":{"version":"blue"}}}'
```

---

## 📋 PHASE 3: FULL PRODUCTION DEPLOYMENT

### Objectif
**Migration complète vers Ruby 3.4.8 + Rails 8.1.1 avec monitoring intensif**

### Timeline
**Durée :** 72 heures  
**Début :** J+3 09:00 (après validation Phase 2)  
**Fin :** J+6 09:00 (monitoring complet)

### Full Deployment Strategy

#### 1. Complete Traffic Migration (J+3, 4h)
```yaml
# Traffic migration progression:

Hour 1-2: 25% traffic (Ruby 3.4.8 + Rails 8.1.1)
Hour 3-4: 50% traffic (Ruby 3.4.8 + Rails 8.1.1)
Hour 5-6: 75% traffic (Ruby 3.4.8 + Rails 8.1.1)
Hour 7-8: 100% traffic (Ruby 3.4.8 + Rails 8.1.1)

Blue Environment: Decommission after 48h monitoring
Green Environment: Full production stack
```

#### 2. Post-Migration Validation (J+3 to J+6)
```bash
# Continuous monitoring for 72 hours:

Daily Validation (J+3, J+4, J+5, J+6):
1. Morning metrics review (09:00)
2. Midday performance check (13:00)  
3. Evening stability assessment (17:00)
4. Overnight monitoring (21:00-07:00)

Weekly Validation (J+7):
1. Full performance analysis
2. Business impact assessment
3. Team retrospective
4. Documentation update
```

### Final Success Criteria
```yaml
✅ Performance: Sustained improvement vs baseline
✅ Stability: Zero critical incidents
✅ Scalability: Handling full production load
✅ User Experience: Positive feedback + metrics
✅ Business Impact: All KPIs maintained/improved
✅ Team Confidence: Operational readiness confirmed
✅ Documentation: Complete migration documentation
```

---

## 🚨 ROLLBACK STRATEGY

### Emergency Rollback (5 minutes)
```bash
# Instant rollback to previous stack:

1. LOAD BALANCER SWITCH
   # Immediate traffic redirect
   kubectl patch service foresy-api -p '{"spec":{"selector":{"version":"stable"}}}'
   
2. DATABASE (if needed)
   # Schema rollback (additive migrations only)
   rails db:migrate:down VERSION=xxx
   rails db:migrate VERSION=yyy
   
3. REDIS (if needed)  
   # Switch to previous Redis configuration
   # No data loss (Redis optional for current features)
   
4. VERIFICATION
   curl -f https://foresy-api.onrender.com/health
   # Expected: 200 OK + stable metrics
```

### Planned Rollback (30 minutes)
```bash
# If issues discovered during monitoring:

1. TRAFFIC REDUCTION
   # Gradual reduction to previous stack
   kubectl patch service foresy-api -p '{"spec":{"selector":{"version":"stable"}}}'
   
2. ANALYSIS
   # Gather logs, metrics, error reports
   # Identify root cause
   # Plan resolution strategy
   
3. COMMUNICATION
   # Notify stakeholders
   # Update status page
   # Document incident
   
4. RESOLUTION
   # Fix identified issues
   # Update documentation
   # Plan re-deployment
```

---

## 📊 MONITORING DASHBOARD

### Key Metrics Real-Time
```yaml
# Production monitoring dashboard:

Performance Metrics:
  - Response Time (p50, p95, p99): Target < 115ms
  - Throughput (req/sec): Target > 1300 req/sec  
  - Memory Usage: Target < 563MB (+10% YJIT overhead)
  - CPU Usage: Target < 70% (2 Puma workers)

Reliability Metrics:
  - Error Rate: Target < 0.1%
  - Uptime: Target > 99.9%
  - Health Check: Target 200 OK
  - Database Connections: Pool utilization < 80%

Business Metrics:
  - Login Success Rate: Target > 99.5%
  - OAuth Completion: Target > 98%
  - API Response Consistency: Target > 99%
  - User Satisfaction: Monitor feedback
```

### Alert Configuration
```yaml
# Critical Alerts (Immediate Response):
  - Error rate > 1%: PagerDuty + Slack
  - Response time > 200ms: PagerDuty + Slack
  - Memory usage > 700MB: PagerDuty + Slack
  - Health check failures: PagerDuty + Slack
  - Database connection failures: PagerDuty + Slack

# Warning Alerts (Monitoring):
  - Response time > 150ms: Slack notification
  - Memory usage > 600MB: Slack notification
  - Error rate > 0.5%: Slack notification
  - YJIT compilation failures: Slack notification
```

---

## 👥 RESPONSABILITÉS ÉQUIPE

### CTO (Michael)
```yaml
Primary Responsibilities:
  - Final go/no-go decision for each phase
  - Stakeholder communication
  - Risk assessment and approval
  - Resource allocation for monitoring

Availability:
  - Phase 1: On-call 24/7
  - Phase 2: On-call 24/7  
  - Phase 3: On-call 24/7
  - Emergency contact for critical decisions
```

### Lead Developer
```yaml
Primary Responsibilities:
  - Technical implementation oversight
  - Performance monitoring and analysis
  - Rollback execution if needed
  - Team coordination during deployment

Availability:
  - Phase 1: Present 100% time
  - Phase 2: Present 100% time
  - Phase 3: Present 100% time
  - Hands-on technical execution
```

### DevOps Engineer
```yaml
Primary Responsibilities:
  - Infrastructure deployment
  - Monitoring setup and configuration
  - Load balancer management
  - Log aggregation and analysis

Availability:
  - Phase 1: Present 100% time
  - Phase 2: Present 100% time
  - Phase 3: Present 100% time
  - Infrastructure emergency response
```

### QA Engineer
```yaml
Primary Responsibilities:
  - Functional testing validation
  - User acceptance testing
  - Performance testing execution
  - Bug identification and reporting

Availability:
  - Phase 1: Present 100% time
  - Phase 2: Present 80% time
  - Phase 3: Present 60% time
  - Testing and validation focus
```

---

## 📞 COMMUNICATION PLAN

### Stakeholder Updates
```yaml
# Regular communication schedule:

Daily Updates (During All Phases):
  - Morning: Status update to all stakeholders
  - Evening: Summary report with metrics
  - Immediate: Critical issues or rollback decisions

Weekly Updates (Post-Deployment):
  - Performance analysis report
  - User feedback summary
  - Business impact assessment
  - Lessons learned documentation
```

### Incident Communication
```yaml
# If issues occur during deployment:

Critical Issues (Rollback Required):
  1. Immediate: Slack alert to all stakeholders
  2. 5 minutes: Phone calls to CTO + Lead Developer
  3. 15 minutes: Status page update
  4. 30 minutes: Detailed incident report

Warning Issues (Monitoring Required):
  1. Immediate: Slack alert to technical team
  2. 1 hour: Assessment and next steps
  3. 2 hours: Update to stakeholders if persistent
  4. End of day: Summary in daily report
```

---

## ✅ VALIDATION CHECKLIST

### Pre-Deployment Checklist
```yaml
Technical Readiness:
  ✅ All tests passing (221 RSpec + 66 Rswag)
  ✅ Code review completed and approved
  ✅ Documentation updated and reviewed
  ✅ Monitoring dashboards configured
  ✅ Rollback procedures tested
  ✅ Team training completed

Stakeholder Readiness:
  ✅ CTO approval obtained
  ✅ Business stakeholders informed
  ✅ Customer support team briefed
  ✅ Status page prepared
  ✅ Communication plan activated

Infrastructure Readiness:
  ✅ Staging environment configured
  ✅ Production canary setup verified
  ✅ Load balancer configuration tested
  ✅ Database migrations prepared
  ✅ Redis configuration validated
```

### Phase Transition Checklist
```yaml
Phase 1 → Phase 2 Transition:
  ✅ All Phase 1 success criteria met
  ✅ Performance benchmarks validated
  ✅ Security scan completed
  ✅ Monitoring configured for production
  ✅ Canary deployment tested
  ✅ Rollback procedures verified

Phase 2 → Phase 3 Transition:
  ✅ All Phase 2 success criteria met
  ✅ Canary traffic performance validated
  ✅ User experience maintained
  ✅ Business metrics preserved
  ✅ Full deployment plan reviewed
  ✅ Team confidence confirmed
```

### Post-Deployment Checklist
```yaml
Phase 3 Completion:
  ✅ All success criteria sustained for 72h
  ✅ Performance improvements documented
  ✅ User feedback positive
  ✅ Business impact assessed
  ✅ Team retrospective completed
  ✅ Documentation finalized
  ✅ Blue environment decommissioned
  ✅ Migration marked as complete
```

---

## 🎯 CONCLUSION

### Expected Outcomes
```yaml
Success Indicators:
  - Performance improvement: +30% throughput
  - Reliability maintenance: < 0.1% error rate
  - User experience: No degradation
  - Business continuity: All KPIs maintained
  - Team confidence: High operational readiness

Risk Mitigation:
  - Progressive deployment: 3-phase approach
  - Comprehensive monitoring: Real-time metrics
  - Quick rollback: 5-minute emergency procedure
  - Team availability: 24/7 coverage during deployment
  - Communication: Regular stakeholder updates
```

### Final Approval
```yaml
✅ PLAN APPROVED FOR EXECUTION

Prepared by: Foresy Technical Team
Approved by: CTO Foresy
Date: 26 December 2025
Next Review: Post-deployment (J+7)
```

---

*Plan de déploiement créé le 26 décembre 2025*  
*Équipe technique Foresy*  
*Approbation CTO requise avant exécution*