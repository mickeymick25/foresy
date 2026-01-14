# RSwag Reactivation Procedure - Phase 5

**Date**: 12 janvier 2026  
**Phase**: 5 - Platinum Validation  
**Purpose**: Reactivate RSwag from observer mode to blocking mode after domain stabilization  
**Prerequisites**: Phase 1.1-1.4 completed successfully (domain architecture stabilized)

---

## 🎯 Reactivation Overview

### Current Status (Phase 1.0-1.4)
- ✅ **RSwag Observer Mode**: Active (non-blocking)
- ✅ **Domain Architecture**: Stabilized (Phase 1.1-1.4 completed)
- ✅ **CI Workflows**: Phase 1.0 compatible (non-blocking)
- ✅ **Coverage Thresholds**: Relaxed (20% global, 10% per-file)

### Target Status (Phase 5)
- 🔴 **RSwag Blocking Mode**: Active (blocking on failures)
- 🔴 **Coverage Thresholds**: Normal (90% global, 80% per-file)
- 🔴 **CI Workflows**: Standard Platinum level
- 🔴 **Quality Gates**: Full enforcement

---

## 📋 Prerequisites Checklist

Before starting reactivation, verify these conditions are met:

### ✅ Domain Architecture Stabilized
- [ ] **Use-cases extracted**: CraCreator, CraUpdater, CraSubmitter, CraLocker implemented
- [ ] **Controllers cleaned**: Zero business logic in controllers (pure orchestration)
- [ ] **Services stabilized**: Create/Update/Destroy operations working correctly
- [ ] **Total recalculation**: Source of truth working (total_days, total_amount)
- [ ] **Git Ledger**: Transactional operations (lock + commit)
- [ ] **DDD compliance**: Domain/Relations separation strict

### ✅ Tests Passing
- [ ] **Domain specs**: 95-100% coverage on domain models
- [ ] **Services specs**: 90-95% coverage on business logic
- [ ] **Request specs**: 70-80% coverage on controllers
- [ ] **Integration tests**: CRA lifecycle working end-to-end
- [ ] **RSwag specs**: Expected to pass after domain fixes

### ✅ API Functionality
- [ ] **CRA operations**: Create, Update, Destroy working (201, 422, 403, 404)
- [ ] **mission_id**: Present and correct in all JSON responses
- [ ] **Pagination**: ≤10 entries per page
- [ ] **Performance**: <1s response time on all endpoints
- [ ] **Error handling**: Proper HTTP status codes

### ✅ Code Quality
- [ ] **RuboCop**: 0 offenses
- [ ] **Complexity**: ABC size <35 for all methods
- [ ] **Architecture**: Service-oriented pattern (no callbacks)
- [ ] **Brakeman**: 0 warnings

---

## 🔄 Reactivation Steps

### Step 1: Backup Current Configuration

```bash
# Create backup of Phase 1.0 configuration
cp .github/workflows/rswag-observer-mode.yml .github/workflows/rswag-observer-mode.yml.backup
cp .github/workflows/e2e-contract-validation.yml .github/workflows/e2e-contract-validation.yml.backup
cp .github/workflows/coverage-check.yml .github/workflows/coverage-check.yml.backup

# Create backup of current test results
cp -r coverage/ coverage-backup-$(date +%Y%m%d)/
```

### Step 2: Reactivate RSwag Blocking Mode

#### 2.1 Restore Original RSwag Workflow

```bash
# Restore original rswag-contract-check.yml
mv .github/workflows/DISABLED_rswag-contract-check.yml .github/workflows/rswag-contract-check.yml
```

#### 2.2 Update RSwag Workflow Name

```yaml
# Update workflow name from observer mode to blocking mode
name: RSwag Contract Validation (BLOCKING MODE)
```

#### 2.3 Remove Observer Mode Comments

Remove these lines from the workflow:
- `continue-on-error: true` (add to blocking jobs)
- Observer mode comments
- Non-blocking error handling
- Phase 1.0 context references

### Step 3: Restore Original E2E Validation

#### 3.1 Remove Phase 1.0 Compatibility

```bash
# Restore original e2e-contract-validation.yml
cp .github/workflows/e2e-contract-validation.yml.backup .github/workflows/e2e-contract-validation.yml

# Remove Phase 1.0 compatibility modifications
# - Remove `continue-on-error: true` from critical steps
# - Restore original error handling
# - Remove Phase 1.0 comments
```

#### 3.2 Restore Original Workflow Name

```yaml
# Update workflow name
name: E2E Contract Validation (PLATINUM LEVEL)
```

