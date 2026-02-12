# 2026-02-12 - Swagger RSwagSpecs Completion Plan

**Date:** 12 February 2026  
**Author:** Senior Product Architect + CTO  
**Objective:** Complete RSwag specs for all API endpoints to ensure Swagger is a verifiable contract, not decorative documentation.

---

## 📌 Executive Summary

Current state: Swagger documentation is incomplete, missing critical endpoints that exist in controllers but lack RSwag request specs. This creates an implementation-documentation gap that violates Clean Architecture principles.

Goal: Create minimal RSwag request specs covering HTTP contract (status codes) for all missing endpoints, enabling Swagger to serve as a verifiable public API surface. **Target: Platinum Level compliance** - ensuring all public API endpoints are contractually protected via RSwag specs.

**Platinum Level Alignment:**
- TDD compliance: All API behavior must have corresponding request specs
- Documentation as Code: Swagger generated exclusively from tests
- No undocumented endpoints in the public API surface
- Schema-first approach: All responses must include minimal schema definitions

**Quality Standards:**
- Use `swagger_helper` for RSwag generation
- Define `path`, `response`, `parameter`, `security` blocks
- Include `run_test!` in each response block
- Reference `$ref` schemas for consistency
- Cover 200/201 (success), 401 (auth), 404/422/409 (errors)

---

## 🎯 Rationale

### Why This Matters

1. **Verifiable Contract**: Swagger must be a verifiable contract, not decorative documentation
2. **Contractual Protection**: An endpoint without RSwag spec is not contractually protected
3. **Implementation-Documentation Gap**: Current state creates discrepancy between implementation and documentation
4. **Clean Architecture**: API documentation = formalized public surface
5. **TDD Compliance**: Features without API specs violate Platinum Level standards

### Decision Matrix

| Endpoint Category | Specification Required? | Rationale |
|-------------------|------------------------|-----------|
| Public API (frontend/partners) | ✅ Mandatory | Consumed externally, needs contractual protection |
| Internal API | ⚠️ Decision required | Either document officially or exclude from public scope |

---

## 📋 Action Plan Overview

| Phase | Focus | Endpoints | Estimated Effort |
|-------|-------|-----------|------------------|
| Phase 1 | Pattern Analysis | - | ~1 hour |
| Phase 1.5 | Schema & Security Validation | - | ~30 minutes |
| Phase 2 | Auth Revocation | 2 | ~45 minutes |
| Phase 3 | CRAs | 8 | ~1.5-2 hours |
| Phase 4 | CRA Entries | 5 | ~1.5 hours |
| Phase 5 | Validation & Generation | - | ~15 minutes |

**Total Estimated Time:** 5-6 hours (realistic) |

---

## 🎯 Phase 1: Pattern Analysis

### Objectives
- Identify existing RSwag specs structure
- Analyze coding patterns and conventions
- Document reusable helpers/concerns

### Tasks
1. List existing specs in `spec/requests/`, `spec/api/`, `spec/integration/`
2. Analyze `describe`, `path`, `response`, `schema` patterns
3. Document parameter extraction patterns
4. Review authentication helpers usage
5. **Verify components.securitySchemes definition** (exact scheme name: `bearerAuth`)
6. **Verify swagger_doc name** (typically `v1/swagger.yaml`)
7. **Identify existing $ref schemas** for User, CRA, CraEntry, Error

### Deliverable
Pattern reference document for new specs consistency

---

## 🎯 Phase 1.5: Schema & Security Validation

### Objectives
- Validate security scheme configuration matches existing specs
- Identify reusable schemas for response documentation
- Ensure consistency with existing Swagger definitions

### Tasks
1. **Security Scheme Check**
   - Verify `securitySchemes.bearerAuth` exists in swagger.yaml
   - Confirm `bearerAuth` is the correct scheme name
   - Document required security declaration format

2. **Schema Inventory**
   - List existing `components/schemas` definitions
   - Identify `$ref` patterns (e.g., `#/components/schemas/User`)
   - Document error schema structure

3. **Standardization**
   - Define error response schema pattern
   - Create reference for common parameters
   - Document pagination response format

### Deliverable
Security & Schema reference for consistent spec creation

---

## 🎯 Phase 2: Priority 1 - Auth Revocation Endpoints

### Scope
Token revocation endpoints for authentication management.

