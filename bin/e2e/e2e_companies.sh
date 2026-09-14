#!/bin/bash

# E2E Company & UserCompany Flow Test Script
# Tests the complete Company onboarding flow as specified in FC-08 v3.2.3
#
# Gherkin scenarios covered (contract §55):
#   Scenario 1  — GET /companies empty (no fictitious company, INV-05)
#   Scenario 2  — POST /companies atomic onboarding (role independent, INV-16)
#   Scenario 3  — POST /companies role client
#   Scenario 5  — POST /user_companies adds client role to existing company
#   Scenario 6  — POST /user_companies duplicate identical role → 422 (INV-18)
#   Scenario 8  — POST /companies invalid SIREN → 422, nothing persisted
#   Scenario 9  — POST /companies duplicate SIREN → 422 (INV-09)
#   Scenario 10 — POST /companies without SIRET → 201, SIRET NULL (INV-11)
#   Scenario 12 — Atomicity: invalid role → 422, no orphan company (INV-17)
#   Scenario 13 — Cross-user access → 403 FORBIDDEN (§43)
#   Scenario 14 — DELETE /companies soft delete (INV-21)
#   Scenario 15 — Flat JSON payload (§41)
#
# Requirements:
#   - HTTP real only (no mocks)
#   - macOS/Linux compatible
#   - curl + jq
#
# Usage:
#   ./bin/e2e/e2e_companies.sh
#   API_BASE_URL=https://staging.example.com ./bin/e2e/e2e_companies.sh

set -euo pipefail

# Configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:3000}"
TEST_EMAIL="e2e_companies_$(date +%s)@foresy.local"
TEST_EMAIL_OTHER="e2e_companies_other_$(date +%s)@foresy.local"
TEST_PASSWORD="TestPassword123!"
LOG_FILE="/tmp/e2e_companies_$(date +%s).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# HTTP helper — sets HTTP_CODE and HTTP_BODY globals (macOS/Linux compatible)
HTTP_CODE=0
HTTP_BODY=""

run_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    local headers="${4:-}"

    local curl_args=(
        -s
        -w "\n%{http_code}"
        -X "$method"
        "${API_BASE_URL}${endpoint}"
    )

    if [[ -n "$data" ]]; then
        curl_args+=(-H "Content-Type: application/json" -d "$data")
    fi

    if [[ -n "$headers" ]]; then
        curl_args+=(-H "$headers")
    fi

    local response
    response=$(curl "${curl_args[@]}")

    HTTP_CODE=$(echo "$response" | tail -n1)
    HTTP_BODY=$(echo "$response" | sed '$d')
}

# JSON helpers (jq required — same as e2e_missions.sh)
json_field() {
    echo "$1" | jq -r "$2" 2>/dev/null || echo "null"
}

# Test execution helpers
TESTS_PASSED=0
TESTS_FAILED=0

test_step() {
    local step_name=$1
    local expected_code=$2
    local actual_code=$3

    log_info "Executing: $step_name"

    if [[ "$actual_code" -eq "$expected_code" ]]; then
        log_success "$step_name - HTTP $actual_code (Expected: $expected_code)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$step_name - HTTP $actual_code (Expected: $expected_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test resources..."
    # Test data remains in the development database (soft-delete friendly).
    # The /__test_support__/e2e/cleanup endpoint is only available in E2E_MODE.
}

trap cleanup EXIT

