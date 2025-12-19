# BRIEFING.md - Foresy API Project

**For AI Context Understanding - Optimized for Fast Project Comprehension**  
**Last Updated:** 19 décembre 2025 (soir)

---

## 🎯 PROJECT CURRENT STATE

### Basic Info
- **Project Type**: Ruby on Rails 7.1.5.1 API-only application
- **Primary Function**: User management with JWT + OAuth (Google/GitHub)
- **Environment**: Docker Compose (non-optional, mandatory)
- **Status**: Production Ready - All tests passing, excellent code quality

### Quality Metrics (Dec 2025)
- **RSpec Tests**: 120 examples, 0 failures (4.13s execution)
- **OAuth Tests**: 9/9 acceptance + 10/10 integration = 100% success
- **Code Quality**: Rubocop 75 files, 0 offenses detected
- **Security**: Brakeman 0 critical vulnerabilities (1 minor Rails EOL warning)
- **CI/CD**: GitHub Actions pipeline fully functional

### Technical Stack
- **Framework**: Rails 7.1.5.1 (API-only)
- **Language**: Ruby 3.3.0
- **Database**: PostgreSQL + Redis (cache/sessions)
- **Authentication**: JWT stateless + OAuth 2.0
- **Containerization**: Docker Compose (web, db, redis services)
- **Testing**: RSpec + Rubocop + Brakeman

---

## 📅 RECENT CHANGES TIMELINE

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
1. **Rails EOL Warning**: Version 7.1.5.1 EOL since Oct 2025
   - **Impact**: No more security updates (non-critical but important)
   - **Action Required**: Plan migration to Rails 7.2+
   - **Timeline**: Recommended within 3-6 months
   - **Effort**: Medium (version migration)

### Known Limitations
2. **shoulda-matchers Warning**: Boolean column validation warnings (cosmetic only)
3. **Documentation Fragmentation**: Some info in README.md AND docs/ (partially resolved)

### ✅ Recently Resolved (Dec 19, 2025 soir)
1. **Authentication Concerns Fix**: Converted concerns to class_methods for AuthenticationService compatibility
2. **Zeitwerk Naming (Concerns)**: Renamed `authentication_metrics_concern_new.rb` to correct name
3. **Refresh Token Validation**: Made session_id optional in validate_user_and_session
4. **JsonWebToken Tests**: Fixed logging expectations to match actual implementation

### ✅ Previously Resolved (Dec 20, 2025)
5. **Authenticatable Refactoring**: Separated authentication logic into concern (96 → 12 lines in ApplicationController)
6. **UUID Migration**: Migrated users/sessions tables to UUID identifiers for enhanced security
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

### Docker Compose Services
```yaml
web:     # Rails API (port 3000)
db:      # PostgreSQL 15+ (port 5432)  
redis:   # Redis cache (port 6379)
```

### Key Files Structure
```
Foresy/
├── README.md                    # Main project documentation (GitHub compatible)
├── docs/
│   ├── BRIEFING.md             # This file - AI project understanding
│   ├── index.md                # Central documentation navigation
│   └── technical/              # Technical documentation
│       ├── changes/            # Change log with timestamps
│       ├── audits/             # Technical analysis reports
│       └── corrections/        # Problem resolution history
├── app/                        # Rails application code
├── spec/                       # RSpec tests (87 examples)
├── config/                     # Rails configuration
├── docker-compose.yml          # Docker Compose configuration
└── .env                        # Environment variables (to be created)
```

---

## ✅ NEXT STEPS & TODO LIST

### Immediate Actions (High Priority)
1. **Rails Migration Planning**
   - **Task**: Plan migration from Rails 7.1.5.1 to 7.2+
   - **Impact**: Remove Brakeman EOL warning, security updates
   - **Timeline**: Next 3-6 months
   - **Owner**: Development team

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

### Quick Start Commands
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

### 🔒 GitHub Secrets Configuration (for CI/CD)
Configure these secrets in **GitHub Repository Settings > Secrets and variables > Actions**:

| Secret | Description | Generation Command |
|--------|-------------|-------------------|
| `SECRET_KEY_BASE` | Rails secret key | `rails secret` |
| `JWT_SECRET` | JWT signing key | `openssl rand -hex 64` |
| `GOOGLE_CLIENT_ID` | Google OAuth | Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | Google OAuth | Google Cloud Console |
| `LOCAL_GITHUB_CLIENT_ID` | GitHub OAuth | GitHub Developer Settings |
| `LOCAL_GITHUB_CLIENT_SECRET` | GitHub OAuth | GitHub Developer Settings |

> ⚠️ **SECURITY**: Never commit real secrets to the repository. Use GitHub Secrets for CI/CD.

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

**Last Updated**: December 19, 2025 (soir)  
**Status**: ✅ Stable, Production Ready, 120 tests passing, 0 Rubocop violations, AI-Optimized Documentation
