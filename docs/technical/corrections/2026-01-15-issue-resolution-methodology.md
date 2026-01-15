# Issue Resolution Methodology

## Overview

This document defines the systematic and enforceable methodology for resolving technical issues in the Foresy API project.  
It is a **source of truth** for debugging, fixing, and preventing issues, with a strict focus on **Domain-Driven Design (DDD)**, **Test-Driven Development (TDD)**, and **CI/CD enforcement**.

This methodology was formalized during the resolution of critical signup endpoint issues (January 15, 2026).

---

## Explicit Problem Statement

### Problem to Solve

The Foresy authentication system currently suffers from **contract ambiguity** caused by successive iterations supporting both:

- Email / Password authentication
- OAuth authentication (Google, GitHub)

This evolution introduced:
- Multiple accepted payload formats for the same endpoint
- Implicit parameter fallbacks in controllers
- Divergence between domain rules and API behavior

As a result:
- Invalid `User` aggregate states became possible
- Authentication behavior became non-deterministic
- Errors appeared at validation time instead of contract level
- The system failed silently until runtime errors surfaced

---

### Target Outcome

The goal of this methodology is not only to fix bugs, but to:

- Restore a **single, explicit API contract**
- Enforce **User aggregate invariants**
- Make invalid states **unrepresentable**
- Detect contract violations **before deployment**

---

## Domain-Driven Design Enforcement

### Bounded Context Identification

All authentication-related issues belong to the following bounded context:

**Identity & Access Context**

This context is responsible for:
- User identity creation
- Authentication method management
- Credential validation
- Access control primitives

It is strictly isolated from:
- Financial forecasting logic
- Subscription & billing
- Business analytics

---

### Aggregate Root: User

The `User` entity is the aggregate root of the Identity & Access context.

#### Domain Invariants (Non-Negotiable)

- A User MUST have exactly one authentication method
- Email is always required and unique
- Password-based users MUST NOT have OAuth attributes
- OAuth users MUST NOT have passwords
- Authentication logic MUST NOT live in controllers
- Controllers MUST NOT contain business rules

Any fix violating these invariants is considered invalid, even if it resolves the immediate issue.

---

### Authentication Evolution Constraint

The coexistence of multiple authentication mechanisms (Email/Password and OAuth) is considered a **domain complexity driver**.

As such:

- Authentication methods MUST be isolated at API level
- A single endpoint MUST NOT support multiple auth strategies
- Backward compatibility MUST NOT be implemented via parameter fallback
- Any auth evolution MUST be explicit and versioned

Controllers are considered anti-corruption layers and MUST:
- validate payload structure
- reject invalid contracts
- delegate all business logic to the domain layer

Failure to respect these rules is considered a violation of the Identity & Access bounded context.

---

## Test-Driven Development Enforcement

### Mandatory Rule

❗ **No production code modification is allowed before a failing automated test exists.**

Manual reproduction (cURL/Postman) is required, but **automated tests are mandatory** before fixing.

---

### TDD Workflow for Issue Resolution

1. Reproduce the bug manually (cURL / Postman)
2. Translate the bug into an automated failing test
3. Verify the test fails for the correct reason
4. Implement the minimal fix
5. Refactor only after tests pass
6. Commit tests and implementation together

---

### Test Categories (Priority Order)

1. **Domain Tests**
   - Validate invariants
   - Prevent invalid states
2. **Request Tests**
   - Validate API contracts
   - Reject malformed payloads
3. **Integration Tests**
   - Verify end-to-end authentication flows

Skipping domain tests for authentication-related issues is strictly forbidden.

---

## Methodology Framework

### 1. Initial Problem Assessment

**Step 1.1: Problem Identification**
- Document the exact error message and HTTP status code
- Identify the affected endpoint(s) and functionality
- Determine if the issue is client-specific or system-wide
- Record the timestamp and context of the issue

**Step 1.2: Impact Assessment**
- Evaluate severity (critical, high, medium, low)
- Determine affected user base
- Assess business impact
- Check if it's a regression or new issue

**Step 1.3: Initial Hypothesis**
- Formulate initial theories about root causes
- Consider recent changes or deployments
- Think about environmental factors

---

## Systematic Diagnosis

### 2. Environment Verification

```bash
# Verify services are running
docker-compose ps

# Test basic connectivity
curl http://localhost:3000/health

# Check database connectivity
docker-compose exec -T db psql -U postgres -d foresy_development -c "SELECT current_database();"

# Test Redis if applicable
docker-compose exec -T redis redis-cli ping
```

### 3. Reproduction Testing

- Test with multiple clients (cURL, Postman, browser)
- Verify if issue is client-specific or system-wide
- Document different behaviors across clients
- Test with different data sets

