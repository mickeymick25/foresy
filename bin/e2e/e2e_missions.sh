#!/bin/bash
# e2e_missions.sh - Test E2E du flux Mission pour Foresy API (FC-06)
#
# Usage:
#   ./bin/e2e/e2e_missions.sh                    # Test localhost:3000
#   STAGING_URL=https://foresy-api.onrender.com E2E_MODE=true ./bin/e2e/e2e_missions.sh
#
# Requirements:
#   - curl
#   - jq
#   - E2E_MODE=true (sur staging/prod) ou RAILS_ENV=test (local)
#
# Tests couverts:
#   1. Création Mission (independent) → 201
#   2. Accès autorisé (GET mission) → 200
#   3. Accès interdit (autre company) → 404
#   4. Lifecycle complet (lead → completed)
#   5. Transition invalide → 422
#   6. Modification post-WON → 200
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -e

API_URL="${STAGING_URL:-http://localhost:3000}"
TIMESTAMP=$(date +%s)
TEST_EMAIL="e2e-mission-${TIMESTAMP}@example.com"
TEST_EMAIL_OTHER="e2e-mission-other-${TIMESTAMP}@example.com"
TEST_PASSWORD="SecurePassword123!"

echo "🎯 E2E Mission Flow Tests - Foresy API (FC-06)"
echo "==============================================="
echo "Target: $API_URL"
echo "Test user: $TEST_EMAIL"
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

# Function to get HTTP status code
http_code() {
    curl -s -o /dev/null -w "%{http_code}" "$@"
}

TESTS_PASSED=0
TESTS_FAILED=0

# ============================================
# SETUP: Create test contexts via E2E endpoint
# ============================================

echo "📦 SETUP: Creating test contexts via /__e2e__/setup..."
echo ""

# Create main user with independent company
echo "   Creating main user (independent)..."
SETUP_RESPONSE=$(curl -s -X POST "$API_URL/__e2e__/setup" \
    -H "Content-Type: application/json" \
    -d "{
        \"user\": {
            \"email\": \"$TEST_EMAIL\",
            \"password\": \"$TEST_PASSWORD\"
        },
        \"company\": {
            \"name\": \"E2E Main Company $TIMESTAMP\",
            \"role\": \"independent\"
        }
    }")

TOKEN=$(json_field "$SETUP_RESPONSE" '.token')
COMPANY_ID=$(json_field "$SETUP_RESPONSE" '.company_id')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
    echo "   ❌ Failed to setup main user"
    echo "   Response: $SETUP_RESPONSE"
    echo ""
    echo "   💡 Make sure E2E_MODE=true or RAILS_ENV=test"
    exit 1
fi
echo "   ✅ Main user created with independent company"
echo "   Company ID: $COMPANY_ID"

# Create other user with independent company (for access control test)
echo "   Creating other user (independent)..."
SETUP_OTHER=$(curl -s -X POST "$API_URL/__e2e__/setup" \
    -H "Content-Type: application/json" \
    -d "{
        \"user\": {
            \"email\": \"$TEST_EMAIL_OTHER\",
            \"password\": \"$TEST_PASSWORD\"
        },
        \"company\": {
            \"name\": \"E2E Other Company $TIMESTAMP\",
            \"role\": \"independent\"
        }
    }")

TOKEN_OTHER=$(json_field "$SETUP_OTHER" '.token')

if [ "$TOKEN_OTHER" = "null" ] || [ -z "$TOKEN_OTHER" ]; then
    echo "   ❌ Failed to setup other user"
    exit 1
fi
echo "   ✅ Other user created with independent company"

echo ""
echo "==============================================="
echo "🧪 TESTS"
echo "==============================================="
echo ""

# ============================================
# TEST 1: Création Mission (independent)
# ============================================

echo "1️⃣  Création Mission (time_based)..."

CREATE_RESPONSE=$(curl -s -X POST "$API_URL/api/v1/missions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "name": "E2E Test Mission",
        "description": "Mission created by E2E test",
        "mission_type": "time_based",
        "status": "lead",
        "start_date": "2025-02-01",
        "daily_rate": 60000,
        "currency": "EUR"
    }')

MISSION_ID=$(json_field "$CREATE_RESPONSE" '.id')
MISSION_STATUS=$(json_field "$CREATE_RESPONSE" '.status')

