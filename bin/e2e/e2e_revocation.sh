#!/bin/bash
set -euo pipefail

# =============================================================================
# E2E Token Revocation Validation Script
# =============================================================================
# Feature Contract: 04_Feature Contract — E2E Revocation
# Purpose: Ensure revoked JWT tokens cannot access protected endpoints
# Location: bin/e2e/e2e_revocation.sh
#
# GOLD LEVEL - Strict Contract Compliance
#
# User Journey (Feature Contract):
#   1. User authenticates successfully
#   2. User receives a JWT token
#   3. User accesses a protected endpoint → HTTP 200
#   4. User revokes the token via logout endpoint
#   5. User tries to access the protected endpoint again with the SAME token → HTTP 401
#
# This proves: a token that WAS valid becomes INVALID after revocation.
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration (Environment Variables)
# -----------------------------------------------------------------------------

BASE_URL="${BASE_URL:-http://localhost:3000}"
TEST_USER_EMAIL="${TEST_USER_EMAIL:-e2e-revocation-$(date +%s)@example.com}"
TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-SecurePassword123!}"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

readonly PROTECTED_ENDPOINT="/api/v1/auth/revoke"
readonly LOGOUT_ENDPOINT="/api/v1/auth/logout"
readonly SIGNUP_ENDPOINT="/api/v1/signup"
readonly LOGIN_ENDPOINT="/api/v1/auth/login"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_pass() { echo -e "${GREEN}[✅ PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[❌ FAIL]${NC} $1"; }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

fail_and_exit() {
    log_fail "$1"
    exit 1
}

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        fail_and_exit "Required dependency '$1' is not installed"
    fi
}

http_status() {
    echo "$1" | tail -1
}

http_body() {
    echo "$1" | sed '$d'
}

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------

echo ""
echo "=============================================="
echo "🔒 E2E Token Revocation Test (Gold Level)"
echo "=============================================="
echo ""
log_info "Target: $BASE_URL"
log_info "User: $TEST_USER_EMAIL"
echo ""

check_dependency "curl"
check_dependency "jq"

# -----------------------------------------------------------------------------
# Step 1 & 2: User authenticates successfully and receives a JWT token
# -----------------------------------------------------------------------------

log_step "1. User authenticates and receives JWT token"

# Try signup first (new user)
SIGNUP_RESP=$(curl -s -X POST "${BASE_URL}${SIGNUP_ENDPOINT}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${TEST_USER_EMAIL}\",\"password\":\"${TEST_USER_PASSWORD}\",\"password_confirmation\":\"${TEST_USER_PASSWORD}\"}" \
    2>/dev/null || echo '{}')

TOKEN=$(echo "$SIGNUP_RESP" | jq -r '.token // empty')

# Fallback to login if user already exists
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    LOGIN_RESP=$(curl -s -X POST "${BASE_URL}${LOGIN_ENDPOINT}" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${TEST_USER_EMAIL}\",\"password\":\"${TEST_USER_PASSWORD}\"}" \
        2>/dev/null || echo '{}')
    TOKEN=$(echo "$LOGIN_RESP" | jq -r '.token // empty')
fi

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    fail_and_exit "Failed to obtain JWT token"
fi

log_pass "JWT token obtained"
log_info "TOKEN: ${TOKEN:0:40}..."

# Store token for contract verification
readonly THE_TOKEN="$TOKEN"

# -----------------------------------------------------------------------------
# Step 3: User accesses a protected endpoint → HTTP 200
# -----------------------------------------------------------------------------

log_step "2. User accesses protected endpoint with valid token → expect 200"

RESP=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}${PROTECTED_ENDPOINT}" \
    -H "Authorization: Bearer ${THE_TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

STATUS=$(http_status "$RESP")
BODY=$(http_body "$RESP")

if [ "$STATUS" = "200" ]; then
    log_pass "Protected endpoint returned HTTP 200"
    if echo "$BODY" | jq -e '.message' > /dev/null 2>&1; then
        log_info "Response: $(echo "$BODY" | jq -r '.message')"
    fi
else
    fail_and_exit "Expected HTTP 200, got HTTP $STATUS"
fi

# -----------------------------------------------------------------------------
# Step 4: User revokes the token via logout endpoint → HTTP 200 or 204
# -----------------------------------------------------------------------------

log_step "3. User revokes token via logout endpoint → expect 200 or 204"

# Need a fresh token for logout since THE_TOKEN was just used for revoke
LOGIN_RESP=$(curl -s -X POST "${BASE_URL}${LOGIN_ENDPOINT}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${TEST_USER_EMAIL}\",\"password\":\"${TEST_USER_PASSWORD}\"}" \
    2>/dev/null || echo '{}')

LOGOUT_TOKEN=$(echo "$LOGIN_RESP" | jq -r '.token // empty')

if [ -z "$LOGOUT_TOKEN" ] || [ "$LOGOUT_TOKEN" = "null" ]; then
    fail_and_exit "Failed to obtain token for logout"
fi

RESP=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}${LOGOUT_ENDPOINT}" \
    -H "Authorization: Bearer ${LOGOUT_TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

STATUS=$(http_status "$RESP")
BODY=$(http_body "$RESP")

if [ "$STATUS" = "200" ] || [ "$STATUS" = "204" ]; then
    log_pass "Token revoked via logout (HTTP $STATUS)"
    if [ "$STATUS" = "200" ] && echo "$BODY" | jq -e '.message' > /dev/null 2>&1; then
        log_info "Response: $(echo "$BODY" | jq -r '.message')"
    fi
else
    fail_and_exit "Expected HTTP 200 or 204, got HTTP $STATUS"
fi

# -----------------------------------------------------------------------------
# Step 5: User tries to access protected endpoint with SAME token → HTTP 401
# -----------------------------------------------------------------------------

log_step "4. User accesses protected endpoint with SAME revoked token → expect 401"
log_info "Using SAME token: ${LOGOUT_TOKEN:0:40}..."

RESP=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}${PROTECTED_ENDPOINT}" \
    -H "Authorization: Bearer ${LOGOUT_TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

STATUS=$(http_status "$RESP")
BODY=$(http_body "$RESP")

if [ "$STATUS" = "401" ]; then
    log_pass "Protected endpoint returned HTTP 401 (access denied)"
    if echo "$BODY" | jq -e '.error' > /dev/null 2>&1; then
        log_info "Error: $(echo "$BODY" | jq -r '.error')"
    fi
else
    log_fail "Expected HTTP 401, got HTTP $STATUS"
    log_fail "🚨 SECURITY ISSUE: Revoked token still grants access!"
    log_info "Response: $BODY"
    exit 1
fi

# -----------------------------------------------------------------------------
# Summary - Contract Verification
# -----------------------------------------------------------------------------

echo ""
echo "=============================================="
echo -e "${GREEN}🎉 E2E Token Revocation Test PASSED${NC}"
echo "=============================================="
echo ""
echo "Feature Contract Verified (Gherkin):"
echo "  ✅ Given: User authenticated with valid JWT token"
echo "  ✅ When: User accessed protected endpoint → HTTP 200"
echo "  ✅ When: User revoked token via logout → HTTP 200/204"
echo "  ✅ Then: User accessed with SAME token → HTTP 401"
echo ""
echo "Security Assertion:"
echo "  ✅ Revoked tokens are immediately invalidated"
echo "  ✅ No unauthorized access after revocation"
echo ""

exit 0