### Step 4: Restore Original Coverage Checks

#### 4.1 Restore Coverage Thresholds

```yaml
# In coverage-check.yml, restore normal thresholds:
GLOBAL_THRESHOLD: 90.0    # Restore from 20.0
FILE_THRESHOLD: 80.0      # Restore from 10.0
```

#### 4.2 Remove Phase 1.0 Compatibility

Remove Phase 1.0 modifications:
- `continue-on-error: true`
- Phase 1.0 threshold logic
- Observer mode comments
- Non-blocking error handling

#### 4.3 Restore Workflow Name

```yaml
# Update workflow name
name: Coverage Check (PLATINUM LEVEL)
```

### Step 5: Clean Up Observer Mode Files

```bash
# Remove Phase 1.0 observer mode files
rm .github/workflows/rswag-observer-mode.yml

# Update remaining workflow names to reflect Platinum level
mv .github/workflows/e2e-contract-validation.yml .github/workflows/e2e-contract-validation.yml
mv .github/workflows/coverage-check.yml .github/workflows/coverage-check.yml
```

---

## 🧪 Validation Testing

### Test 1: RSwag Workflow Validation

```bash
# Test RSwag workflow in isolation
docker compose run --rm web bundle exec rspec spec/requests/ --tag type:rswag --format documentation

# Expected result: All RSwag specs should pass
# If failures occur: Investigate and fix before proceeding
```

### Test 2: E2E Contract Validation

```bash
# Test E2E workflow
docker compose run --rm web bundle exec rake rswag:specs:swaggerize
docker compose run --rm web bundle exec rspec spec/requests/ --format documentation

# Expected result: No failures, clean contract validation
```

### Test 3: Coverage Validation

```bash
# Test coverage with normal thresholds
docker compose run --rm web bundle exec rspec --format progress

# Check coverage report
open coverage/index.html

# Expected result: Coverage should be at or approaching targets
```

### Test 4: Full CI Pipeline

```bash
# Test complete CI pipeline locally
docker compose run --rm web bash -c "
  echo '=== RSPEC ===' && bundle exec rspec --format progress &&
  echo '=== RUBOCOP ===' && bundle exec rubocop --format simple &&
  echo '=== BRAKEMAN ===' && bundle exec brakeman
"

# Expected result: All tools should pass without critical failures
```

---

## 🔍 Verification Checklist

After reactivation, verify these conditions:

### ✅ RSwag Blocking Mode
- [ ] **Workflow active**: `rswag-contract-check.yml` is running
- [ ] **Failures block**: PRs fail when RSwag specs fail
- [ ] **Comments working**: Automatic PR comments on failures
- [ ] **Swagger generated**: Documentation generated automatically

### ✅ E2E Contract Validation
- [ ] **Workflow active**: `e2e-contract-validation.yml` is running
- [ ] **Failures block**: PRs fail on critical E2E failures
- [ ] **Contract sync**: Swagger documentation matches specs
- [ ] **Standards enforced**: Template usage and separation validated

### ✅ Coverage Thresholds
- [ ] **Global threshold**: 90% enforced (failures if <90%)
- [ ] **Per-file threshold**: 80% enforced (failures if <80%)
- [ ] **Badges updated**: Coverage badges reflect normal thresholds
- [ ] **Comments working**: Automatic PR comments on failures

### ✅ Overall CI Pipeline
- [ ] **All workflows active**: No disabled or observer mode workflows
- [ ] **Standard names**: No "Phase 1.0" or "Observer" in names
- [ ] **Blocking behavior**: All quality gates active
- [ ] **PR integration**: Automatic comments and failures working

---

## 🚨 Rollback Procedure

If reactivation causes issues:

### Immediate Rollback

```bash
# Quick rollback to Phase 1.0 configuration
cp .github/workflows/rswag-observer-mode.yml.backup .github/workflows/rswag-observer-mode.yml
cp .github/workflows/e2e-contract-validation.yml.backup .github/workflows/e2e-contract-validation.yml
cp .github/workflows/coverage-check.yml.backup .github/workflows/coverage-check.yml

# Restore observer mode
mv .github/workflows/rswag-contract-check.yml .github/workflows/DISABLED_rswag-contract-check.yml
```

### Investigate and Fix

1. **Identify root cause** of reactivation failure
2. **Fix domain issues** that caused RSwag failures
3. **Update test coverage** if needed
4. **Re-run validation tests** before retrying reactivation

### Retry Reactivation

