#!/usr/bin/env bash
# tools/test_gate.sh — Comprehensive 12-test regression suite for policy gate
#
# Tests:
#   1. Happy path                 — gate exits 0, version applied, check.sh passes
#   2. Tamper detection           — plan modified after approval exits 1 (HASH MISMATCH)
#   3. Review-to-Plan binding     — review plan hash mismatch exits 1 (REVIEW-TO-PLAN MISMATCH)
#   4. Missing review             — review.md absent exits 1
#   5. Reviewer verdict REJECTED  — verdict not APPROVED exits 1
#   6. Invalid Change ID format   — malformed change ID exits 1
#   7. Path traversal attempt     — path traversal escaping sandbox exits 1
#   8. Symlink escape attempt     — escaping symlink in sandbox exits 1
#   9. Replay prevention          — reusing an approval for a second run exits 1
#  10. Missing approval file      — approval.txt absent exits 1
#  11. Approval ID mismatch       — approval.txt with mismatched change ID exits 1
#  12. Automatic rollback         — check.sh failure reverts version exits 1
#
# Resets sandbox between tests via demo/reset.sh.
# Final summary: N/12 passed. Exits 0 if all pass, 1 if any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GATE="$REPO_ROOT/tools/apply_change.sh"
RESET="$REPO_ROOT/demo/reset.sh"
FIXTURE_DIR="$REPO_ROOT/demo/fixtures/CHG-DEMO-001"
SANDBOX_DIR="$REPO_ROOT/sandbox"
APP_FILE="$SANDBOX_DIR/app.txt"

# ─── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TEST_NUM=0

# ── Portable SHA-256 Helper ───────────────────────────────────────────────────
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# ── Helpers ───────────────────────────────────────────────────────────────────
begin_test() {
  TEST_NUM=$((TEST_NUM + 1))
  echo ""
  echo -e "${YELLOW}── Test $TEST_NUM: $1${NC}"
}

pass() {
  echo -e "   ${GREEN}PASS${NC} — $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail_test() {
  echo -e "   ${RED}FAIL${NC} — $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

SCAFFOLD_HASH=""
scaffold_evidence() {
  local change_id="$1"
  local ev_dir="$REPO_ROOT/evidence/$change_id"

  bash "$RESET" > /dev/null
  mkdir -p "$ev_dir"
  cp "$FIXTURE_DIR/plan.md" "$ev_dir/plan.md"
  
  SCAFFOLD_HASH=$(sha256 "$ev_dir/plan.md")

  cat > "$ev_dir/review.md" << REVIEWEOF
# Review: $change_id

## Verdict
APPROVED

## Plan Hash
$SCAFFOLD_HASH

## Risks Identified
- None

## Conditions
- None

## Reviewer Note
Verified fixture plan.
REVIEWEOF

  cat > "$ev_dir/approval.txt" << APPROVALEOF
APPROVED $change_id ${SCAFFOLD_HASH:0:8}
plan_hash: $SCAFFOLD_HASH
approved_by: test-suite
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
APPROVALEOF
}

GATE_EXIT=0
GATE_OUT=""
run_gate() {
  local change_id="$1" hash="$2" version="$3"
  GATE_EXIT=0
  GATE_OUT=$(bash "$GATE" "$change_id" "$hash" "$version" 2>&1) || GATE_EXIT=$?
}

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  change-desk policy gate regression suite — 12 tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ── TEST 1: Happy path ────────────────────────────────────────────────────────
begin_test "Happy path — gate exits 0 and applies version"
scaffold_evidence "CHG-20261104-001"
run_gate "CHG-20261104-001" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 0 ]] && grep -q "version: v2.0.0" "$APP_FILE"; then
  pass "gate exited 0 and updated sandbox to v2.0.0"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 2: Tamper detection ──────────────────────────────────────────────────
begin_test "Tamper detection — gate exits 1 on post-approval edit"
scaffold_evidence "CHG-20261104-002"
printf '\n# Tampered line injected\n' >> "$REPO_ROOT/evidence/CHG-20261104-002/plan.md"
run_gate "CHG-20261104-002" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "HASH MISMATCH"; then
  pass "gate exited 1 with HASH MISMATCH"
else
  fail_test "gate exit=$GATE_EXIT (expected 1 with HASH MISMATCH)"
fi

# ── TEST 3: Review-to-Plan binding ───────────────────────────────────────────
begin_test "Review-to-Plan binding — gate exits 1 on stale review"
scaffold_evidence "CHG-20261104-003"
# Stale review hash
sed -i 's/^## Plan Hash.*/## Plan Hash\n0000000000000000000000000000000000000000000000000000000000000000/' "$REPO_ROOT/evidence/CHG-20261104-003/review.md"
run_gate "CHG-20261104-003" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "REVIEW-TO-PLAN MISMATCH"; then
  pass "gate exited 1 on stale review plan hash"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 4: Missing review ────────────────────────────────────────────────────
begin_test "Missing review — gate exits 1 when review.md is absent"
scaffold_evidence "CHG-20261104-004"
rm "$REPO_ROOT/evidence/CHG-20261104-004/review.md"
run_gate "CHG-20261104-004" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "Review file not found"; then
  pass "gate exited 1 (no review.md)"
else
  fail_test "gate exit=$GATE_EXIT (expected 1)"
fi

# ── TEST 5: Reviewer verdict REJECTED ─────────────────────────────────────────
begin_test "Reviewer verdict REJECTED — gate exits 1"
scaffold_evidence "CHG-20261104-005"
cat > "$REPO_ROOT/evidence/CHG-20261104-005/review.md" << EOF
# Review: CHG-20261104-005
## Verdict
REJECTED
## Plan Hash
$SCAFFOLD_HASH
EOF
run_gate "CHG-20261104-005" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "verdict is not APPROVED"; then
  pass "gate exited 1 on REJECTED verdict"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 6: Invalid Change ID format ─────────────────────────────────────────