### 4. Root Cause Investigation

#### Log Analysis

```bash
docker-compose logs -f web
docker-compose logs web --tail=50 | grep -i error
docker-compose logs web --tail=100
```

#### Code Review

- Examine controller logic and parameter handling
- Check validation rules and constraints
- Review recent commits for related changes
- Analyze middleware and filters

#### Database Investigation

- Check for constraint violations
- Verify data integrity
- Look for foreign key issues
- Examine transaction rollbacks

---

## API Contract Validation

### Contract-First Principle

Each API endpoint MUST define:

- Accepted payload structures
- Explicitly rejected payload structures
- Expected HTTP status codes

**Implicit parameter fallback is strictly forbidden.**

#### Example: Signup Endpoint Contract

**Accepted**

```json
{
  "user": {
    "email": "user@foresy.local",
    "password": "secret123",
    "password_confirmation": "secret123"
  }
}
```

**Rejected**

- Root-level parameters
- Mixed payloads
- Missing user key

#### Enforcement Mechanisms

- `params.require(:user)` in controllers
- Request specs asserting 400 Bad Request
- CI failure on contract violation

---

## Canonical Failure Scenario

### Description

The canonical failure scenario that this methodology aims to prevent is the following:

- A client sends duplicated parameters:
  - One at root level
  - One nested under `user`
- The controller partially accepts the payload
- Domain validation fails with misleading errors
- The API returns a 422 instead of rejecting the request upfront

---

### Why This Is a System Failure

This failure:
- Should have been rejected at the API contract level
- Should never reach domain validation
- Indicates missing request specs
- Indicates weak boundary enforcement between API and domain

This scenario MUST be covered by automated tests at all times.

**Any regression allowing this scenario to pass is considered a critical failure and must block deployment.**

---

## Solution Development

### Solution Design

- Consider multiple approaches
- Evaluate pros/cons
- Think about edge cases
- Define rollback strategy

### Implementation

- Apply minimal, targeted fixes
- Respect domain invariants
- Avoid controller bloat
- Document all changes

### Validation

- Test original failing scenario
- Run full regression suite
- Verify multiple payload variants
- Confirm no performance degradation

---

## CI/CD Gatekeeping Rules

### Mandatory Pipeline

A change is valid ONLY if:

- All tests pass
- No authentication coverage regression
- No RuboCop violations
- No contract-breaking change

### Forbidden Situations

- Fix merged without tests
- Hotfix directly on main
- Contract changes without documentation update
- Increased controller logic without justification

### Authentication Change Checklist (CI-Enforced)

- [ ] Domain invariants covered
- [ ] Request specs updated
- [ ] OAuth and password flows isolated
- [ ] No ambiguous params accepted

---

## Case Study: Signup Endpoint Issue

### Problem Description

- **Issue**: HTTP 422 errors on signup
- **Error**: "Password can't be blank", "Password is too short"
- **Affected**: Postman and cURL
- **Environment**: Local (Docker)

### Investigation Summary

```text
Parameters: {
  "email" => "test@example.com",
  "password" => "[FILTERED]",
  "user" => { "email" => "test@example.com" }
}
```

### Root Cause

- Duplicate parameters sent by client
- Controller favored nested params
- Missing password in permitted structure
- No contract-level rejection

### Resolution

- Enforced strict payload structure
- Added request specs rejecting invalid formats
- Removed param fallbacks
- Updated Postman collections

### What Should Have Been Prevented

- Contract tests should have rejected root-level params
- Domain tests should have rejected incomplete users
- CI should have failed earlier

This issue reveals a structural flaw in how authentication evolution was handled, and serves as the reference failure scenario this methodology is designed to prevent.

---

## Quality Assurance Checklist

### Before Resolution

- [ ] Issue reproduced
- [ ] Impact assessed
- [ ] Tests planned
- [ ] Logs monitored

### During Resolution

- [ ] Failing test written
- [ ] Root cause documented
- [ ] Minimal fix applied

### After Resolution

- [ ] Tests passing
- [ ] Regression verified
- [ ] Documentation updated
- [ ] CI green

---

## Final Rule (Team Reminder)

**If a bug can create an invalid User, then the problem is not the bug, but the API ↔ Domain boundary.**

---

## Continuous Improvement

### Metrics

- Time to resolution
- Issue recurrence
- Test coverage evolution
- Contract violations

### Reviews

- Monthly methodology review
- Update based on incidents
- Improve automation and CI rules

---

## Escalation Path

1. Developer
2. Senior Developer
3. Technical Lead
4. CTO

---

**Document Version**: 1.3  
**Last Updated**: January 15, 2026  
**Owner**: Engineering  
**Review Cycle**: Monthly  
**Next Review**: February 15, 2026