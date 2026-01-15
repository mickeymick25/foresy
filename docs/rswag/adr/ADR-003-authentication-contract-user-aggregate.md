# ADR-003: Authentication Contract & User Aggregate

## Status
Accepted

## Context

The Foresy authentication system has evolved through successive iterations, originally supporting Email/Password authentication, then adding OAuth authentication (Google, GitHub). This evolution introduced several critical issues:

- Multiple accepted payload formats for the same endpoint
- Implicit parameter fallbacks in controllers
- Divergence between domain rules and API behavior
- Invalid `User` aggregate states becoming possible
- Authentication behavior becoming non-deterministic
- Errors appearing at validation time instead of contract level
- System failed silently until runtime errors surfaced

The January 15, 2026 incident revealed that the coexistence of authentication mechanisms created contract ambiguity, allowing duplicated parameters and inconsistent behavior across different clients (Postman, cURL).

## Decision

The authentication system **MUST** follow the architectural constraints defined below to ensure domain integrity and API predictability.

### 1. Single Authentication Method per Endpoint

Each API endpoint **MUST** support exactly one authentication strategy:

- Authentication methods **MUST** be isolated at API level
- A single endpoint **MUST NOT** support multiple auth strategies
- Backward compatibility **MUST NOT** be implemented via parameter fallback
- Any auth evolution **MUST** be explicit and versioned

### 2. OAuth Endpoint Architecture

OAuth authentication **MUST** be implemented through dedicated endpoints and **MUST NOT** reuse signup endpoints:

```ruby
# CORRECT: Dedicated OAuth endpoints
get '/api/v1/auth/google_oauth2/callback'  # OAuth callback
get '/api/v1/auth/github/callback'          # OAuth callback
post '/api/v1/auth/:provider/callback'      # General OAuth callback

# FORBIDDEN: Reusing signup endpoints for OAuth
post '/api/v1/signup' do
  parameter :provider  # ❌ Not allowed - signup is for password auth only
end
```

### 3. User Aggregate Invariants (Non-Negotiable)

The `User` entity **MUST** maintain these invariants at all times:

- A User **MUST** have exactly one authentication method
- Email **MUST** be always required and unique
- Password-based users **MUST NOT** have OAuth attributes
- OAuth users **MUST NOT** have passwords
- Authentication logic **MUST NOT** live in controllers
- Controllers **MUST NOT** contain business rules

Any violation of these invariants **MUST** be rejected at the contract level, never reaching domain validation.

### 4. Controller Anti-Corruption Layer

Controllers **MUST** act as anti-corruption layers and follow these rules:

```ruby
# Controllers are considered anti-corruption layers and MUST:
# - validate payload structure
# - reject invalid contracts
# - delegate all business logic to the domain layer

# Example: Signup Controller
class Api::V1::UsersController < ApplicationController
  # Contract validation - MUST reject invalid payloads upfront
  def create
    # MUST use strict parameter validation
    user_params = params.require(:user).permit(:email, :password, :password_confirmation)
    
    # MUST NOT implement parameter fallback
    # FORBIDDEN: params[:email] || params.dig(:user, :email)
    
    # MUST delegate all business logic to domain layer
    result = UserCreationService.call(user_params)
    
    # MUST handle domain results appropriately
    if result.success?
      render json: result.user, status: :created
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end
  
  # MUST NOT contain authentication logic
  # FORBIDDEN: Password validation, OAuth handling, etc.
end
```

### 5. Domain Services Standards

Domain services **MUST** follow these standards to ensure consistency and predictability:

```ruby
# Domain services MUST:
# - be deterministic
# - return explicit success/failure results
# - never raise raw framework exceptions

# Example: UserCreationService
class UserCreationService
  def self.call(params)
    # MUST be deterministic - same input always produces same output
    # MUST return explicit result object
    # MUST NOT raise ActiveRecord::RecordInvalid, etc.
    
    result = Result.new
    
    # Domain validation
    unless valid_email?(params[:email])
      result.add_error(:email, 'invalid')
      return result
    end
    
    # Business logic
    user = User.new(email: params[:email], password: params[:password])
    
    if user.save
      result.success = true
      result.user = user
    else
      result.add_error(:base, user.errors.full_messages.join(', '))
    end
    
    result
  end
  
  private
  
  def self.valid_email?(email)
    email =~ URI::MailTo::EMAIL_REGEXP
  end
end

# Result object pattern
class Result
  attr_accessor :success, :user, :errors
  
  def initialize
    @success = false
    @errors = {}
  end
  
  def add_error(field, message)
    @errors[field] = message
  end
  
  def success?
    @success
  end
end
```

