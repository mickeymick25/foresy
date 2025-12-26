#!/bin/bash
set -euo pipefail

# =============================================================================
# E2E Token Revocation Validation Script
# =============================================================================
# Feature Contract: 04_Feature Contract — E2E Revocation
# Purpose: Ensure revoked JWT tokens cannot access protected endpoints
# Location: bin/e2e/e2e_revocation.sh
#
# Flow (aligned with Feature Contract):
#   1. User authenticates → receives JWT token
#   2. User accesses protected resource → HTTP 200
#   3. User logs out (revokes token)
#   4. User tries same token again → HTTP 401
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

# Validate JSON field value
validate_json_field() {
    local json="$1"
    local field="$2"
    local expected="$3"
    local actual

    actual=$(echo "$json" | jq -r ".$field // empty")

    if [ "$actual" = "$expected" ]; then
        return 0
    else
        return 1
    fi
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

# Store the token for later verification
ORIGINAL_TOKEN="$TOKEN"

# -----------------------------------------------------------------------------
# Step 2: Access protected endpoint with valid token (expect 200)
# -----------------------------------------------------------------------------

log_step "2. Accessing protected endpoint with valid token..."

# Use a read-only protected endpoint to verify token validity
# Try /api/v1/auth/revoke with GET-like behavior or use the token validation
PROTECTED_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/v1/auth/revoke" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

PROTECTED_BODY=$(extract_body "$PROTECTED_RESPONSE")
PROTECTED_STATUS=$(extract_status "$PROTECTED_RESPONSE")

if [ "$PROTECTED_STATUS" = "200" ]; then
    log_success "Protected endpoint returned HTTP 200 with valid token"

    # Validate response body contains expected message
    if echo "$PROTECTED_BODY" | jq -e '.message' > /dev/null 2>&1; then
        log_info "Response body validated: $(echo "$PROTECTED_BODY" | jq -r '.message')"
    fi
else
    log_error "Expected HTTP 200, got HTTP $PROTECTED_STATUS"
    log_info "Response: $PROTECTED_BODY"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 3: Re-authenticate to get a fresh token for the revocation test
# -----------------------------------------------------------------------------

log_step "3. Re-authenticating to get a fresh token..."

LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"${TEST_USER_EMAIL}\", \"password\": \"${TEST_USER_PASSWORD}\"}" \
    2>/dev/null || echo '{}')

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token // empty')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    log_error "Failed to obtain new JWT token"
    exit 1
fi

log_success "Fresh JWT token obtained"
log_info "Token: ${TOKEN:0:20}..."

# -----------------------------------------------------------------------------
# Step 4: Revoke the token via logout endpoint (expect 200 or 204)
# -----------------------------------------------------------------------------

log_step "4. Revoking token via logout endpoint..."

LOGOUT_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/v1/auth/logout" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

LOGOUT_BODY=$(extract_body "$LOGOUT_RESPONSE")
LOGOUT_STATUS=$(extract_status "$LOGOUT_RESPONSE")

if [ "$LOGOUT_STATUS" = "200" ] || [ "$LOGOUT_STATUS" = "204" ]; then
    log_success "Token revoked successfully (HTTP $LOGOUT_STATUS)"

    # Validate response body if present
    if [ "$LOGOUT_STATUS" = "200" ] && echo "$LOGOUT_BODY" | jq -e '.message' > /dev/null 2>&1; then
        LOGOUT_MSG=$(echo "$LOGOUT_BODY" | jq -r '.message')
        log_info "Logout message: $LOGOUT_MSG"

        # Verify expected message
        if [[ "$LOGOUT_MSG" == *"success"* ]] || [[ "$LOGOUT_MSG" == *"logged out"* ]] || [[ "$LOGOUT_MSG" == *"Logged out"* ]]; then
            log_success "Logout response body validated"
        fi
    fi
else
    log_error "Expected HTTP 200 or 204, got HTTP $LOGOUT_STATUS"
    log_info "Response: $LOGOUT_BODY"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 5: Try to access protected endpoint with SAME revoked token (expect 401)
# -----------------------------------------------------------------------------

log_step "5. Accessing protected endpoint with SAME revoked token..."
log_info "Using revoked token: ${TOKEN:0:20}..."

REVOKED_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/v1/auth/revoke" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

REVOKED_BODY=$(extract_body "$REVOKED_RESPONSE")
REVOKED_STATUS=$(extract_status "$REVOKED_RESPONSE")

if [ "$REVOKED_STATUS" = "401" ]; then
    log_success "Protected endpoint correctly returned HTTP 401 with revoked token"

    # Validate error response body
    if echo "$REVOKED_BODY" | jq -e '.error' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$REVOKED_BODY" | jq -r '.error')
        log_info "Error message: $ERROR_MSG"
        log_success "Error response body validated"
    fi
else
    log_error "Expected HTTP 401, got HTTP $REVOKED_STATUS"
    log_info "Response: $REVOKED_BODY"
    log_error "SECURITY ISSUE: Revoked token still has access!"
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
echo "Feature Contract validated:"
echo "  ✅ Step 1: User authenticated successfully (JWT obtained)"
echo "  ✅ Step 2: Protected endpoint returned 200 with valid token"
echo "  ✅ Step 3: Fresh token obtained for revocation test"
echo "  ✅ Step 4: Token revoked via logout endpoint"
echo "  ✅ Step 5: Protected endpoint returned 401 with revoked token"
echo ""
echo "Security verification:"
echo "  ✅ Token invalidation is immediate"
echo "  ✅ Revoked tokens cannot access protected resources"
echo ""
echo "Test user: $TEST_USER_EMAIL"
echo "Note: Clean up with: DELETE FROM users WHERE email LIKE 'e2e-revocation-%@example.com';"
echo ""

exit 0