if [ "$MISSION_ID" != "null" ] && [ -n "$MISSION_ID" ] && [ "$MISSION_STATUS" = "lead" ]; then
    echo "   ✅ Mission created successfully (HTTP 201)"
    echo "   Mission ID: $MISSION_ID"
    echo "   Status: $MISSION_STATUS"
    ((TESTS_PASSED++))
else
    echo "   ❌ Failed to create mission"
    echo "   Response: $CREATE_RESPONSE"
    ((TESTS_FAILED++))
fi

echo ""

# ============================================
# TEST 2: Accès autorisé (GET mission)
# ============================================

echo "2️⃣  Accès autorisé (GET mission)..."

GET_RESPONSE=$(curl -s -X GET "$API_URL/api/v1/missions/$MISSION_ID" \
    -H "Authorization: Bearer $TOKEN")

GET_CODE=$(http_code -X GET "$API_URL/api/v1/missions/$MISSION_ID" \
    -H "Authorization: Bearer $TOKEN")

GET_NAME=$(json_field "$GET_RESPONSE" '.name')

if [ "$GET_CODE" = "200" ] && [ "$GET_NAME" = "E2E Test Mission" ]; then
    echo "   ✅ Access granted (HTTP 200)"
    echo "   Mission name: $GET_NAME"
    ((TESTS_PASSED++))
else
    echo "   ❌ Access denied unexpectedly (HTTP $GET_CODE)"
    echo "   Response: $GET_RESPONSE"
    ((TESTS_FAILED++))
fi

echo ""

# ============================================
# TEST 3: Accès interdit (autre user)
# ============================================

echo "3️⃣  Accès interdit (autre user) → 404..."

ACCESS_DENIED_CODE=$(http_code -X GET "$API_URL/api/v1/missions/$MISSION_ID" \
    -H "Authorization: Bearer $TOKEN_OTHER")

if [ "$ACCESS_DENIED_CODE" = "404" ]; then
    echo "   ✅ Access correctly denied (HTTP 404 - no information leak)"
    ((TESTS_PASSED++))
else
    echo "   ❌ Expected 404, got HTTP $ACCESS_DENIED_CODE"
    ((TESTS_FAILED++))
fi

echo ""

# ============================================
# TEST 4: Lifecycle complet
# ============================================

echo "4️⃣  Lifecycle: lead → pending → won → in_progress → completed..."

LIFECYCLE_OK=true

