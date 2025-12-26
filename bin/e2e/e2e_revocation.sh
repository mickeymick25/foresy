#!/bin/bash
set -euo pipefail

# =============================================================================
# E2E Token Revocation Validation Script
# =============================================================================
# Feature Contract: 04_Feature Contract — E2E Revocation
# Purpose: Ensure revoked JWT tokens cannot access protected endpoints
# Location: bin/e2e/e2e_revocation.sh
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BASE_URL="${BASE_URL:-http://localhost:3000}"
TEST_USER_EMAIL="${TEST_USER_EMAIL:-e2e-revocation-$(date +%s)@example.com}"
TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-SecurePassword123!}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✅ PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[❌ FAIL]${NC} $1"
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Required dependency '$1' is not installed"
        exit 1
    fi
}

# Extract HTTP status code from curl response (macOS/Linux compatible)
extract_status() {
    echo "$1" | tail -1
}

# Extract body from curl response (macOS/Linux compatible)
extract_body() {
    echo "$1" | sed '$d'
}

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------

echo ""
echo "=============================================="
echo "🔒 E2E Token Revocation Validation"
echo "=============================================="
echo ""

log_info "Base URL: $BASE_URL"
log_info "Test User: $TEST_USER_EMAIL"
echo ""

# Check dependencies
check_dependency "curl"
check_dependency "jq"

# -----------------------------------------------------------------------------
# Step 1: Authenticate and obtain JWT token
# -----------------------------------------------------------------------------

log_step "1. Authenticating user and obtaining JWT token..."

# First, try to signup (in case user doesn't exist)
SIGNUP_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/v1/signup" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"${TEST_USER_EMAIL}\", \"password\": \"${TEST_USER_PASSWORD}\", \"password_confirmation\": \"${TEST_USER_PASSWORD}\"}" \
    2>/dev/null || echo '{}')

# Extract token from signup or try login
TOKEN=$(echo "$SIGNUP_RESPONSE" | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
    # User might already exist, try login
    LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/v1/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"email\": \"${TEST_USER_EMAIL}\", \"password\": \"${TEST_USER_PASSWORD}\"}" \
        2>/dev/null || echo '{}')

    TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')
fi

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    log_error "Failed to obtain JWT token"
    log_info "Signup response: $SIGNUP_RESPONSE"
    exit 1
fi

log_success "JWT token obtained successfully"
log_info "Token: ${TOKEN:0:20}..."

# -----------------------------------------------------------------------------
# Step 2: Access protected endpoint with valid token (expect 200)
# -----------------------------------------------------------------------------

log_step "2. Accessing protected endpoint with valid token..."

PROTECTED_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/v1/auth/revoke" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

PROTECTED_BODY=$(extract_body "$PROTECTED_RESPONSE")
PROTECTED_STATUS=$(extract_status "$PROTECTED_RESPONSE")

if [ "$PROTECTED_STATUS" = "200" ]; then
    log_success "Protected endpoint returned HTTP 200 with valid token"
else
    log_error "Expected HTTP 200, got HTTP $PROTECTED_STATUS"
    log_info "Response: $PROTECTED_BODY"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 3: Login again to get a new token (previous was revoked)
# -----------------------------------------------------------------------------

log_step "3. Obtaining new token after revocation..."

LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"${TEST_USER_EMAIL}\", \"password\": \"${TEST_USER_PASSWORD}\"}" \
    2>/dev/null || echo '{}')

NEW_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')

if [ -z "$NEW_TOKEN" ] || [ "$NEW_TOKEN" = "null" ]; then
    log_error "Failed to obtain new JWT token"
    exit 1
fi

log_success "New JWT token obtained"
log_info "Token: ${NEW_TOKEN:0:20}..."

# -----------------------------------------------------------------------------
# Step 4: Revoke the token via logout endpoint (expect 200 or 204)
# -----------------------------------------------------------------------------

log_step "4. Revoking token via logout endpoint..."

LOGOUT_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/v1/auth/logout" \
    -H "Authorization: Bearer ${NEW_TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

LOGOUT_BODY=$(extract_body "$LOGOUT_RESPONSE")
LOGOUT_STATUS=$(extract_status "$LOGOUT_RESPONSE")

if [ "$LOGOUT_STATUS" = "200" ] || [ "$LOGOUT_STATUS" = "204" ]; then
    log_success "Token revoked successfully (HTTP $LOGOUT_STATUS)"
else
    log_error "Expected HTTP 200 or 204, got HTTP $LOGOUT_STATUS"
    log_info "Response: $LOGOUT_BODY"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 5: Try to access protected endpoint with revoked token (expect 401)
# -----------------------------------------------------------------------------

log_step "5. Accessing protected endpoint with revoked token..."

REVOKED_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/v1/auth/revoke" \
    -H "Authorization: Bearer ${NEW_TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

REVOKED_BODY=$(extract_body "$REVOKED_RESPONSE")
REVOKED_STATUS=$(extract_status "$REVOKED_RESPONSE")

if [ "$REVOKED_STATUS" = "401" ]; then
    log_success "Protected endpoint correctly returned HTTP 401 with revoked token"
else
    log_error "Expected HTTP 401, got HTTP $REVOKED_STATUS"
    log_info "Response: $REVOKED_BODY"
    exit 1
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

echo ""
echo "=============================================="
echo -e "${GREEN}🎉 E2E Token Revocation Test PASSED${NC}"
echo "=============================================="
echo ""
echo "All acceptance criteria validated:"
echo "  ✅ User authenticated successfully"
echo "  ✅ Protected endpoint returned 200 with valid token"
echo "  ✅ Token revoked via logout endpoint"
echo "  ✅ Protected endpoint returned 401 with revoked token"
echo ""

exit 0