### 6. API Contract-First Principle

Each authentication endpoint **MUST** define:

- Accepted payload structures (explicit)
- Explicitly rejected payload structures
- Expected HTTP status codes

**Implicit parameter fallback is strictly FORBIDDEN.**

#### HTTP Status Codes Semantics

**422 Unprocessable Entity** is reserved exclusively for domain-level validation errors.
**Contract violations MUST always return 400 Bad Request.**

```ruby
# CORRECT: Contract violation -> 400 Bad Request
def create
  unless params[:user].present?
    render json: { error: 'Missing user parameter' }, status: :bad_request
    return
  end
end

# CORRECT: Domain validation error -> 422 Unprocessable Entity  
def create
  user = User.new(user_params)
  unless user.valid?
    render json: { error: user.errors.full_messages }, status: :unprocessable_entity
    return
  end
end
```

#### Example: Signup Endpoint Contract

**Accepted Structure**

```json
{
  "user": {
    "email": "user@foresy.local",
    "password": "secret123",
    "password_confirmation": "secret123"
  }
}
```

**Rejected Structures (MUST return 400 Bad Request)**

```json
// Root-level parameters
{
  "email": "user@foresy.local",
  "password": "secret123",
  "password_confirmation": "secret123"
}

// Mixed payloads
{
  "user": {
    "email": "user@foresy.local"
  },
  "password": "secret123"
}

// Missing user key
{
  "email": "user@foresy.local",
  "password": "secret123"
}
```

### 7. Enforcement Mechanisms

The following mechanisms **MUST** be implemented:

- `params.require(:user)` in controllers (no fallback allowed)
- Request specs asserting 400 Bad Request for invalid contracts
- Request specs asserting 422 Unprocessable Entity for domain validation errors
- CI failure on contract violation
- Domain tests validating User aggregate invariants

## Consequences

### Positive Consequences

- **Guaranteed User aggregate integrity** through strict invariants
- **Predictable authentication behavior** with isolated endpoints
- **Early contract validation** preventing invalid domain states
- **Clear separation of concerns** between API and domain layers
- **Easier testing and maintenance** with explicit contracts
- **Consistent error handling** through standardized HTTP status codes

### Negative Consequences

- **Increased initial development time** for new authentication methods
- **Breaking changes** for existing mixed authentication endpoints
- **Migration required** for current ambiguous contracts
- **Learning curve** for team members unfamiliar with DDD patterns

## Implementation Guidelines

### For New Authentication Endpoints

1. **Define Contract First**: Specify accepted/rejected payload structures
2. **Implement Controller**: Use anti-corruption layer pattern
3. **Create Domain Services**: Follow domain services standards
4. **Add Contract Tests**: Ensure 400 Bad Request for invalid contracts
5. **Add Domain Tests**: Validate User aggregate invariants

### For Existing Endpoints

1. **Audit Current Implementation**: Identify ambiguous contracts
2. **Plan Migration**: Version new, explicit contracts
3. **Deprecate Old Patterns**: Remove parameter fallbacks
4. **Update Tests**: Ensure contract and domain coverage
5. **Monitor Metrics**: Track contract violations and HTTP status code usage

## Canonical Failure Scenario

The following scenario **MUST** be prevented at all costs:

1. Client sends duplicated parameters:
   - One at root level
   - One nested under `user`
2. Controller partially accepts the payload
3. Domain validation fails with misleading errors
4. API returns 422 instead of rejecting upfront

**Any regression allowing this scenario to pass is considered a critical failure and MUST block deployment.**

## Monitoring and Compliance

- **Contract Violations**: Monitor and alert on 400 Bad Request rates
- **HTTP Status Code Usage**: Track 400 vs 422 distribution
- **Domain Integrity**: Track User aggregate invariant violations
- **Test Coverage**: Ensure contract and domain test coverage
- **CI Gates**: Automated enforcement of architectural constraints

## References

- [Issue Resolution Methodology v1.3](../corrections/2026-01-15-issue-resolution-methodology.md)
- [User Aggregate Domain Model](../models/user.rb)
- [Authentication Services](../services/authentication_service.rb)
- [API Contract Tests](../spec/requests/api/v1/users_request_spec.rb)
- [Domain Services Pattern](../docs/architecture/domain-services.md) (future)

---

**Date**: January 15, 2026  
**Status**: Accepted  
**Version**: 1.4  
**Review Date**: February 15, 2026  
**Owner**: Engineering Team