# lead → pending
PATCH_PENDING=$(curl -s -X PATCH "$API_URL/api/v1/missions/$MISSION_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"status": "pending"}')

STATUS_PENDING=$(json_field "$PATCH_PENDING" '.status')
if [ "$STATUS_PENDING" = "pending" ]; then
    echo "   ✅ lead → pending"
else
    echo "   ❌ lead → pending failed (got: $STATUS_PENDING)"
    LIFECYCLE_OK=false
fi

# pending → won
PATCH_WON=$(curl -s -X PATCH "$API_URL/api/v1/missions/$MISSION_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"status": "won"}')

STATUS_WON=$(json_field "$PATCH_WON" '.status')
if [ "$STATUS_WON" = "won" ]; then
    echo "   ✅ pending → won"
else
    echo "   ❌ pending → won failed (got: $STATUS_WON)"
    LIFECYCLE_OK=false
fi

# won → in_progress
PATCH_PROGRESS=$(curl -s -X PATCH "$API_URL/api/v1/missions/$MISSION_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"status": "in_progress"}')

STATUS_PROGRESS=$(json_field "$PATCH_PROGRESS" '.status')
if [ "$STATUS_PROGRESS" = "in_progress" ]; then
    echo "   ✅ won → in_progress"
else
    echo "   ❌ won → in_progress failed (got: $STATUS_PROGRESS)"
    LIFECYCLE_OK=false
fi

# in_progress → completed
PATCH_COMPLETED=$(curl -s -X PATCH "$API_URL/api/v1/missions/$MISSION_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"status": "completed"}')

STATUS_COMPLETED=$(json_field "$PATCH_COMPLETED" '.status')
if [ "$STATUS_COMPLETED" = "completed" ]; then
    echo "   ✅ in_progress → completed"
else
    echo "   ❌ in_progress → completed failed (got: $STATUS_COMPLETED)"
    LIFECYCLE_OK=false
fi

if [ "$LIFECYCLE_OK" = true ]; then
    echo "   🎯 Full lifecycle validated"
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

echo ""

# ============================================
# TEST 5: Transition invalide → 422
# ============================================

echo "5️⃣  Transition invalide (lead → won direct) → 422..."

# Create a new mission for this test
NEW_MISSION=$(curl -s -X POST "$API_URL/api/v1/missions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{
        "name": "E2E Transition Test",
        "mission_type": "time_based",
        "status": "lead",
        "start_date": "2025-03-01",
        "daily_rate": 50000,
        "currency": "EUR"
    }')

NEW_MISSION_ID=$(json_field "$NEW_MISSION" '.id')

# Try invalid transition: lead → won (should fail, must go through pending)
INVALID_CODE=$(http_code -X PATCH "$API_URL/api/v1/missions/$NEW_MISSION_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"status": "won"}')

if [ "$INVALID_CODE" = "422" ]; then
    echo "   ✅ Invalid transition correctly rejected (HTTP 422)"
    ((TESTS_PASSED++))
else
    echo "   ❌ Expected 422, got HTTP $INVALID_CODE"
    ((TESTS_FAILED++))
fi

echo ""

# ============================================
# TEST 6: Modification post-WON
# ============================================

echo "6️⃣  Modification post-WON (champs contractuels)..."

# Transition new mission to won state
curl -s -X PATCH "$API_URL/api/v1/missions/$NEW_MISSION_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"status": "pending"}' > /dev/null

curl -s -X PATCH "$API_URL/api/v1/missions/$NEW_MISSION_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"status": "won"}' > /dev/null

# Now try to modify after won
POST_WON_PATCH=$(curl -s -X PATCH "$API_URL/api/v1/missions/$NEW_MISSION_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"name": "Modified After Won", "daily_rate": 70000}')

POST_WON_CODE=$(http_code -X PATCH "$API_URL/api/v1/missions/$NEW_MISSION_ID" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"description": "Another modification"}')

MODIFIED_NAME=$(json_field "$POST_WON_PATCH" '.name')
MODIFIED_RATE=$(json_field "$POST_WON_PATCH" '.daily_rate')

if [ "$MODIFIED_NAME" = "Modified After Won" ] && [ "$MODIFIED_RATE" = "70000" ]; then
    echo "   ✅ Post-WON modification allowed (HTTP 200)"
    echo "   New name: $MODIFIED_NAME"
    echo "   New rate: $MODIFIED_RATE"
    ((TESTS_PASSED++))
else
    echo "   ❌ Post-WON modification failed"
    echo "   Response: $POST_WON_PATCH"
    ((TESTS_FAILED++))
fi

echo ""

# ============================================
# CLEANUP (optional)
# ============================================

echo "🧹 CLEANUP..."

CLEANUP_RESPONSE=$(curl -s -X DELETE "$API_URL/__e2e__/cleanup?email_pattern=e2e-mission-${TIMESTAMP}%25" \
    -H "Content-Type: application/json")

CLEANUP_STATUS=$(json_field "$CLEANUP_RESPONSE" '.message')
if [ "$CLEANUP_STATUS" = "Cleanup completed" ]; then
    echo "   ✅ Test data cleaned up"
else
    echo "   ⚠️  Cleanup may have failed: $CLEANUP_RESPONSE"
    echo "   Manual cleanup SQL:"
    echo "   DELETE FROM missions WHERE name LIKE 'E2E%';"
    echo "   DELETE FROM users WHERE email LIKE 'e2e-mission-${TIMESTAMP}%';"
fi

echo ""

# ============================================
# SUMMARY
# ============================================

echo "==============================================="
echo "📊 SUMMARY"
echo "==============================================="
echo ""
echo "Tests passed: $TESTS_PASSED / $((TESTS_PASSED + TESTS_FAILED))"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "🎉 All E2E mission tests passed!"
    echo ""
    echo "🏆 FC-06 Mission Management - E2E VALIDATED"
    exit 0
else
    echo "❌ Some tests failed. Check output above."
    exit 1
fi