After fixing issues:
1. **Backup current state** again
2. **Re-run reactivation steps**
3. **Validate with testing checklist**
4. **Proceed only if all tests pass**

---

## 📊 Success Metrics

### Immediate Success Indicators
- ✅ **0 RSwag failures** in CI pipeline
- ✅ **0 E2E failures** in critical tests
- ✅ **Coverage trending up** toward 90%
- ✅ **All workflows active** and blocking on failures

### Phase 5 Success Criteria
- ✅ **API CRA**: 100% functional endpoints
- ✅ **Tests Coverage**: ≥90% global, ≥80% per-file
- ✅ **Code Quality**: 0 RuboCop offenses, 0 Brakeman warnings
- ✅ **Performance**: <1s response time all endpoints
- ✅ **Architecture**: DDD compliance strict

### Long-term Success Indicators
- 📈 **Coverage trending**: Increasing month over month
- 🔒 **Quality gates**: Preventing regressions
- 📋 **Documentation**: Swagger always synchronized
- 🚀 **Velocity**: Development speed maintained with quality

---

## 📝 Documentation Updates

After successful reactivation:

### 1. Update Recovery Plan

```markdown
# Foresy Platinum Recovery Action Plan - Update

## Phase 5 Completion
- ✅ RSwag reactivated successfully (date: YYYY-MM-DD)
- ✅ All quality gates restored to Platinum level
- ✅ CI pipeline fully operational

## Next Steps
- FC-08 development can proceed
- Maintain Platinum standards going forward
- Regular quality audits scheduled
```

### 2. Update README

```markdown
## Current Status
- **Phase**: 5 - Platinum Level Active
- **Quality Gates**: Full enforcement (90% coverage, 0 RuboCop, etc.)
- **CI Pipeline**: Standard Platinum configuration
- **Development**: FC-08 ready to start
```

### 3. Archive Phase 1.0 Documentation

```bash
# Move Phase 1.0 specific documentation
mkdir docs/technical/corrections/phase-1.0-archive/
mv docs/technical/corrections/RSwag_Reactivation_Procedure_Phase5.md docs/technical/corrections/phase-1.0-archive/
```

---

## 🎯 Post-Reactivation Monitoring

### Week 1: Intensive Monitoring
- [ ] **Daily CI checks**: Verify no unexpected failures
- [ ] **Coverage trends**: Monitor coverage percentage
- [ ] **Development impact**: Ensure team velocity maintained
- [ ] **Quality metrics**: Track RuboCop, Brakeman, performance

### Week 2-4: Stabilization
- [ ] **Weekly reviews**: Quality metrics dashboard
- [ ] **Team feedback**: Development experience assessment
- [ ] **Process optimization**: CI/CD performance tuning
- [ ] **Documentation updates**: Keep docs synchronized

### Month 2+: Normal Operations
- [ ] **Regular audits**: Scheduled quality reviews
- [ ] **Continuous improvement**: Metrics-based optimization
- [ ] **Knowledge transfer**: Ensure team understands new standards
- [ ] **Process evolution**: Adapt as needed based on experience

---

## 📞 Support Contacts

### Technical Issues
- **Lead Backend Engineer**: Domain architecture questions
- **DevOps Engineer**: CI/CD workflow issues
- **QA Engineer**: Test coverage and quality metrics
- **CTO**: Strategic decisions and escalation

### Emergency Contacts
- **GitHub Issues**: For technical problems requiring investigation
- **Slack Channel**: #foresy-recovery for real-time support
- **Email**: foresy-tech-team@company.com for formal escalation

---

## 📅 Timeline

### Estimated Reactivation Time
- **Preparation**: 30 minutes (backup, checklist verification)
- **Reactivation**: 1-2 hours (workflow updates, testing)
- **Validation**: 2-4 hours (comprehensive testing)
- **Rollback if needed**: 30 minutes (if issues encountered)

### Total Downtime
- **Best case**: 2-3 hours (smooth reactivation)
- **Typical case**: 4-6 hours (some troubleshooting expected)
- **Worst case**: 1-2 days (significant domain issues discovered)

### Success Probability
- **High (90%)**: If Phase 1.1-1.4 completed successfully
- **Medium (70%)**: If minor issues in domain stabilization
- **Low (50%)**: If significant problems discovered during validation

---

**Document Status**: ✅ **Ready for Execution**  
**Last Updated**: 12 janvier 2026  
**Phase**: 5 - Platinum Validation  
**Owner**: Technical Co-Director Team  

**⚠️ Important**: Only execute this procedure after Phase 1.1-1.4 are successfully completed and domain architecture is fully stabilized.