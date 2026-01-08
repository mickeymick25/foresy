# ADR-002: RSwag vs Request Specs – Boundary of Responsibility

## Status
Accepted

## Context

The Foresy API uses both **RSwag specifications** and **RSpec request specs** to test API behavior.

Historically, responsibilities between these two test layers were unclear, leading to:
- duplicated test coverage
- inconsistent assertions
- fragile RSwag specs
- business logic leaking into documentation tests

With the stabilization of the RSwag methodology (ADR-001), it is necessary to **explicitly define the boundary of responsibility** between:
- **RSwag specs** (API contract & documentation)
- **Request specs** (behavioral & business logic testing)

This ADR formalizes that boundary.

---

## Decision

### 1. RSwag Specs Responsibility (Contract Layer)

RSwag specs are the **single source of truth for the public API contract**.

They are responsible for:

- ✅ Endpoint existence and HTTP verb
- ✅ Request parameters (path, query, body, headers)
- ✅ Authentication requirements (presence, type, behavior)
- ✅ HTTP status codes
- ✅ Response schema and shape
- ✅ High-level error cases observable by API consumers
- ✅ Swagger / OpenAPI documentation generation

RSwag specs **MUST NOT**:
- ❌ Assert internal business rules in detail
- ❌ Test edge-case permutations of business logic
- ❌ Validate database side effects beyond what is observable in the response
- ❌ Mock or stub application code
- ❌ Encode knowledge of internal services or models

RSwag specs answer the question:

> “What does this endpoint guarantee to an API consumer?”

---

### 2. Request Specs Responsibility (Behavior Layer)

Request specs are responsible for **business behavior and domain correctness**.

They are responsible for:

- ✅ Complex business rules
- ✅ Authorization logic beyond presence of a token
- ✅ Edge cases and invalid state transitions
- ✅ Data integrity and side effects
- ✅ Permission matrices (roles, ownership, visibility)
- ✅ Regression coverage for past bugs

Request specs **MAY**:
- Use factories extensively
- Use helpers, shared contexts, and setup logic
- Assert database changes
- Assert internal state transitions

Request specs answer the question:

> “Does the application behave correctly in all business scenarios?”

---

### 3. Authentication Boundary

| Concern | RSwag | Request Spec |
|------|------|-------------|
| Missing token | ✅ | ❌ |
| Invalid / malformed token | ✅ | ❌ |
| Expired token | ✅ | ❌ |
| Ownership / authorization | ❌ | ✅ |
| Role-based permissions | ❌ | ✅ |

RSwag validates **authentication mechanics**.  
Request specs validate **authorization rules**.

---

### 4. Error Handling Boundary

RSwag specs:
- Assert **status code**
- Assert **error key**
- Assert **response shape**

Request specs:
- Assert **exact failure reason**
- Assert **which rule failed**
- Assert **which model or service raised**

---

### 5. Duplication Rules (Hard Constraint)

- ❌ The same scenario MUST NOT be tested in both RSwag and request specs
- ❌ RSwag specs MUST NOT replicate request spec coverage
- ❌ Request specs MUST NOT reassert API contract details already covered by RSwag

If a test feels duplicated:
- The **higher-level contract** stays in RSwag
- The **deeper behavioral logic** moves to request specs

---

## Consequences

### Positive
- Clear separation of concerns
- Faster RSwag execution
- Stable Swagger documentation
- Reduced cognitive load
- Easier onboarding
- Cleaner reviews

### Negative
- Requires discipline during test writing
- Reviewers must enforce boundaries

These trade-offs are accepted.

---

## Enforcement Rules

1. RSwag specs **must follow the canonical templates**
2. Business logic assertions in RSwag are forbidden
3. Any exception requires a new ADR
4. Reviewers are expected to block PRs that violate this boundary

---

## Related Documents

- ADR-001: RSwag Authentication Strategy
- docs/rswag/guide.md
- spec/requests/api/v1/**/swagger/*

---

## Summary

| Layer | Responsibility |
|----|----|
| RSwag | API contract & documentation |
| Request Specs | Business behavior & correctness |

This separation is **intentional, enforced, and non-negotiable**.