### Endpoints to Document

| Endpoint | Method | Status Codes to Cover |
|----------|--------|----------------------|
| `/api/v1/auth/revoke` | DELETE | 200, 401 |
| `/api/v1/auth/revoke_all` | DELETE | 200, 401 |

### Specification Requirements

#### 2.1 DELETE /api/v1/auth/revoke

**Purpose:** Revoke current session token

**Responses:**
- `200`: Token revoked successfully
- `401`: Unauthorized (no valid JWT)

**Test Cases:**
```ruby
# Authenticated request with valid token -> 200
# Unauthenticated request -> 401
```

#### 2.2 DELETE /api/v1/auth/revoke_all

**Purpose:** Revoke all sessions for current user

**Responses:**
- `200`: All tokens revoked successfully
- `401`: Unauthorized (no valid JWT)

**Test Cases:**
```ruby
# Authenticated request with valid token -> 200, revoked_count returned
# Unauthenticated request -> 401
```

### File Location
`spec/requests/api/v1/auth_revocation_spec.rb`

**Estimated Lines:** ~30-40 lines per endpoint

---

## 🎯 Phase 3: Priority 2a - CRAs Endpoints

### Scope
Complete CRA (Compte Rendu d'Activité) management endpoints.

### Endpoints to Document

| Endpoint | Method | Status Codes to Cover |
|----------|--------|----------------------|
| `/api/v1/cras` | POST | 201, 401, 422 |
| `/api/v1/cras` | GET | 200 |
| `/api/v1/cras/:id` | GET | 200, 401, 404 |
| `/api/v1/cras/:id` | PATCH | 200, 401, 404, 422 |
| `/api/v1/cras/:id` | DELETE | 200, 401, 404, 409 |
| `/api/v1/cras/:id/submit` | POST | 200, 401, 404, 422, 409 |
| `/api/v1/cras/:id/lock` | POST | 200, 401, 404, 422, 409 |
| `/api/v1/cras/:id/export` | GET | 200, 401, 404 |

### Specification Requirements

#### 3.1 POST /api/v1/cras

**Purpose:** Create a new CRA

**Responses:**
- `201`: CRA created successfully
- `401`: Unauthorized
- `422`: Validation failed (missing required fields, business rules)

**Test Cases:**
```ruby
# Valid CRA data with authentication -> 201
# Missing authentication -> 401
# Invalid/missing CRA parameters -> 422
```

#### 3.2 GET /api/v1/cras

**Purpose:** List accessible CRAs with pagination

**Responses:**
- `200`: List returned (empty or with data)

**Test Cases:**
```ruby
# Authenticated request -> 200, array of CRAs
```

#### 3.3 GET /api/v1/cras/:id

**Purpose:** Show specific CRA with entries

**Responses:**
- `200`: CRA found and returned
- `401`: Unauthorized
- `404`: CRA not found or not accessible

**Test Cases:**
```ruby
# Valid CRA ID with authentication -> 200
# No authentication -> 401
# Non-existent CRA ID -> 404
```

#### 3.4 PATCH /api/v1/cras/:id

**Purpose:** Update CRA with business rule validation

**Responses:**
- `200`: CRA updated successfully
- `401`: Unauthorized
- `404`: CRA not found
- `422`: Invalid transition or validation failed

**Test Cases:**
```ruby
# Valid update on draft CRA -> 200
# No authentication -> 401
# Non-existent CRA -> 404
# Update on locked CRA -> 422/409
```

#### 3.5 DELETE /api/v1/cras/:id

**Purpose:** Archive CRA (soft delete)

**Responses:**
- `200`: CRA archived successfully
- `401`: Unauthorized
- `404`: CRA not found
- `409`: Conflict (CRA has entries, cannot archive)

**Test Cases:**
```ruby
# Valid archive request -> 200
# No authentication -> 401
# Non-existent CRA -> 404
# CRA with entries -> 409
```

#### 3.6 POST /api/v1/cras/:id/submit

**Purpose:** Submit CRA (draft → submitted)

**Responses:**
- `200`: CRA submitted successfully
- `401`: Unauthorized
- `404`: CRA not found
- `422`: Validation failed
- `409`: Conflict (already submitted/locked)

**Test Cases:**
```ruby
# Submit draft CRA -> 200
# No authentication -> 401
# Non-existent CRA -> 404
# Invalid CRA state -> 422/409
```

#### 3.7 POST /api/v1/cras/:id/lock

**Purpose:** Lock CRA with Git versioning (submitted → locked)

**Responses:**
- `200`: CRA locked successfully
- `401`: Unauthorized
- `404`: CRA not found
- `422`: Validation failed
- `409`: Conflict (already locked)

**Test Cases:**
```ruby
# Lock submitted CRA -> 200
# No authentication -> 401
# Non-existent CRA -> 404
# Lock non-submitted CRA -> 422/409
```

#### 3.8 GET /api/v1/cras/:id/export

**Purpose:** Export CRA as CSV

**Responses:**
- `200`: CSV file returned
- `401`: Unauthorized
- `404`: CRA not found

**Test Cases:**
```ruby
# Valid export request -> 200, produces 'text/csv'
# No authentication -> 401
# Non-existent CRA -> 404
```

**Swagger Configuration:**
```ruby
produces 'text/csv', 'application/json'
```

### File Location
`spec/requests/api/v1/cras_spec.rb`

**Estimated Lines:** ~200-250 lines total

---

## 🎯 Phase 4: Priority 2b - CRA Entries Endpoints

### Scope
CRA Entry (daily activity) management endpoints.

### Endpoints to Document

| Endpoint | Method | Status Codes to Cover |
|----------|--------|----------------------|
| `/api/v1/cras/:cra_id/entries` | POST | 201, 401, 404, 422 |
| `/api/v1/cras/:cra_id/entries` | GET | 200, 401, 404 |
| `/api/v1/cras/:cra_id/entries/:id` | GET | 200, 401, 404 |
| `/api/v1/cras/:cra_id/entries/:id` | PATCH | 200, 401, 404, 422 |
| `/api/v1/cras/:cra_id/entries/:id` | DELETE | 200, 401, 404, 409 |

### Specification Requirements

#### Schema Coverage Guidelines

For each endpoint, include:

1. **Success Response (200/201)**
   - Minimal schema with key fields
   - Use `$ref` for complex objects
   - Include only essential properties

2. **Error Responses (401, 404, 422, 409)**
   - Use `$ref` to existing `Error` schema
   - Consistent error format across API

3. **Standardized Error Schema**
   ```yaml
   # components/schemas/Error
   Error:
     type: object
     required:
       - error
       - message
     properties:
       error:
         type: string
         description: Error code (e.g., 'unauthorized', 'not_found')
       message:
         type: string
         description: Human-readable error message
   ```

4. **Example Schema References**
   ```ruby
   # User response
   schema '$ref' => '#/components/schemas/User'
   
   # Error response
   schema '$ref' => '#/components/schemas/Error'
   
   # Inline for simple responses
   schema type: :object,
          properties: {
            message: { type: :string }
          }
   ```

#### 4.1 POST /api/v1/cras/:cra_id/entries

**Purpose:** Create new CRA entry

**Responses:**
- `201`: Entry created successfully
- `401`: Unauthorized
- `404`: CRA not found
- `422`: Validation failed (duplicate entry, invalid date, etc.)

**Test Cases:**
```ruby
# Valid entry data on draft CRA -> 201
# No authentication -> 401
# Non-existent CRA -> 404
# Duplicate entry -> 422
```

#### 4.2 GET /api/v1/cras/:cra_id/entries

**Purpose:** List CRA entries

**Responses:**
- `200`: List returned
- `401`: Unauthorized
- `404`: CRA not found

**Test Cases:**
```ruby
# Valid list request -> 200
# No authentication -> 401
# Non-existent CRA -> 404
```

#### 4.3 GET /api/v1/cras/:cra_id/entries/:id

**Purpose:** Show specific entry

**Responses:**
- `200`: Entry found
- `401`: Unauthorized
- `404`: Entry not found

**Test Cases:**
```ruby
# Valid entry ID -> 200
# No authentication -> 401
# Non-existent entry -> 404
```

#### 4.4 PATCH /api/v1/cras/:cra_id/entries/:id

**Purpose:** Update CRA entry

**Responses:**
- `200`: Entry updated
- `401`: Unauthorized
- `404`: Entry not found
- `422`: Validation failed

**Test Cases:**
```ruby
# Valid update on draft CRA -> 200
# No authentication -> 401
# Non-existent entry -> 404
# Update on locked CRA -> 422
```

#### 4.5 DELETE /api/v1/cras/:cra_id/entries/:id

**Purpose:** Delete CRA entry

**Responses:**
- `200`: Entry deleted
- `401`: Unauthorized
- `404`: Entry not found
- `409**: Conflict (cannot delete from locked CRA)

**Test Cases:**
```ruby
# Valid delete request -> 200
# No authentication -> 401
# Non-existent entry -> 404
# Delete from locked CRA -> 409
```

### File Location
`spec/requests/api/v1/cra_entries_spec.rb`

**Estimated Lines:** ~150-200 lines total

---

## 🎯 Phase 5: Validation & Generation

### Tasks

1. **Generate Swagger Documentation**
   ```bash
   docker compose exec -T web bundle exec rake rswag
   ```

2. **Verify Complete Coverage**
   - Check all 27 endpoints are documented
   - Verify no duplicate entries
   - Validate YAML syntax

3. **Run RSwag Tests**
   ```bash
   docker compose exec -T web bundle exec rswag
   # Expected: 134 + new examples, 0 failures
   ```

4. **Update Documentation References**
   - README.md - API structure section
   - VISION.md - Current metrics
   - BRIEFING.md - Swagger coverage note

---

## 📏 Specification Standards

### General Guidelines

1. **Minimal Coverage**: Focus on HTTP contract, not business logic
2. **Authentication**: Use JWT token via `Authorization: Bearer` header
3. **Response Codes**: Cover success, client error, and conflict scenarios
4. **No Excessive Mocking**: Use existing factories and test data

### Response Code Coverage Matrix

| Response Code | Meaning | Coverage Required |
|---------------|---------|-------------------|
| 200 | Success | ✅ All endpoints |
| 201 | Created | ✅ POST endpoints |
| 401 | Unauthorized | ✅ All authenticated endpoints |
| 404 | Not Found | ✅ All endpoints with ID parameter |
| 422 | Validation Failed | ✅ All POST/PATCH endpoints |
| 409 | Conflict | ✅ Endpoints with state transitions |

### RSwag Spec Structure (CORRECTED)

```ruby
# spec/requests/api/v1/[resource]_spec.rb

require 'swagger_helper'

RSpec.describe 'API V1 Auth', swagger_doc: 'v1/swagger.yaml', type: :request do

  path '/api/v1/auth/revoke' do
    delete 'Revoke current token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      response '200', 'token revoked' do
        schema type: :object,
               properties: {
                 message: { type: :string },
                 revoked_at: { type: :string }
               },
               required: ['message', 'revoked_at']

        let(:Authorization) { "Bearer #{valid_token}" }
        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  # Repeat pattern for other endpoints...
end
```

### Key RSwag Elements

| Element | Purpose | Required |
|---------|---------|----------|
| `require 'swagger_helper'` | RSwag test configuration | ✅ |
| `swagger_doc: 'v1/swagger.yaml'` | Target swagger file | ✅ |
| `type: :request` | Request spec type | ✅ |
| `path '/endpoint'` | Define API path | ✅ |
| `delete/post/get/patch` | HTTP method | ✅ |
| `tags` | Grouping in Swagger UI | ✅ |
| `consumes/produces` | Media types | ✅ |
| `security [ bearerAuth: [] ]` | Authentication requirement | ⚠️ |
| `parameter` | Input parameters | As needed |
| `response 'CODE', 'description'` | Success/error responses | ✅ |
| `schema` or `$ref` | Response structure | ✅ |
| `run_test!` | Execute test | ✅ |

### Schema Pattern

```ruby
# Success response
response '200', 'success message' do
  schema type: :object,
         properties: {
           data: { type: :object },
           message: { type: :string }
         }
  run_test!
end

# Error response (reuse existing schema)
response '401', 'unauthorized' do
  schema '$ref' => '#/components/schemas/Error'
  run_test!
end
```

---

## ✅ Definition of Done

### Technical Criteria
- [ ] All Phase 1 tasks completed
- [ ] Phase 1.5 completed (security & schema validation)
- [ ] Phase 2 specs created (2 endpoints)
- [ ] Phase 3 specs created (8 endpoints)
- [ ] Phase 4 specs created (5 endpoints)
- [ ] `rake rswag` runs successfully
- [ ] All RSwag tests pass (0 failures)
- [ ] swagger/v1/swagger.yaml contains all 27 endpoints
- [ ] **Anti-regression:** No endpoint in `config/routes.rb` is missing from swagger

### Platinum+ Governance Criteria
- [ ] CI check enforces swagger consistency on every commit
- [ ] Error schema standardized across all 401/404/422/409 responses
- [ ] Export endpoint declares `produces 'text/csv'`

### Quality Criteria
- [ ] Code follows existing patterns
- [ ] No hardcoded values without context
- [ ] Tests are deterministic
- [ ] Documentation comments added

### Process Criteria
- [ ] Plan approved by stakeholder
- [ ] Phase 2 completed and validated
- [ ] Phase 3 completed and validated
- [ ] Phase 4 completed and validated
- [ ] Final validation completed

### Platinum+ Anti-Regression Rules
To maintain Platinum+ compliance over time:

1. **Regression Prevention**
   - [ ] No endpoint in `config/routes.rb` should be absent from swagger.yaml
   - [ ] Add automated check: compare routes.rb paths with swagger paths
   - [ ] Document in `CONTRIBUTING.md`: "All new endpoints require RSwag specs"

2. **CI Enforcement (Recommended)**
   ```yaml
   # .github/workflows/swagger-validation.yml
   name: Swagger Validation
   
   on:
     pull_request:
       paths:
         - 'app/controllers/**/*.rb'
         - 'spec/requests/**/*.rb'
   
   jobs:
     validate-swagger:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - name: Setup Ruby
           uses: ruby/setup-ruby@v1
         - name: Generate Swagger
           run: bundle exec rake rswag
         - name: Check for changes
           run: |
             if git diff --quiet swagger/v1/swagger.yaml; then
               echo "Swagger up to date"
             else
               echo "::error file=swagger/v1/swagger.yaml::Swagger documentation is out of sync. Run 'bundle exec rake rswag' and commit changes."
               exit 1
             fi
   ```

3. **Standardized Error Schema**
   ```yaml
   # To be added to swagger.yaml components/schemas
   Error:
     type: object
     required:
       - error
       - message
     properties:
       error:
         type: string
         description: Error code (e.g., 'not_found', 'unauthorized', 'invalid_payload')
         example: 'not_found'
       message:
         type: string
         description: Human-readable error message
         example: 'Resource not found'
       timestamp:
         type: string
         format: date-time
         description: ISO 8601 timestamp of error
     example:
       error: 'not_found'
       message: 'CRA with ID xxx not found'
       timestamp: '2026-02-12T10:30:00Z'
   ```

4. **CSV Export Content-Type**
   For `/api/v1/cras/:id/export` endpoint:
   ```ruby
   produces 'text/csv'
   ```
   This ensures Swagger documents CSV as the expected response format.

---

## 🔗 Related Documents
## 🌿 Git Workflow

### Branch Naming Convention

Following the project's feature branch naming pattern:

```
chore/swagger-rswag-specs-completion
```

### Branch Creation

```bash
# Create branch from main
git checkout main
git pull origin main
git checkout -b chore/swagger-rswag-specs-completion
```

### Commit Pattern

Each phase completed as a single commit:

| Phase | Commit Message |
|-------|---------------|
| Phase 1 | `chore: analyze RSwag specs patterns` |
| Phase 2 | `chore: add auth revocation RSwag specs` |
| Phase 3 | `chore: add CRAs RSwag specs` |
| Phase 4 | `chore: add CRA entries RSwag specs` |
| Phase 5 | `chore: regenerate swagger and validate` |

### Pull Request

- **Title:** `chore: Complete RSwag specs for missing endpoints`
- **Description:** Reference this plan document
- **Labels:** `chore`, `documentation`, `rswag`
- **Reviewer:** Senior Product Architect + CTO

### Merge Strategy

1. Squash commits into single logical unit
2. Delete branch after merge
3. Tag: `rswag-specs-complete` (optional)

---

## 🔗 Related Documents

- `docs/VISION.md` - Product vision and architecture principles
- `docs/BRIEFING.md` - Project context and technical architecture
- `README.md` - API documentation and endpoints reference
- `docs/technical/fc07/README.md` - FC-07 CRA technical documentation

---

**Last Updated:** 12 February 2026  
**Status:** Pending Approval