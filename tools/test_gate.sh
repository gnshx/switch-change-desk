#!/usr/bin/env bash
# tools/test_gate.sh — Automated test suite for the apply_change.sh policy gate.
#
# Tests:
#   1. Happy path         — gate exits 0
#   2. Tamper             — gate exits 1, output contains "HASH MISMATCH"
#   3. Missing review     — gate exits 1 (review.md absent)
#   4. Wrong change ID    — gate exits 1 (approval.txt has wrong ID)
#   5. Verdict REJECTED   — gate exits 1 (review.md verdict is REJECTED)
#
# Resets sandbox between each test via demo/reset.sh.
# Prints PASS / FAIL per test.
# Final summary: N/5 passed. Exit 0 if all pass, 1 if any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GATE="$REPO_ROOT/tools/apply_change.sh"
RESET="$REPO_ROOT/demo/reset.sh"
FIXTURE_DIR="$REPO_ROOT/demo/fixtures/CHG-DEMO-001"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TEST_NUM=0

# ── Helper: begin a test ───────────────────────────────────────────────────────
begin_test() {
    TEST_NUM=$((TEST_NUM + 1))
    echo ""
    echo -e "${YELLOW}── Test $TEST_NUM: $1${NC}"
}

# ── Helper: record result ─────────────────────────────────────────────────────
pass() {
    echo -e "   ${GREEN}PASS${NC} — $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail_test() {
    echo -e "   ${RED}FAIL${NC} — $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# ── Helper: reset + scaffold a minimal valid evidence dir ─────────────────────
#   Usage: scaffold_evidence <change-id>
#   Copies fixture plan + review, computes hash, writes approval.txt.
#   Sets SCAFFOLD_HASH global.
SCAFFOLD_HASH=""
scaffold_evidence() {
    local change_id="$1"
    local ev_dir="$REPO_ROOT/evidence/$change_id"

    bash "$RESET" > /dev/null
    mkdir -p "$ev_dir"
    cp "$FIXTURE_DIR/plan.md"   "$ev_dir/plan.md"
    cp "$FIXTURE_DIR/review.md" "$ev_dir/review.md"

    SCAFFOLD_HASH=$(sha256sum "$ev_dir/plan.md" | awk '{print $1}')

    cat > "$ev_dir/approval.txt" << EOF
APPROVED $change_id
hash: $SCAFFOLD_HASH
approved_by: test-suite
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
}

# ── Run gate, capturing output + exit code without set -e killing us ──────────
GATE_EXIT=0
GATE_OUT=""
run_gate() {
    local change_id="$1" hash="$2" version="$3"
    GATE_EXIT=0
    GATE_OUT=$(bash "$GATE" "$change_id" "$hash" "$version" 2>&1) || GATE_EXIT=$?
}

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  change-desk gate test suite — 5 tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ═════════════════════════════════════════════════════════════════════════════
# TEST 1 — Happy path: gate exits 0
# ═════════════════════════════════════════════════════════════════════════════
begin_test "Happy path — gate exits 0"

scaffold_evidence "CHG-TEST-001"
run_gate "CHG-TEST-001" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 0 ]]; then
    pass "gate exited 0"
else
    fail_test "gate exited $GATE_EXIT (expected 0). Output: $GATE_OUT"
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 2 — Tamper: gate exits 1, output contains HASH MISMATCH
# ═════════════════════════════════════════════════════════════════════════════
begin_test "Tamper — gate exits 1 with HASH MISMATCH"

scaffold_evidence "CHG-TEST-002"
EV_DIR="$REPO_ROOT/evidence/CHG-TEST-002"
SAVED_HASH="$SCAFFOLD_HASH"

# Tamper: append a blank line after approval was written
printf '\n' >> "$EV_DIR/plan.md"

run_gate "CHG-TEST-002" "$SAVED_HASH" "v2.0.0"

HASH_MISMATCH_IN_OUTPUT=false
echo "$GATE_OUT" | grep -q "HASH MISMATCH" && HASH_MISMATCH_IN_OUTPUT=true || true

if [[ $GATE_EXIT -eq 1 ]] && [[ "$HASH_MISMATCH_IN_OUTPUT" == "true" ]]; then
    pass "gate exited 1 with HASH MISMATCH in output"
else
    fail_test "gate exit=$GATE_EXIT, HASH MISMATCH found=$HASH_MISMATCH_IN_OUTPUT"
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 3 — Missing review: gate exits 1
# ═════════════════════════════════════════════════════════════════════════════
begin_test "Missing review — gate exits 1"

scaffold_evidence "CHG-TEST-003"
EV_DIR="$REPO_ROOT/evidence/CHG-TEST-003"

# Remove review.md to simulate no-review scenario
rm "$EV_DIR/review.md"

run_gate "CHG-TEST-003" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]]; then
    pass "gate exited 1 (no review.md)"
else
    fail_test "gate exited $GATE_EXIT (expected 1)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 4 — Wrong change ID in approval: gate exits 1
# ═════════════════════════════════════════════════════════════════════════════
begin_test "Wrong change ID in approval — gate exits 1"

scaffold_evidence "CHG-TEST-004"
EV_DIR="$REPO_ROOT/evidence/CHG-TEST-004"
SAVED_HASH="$SCAFFOLD_HASH"

# Overwrite approval.txt with a different change ID
cat > "$EV_DIR/approval.txt" << EOF
APPROVED CHG-WRONG-999
hash: $SAVED_HASH
approved_by: test-suite
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

run_gate "CHG-TEST-004" "$SAVED_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]]; then
    pass "gate exited 1 (wrong change ID in approval)"
else
    fail_test "gate exited $GATE_EXIT (expected 1)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# TEST 5 — Reviewer verdict REJECTED: gate exits 1
# ═════════════════════════════════════════════════════════════════════════════
begin_test "Reviewer verdict REJECTED — gate exits 1"

scaffold_evidence "CHG-TEST-005"
EV_DIR="$REPO_ROOT/evidence/CHG-TEST-005"

# Overwrite review.md with REJECTED verdict
cat > "$EV_DIR/review.md" << 'REVIEWEOF'
# Code Review: CHG-TEST-005

## Reviewer
Test Suite

## Review Findings
The plan has critical issues that must be resolved before proceeding.

## Verdict
REJECTED
REVIEWEOF

run_gate "CHG-TEST-005" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]]; then
    pass "gate exited 1 (verdict REJECTED)"
else
    fail_test "gate exited $GATE_EXIT (expected 1)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════════════
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "${GREEN}  RESULT: $PASS_COUNT/$TOTAL passed — ALL TESTS PASSED${NC}"
else
    echo -e "${RED}  RESULT: $PASS_COUNT/$TOTAL passed — $FAIL_COUNT FAILED${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Final reset to leave sandbox clean
bash "$RESET" > /dev/null

[[ $FAIL_COUNT -eq 0 ]]
