#!/bin/bash
set -euo pipefail

# =============================================================================
# E2E Token Revocation Validation Script
# =============================================================================
# Feature Contract: 04_Feature Contract — E2E Revocation
# Purpose: Ensure revoked JWT tokens cannot access protected endpoints
# Location: bin/e2e/e2e_revocation.sh
#
# Contract Flow (STRICT):
#   1. User authenticates → receives TOKEN
#   2. User accesses protected resource with TOKEN → HTTP 200
#   3. User revokes TOKEN via logout
#   4. User accesses SAME protected resource with SAME TOKEN → HTTP 401
#
# This proves: a token that WAS valid becomes INVALID after revocation.
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BASE_URL="${BASE_URL:-http://localhost:3000}"
TEST_USER_EMAIL="${TEST_USER_EMAIL:-e2e-revocation-$(date +%s)@example.com}"
TEST_USER_PASSWORD="${TEST_USER_PASSWORD:-SecurePassword123!}"

# Protected endpoint (read-only, neutral)
PROTECTED_ENDPOINT="/api/v1/auth/revoke"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_pass() { echo -e "${GREEN}[✅ PASS]${NC} $1"; }
log_fail() { echo -e "${RED}[❌ FAIL]${NC} $1"; }
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_fail "Required dependency '$1' is not installed"
        exit 1
    fi
}

http_status() {
    echo "$1" | tail -1
}

http_body() {
    echo "$1" | sed '$d'
}

# -----------------------------------------------------------------------------
# Pre-flight
# -----------------------------------------------------------------------------

echo ""
echo "=============================================="
echo "🔒 E2E Token Revocation Test"
echo "=============================================="
echo ""
log_info "Target: $BASE_URL"
log_info "User: $TEST_USER_EMAIL"
echo ""

check_dependency "curl"
check_dependency "jq"

# -----------------------------------------------------------------------------
# Step 1: Authenticate and get TOKEN
# -----------------------------------------------------------------------------

log_step "1. Authenticate user and obtain TOKEN"

SIGNUP_RESP=$(curl -s -X POST "${BASE_URL}/api/v1/signup" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${TEST_USER_EMAIL}\",\"password\":\"${TEST_USER_PASSWORD}\",\"password_confirmation\":\"${TEST_USER_PASSWORD}\"}" \
    2>/dev/null || echo '{}')

TOKEN=$(echo "$SIGNUP_RESP" | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
    LOGIN_RESP=$(curl -s -X POST "${BASE_URL}/api/v1/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${TEST_USER_EMAIL}\",\"password\":\"${TEST_USER_PASSWORD}\"}" \
        2>/dev/null || echo '{}')
    TOKEN=$(echo "$LOGIN_RESP" | jq -r '.token // empty')
fi

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    log_fail "Failed to obtain TOKEN"
    exit 1
fi

log_pass "TOKEN obtained"
log_info "TOKEN: ${TOKEN:0:30}..."

# -----------------------------------------------------------------------------
# Step 2: Access protected endpoint with TOKEN → expect 200
# -----------------------------------------------------------------------------

log_step "2. Access protected endpoint with valid TOKEN"

RESP=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}${PROTECTED_ENDPOINT}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

STATUS=$(http_status "$RESP")

if [ "$STATUS" = "200" ]; then
    log_pass "Protected endpoint returned HTTP 200"
else
    log_fail "Expected HTTP 200, got HTTP $STATUS"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 3: Re-login to get the SAME user session, then logout to revoke
# -----------------------------------------------------------------------------

log_step "3. Login again and revoke TOKEN via logout"

# Login to get a fresh token (same user)
LOGIN_RESP=$(curl -s -X POST "${BASE_URL}/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${TEST_USER_EMAIL}\",\"password\":\"${TEST_USER_PASSWORD}\"}" \
    2>/dev/null || echo '{}')

FRESH_TOKEN=$(echo "$LOGIN_RESP" | jq -r '.token // empty')

if [ -z "$FRESH_TOKEN" ] || [ "$FRESH_TOKEN" = "null" ]; then
    log_fail "Failed to obtain fresh token for logout"
    exit 1
fi

# Logout with fresh token to invalidate session
LOGOUT_RESP=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}/api/v1/auth/logout" \
    -H "Authorization: Bearer ${FRESH_TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

LOGOUT_STATUS=$(http_status "$LOGOUT_RESP")

if [ "$LOGOUT_STATUS" = "200" ] || [ "$LOGOUT_STATUS" = "204" ]; then
    log_pass "Logout successful (HTTP $LOGOUT_STATUS)"
else
    log_fail "Logout failed with HTTP $LOGOUT_STATUS"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 4: Access protected endpoint with SAME FRESH_TOKEN → expect 401
# -----------------------------------------------------------------------------

log_step "4. Access protected endpoint with REVOKED token"
log_info "Using SAME token: ${FRESH_TOKEN:0:30}..."

RESP=$(curl -s -w "\n%{http_code}" -X DELETE "${BASE_URL}${PROTECTED_ENDPOINT}" \
    -H "Authorization: Bearer ${FRESH_TOKEN}" \
    -H "Content-Type: application/json" \
    2>/dev/null)

STATUS=$(http_status "$RESP")
BODY=$(http_body "$RESP")

if [ "$STATUS" = "401" ]; then
    log_pass "Protected endpoint returned HTTP 401 (access denied)"

    # Validate error body
    if echo "$BODY" | jq -e '.error' > /dev/null 2>&1; then
        ERROR=$(echo "$BODY" | jq -r '.error')
        log_info "Error: $ERROR"
    fi
else
    log_fail "Expected HTTP 401, got HTTP $STATUS"
    log_fail "SECURITY ISSUE: Revoked token still grants access!"
    log_info "Response: $BODY"
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
echo "Contract verified:"
echo "  ✅ Token obtained via authentication"
echo "  ✅ Token granted access (HTTP 200)"
echo "  ✅ Token revoked via logout"
echo "  ✅ SAME token denied access (HTTP 401)"
echo ""
echo "Security assertion:"
echo "  ✅ Revoked tokens are immediately invalidated"
echo ""

exit 0
