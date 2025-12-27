# BRIEFING.md - Foresy API Project

**For AI Context Understanding - Optimized for Fast Project Comprehension**  
**Last Updated:** 26 décembre 2025

---

## 🎯 PROJECT CURRENT STATE

### Basic Info
- **Project Type**: Ruby on Rails 8.1.1 API-only application
- **Primary Function**: User management with JWT + OAuth (Google/GitHub)
- **Ruby Version**: 3.4.8
- **Environment**: Docker Compose (non-optional, mandatory)
- **Status**: Production Ready - All tests passing, excellent code quality

### Quality Metrics (Dec 2025)
- **RSpec Tests**: 221 examples, 0 failures
- **OAuth Tests**: 15/15 acceptance (Feature Contract compliant)
- **Code Quality**: Rubocop 82 files, 0 offenses detected
- **Security**: Brakeman 0 critical vulnerabilities, no token logging, stateless JWT, token revocation
- **CI/CD**: GitHub Actions CI + Render CD fully functional
- **Production**: Deployed on Render (https://foresy-api.onrender.com)
- **Rails Upgrade**: ✅ Successfully migrated from 7.1.5.1 to 8.1.1 (Dec 26, 2025)

### Technical Stack
- **Framework**: Rails 8.1.1 (API-only)
- **Language**: Ruby 3.4.8
- **Database**: PostgreSQL + Redis (cache/sessions)
- **Authentication**: JWT stateless + OAuth 2.0
- **Containerization**: Docker Compose (web, db, redis services)
- **Testing**: RSpec + Rubocop + Brakeman
- **Bundler**: 4.0.3

---

## 📅 RECENT CHANGES TIMELINE

### Dec 26, 2025 - 🧪 E2E Token Revocation Script (FEATURE - GOLD LEVEL)
- **Feature Contract**: `04_Feature Contract — E2E Revocation`
- **Script**: `bin/e2e/e2e_revocation.sh`
- **Purpose**: Validate JWT token revocation flow end-to-end
- **Level**: ✅ Gold Level (CTO approved)
- **Tests**: 4/4 steps passed (same token before/after revocation)
- **Contract Compliance**: Strict Gherkin criteria verified
- **Compatibility**: macOS/Linux, CI-safe
- **Documentation**: `docs/technical/changes/2025-12-26-E2E_Revocation_Script.md`

### Dec 26, 2025 - 🚀 Rails 8.1.1 Migration (MAJOR UPGRADE)
- **Objective**: Upgrade from Rails 7.1.5.1 (EOL) to Rails 8.1.1
- **Changes Made**:
  - Ruby upgraded: 3.3.0 → 3.4.8
  - Rails upgraded: 7.1.5.1 → 8.1.1
  - Bundler upgraded: 2.x → 4.0.3
  - Dockerfile updated for multi-stage Gold Level (5 stages)
  - docker-compose.yml updated with bundle_cache, Redis, profiles
  - .ruby-version removed (Docker is source of truth)
  - .rubocop.yml updated with TargetRubyVersion 3.4
  - .dockerignore updated with complete exclusions
  - entrypoint.sh simplified and robustified
- **Validation**:
  - RSpec: 221 tests, 0 failures ✅
  - Rubocop: 82 files, 0 offenses ✅
  - Brakeman: 0 vulnerabilities ✅
  - Zeitwerk: All autoloading OK ✅
  - Health check: OK ✅
- **Known Warnings** (non-blocking):
  - `ostruct` will be removed from default gems in Ruby 4.0 (rswag-ui)
  - `:unprocessable_entity` deprecated in Rack (use `:unprocessable_content`)
- **Result**: Full compatibility maintained, no breaking changes
- **Documentation**: `docs/technical/changes/2025-12-26-Rails_8_1_1_Migration_Complete.md`

### Dec 24, 2025 - 🔒 Token Revocation Endpoints (NEW FEATURE)
- **Objective**: Allow users to invalidate their JWT tokens proactively
- **New Endpoints**:
  - `DELETE /api/v1/auth/revoke` - Revoke current session token
  - `DELETE /api/v1/auth/revoke_all` - Revoke all user sessions
- **Features**:
  - Immediate token invalidation
  - Audit logging for security
  - Returns revoked_count for revoke_all
  - Isolated per user
- **Result**: 221 tests pass, 12 new tests for revocation
- **Documentation**: `docs/technical/guides/token_revocation_strategy.md`

### Dec 24, 2025 - 📖 OAuth Flow Documentation (DOCS)
- **Objective**: Complete documentation of OAuth flow for frontend integration
- **Contents**: State/CSRF protection, scopes, JWT claims, React/Vue examples
- **Documentation**: `docs/technical/guides/oauth_flow_documentation.md`

### Dec 24, 2025 - 🧪 OAuth Feature Contract Tests (TESTS)
- **Objective**: Improve OAuth test coverage to match Feature Contract
- **New Tests**:
  - Existing user login (no duplicate creation)
  - New user automatic creation
  - JWT claims validation (user_id, exp)
  - Provider uniqueness constraints
- **Result**: 209 → 221 tests (+12 new)

### Dec 23, 2025 - 🔧 OmniAuth Session Middleware Fix (CRITICAL)
- **Objective**: Fix OmniAuth::NoSessionError blocking all API endpoints
- **Problem**: OmniAuth middleware requires session but Foresy had sessions disabled for stateless JWT
- **Changes Made**:
  - Added Cookies and Session::CookieStore middlewares in `config/application.rb`
  - Configured minimal cookie session in `config/initializers/session_store.rb`
  - Added `request_validation_phase = nil` in `config/initializers/omniauth.rb`
- **Result**: All endpoints functional, 204 tests pass, 0 Rubocop offenses
- **Impact**: CRITICAL - Unblocks production deployment on Render

### Dec 23, 2025 - 🔧 CI/Rubocop/Standards/Configuration Fix (CRITICAL)
- **Objective**: Restore Rails configuration files, align OAuth files with Rails conventions, fix Rubocop violations for CI compliance
- **Problem**: development.rb/test.rb incorrectly cleaned, 5 Rubocop offenses blocking CI, non-standard OAuth file names
- **Changes Made**:
  - Restored `config/environments/development.rb` to complete Rails standard configuration
  - Fixed `config/environments/test.rb` by removing incorrect Redis configuration causing gem errors
  - Renamed OAuth service files to Rails convention: OAuth_token_service.rb → o_auth_token_service.rb
  - Fixed 2 LineLength violations in oauth_feature_contract_spec.rb
- **Results**:
  - Rubocop: 5 offenses → 0 offenses detected (81 files inspected)
  - RSpec: 204 examples, 0 failures (unchanged performance)
  - RSwag: 54 examples, 0 failures (unchanged performance)
  - CI: 100% functional, Rails standards compliance achieved
- **Impact**: CRITICAL - Unblocks CI, achieves 100% Rubocop compliance, maintains all functionality

### Dec 22, 2025 - 🔒 Remove Token Logging (Security - PR Point 2)
- **Objective**: Address PR security concern about token leakage in logs
- **Problem**: Tokens (even truncated) were logged, risking exposure via log retention/APM
- **Changes Made**:
  - Removed all token logging from AuthenticationLoggingConcern
  - Removed token logging from JsonWebToken, AuthenticationService, AuthenticationValidationConcern
  - Mask IP addresses in logs (show only first 2 octets)
  - Use user IDs instead of emails in logs for privacy
  - Fixed JWT rescue order (specific exceptions before generic)
- **Result**: 151 tests pass, 0 Rubocop offenses
- **Impact**: Tokens are NEVER logged, enhanced privacy and security

### Dec 22, 2025 - 🔒 Remove Cookie/Session Middlewares (Security - PR Point 1)
- **Objective**: Address PR security concern about CSRF risk
- **Problem**: CookieStore middleware was added for OmniAuth but contradicted stateless JWT design
- **Changes Made**:
  - Removed `ActionDispatch::Cookies` middleware from application.rb
  - Removed `ActionDispatch::Session::CookieStore` middleware
  - OAuth now uses direct code exchange (OAuthCodeExchangeService) - no cookies needed
- **Result**: 151 tests pass, fully stateless architecture confirmed
- **Impact**: Eliminates CSRF risk, aligns with JWT stateless design

### Dec 20, 2025 (soir) - 🔧 OAuth Code Exchange Service
- **Objective**: Enable frontend apps to authenticate via OAuth using authorization codes
- **Problem**: Direct API calls with OAuth code failed because OmniAuth only works with browser redirects
- **Changes Made**:
  - Created `OAuthCodeExchangeService` to exchange codes with Google/GitHub APIs
  - Modified `OAuthValidationService.extract_oauth_data` to support both flows
  - Updated `OauthController` to pass code parameters to validation service
- **Result**: 149 tests pass, 0 Rubocop offenses
- **Impact**: Frontend apps can now send OAuth codes to API for authentication

### Dec 20, 2025 (soir) - 🔧 Signup Session Fix
- **Objective**: Align signup behavior with login
- **Problem**: Signup returned a simple JWT token without creating a session, causing logout to fail
- **Changes Made**:
  - Modified `UsersController#create` to use `AuthenticationService.login`
  - Signup now returns `token` + `refresh_token` like login
  - User is fully logged in after signup
- **Result**: 149 tests pass, logout works immediately after signup
- **Impact**: Consistent authentication flow across signup and login

### Dec 20, 2025 (soir) - 🚀 Render Deployment (CD) ✅ LIVE
- **Objective**: Deploy Foresy API to production with Continuous Deployment
- **Platform**: Render.com (Frankfurt region)
- **Changes Made**:
  - Created `render.yaml` blueprint (PostgreSQL + Redis + Web Service)
  - Optimized Dockerfile with multi-stage build
  - Simplified `entrypoint.sh` for Render compatibility
  - Added `/health` endpoint for Render health checks
  - Enabled SSL for production database connection
- **Result**: API live at https://foresy-api.onrender.com
- **Impact**: Full CI/CD pipeline operational (GitHub Actions CI + Render CD)

### Dec 20, 2025 - 🔧 pgcrypto Complete Elimination (CRITICAL) ✅ RESOLVED
- **Objective**: Completely eliminate pgcrypto dependency for managed PostgreSQL compatibility
- **Problems Identified**:
  - Previous migration still attempted conditional pgcrypto activation
  - Schema.rb still contained `enable_extension "pgcrypto"` and `id: :uuid`
  - Rswag OAuth specs expected string UUIDs but got integer IDs
- **Changes Made**:
  - Rewrote single migration `20251220_create_pgcrypto_compatible_tables.rb` without ANY pgcrypto reference
  - Tables use standard bigint IDs (auto-increment)
  - Added `uuid` string column (36 chars) for public identifiers via SecureRandom.uuid
  - Regenerated clean schema.rb with only `enable_extension "plpgsql"`
  - Fixed rswag OAuth specs to expect integer IDs (`type: :integer`)
- **Result**: 149 tests pass, 0 Rubocop offenses, Swagger regenerated
- **Impact**: 100% compatibility with all managed PostgreSQL environments (RDS, CloudSQL, Heroku, Azure)
- **Documentation**: `docs/technical/corrections/2025-12-19-pgcrypto_elimination_solution.md`

### Dec 19, 2025 (soir) - 🧹 Authenticatable Cleanup (MEDIUM)
- **Objective**: Unify ambiguous methods and add unit tests
- **Problems Identified**:
  - Two similar methods `payload_valid?` and `valid_payload?` causing confusion
  - No documentation on authentication flow
  - No unit tests for Authenticatable concern
- **Changes Made**:
  - Unified `payload_valid?` into `valid_payload?` (single clear method)
  - Added complete YARD documentation for all methods
  - Added authentication flow documentation in header
  - Created `spec/controllers/concerns/authenticatable_spec.rb` with 29 unit tests
- **Result**: 149 tests pass, 0 Rubocop violations
- **Impact**: Better maintainability, clear authentication flow documentation
- **Documentation**: `docs/technical/changes/2025-12-19-Authenticatable_Cleanup.md`

### Dec 19, 2025 (soir) - 🔧 Authentication Concerns Fix (CRITICAL)
- **Objective**: Fix 20+ test failures related to authentication concerns
- **Problems Identified**:
  - Zeitwerk naming issue: `authentication_metrics_concern_new.rb` should be `authentication_metrics_concern.rb`
  - Concerns using instance methods (`private`) but `AuthenticationService` calling them as class methods
  - `validate_user_and_session` requiring `session_id` but refresh tokens don't contain one
  - JsonWebToken tests with incorrect logging expectations
- **Changes Made**:
  - Renamed `authentication_metrics_concern_new.rb` → `authentication_metrics_concern.rb`
  - Converted all 3 concerns to use `class_methods do` instead of `private`
  - Made `session_id` optional in `validate_user_and_session` (uses latest active session if absent)
  - Fixed JsonWebToken spec logging expectations
- **Result**: 120 tests pass, 0 Rubocop violations
- **Impact**: Full test suite restored, authentication flow working correctly
- **Documentation**: `docs/technical/changes/2025-12-19-Authentication_Concerns_Fix.md`

### Dec 20, 2025 - 🔧 Major Code Quality & Security Improvements (CRITICAL)
- **Objective**: Complete codebase quality improvement and security hardening session
- **Action**: Comprehensive refactoring and security updates across multiple areas
- **Changes Made**:
  - **Refactoring**: Separated authentication logic into Authenticatable concern (96 → 12 lines in ApplicationController)
  - **Security**: Updated gems to fix 20+ vulnerabilities (Rack, Rails, Nokogiri, etc.)
  - **Performance**: Reactivated Bootsnap for Rails boot optimization
  - **Architecture**: Migrated to UUID identifiers for users/sessions tables
  - **Cleanup**: Consolidated migrations, cleaned debug logs, optimized autoload
  - **Configuration**: Fixed Brakeman ignore patterns and require_relative issues
- **Result**: 97 tests pass, 0 Rubocop violations, 0 Brakeman critical vulnerabilities
- **Impact**: Production-ready code with enhanced security and maintainability
- **Documentation**: Multiple files in `docs/technical/changes/2025-12-20-*.md`

### Dec 19, 2025 - 📋 Rswag OAuth Specs Feature Contract (MAJOR)
- **Objective**: Create rswag specs for OAuth endpoints to auto-generate Swagger
- **Action**: Created comprehensive rswag specs conforming to Feature Contract
- **Changes Made**:
  - Created `spec/requests/api/v1/oauth_spec.rb` with 10 test cases
  - Covered both Google and GitHub providers
  - Covered all error codes (400, 401, 422, 500)
  - Covered all edge cases (missing code, redirect_uri, email, UID)
  - Regenerated Swagger documentation automatically
- **Result**: 97 tests pass, Swagger auto-generated with 48 examples
- **Impact**: Full Feature Contract compliance, auto-synchronized documentation
- **Documentation**: `docs/technical/changes/2025-12-19-Rswag_OAuth_Specs_Feature_Contract.md`

### Dec 19, 2025 - 🔧 Zeitwerk OAuth Services Rename (CRITICAL)
- **Problem**: CI failing with `uninitialized constant OauthTokenService` due to Zeitwerk naming convention
- **Action**: Renamed OAuth service files to match Zeitwerk convention
- **Changes Made**:
  - Renamed `oauth_token_service.rb` → `o_auth_token_service.rb`
  - Renamed `oauth_user_service.rb` → `o_auth_user_service.rb`
  - Renamed `oauth_validation_service.rb` → `o_auth_validation_service.rb`
  - Updated `require_relative` paths in controller and specs
- **Result**: CI 100% functional, 87 tests pass
- **Impact**: Zeitwerk autoloading now works correctly
- **Documentation**: `docs/technical/changes/2025-12-19-Zeitwerk_OAuth_Services_Rename.md`

### Dec 19, 2025 - 🔒 Security & Secrets Configuration (CRITICAL)
- **Problem**: Secrets exposed in code + CI failing due to missing environment variables
- **Action**: Complete security overhaul of secrets management
- **Changes Made**:
  - Removed hardcoded secrets from `.github/workflows/ci.yml`
  - Configured GitHub Secrets for `SECRET_KEY_BASE` and `JWT_SECRET`
  - Aligned OAuth variables (`LOCAL_GITHUB_CLIENT_ID` instead of `GITHUB_CLIENT_ID`)
  - Cleaned `.env` and `.env.test` files with secure placeholders
  - Added `spec/examples.txt` to `.gitignore`
- **Result**: CI 100% functional with secure secrets configuration
- **Impact**: Security reinforced, no secrets exposed in repository
- **Documentation**: `docs/technical/changes/2025-12-19-Security_CI_Complete_Fix.md`

### Dec 18, 2025 - Documentation Centralization
- **Action**: Complete documentation reorganization under `docs/`
- **Removed**: Redundant `project/` folder, README in `changes/`
- **Updated**: All links in `docs/index.md` corrected
- **Result**: Clean, coherent documentation structure
- **Impact**: Documentation now navigable from single index

### Dec 18, 2025 - CI Resolution
- **Problems Fixed**: FrozenError, NameError in CI configuration
- **Tests Fixed**: OAuth regression (9/9 → 9/9, 8/10 → 10/10)
- **Code Quality**: 16 Rubocop violations auto-corrected
- **Result**: CI pipeline fully operational, 100% test success

### Jan 2025 - Major CI Restoration
- **Problem**: CI completely broken (0 tests)
- **Solution**: Fixed Zeitwerk errors, removed redundant files
- **Result**: 0 → 87 functional tests
- **Impact**: Restored and optimized CI/CD pipeline

---

## ⚠️ ACTIVE ISSUES & ATTENTION POINTS

### High Priority Issues
1. ~~**Rails EOL Warning**: Version 7.1.5.1 EOL since Oct 2025~~ ✅ **RESOLVED Dec 26, 2025**
   - **Status**: Migrated to Rails 8.1.1 + Ruby 3.4.8
   - **Impact**: Full security support restored

### Known Limitations
2. **shoulda-matchers Warning**: Boolean column validation warnings (cosmetic only)
3. **Documentation Fragmentation**: Some info in README.md AND docs/ (partially resolved)
4. **Ruby 4.0 Deprecation Warnings**: `ostruct` gem will be removed from default gems (rswag-ui dependency)
5. **Rack Deprecation**: `:unprocessable_entity` status code deprecated, use `:unprocessable_content`

### ✅ Recently Resolved (Dec 20-22, 2025)
1. **Token Logging Removed**: Tokens are never logged to prevent secret leakage (PR Point 2)
2. **Cookie/Session Middlewares Removed**: Eliminated CSRF risk by removing unnecessary CookieStore (PR Point 1)
3. **OAuth Code Exchange**: API can now exchange OAuth codes with Google/GitHub for frontend apps
4. **Signup Session Fix**: Signup now creates session like login, logout works after signup
3. **Render Deployment**: API deployed to production with CD pipeline
4. **pgcrypto Complete Elimination**: Rewrote migration to use bigint IDs + uuid string column, regenerated clean schema.rb without pgcrypto
5. **Rswag Specs Fix**: Updated OAuth specs to expect integer IDs instead of UUID strings

### ✅ Previously Resolved (Dec 19-20, 2025)
1. **Authenticatable Cleanup**: Unified `payload_valid?`/`valid_payload?` methods, added 29 unit tests
2. **Authentication Concerns Fix**: Converted concerns to class_methods for AuthenticationService compatibility
3. **Zeitwerk Naming (Concerns)**: Renamed `authentication_metrics_concern_new.rb` to correct name
4. **Refresh Token Validation**: Made session_id optional in validate_user_and_session
5. **JsonWebToken Tests**: Fixed logging expectations to match actual implementation
6. **Authenticatable Refactoring**: Separated authentication logic into concern (96 → 12 lines in ApplicationController)
7. **Security Gems Update**: Updated gems to fix 20+ vulnerabilities (Rack, Rails, Nokogiri, etc.)
8. **Bootsnap Reactivation**: Reactivated Bootsnap for Rails boot performance optimization
9. **Migrations Consolidation**: Consolidated and cleaned up users/sessions migrations
10. **Rswag OAuth Specs**: Complete specs conforming to Feature Contract, Swagger auto-generated
11. **Zeitwerk Naming**: OAuth service files renamed (`o_auth_*_service.rb`) for correct autoloading
12. **Secrets Security**: Hardcoded secrets removed, GitHub Secrets configured
13. **CI Environment Variables**: `SECRET_KEY_BASE` and `JWT_SECRET` now properly injected
14. **OAuth Variables Naming**: Aligned with GitHub restrictions (`LOCAL_GITHUB_*`)

### Maintained Standards
4. **Code Quality**: 0 Rubocop violations (strict standard maintained)
5. **Test Coverage**: All endpoints tested
6. **CI/CD**: GitHub Actions pipeline functional
7. **Security**: JWT stateless, robust validation

---

## 🏗️ TECHNICAL ARCHITECTURE

### API Structure
```
/api/v1/
├── auth/
│   ├── login          # JWT authentication
│   ├── logout         # User logout
│   ├── refresh        # Token refresh
│   └── :provider/     # OAuth callbacks (google_oauth2, github)
├── users/
│   └── create         # User registration
└── health             # Health check endpoint
```

### Docker Compose Services (Development)
```yaml
web:     # Rails API (port 3000)
db:      # PostgreSQL 15+ (port 5432)  
redis:   # Redis cache (port 6379)
```

### Render Services (Production)
```yaml
foresy-api:   # Rails API (Docker)
foresy-db:    # PostgreSQL 16 (managed)
foresy-redis: # Redis (managed)
```

### Key Files Structure
```
Foresy/
├── README.md                    # Main project documentation (GitHub compatible)
├── render.yaml                  # Render deployment blueprint
├── Dockerfile                   # Multi-stage Docker build
├── entrypoint.sh               # Container entrypoint script
├── docs/
│   ├── BRIEFING.md             # This file - AI project understanding
│   ├── index.md                # Central documentation navigation
│   └── technical/              # Technical documentation
│       ├── changes/            # Change log with timestamps
│       ├── audits/             # Technical analysis reports
│       └── corrections/        # Problem resolution history
├── app/                        # Rails application code
├── spec/                       # RSpec tests (149 examples)
├── config/                     # Rails configuration
├── docker-compose.yml          # Docker Compose configuration (dev)
└── .env                        # Environment variables (to be created)
```

---

## ✅ NEXT STEPS & TODO LIST

### Immediate Actions (High Priority)
1. **Sprint 3 Completion - E2E Testing Infrastructure ✅ COMPLETED**
   - **Task**: Finalize E2E staging tests (scripts + documentation)
   - **Completed**: Smoke tests (15 endpoints) + E2E auth flow (8 tests) + E2E revocation (4 tests - Gold Level) in bin/e2e/
   - **Impact**: Full CI/CD staging test coverage, automated end-to-end validation
   - **Status**: ✅ All tests passing locally and on production (Render)

2. **✅ Production Errors 500 Resolution (FINISHED)**
   - **Task**: Fix critical HTTP 500 errors on all authentication endpoints in production
   - **Completed**: Database migrations applied via fix/omniauth-session-middleware branch deployment
   - **Impact**: All auth/OAuth endpoints now functional in production (401/422/400 responses)
   - **Validation**: 23/23 E2E tests passing in production (15 smoke + 8 auth flow)
   - **Status**: ✅ CRITICAL issue resolved, production fully operational

3. **✅ PR #7 Analysis Complete (READY FOR MERGE)**
   - **Task**: Complete analysis of 10 priority points and final validation
   - **Completed**: 9/10 points finished, 1/10 analyzed (Redis cache - low priority)
   - **Critical/High Priority**: 100% complete (Points 1-4)
   - **All Tests**: RSpec 221 ✅, Rswag 66 ✅, Rubocop 82 ✅
   - **Status**: ✅ PR #7 ready for merge into main branch

4. ~~**Rails Migration Planning**~~ ✅ **COMPLETED Dec 26, 2025**
   - **Task**: ~~Plan migration from Rails 7.1.5.1 to 7.2+~~ Migrated to Rails 8.1.1
   - **Impact**: Brakeman EOL warning removed, security restored
   - **Result**: Ruby 3.4.8 + Rails 8.1.1 + YJIT enabled
   - **Documentation**: `docs/technical/changes/2025-12-26-Rails_8_1_1_Migration_Complete.md`

### Medium Priority (Maintenance)
2. **Documentation Maintenance**
   - **Task**: Add new change files with proper conventions
   - **Standard**: YYYY-MM-DD-Descriptive_Title.md format
   - **Location**: `docs/technical/changes/`

3. **Quality Monitoring**
   - **Task**: Verify test metrics on each commit
   - **Tools**: RSpec, Rubocop, Brakeman (automated in CI)

### Future Improvements (Low Priority)
4. **Performance Optimization**
   - **Target**: < 100ms response time for authenticated endpoints
   - **Focus**: Authentication and user management endpoints

5. **Advanced Monitoring**
   - **Goal**: Prometheus/Grafana metrics for production
   - **Current**: Basic health checks available

---

## 🚀 DEVELOPMENT SETUP (FOR AI UNDERSTANDING)

### Quick Start Commands (Development)
```bash
# Clone and launch with Docker Compose
git clone <repo-url> && cd Foresy
docker-compose up -d

# Check container status
docker-compose ps

# View real-time logs
docker-compose logs -f web

# Access application
open http://localhost:3000  # macOS
xdg-open http://localhost:3000  # Linux
```

### Production URLs (Render)
```bash
# API Status
curl https://foresy-api.onrender.com/

# Health Check
curl https://foresy-api.onrender.com/health

# Signup
curl -X POST https://foresy-api.onrender.com/api/v1/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# Login
curl -X POST https://foresy-api.onrender.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'
```

### Essential Testing Commands
```bash
# Complete RSpec test suite
docker-compose run --rm web bundle exec rspec

# OAuth-specific tests
docker-compose run --rm web bundle exec rspec spec/acceptance/oauth_feature_contract_spec.rb
docker-compose run --rm web bundle exec rspec spec/integration/oauth/oauth_callback_spec.rb

# Code quality checks
docker-compose run --rm web bundle exec rubocop

# Security audit
docker-compose run --rm web bundle exec brakeman
```

### Required Environment Variables
Create `.env` file at project root:
```bash
# OAuth Configuration (Required)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
LOCAL_GITHUB_CLIENT_ID=your_github_client_id    # Note: LOCAL_ prefix required
LOCAL_GITHUB_CLIENT_SECRET=your_github_client_secret

# JWT Configuration (Required)
JWT_SECRET=your_jwt_secret_key

# Database Configuration (Optional - defaults available)
POSTGRES_PASSWORD=your_db_password
REDIS_PASSWORD=your_redis_password
```

### 🔒 GitHub Secrets Configuration (for CI)
Configure these secrets in **GitHub Repository Settings > Secrets and variables > Actions**:

| Secret | Description | Generation Command |
|--------|-------------|-------------------|
| `SECRET_KEY_BASE` | Rails secret key | `rails secret` |
| `JWT_SECRET` | JWT signing key | `openssl rand -hex 64` |
| `GOOGLE_CLIENT_ID` | Google OAuth | Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | Google OAuth | Google Cloud Console |
| `LOCAL_GITHUB_CLIENT_ID` | GitHub OAuth | GitHub Developer Settings |
| `LOCAL_GITHUB_CLIENT_SECRET` | GitHub OAuth | GitHub Developer Settings |

### 🚀 Render Environment Variables (for CD)
Configure in **Render Dashboard > foresy-api > Environment**:

| Variable | Source |
|----------|--------|
| `DATABASE_URL` | Internal URL from foresy-db |
| `RAILS_ENV` | `production` |
| `SECRET_KEY_BASE` | Generate |
| `JWT_SECRET` | Generate |
| `GOOGLE_CLIENT_ID` | Manual |
| `GOOGLE_CLIENT_SECRET` | Manual |
| `LOCAL_GITHUB_CLIENT_ID` | Manual |
| `LOCAL_GITHUB_CLIENT_SECRET` | Manual |

> ⚠️ **SECURITY**: Never commit real secrets to the repository.

### Docker Compose Management
```bash
# Stop all services
docker-compose down

# Rebuild and restart (after code changes)
docker-compose up -d --build

# Clean volumes (WARNING: deletes DB data)
docker-compose down -v

# Access web container interactively
docker-compose run --rm web bash
```

---

## 🤖 AI QUICK REFERENCE (KEY PATTERNS)

### Code Organization Patterns
- **Controllers**: Located in `app/controllers/api/v1/`
- **Models**: Standard Rails models in `app/models/`
- **Tests**: RSpec structure in `spec/` (acceptance/, integration/, unit/)
- **Configuration**: Environment-specific in `config/environments/`

### Development Standards
- **Test Requirement**: 0 failures mandatory for any merge
- **Code Quality**: 0 Rubocop violations mandatory
- **Security**: 0 Brakeman critical vulnerabilities mandatory
- **Documentation**: Update `docs/index.md` when adding new files

### OAuth Implementation Details
- **Providers**: Google OAuth2 and GitHub supported
- **Flow**: Standard OAuth 2.0 with JWT token generation
- **Testing**: Separate acceptance and integration test suites
- **Controller**: `app/controllers/api/v1/oauth_controller.rb`

### Key Technical Decisions
- **JWT Stateless**: No server-side sessions
- **Docker Mandatory**: Project cannot run without Docker Compose
- **API-Only**: No views, JSON responses only
- **Redis**: Used for caching and session management

### Documentation Patterns
- **Changes**: Timestamped files in `docs/technical/changes/`
- **Audits**: Technical analysis in `docs/technical/audits/`
- **Corrections**: Problem resolutions in `docs/technical/corrections/`
- **Central Index**: `docs/index.md` for navigation

---

## 📋 PROJECT CONTEXT SUMMARY

**Current Status**: Excellent technical condition, production-ready
**Main Strength**: 100% test coverage, zero code quality issues
**Primary Concern**: Rails version EOL (migration needed)
**Development Model**: Docker Compose mandatory, CI/CD automated
**Documentation**: Centralized, well-organized, AI-optimized

**For AI Sessions**: Read this file first for complete project understanding (2-3 minutes). All key information consolidated here for rapid context acquisition.

---

**Last Updated**: December 20, 2025 (soir)  
**Status**: ✅ LIVE on Render, 149 tests passing, 0 Rubocop violations, CI/CD operational, pgcrypto eliminated