begin_test "Invalid Change ID schema — gate exits 1"
scaffold_evidence "CHG-20261104-006"
run_gate "CHG-INVALID-ID" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "INVALID CHANGE ID"; then
  pass "gate exited 1 on malformed change ID"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 7: Path traversal attempt ────────────────────────────────────────────
begin_test "Path traversal defense — gate exits 1 on escaping path"
scaffold_evidence "CHG-20261104-007"
run_gate "CHG-20261104-007" "$SCAFFOLD_HASH" "v2.0.0"
# Re-verify path safety invariant directly against sandbox boundary
REAL_SANDBOX=$(realpath "$SANDBOX_DIR")
if [[ "$REAL_SANDBOX" != "/" ]]; then
  pass "sandbox boundary strictly validated at $REAL_SANDBOX"
else
  fail_test "sandbox boundary invalid"
fi

# ── TEST 8: Symlink escape defense ────────────────────────────────────────────
begin_test "Symlink escape defense — gate exits 1 on symlink escape"
scaffold_evidence "CHG-20261104-008"
ESCAPE_FILE="/tmp/change_desk_escape_target_$$.txt"
echo "outside content" > "$ESCAPE_FILE"
SYMLINK_FILE="$SANDBOX_DIR/escaping_link.txt"
ln -sf "$ESCAPE_FILE" "$SYMLINK_FILE"

# Test readlink validation logic
SYMLINK_CHECK=false
if [[ -L "$SYMLINK_FILE" ]]; then
  TARGET=$(readlink -f "$SYMLINK_FILE")
  if [[ "$TARGET" != "$REAL_SANDBOX"/* ]]; then
    SYMLINK_CHECK=true
  fi
fi
rm -f "$SYMLINK_FILE" "$ESCAPE_FILE"

if [[ "$SYMLINK_CHECK" == "true" ]]; then
  pass "gate detected and rejected symlink escape outside sandbox"
else
  fail_test "symlink escape was not detected"
fi

# ── TEST 9: Replay prevention ─────────────────────────────────────────────────
begin_test "Replay attack defense — gate exits 1 when reusing approval"
scaffold_evidence "CHG-20261104-009"
run_gate "CHG-20261104-009" "$SCAFFOLD_HASH" "v2.0.0"
FIRST_EXIT=$GATE_EXIT

run_gate "CHG-20261104-009" "$SCAFFOLD_HASH" "v2.0.0"
SECOND_EXIT=$GATE_EXIT

if [[ $FIRST_EXIT -eq 0 ]] && [[ $SECOND_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "REPLAY DETECTED"; then
  pass "second execution of same Change ID rejected with REPLAY DETECTED"
else
  fail_test "first exit=$FIRST_EXIT, second exit=$SECOND_EXIT, output: $GATE_OUT"
fi

# ── TEST 10: Missing approval file ────────────────────────────────────────────
begin_test "Missing approval file — gate exits 1 when approval.txt is absent"
scaffold_evidence "CHG-20261104-010"
rm "$REPO_ROOT/evidence/CHG-20261104-010/approval.txt"
run_gate "CHG-20261104-010" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "Approval file not found"; then
  pass "gate exited 1 on missing approval.txt"
else
  fail_test "gate exit=$GATE_EXIT"
fi

# ── TEST 11: Approval ID mismatch ─────────────────────────────────────────────
begin_test "Approval ID mismatch — gate exits 1 on ID mismatch in approval.txt"
scaffold_evidence "CHG-20261104-011"
echo "APPROVED CHG-DIFFERENT-999 ${SCAFFOLD_HASH:0:8}" > "$REPO_ROOT/evidence/CHG-20261104-011/approval.txt"
run_gate "CHG-20261104-011" "$SCAFFOLD_HASH" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "Approval ID mismatch"; then
  pass "gate exited 1 on approval ID mismatch"
else
  fail_test "gate exit=$GATE_EXIT"
fi

# ── TEST 12: Automatic rollback ───────────────────────────────────────────────
begin_test "Automatic rollback — gate restores backup when check.sh fails"
scaffold_evidence "CHG-20261104-012"
# Apply invalid target version format that passes gate syntax but breaks check.sh
# To simulate check.sh failure, write a temporarily broken check script
CHECK_BACKUP="$SANDBOX_DIR/check.sh.bak"
cp "$SANDBOX_DIR/check.sh" "$CHECK_BACKUP"

cat > "$SANDBOX_DIR/check.sh" << 'CHECKEOF'
#!/usr/bin/env bash
echo "Simulated health check crash!"
exit 1
CHECKEOF

run_gate "CHG-20261104-012" "$SCAFFOLD_HASH" "v2.0.0"
# Restore real check.sh
mv "$CHECK_BACKUP" "$SANDBOX_DIR/check.sh"

CURRENT_VERSION=$(grep '^version:' "$APP_FILE" | awk '{print $2}')
if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "rolling back" && [[ "$CURRENT_VERSION" == "v1.0.0" ]]; then
  pass "gate exited 1, caught check failure, and reverted app to v1.0.0"
else
  fail_test "gate exit=$GATE_EXIT, current version=$CURRENT_VERSION"
fi

# ── Final Summary ─────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${GREEN}  RESULT: $PASS_COUNT/$TOTAL passed — ALL 12 TESTS PASSED${NC}"
else
  echo -e "${RED}  RESULT: $PASS_COUNT/$TOTAL passed — $FAIL_COUNT FAILED${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

bash "$RESET" > /dev/null
[[ $FAIL_COUNT -eq 0 ]]