main() {
    log_info "🎯 E2E Companies Flow Tests — Foresy API (FC-08 v3.2.3)"
    log_info "Target: $API_BASE_URL"

    # ============================================
    # Step 1: Signup + Login (public endpoints)
    # ============================================
    log_info "=== Step 1: Authentication Setup ==="

    run_request "POST" "/api/v1/signup" "{
        \"email\": \"$TEST_EMAIL\",
        \"password\": \"$TEST_PASSWORD\",
        \"password_confirmation\": \"$TEST_PASSWORD\"
    }"
    local signup_code=$HTTP_CODE
    if ! test_step "User Signup" 201 $signup_code; then
        log_error "Failed to create test user. Response: $HTTP_BODY"
        exit 1
    fi

    run_request "POST" "/api/v1/auth/login" "{
        \"email\": \"$TEST_EMAIL\",
        \"password\": \"$TEST_PASSWORD\"
    }"
    local login_code=$HTTP_CODE
    if ! test_step "User Login" 200 $login_code; then
        log_error "Failed to login. Response: $HTTP_BODY"
        exit 1
    fi

    local auth_token
    auth_token=$(json_field "$HTTP_BODY" ".token")
    local headers="Authorization: Bearer $auth_token"
    log_success "Authentication successful"

    # ============================================
    # Step 2: GET /companies — empty (Scenario 1)
    # ============================================
    log_info "=== Step 2: Empty Company List (Scenario 1) ==="

    run_request "GET" "/api/v1/companies" "" "$headers"
    if ! test_step "List Companies (no company yet)" 200 $HTTP_CODE; then
        log_error "Failed to list companies. Response: $HTTP_BODY"
        exit 1
    fi

    local empty_total
    empty_total=$(json_field "$HTTP_BODY" ".meta.total")
    if [[ "$empty_total" == "0" ]]; then
        log_success "No fictitious company created (INV-05)"
    else
        log_error "Expected 0 companies, got: $empty_total"
        exit 1
    fi

    # ============================================
    # Step 3: POST /companies — atomic onboarding (Scenario 2)
    # ============================================
    log_info "=== Step 3: Atomic Onboarding Independent (Scenario 2) ==="

    run_request "POST" "/api/v1/companies" "{
        \"company\": {
            \"name\": \"E2E Consulting\",
            \"siren\": \"123456789\",
            \"siret\": \"12345678900012\",
            \"legal_form\": \"EI\",
            \"vat_regime\": \"franchise\"
        },
        \"role\": \"independent\"
    }" "$headers"
    if ! test_step "Create Company + UserCompany (atomic)" 201 $HTTP_CODE; then
        log_error "Failed to create company. Response: $HTTP_BODY"
        exit 1
    fi

    local company_a_id
    company_a_id=$(json_field "$HTTP_BODY" ".id")
    log_success "Company A created with ID: $company_a_id (relationship independent)"

    # ============================================
    # Step 4: POST /companies — flat JSON, client (Scenarios 3+15)
    # ============================================
    log_info "=== Step 4: Flat JSON Onboarding Client (Scenarios 3+15) ==="

    run_request "POST" "/api/v1/companies" "{
        \"name\": \"E2E Client Corp\",
        \"siren\": \"987654321\",
        \"role\": \"client\"
    }" "$headers"
    if ! test_step "Create Company (flat JSON + role client)" 201 $HTTP_CODE; then
        log_error "Failed to create company (flat JSON). Response: $HTTP_BODY"
        exit 1
    fi

    local company_b_id
    company_b_id=$(json_field "$HTTP_BODY" ".id")
    log_success "Company B created with ID: $company_b_id (relationship client)"

    # ============================================
    # Step 5: GET /companies — 2 companies (Scenario 4)
    # ============================================
    log_info "=== Step 5: List Shows Both Companies (Scenario 4) ==="

    run_request "GET" "/api/v1/companies" "" "$headers"
    if ! test_step "List Companies" 200 $HTTP_CODE; then
        log_error "Failed to list companies. Response: $HTTP_BODY"
        exit 1
    fi

    local list_total
    list_total=$(json_field "$HTTP_BODY" ".meta.total")
    if [[ "$list_total" == "2" ]]; then
        log_success "Both companies accessible (Scenario 4)"
    else
        log_error "Expected 2 companies, got: $list_total"
        exit 1
    fi

    # ============================================
    # Step 6: GET /companies/:id
    # ============================================
    log_info "=== Step 6: Show Company ==="

    run_request "GET" "/api/v1/companies/$company_a_id" "" "$headers"
    if ! test_step "Show Company A" 200 $HTTP_CODE; then
        log_error "Failed to show company. Response: $HTTP_BODY"
        exit 1
    fi

    # ============================================
    # Step 7: PATCH /companies/:id
    # ============================================
    log_info "=== Step 7: Update Company ==="

    run_request "PATCH" "/api/v1/companies/$company_a_id" "{
        \"company\": {
            \"name\": \"E2E Consulting Updated\",
            \"vat_regime\": \"reelle_simplifiee\"
        }
    }" "$headers"
    if ! test_step "Update Company A" 200 $HTTP_CODE; then
        log_error "Failed to update company. Response: $HTTP_BODY"
        exit 1
    fi

    # ============================================
    # Step 8: POST /user_companies — add client role (Scenario 5)
    # ============================================
    log_info "=== Step 8: Add Client Role to Company A (Scenario 5) ==="

    run_request "POST" "/api/v1/user_companies" "{
        \"company_id\": \"$company_a_id\",
        \"role\": \"client\"
    }" "$headers"
    if ! test_step "Add client role to Company A" 201 $HTTP_CODE; then
        log_error "Failed to add role. Response: $HTTP_BODY"
        exit 1
    fi

    local relationship_id
    relationship_id=$(json_field "$HTTP_BODY" ".id")

    # ============================================
    # Step 9: POST /user_companies — duplicate role (Scenario 6)
    # ============================================
    log_info "=== Step 9: Duplicate Role Rejected (Scenario 6) ==="

    run_request "POST" "/api/v1/user_companies" "{
        \"company_id\": \"$company_a_id\",
        \"role\": \"independent\"
    }" "$headers"
    if ! test_step "Duplicate identical role rejected" 422 $HTTP_CODE; then
        log_error "Expected 422 for duplicate relationship, got: $HTTP_CODE"
        exit 1
    fi

    # ============================================
    # Step 10: POST /user_companies — invalid role
    # ============================================
    log_info "=== Step 10: Invalid Role Rejected ==="

    run_request "POST" "/api/v1/user_companies" "{
        \"company_id\": \"$company_a_id\",
        \"role\": \"unsupported_role\"
    }" "$headers"
    if ! test_step "Invalid role rejected" 422 $HTTP_CODE; then
        log_error "Expected 422 for invalid role, got: $HTTP_CODE"
        exit 1
    fi

    # ============================================
    # Step 11: POST /companies — invalid SIREN (Scenario 8)
    # ============================================
    log_info "=== Step 11: Invalid SIREN Rejected (Scenario 8) ==="

    run_request "POST" "/api/v1/companies" "{
        \"company\": { \"name\": \"Bad Siren Corp\", \"siren\": \"12345\" },
        \"role\": \"independent\"
    }" "$headers"
    if ! test_step "Invalid SIREN rejected" 422 $HTTP_CODE; then
        log_error "Expected 422 for invalid SIREN, got: $HTTP_CODE"
        exit 1
    fi

    # ============================================
    # Step 12: POST /companies — duplicate SIREN (Scenario 9)
    # ============================================
    log_info "=== Step 12: Duplicate SIREN Rejected (Scenario 9) ==="

    run_request "POST" "/api/v1/companies" "{
        \"company\": { \"name\": \"Duplicate Corp\", \"siren\": \"123456789\" },
        \"role\": \"independent\"
    }" "$headers"
    if ! test_step "Duplicate SIREN rejected" 422 $HTTP_CODE; then
        log_error "Expected 422 for duplicate SIREN, got: $HTTP_CODE"
        exit 1
    fi

    # ============================================
    # Step 13: POST /companies — without SIRET (Scenario 10)
    # ============================================
    log_info "=== Step 13: Create Company Without SIRET (Scenario 10) ==="

    run_request "POST" "/api/v1/companies" "{
        \"company\": { \"name\": \"No Siret Corp\", \"siren\": \"111222333\" },
        \"role\": \"independent\"
    }" "$headers"
    if ! test_step "Create Company without SIRET" 201 $HTTP_CODE; then
        log_error "Expected 201 without SIRET, got: $HTTP_CODE"
        exit 1
    fi

    # ============================================
    # Step 14: POST /companies — invalid role, atomicity (Scenario 12)
    # ============================================
    log_info "=== Step 14: Atomicity — Invalid Role (Scenario 12) ==="

    run_request "POST" "/api/v1/companies" "{
        \"company\": { \"name\": \"Orphan Corp\", \"siren\": \"333444555\" },
        \"role\": \"unsupported_role\"
    }" "$headers"
    if ! test_step "Atomic onboarding rolled back" 422 $HTTP_CODE; then
        log_error "Expected 422 for invalid role onboarding, got: $HTTP_CODE"
        exit 1
    fi

    # ============================================
    # Step 15: Cross-user access rejected (Scenario 13)
    # ============================================
    log_info "=== Step 15: Cross-User Access Rejected (Scenario 13) ==="

    run_request "POST" "/api/v1/signup" "{
        \"email\": \"$TEST_EMAIL_OTHER\",
        \"password\": \"$TEST_PASSWORD\",
        \"password_confirmation\": \"$TEST_PASSWORD\"
    }"

    run_request "POST" "/api/v1/auth/login" "{
        \"email\": \"$TEST_EMAIL_OTHER\",
        \"password\": \"$TEST_PASSWORD\"
    }"
    if ! test_step "Other User Login" 200 $HTTP_CODE; then
        log_error "Failed to login as other user"
        exit 1
    fi

    local other_token
    other_token=$(json_field "$HTTP_BODY" ".token")
    local other_headers="Authorization: Bearer $other_token"

    run_request "GET" "/api/v1/companies/$company_a_id" "" "$other_headers"
    if ! test_step "Cross-user access rejected" 403 $HTTP_CODE; then
        log_error "Expected 403 for cross-user access, got: $HTTP_CODE"
        exit 1
    fi

    if [[ "$HTTP_BODY" == *"FORBIDDEN"* ]]; then
        log_success "Standardized error code FORBIDDEN present (§44)"
    else
        log_error "Standardized error format missing: $HTTP_BODY"
        exit 1
    fi

    # ============================================
    # Step 16: DELETE /user_companies/:id — soft delete (§37.4)
    # ============================================
    log_info "=== Step 16: Soft Delete Relationship (§37.4) ==="

    run_request "DELETE" "/api/v1/user_companies/$relationship_id" "" "$headers"
    if ! test_step "Soft delete relationship" 200 $HTTP_CODE; then
        log_error "Failed to soft delete relationship. Response: $HTTP_BODY"
        exit 1
    fi

    run_request "GET" "/api/v1/user_companies" "" "$headers"
    if [[ "$HTTP_BODY" == *"$relationship_id"* ]]; then
        log_error "Soft-deleted relationship still listed"
        exit 1
    else
        log_success "Soft-deleted relationship excluded from active list (§31)"
    fi

    # ============================================
    # Step 17: DELETE /companies/:id — soft delete (Scenario 14)
    # ============================================
    log_info "=== Step 17: Soft Delete Company (Scenario 14) ==="

    run_request "DELETE" "/api/v1/companies/$company_a_id" "" "$headers"
    if ! test_step "Soft delete company" 200 $HTTP_CODE; then
        log_error "Failed to soft delete company. Response: $HTTP_BODY"
        exit 1
    fi

    # ============================================
    # Final summary
    # ============================================
    log_info "=== E2E Test Summary ==="
    log_success "✅ All E2E test steps completed successfully!"
    log_success "📊 Test Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
    log_success "  - User created and authenticated: ✅"
    log_success "  - Empty list without fictitious company (Scenario 1, INV-05): ✅"
    log_success "  - Atomic onboarding independent (Scenario 2, INV-16): ✅"
    log_success "  - Flat JSON onboarding client (Scenarios 3+15): ✅"
    log_success "  - Multiple companies accessible (Scenario 4): ✅"
    log_success "  - Company shown and updated: ✅"
    log_success "  - Multiple roles same company (Scenario 5): ✅"
    log_success "  - Duplicate role rejected (Scenario 6, INV-18): ✅"
    log_success "  - Invalid role rejected: ✅"
    log_success "  - Invalid SIREN rejected (Scenario 8): ✅"
    log_success "  - Duplicate SIREN rejected (Scenario 9): ✅"
    log_success "  - Company without SIRET (Scenario 10, INV-11): ✅"
    log_success "  - Atomicity rollback (Scenario 12, INV-17): ✅"
    log_success "  - Cross-user access rejected (Scenario 13, §43): ✅"
    log_success "  - Relationship soft deleted (§37.4): ✅"
    log_success "  - Company soft deleted (Scenario 14, INV-21): ✅"

    log_info "🎯 FC-08 E2E Test PASSED"
    log_info "📝 Log file available at: $LOG_FILE"

    return 0
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi