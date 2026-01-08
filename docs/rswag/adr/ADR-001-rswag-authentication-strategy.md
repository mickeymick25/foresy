# ADR-001 — RSwag Authentication Strategy (JWT via Real Login)

## Status
Accepted

## Context

The API uses JWT authentication for all protected endpoints.

Historically, RSwag request specs attempted to generate JWT tokens manually using `JWT.encode`.
This led to multiple issues:

- Tokens not matching the real backend configuration (secret, claims, expiration)
- False positives and false negatives in tests
- Fragile specs tightly coupled to implementation details
- RSwag DSL misuse (`header` used outside its valid context)
- Inconsistent handling of missing, invalid, or malformed tokens

These issues made RSwag tests unreliable and costly to maintain.

## Decision

All RSwag request specs for authenticated endpoints **MUST** follow the canonical authentication strategy defined below.

### 1. Authentication via the real API

JWT tokens **MUST** be obtained using the real authentication endpoint:

- `/api/v1/auth/login`
- Via the helper method `authenticate(user)`

Manual token generation using `JWT.encode` is **FORBIDDEN** in specs.

### 2. Authorization header injection

Authentication is provided using the RSwag-supported pattern:

```ruby
let(:Authorization) { "Bearer #{authenticate(user)}" }
```

Rules:
- header MUST NOT be used in before blocks
- let(:Authorization) is the only supported mechanism
- The parameter must be declared explicitly in the spec

### 3. Missing authorization cases

To test unauthenticated access:
- The Authorization header MUST be omitted entirely
- nil MUST NOT be used
- No fallback or default token is allowed

### 4. Invalid and malformed tokens

For negative authentication tests:
- invalid_jwt_token is used for invalid signatures
- malformed_jwt_token is used for structurally invalid tokens

These tokens are provided by SwaggerAuthHelper.

### 5. Canonical helper

All authentication-related logic is centralized in:
`spec/support/swagger_auth_helper.rb`

This helper:
- Uses the real authentication API
- Reflects production behavior
- Is automatically included in RSwag specs

No duplication of authentication logic is allowed elsewhere.

## Consequences

### Positive
- RSwag tests accurately reflect real authentication behavior
- Elimination of JWT configuration drift
- Consistent and predictable authorization tests
- Reduced cognitive load for contributors
- Copy/paste-friendly templates for new endpoints

### Trade-offs
- Specs are slightly slower due to real login calls
- Test setup is more explicit

These trade-offs are accepted in favor of correctness and long-term maintainability.

## References
- `docs/rswag-guide.md`
- `spec/support/swagger_auth_helper.rb`
- `spec/requests/api/v1/**/swagger_*_spec.rb`
