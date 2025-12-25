#!/bin/bash
# smoke_test.sh - Smoke tests basiques pour Foresy API
#
# Usage:
#   ./bin/e2e/smoke_test.sh                    # Test localhost:3000
#   STAGING_URL=https://foresy-api.onrender.com ./bin/e2e/smoke_test.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -e

API_URL="${STAGING_URL:-http://localhost:3000}"
PASS=0
FAIL=0

echo "🔥 Smoke Tests - Foresy API"
echo "=============================="
echo "Target: $API_URL"
echo "Date: $(date)"
echo ""

# Function to test an endpoint
test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local expected_code="$4"
    local data="$5"

    echo -n "$name... "

    if [ -n "$data" ]; then
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$API_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data" 2>/dev/null || echo "000")
    else
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$API_URL$endpoint" 2>/dev/null || echo "000")
    fi

    if [ "$RESPONSE" = "$expected_code" ]; then
        echo "✅ PASS (HTTP $RESPONSE)"
        ((PASS++))
        return 0
    else
        echo "❌ FAIL (HTTP $RESPONSE, expected $expected_code)"
        ((FAIL++))
        return 1
    fi
}

# Function to test with alternative expected codes
test_endpoint_any() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local expected_codes="$4"  # comma-separated
    local data="$5"

    echo -n "$name... "

    if [ -n "$data" ]; then
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$API_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data" 2>/dev/null || echo "000")
    else
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$API_URL$endpoint" 2>/dev/null || echo "000")
    fi

    if echo "$expected_codes" | grep -q "$RESPONSE"; then
        echo "✅ PASS (HTTP $RESPONSE)"
        ((PASS++))
        return 0
    else
        echo "❌ FAIL (HTTP $RESPONSE, expected one of: $expected_codes)"
        ((FAIL++))
        return 1
    fi
}

echo "=== Health & Status ==="

# Test 1: Health check
test_endpoint "1. Health check" "GET" "/health" "200" || true

# Test 2: Root endpoint
test_endpoint "2. Root endpoint" "GET" "/" "200" || true

# Test 3: Rails health check
test_endpoint "3. Rails up check" "GET" "/up" "200" || true

echo ""
echo "=== Authentication Endpoints ==="

# Test 4: Login endpoint (expects 401 without credentials)
test_endpoint "4. Login (no credentials)" "POST" "/api/v1/auth/login" "401" '{}' || true

# Test 5: Login with empty email
test_endpoint "5. Login (empty email)" "POST" "/api/v1/auth/login" "401" '{"email": "", "password": "test"}' || true

# Test 6: Signup endpoint (validation error expected)
test_endpoint_any "6. Signup (invalid data)" "POST" "/api/v1/signup" "422,400" '{}' || true

# Test 7: Refresh without token
test_endpoint "7. Refresh (no token)" "POST" "/api/v1/auth/refresh" "401" '{}' || true

# Test 8: Logout without auth header
test_endpoint "8. Logout (no auth)" "DELETE" "/api/v1/auth/logout" "401" || true

echo ""
echo "=== Token Revocation Endpoints ==="

# Test 9: Revoke without auth header
test_endpoint "9. Revoke (no auth)" "DELETE" "/api/v1/auth/revoke" "401" || true

# Test 10: Revoke all without auth header
test_endpoint "10. Revoke all (no auth)" "DELETE" "/api/v1/auth/revoke_all" "401" || true

echo ""
echo "=== OAuth Endpoints ==="

# Test 11: OAuth callback with invalid provider
test_endpoint "11. OAuth invalid provider" "POST" "/api/v1/auth/invalid_provider/callback" "400" '{"code": "test", "redirect_uri": "http://test.com"}' || true

# Test 12: OAuth Google without code
test_endpoint_any "12. OAuth Google (no code)" "POST" "/api/v1/auth/google_oauth2/callback" "422,401" '{"redirect_uri": "http://test.com"}' || true

# Test 13: OAuth GitHub without code
test_endpoint_any "13. OAuth GitHub (no code)" "POST" "/api/v1/auth/github/callback" "422,401" '{"redirect_uri": "http://test.com"}' || true

# Test 14: OAuth failure endpoint
test_endpoint_any "14. OAuth failure endpoint" "GET" "/api/v1/auth/failure" "401,404" || true

echo ""
echo "=== API Documentation ==="

# Test 15: Swagger docs (may be disabled in production)
test_endpoint_any "15. API docs" "GET" "/api-docs" "200,404,301,302" || true

# Summary
echo ""
echo "=============================="
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo ""

if [ $FAIL -gt 0 ]; then
    echo "❌ Some smoke tests failed!"
    exit 1
else
    echo "🎉 All smoke tests passed!"
    exit 0
fi
