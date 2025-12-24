#!/bin/bash
# e2e_auth_flow.sh - Test du flux d'authentification complet pour Foresy API
#
# Usage:
#   ./bin/e2e/e2e_auth_flow.sh                    # Test localhost:3000
#   STAGING_URL=https://foresy-api.onrender.com ./bin/e2e/e2e_auth_flow.sh
#
# Requirements:
#   - curl
#   - jq
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -e

API_URL="${STAGING_URL:-http://localhost:3000}"
TIMESTAMP=$(date +%s)
TEST_EMAIL="e2e-test-${TIMESTAMP}@example.com"
TEST_PASSWORD="SecurePassword123!"

echo "🔐 E2E Auth Flow Tests - Foresy API"
echo "===================================="
echo "Target: $API_URL"
echo "Test email: $TEST_EMAIL"
echo "Date: $(date)"
echo ""

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required but not installed."
    echo "   Install with: apt-get install jq (Linux) or brew install jq (macOS)"
    exit 1
fi

# Function to extract JSON field
json_field() {
    echo "$1" | jq -r "$2" 2>/dev/null || echo "null"
}

# Step 1: Signup
echo "1. Creating new user..."
SIGNUP_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/signup" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"$TEST_PASSWORD\", \"password_confirmation\": \"$TEST_PASSWORD\"}")

TOKEN=$(json_field "$SIGNUP_RESPONSE" '.token')
REFRESH_TOKEN=$(json_field "$SIGNUP_RESPONSE" '.refresh_token')

if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo "   ✅ Signup successful, token received"
    echo "   Token: ${TOKEN:0:20}..."
else
    ERROR=$(json_field "$SIGNUP_RESPONSE" '.error // .errors[0] // "Unknown error"')
    echo "   ❌ Signup failed: $ERROR"
    echo "   Full response: $SIGNUP_RESPONSE"
    exit 1
fi

# Step 2: Test authenticated endpoint (revoke as a test)
echo ""
echo "2. Testing authenticated request..."
AUTH_RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/api/v1/auth/revoke" \
    -H "Authorization: Bearer $TOKEN")

if [ "$AUTH_RESPONSE_CODE" = "200" ]; then
    echo "   ✅ Authenticated request successful (HTTP $AUTH_RESPONSE_CODE)"
else
    echo "   ❌ Authenticated request failed (HTTP $AUTH_RESPONSE_CODE)"
    exit 1
fi

# Step 3: Login with same credentials
echo ""
echo "3. Testing login with credentials..."
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"$TEST_PASSWORD\"}")

NEW_TOKEN=$(json_field "$LOGIN_RESPONSE" '.token')
NEW_REFRESH=$(json_field "$LOGIN_RESPONSE" '.refresh_token')
LOGIN_EMAIL=$(json_field "$LOGIN_RESPONSE" '.email')

if [ "$NEW_TOKEN" != "null" ] && [ -n "$NEW_TOKEN" ]; then
    echo "   ✅ Login successful"
    echo "   Email: $LOGIN_EMAIL"
    echo "   Token: ${NEW_TOKEN:0:20}..."
else
    ERROR=$(json_field "$LOGIN_RESPONSE" '.error // "Unknown error"')
    echo "   ❌ Login failed: $ERROR"
    echo "   Full response: $LOGIN_RESPONSE"
    exit 1
fi

# Step 4: Test refresh token
echo ""
echo "4. Testing token refresh..."
REFRESH_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/refresh" \
    -H "Content-Type: application/json" \
    -d "{\"refresh_token\": \"$NEW_REFRESH\"}")

REFRESHED_TOKEN=$(json_field "$REFRESH_RESPONSE" '.token')
REFRESHED_REFRESH=$(json_field "$REFRESH_RESPONSE" '.refresh_token')

if [ "$REFRESHED_TOKEN" != "null" ] && [ -n "$REFRESHED_TOKEN" ]; then
    echo "   ✅ Token refresh successful"
    echo "   New token: ${REFRESHED_TOKEN:0:20}..."
else
    ERROR=$(json_field "$REFRESH_RESPONSE" '.error // "Unknown error"')
    echo "   ❌ Refresh failed: $ERROR"
    echo "   Full response: $REFRESH_RESPONSE"
    exit 1
fi

# Step 5: Test logout
echo ""
echo "5. Testing logout..."
LOGOUT_RESPONSE=$(curl -s -X DELETE "$API_URL/api/v1/auth/logout" \
    -H "Authorization: Bearer $REFRESHED_TOKEN")

LOGOUT_MSG=$(json_field "$LOGOUT_RESPONSE" '.message')

if [ "$LOGOUT_MSG" = "Logged out successfully" ]; then
    echo "   ✅ Logout successful"
else
    ERROR=$(json_field "$LOGOUT_RESPONSE" '.error // "Unknown error"')
    echo "   ❌ Logout failed: $ERROR"
    echo "   Full response: $LOGOUT_RESPONSE"
    exit 1
fi

# Step 6: Verify token is invalid after logout
echo ""
echo "6. Verifying token invalidation..."
INVALID_RESPONSE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$API_URL/api/v1/auth/revoke" \
    -H "Authorization: Bearer $REFRESHED_TOKEN")

if [ "$INVALID_RESPONSE_CODE" = "401" ]; then
    echo "   ✅ Token correctly invalidated (HTTP 401)"
else
    echo "   ❌ Token still valid! (HTTP $INVALID_RESPONSE_CODE, expected 401)"
    exit 1
fi

# Step 7: Test login with wrong password
echo ""
echo "7. Testing login with wrong password..."
WRONG_PWD_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"wrong_password\"}")

WRONG_PWD_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TEST_EMAIL\", \"password\": \"wrong_password\"}")

if [ "$WRONG_PWD_CODE" = "401" ]; then
    echo "   ✅ Correctly rejected wrong password (HTTP 401)"
else
    echo "   ❌ Should have rejected wrong password (HTTP $WRONG_PWD_CODE)"
    exit 1
fi

# Step 8: Test login with non-existent user
echo ""
echo "8. Testing login with non-existent user..."
NONEXIST_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email": "nonexistent@example.com", "password": "password123"}')

if [ "$NONEXIST_CODE" = "401" ]; then
    echo "   ✅ Correctly rejected non-existent user (HTTP 401)"
else
    echo "   ❌ Should have rejected non-existent user (HTTP $NONEXIST_CODE)"
    exit 1
fi

# Summary
echo ""
echo "===================================="
echo "🎉 All E2E auth flow tests passed!"
echo ""
echo "Test user created: $TEST_EMAIL"
echo "Note: This user will remain in the database."
echo "      Clean up with: DELETE FROM users WHERE email LIKE 'e2e-test-%@example.com';"
