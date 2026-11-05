#!/usr/bin/env bash
# tools/test_gate.sh — Comprehensive 21-test regression suite for policy gate
#
# Tests all 8 deterministic safety invariants and edge cases:
#   1. Happy path                 — gate exits 0, version applied, check.sh passes
#   2. Tamper detection           — plan modified after approval exits 1 (HASH MISMATCH)
#   3. Full hash mismatch         — prefix matches but full 64-hex differs exits 1
#   4. Unsigned approval          — missing hmac_sig / plan_hash fails closed exits 1
#   5. Invalid HMAC signature     — forged or corrupted signature exits 1
#   6. Version mismatch           — signed version differs from target version exits 1
#   7. Short hash prefix          — prefix under 8 hex chars exits 1 immediately
#   8. Malformed Change ID        — path traversal ID (../../x) exits 1 without creating files
#   9. Missing approval file      — approval.txt absent exits 1
#  10. Approval ID mismatch       — approval.txt with mismatched change ID exits 1
#  11. Missing review             — review.md absent exits 1
#  12. Reviewer verdict REJECTED  — verdict not APPROVED exits 1
#  13. Missing review Plan Hash   — review.md without ## Plan Hash exits 1
#  14. Malformed review hash      — non-64-hex review hash exits 1
#  15. Stale review binding       — review conducted on different plan hash exits 1
#  16. Dynamic path traversal     — target file containing '..' escapes sandbox exits 1
#  17. Symlink escape attempt     — symlink escaping sandbox exits 1
#  18. Replay prevention          — duplicate run of same Change ID exits 1
#  19. Automatic rollback         — check.sh failure reverts state to v1.0.0 exits 1
#  20. Clean log output           — execution.log strips ANSI escape sequences
#  21. Approve CLI --yes refusal  — approve.sh refuses --yes bypass flag
#
# Resets sandbox between tests via demo/reset.sh.
# Final summary: N/21 passed. Exits 0 if all pass, 1 if any fail.

set -euo pipefail
export CHANGE_DESK_TEST_MODE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GATE="$REPO_ROOT/tools/apply_change.sh"
APPROVE_TOOL="$REPO_ROOT/tools/approve.sh"
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

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

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
  local target_ver="${2:-v2.0.0}"
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

  bash "$APPROVE_TOOL" "$change_id" "$target_ver" > /dev/null
}

GATE_EXIT=0
GATE_OUT=""
run_gate() {
  local change_id="$1" hash="$2" version="$3" target_file="${4:-}"
  GATE_EXIT=0
  if [[ -n "$target_file" ]]; then
    GATE_OUT=$(bash "$GATE" "$change_id" "$hash" "$version" "$target_file" 2>&1) || GATE_EXIT=$?
  else
    GATE_OUT=$(bash "$GATE" "$change_id" "$hash" "$version" 2>&1) || GATE_EXIT=$?
  fi
}

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  change-desk policy gate regression suite — 21 tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ── TEST 1: Happy path ────────────────────────────────────────────────────────
begin_test "Happy path — gate exits 0 and applies version"
scaffold_evidence "CHG-20261104-001" "v2.0.0"
run_gate "CHG-20261104-001" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 0 ]] && grep -q "version: v2.0.0" "$APP_FILE"; then
  pass "gate exited 0 and updated sandbox to v2.0.0"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 2: Tamper detection (prefix mismatch) ────────────────────────────────
begin_test "Tamper detection — gate exits 1 on post-approval edit"
scaffold_evidence "CHG-20261104-002" "v2.0.0"
printf '\n# Tampered line injected\n' >> "$REPO_ROOT/evidence/CHG-20261104-002/plan.md"
run_gate "CHG-20261104-002" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "HASH MISMATCH"; then
  pass "gate exited 1 with HASH MISMATCH"
else
  fail_test "gate exit=$GATE_EXIT (expected 1 with HASH MISMATCH)"
fi

# ── TEST 3: Full hash mismatch when caller uses new prefix ────────────────────
begin_test "Full hash mismatch — passing modified plan's prefix caught by signed hash"
scaffold_evidence "CHG-20261104-003" "v2.0.0"
printf '\n# Tampered line injected\n' >> "$REPO_ROOT/evidence/CHG-20261104-003/plan.md"
NEW_HASH=$(sha256 "$REPO_ROOT/evidence/CHG-20261104-003/plan.md")
run_gate "CHG-20261104-003" "${NEW_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "PLAN TAMPERING DETECTED"; then
  pass "gate detected tampering against signed 64-hex hash"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 4: Unsigned approval fails closed ────────────────────────────────────
begin_test "Unsigned approval fails closed — missing hmac_sig exits 1"
scaffold_evidence "CHG-20261104-004" "v2.0.0"
sed -i '/^hmac_sig:/d' "$REPO_ROOT/evidence/CHG-20261104-004/approval.txt"
run_gate "CHG-20261104-004" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "FAIL-CLOSED"; then
  pass "gate refused unsigned approval file"
else
  fail_test "gate exit=$GATE_EXIT (expected fail-closed refusal)"
fi

# ── TEST 5: Forged HMAC signature rejected ────────────────────────────────────
begin_test "Forged HMAC signature — invalid signature string exits 1"
scaffold_evidence "CHG-20261104-005" "v2.0.0"
sed -i 's/^hmac_sig:.*/hmac_sig: deadbeef0000111122223333444455556666777788889999aaaabbbbccccdddd/' "$REPO_ROOT/evidence/CHG-20261104-005/approval.txt"
run_gate "CHG-20261104-005" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "INVALID OPERATOR SIGNATURE"; then
  pass "gate detected and rejected invalid operator signature"
else
  fail_test "gate exit=$GATE_EXIT (expected signature refusal)"
fi

# ── TEST 6: Target version mismatch against signed approval ───────────────────
begin_test "Version mismatch — caller version differs from signed version exits 1"
scaffold_evidence "CHG-20261104-006" "v2.0.0"
run_gate "CHG-20261104-006" "${SCAFFOLD_HASH:0:8}" "v9.9.9"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "VERSION MISMATCH"; then
  pass "gate rejected unauthorized target version"
else
  fail_test "gate exit=$GATE_EXIT (expected version mismatch refusal)"
fi

# ── TEST 7: Short hash prefix rejected immediately ────────────────────────────
begin_test "Short hash prefix — prefix < 8 hex chars rejected immediately"
scaffold_evidence "CHG-20261104-007" "v2.0.0"
run_gate "CHG-20261104-007" "abc" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "INVALID HASH PREFIX"; then
  pass "gate rejected short hash prefix"
else
  fail_test "gate exit=$GATE_EXIT (expected short prefix refusal)"
fi

# ── TEST 8: Malformed Change ID creates no files ──────────────────────────────
begin_test "Malformed Change ID creates no files on disk"
bash "$RESET" > /dev/null
BAD_ID="../../malicious_escape"
run_gate "$BAD_ID" "12345678" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && [[ ! -d "$REPO_ROOT/evidence/$BAD_ID" ]] && [[ ! -d "$REPO_ROOT/malicious_escape" ]]; then
  pass "gate rejected malformed ID without creating any directories"
else
  fail_test "gate exit=$GATE_EXIT or created illegal path"
fi

# ── TEST 9: Missing approval file ─────────────────────────────────────────────
begin_test "Missing approval — approval.txt absent exits 1"
scaffold_evidence "CHG-20261104-009" "v2.0.0"
rm -f "$REPO_ROOT/evidence/CHG-20261104-009/approval.txt"
run_gate "CHG-20261104-009" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "Approval file not found"; then
  pass "gate exited 1 on missing approval.txt"
else
  fail_test "gate exit=$GATE_EXIT (expected 1)"
fi

# ── TEST 10: Approval ID mismatch ─────────────────────────────────────────────
begin_test "Approval ID mismatch — approval for different change ID exits 1"
scaffold_evidence "CHG-20261104-010" "v2.0.0"
sed -i 's/CHG-20261104-010/CHG-20261104-999/' "$REPO_ROOT/evidence/CHG-20261104-010/approval.txt"
run_gate "CHG-20261104-010" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "Approval ID mismatch"; then
  pass "gate exited 1 on approval ID mismatch"
else
  fail_test "gate exit=$GATE_EXIT (expected 1)"
fi

# ── TEST 11: Missing review file ──────────────────────────────────────────────
begin_test "Missing review — review.md absent exits 1"
scaffold_evidence "CHG-20261104-011" "v2.0.0"
rm -f "$REPO_ROOT/evidence/CHG-20261104-011/review.md"
run_gate "CHG-20261104-011" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "Review file not found"; then
  pass "gate exited 1 (no review.md)"
else
  fail_test "gate exit=$GATE_EXIT (expected 1)"
fi

# ── TEST 12: Reviewer verdict REJECTED ────────────────────────────────────────
begin_test "Reviewer verdict REJECTED — gate exits 1"
scaffold_evidence "CHG-20261104-012" "v2.0.0"
sed -i 's/APPROVED/REJECTED/' "$REPO_ROOT/evidence/CHG-20261104-012/review.md"
run_gate "CHG-20261104-012" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "verdict is not APPROVED"; then
  pass "gate exited 1 on REJECTED verdict"
else
  fail_test "gate exit=$GATE_EXIT (expected 1)"
fi

# ── TEST 13: Missing ## Plan Hash section in review ───────────────────────────
begin_test "Missing ## Plan Hash in review — exits 1"
scaffold_evidence "CHG-20261104-013" "v2.0.0"
sed -i '/## Plan Hash/,+1d' "$REPO_ROOT/evidence/CHG-20261104-013/review.md"
run_gate "CHG-20261104-013" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "REVIEW BINDING MISSING"; then
  pass "gate required mandatory ## Plan Hash section"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 14: Non-64-hex review plan hash ──────────────────────────────────────
begin_test "Non-64-hex review plan hash — exits 1"
scaffold_evidence "CHG-20261104-014" "v2.0.0"
sed -i "s/$SCAFFOLD_HASH/short_hash/" "$REPO_ROOT/evidence/CHG-20261104-014/review.md"
run_gate "CHG-20261104-014" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "INVALID REVIEW HASH"; then
  pass "gate required 64 hex characters for review plan hash"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 15: Stale review binding ─────────────────────────────────────────────
begin_test "Review-to-Plan binding — review conducted on different hash exits 1"
scaffold_evidence "CHG-20261104-015" "v2.0.0"
sed -i 's/^[0-9a-f]\{64\}$/0000000000000000000000000000000000000000000000000000000000000000/' "$REPO_ROOT/evidence/CHG-20261104-015/review.md"
run_gate "CHG-20261104-015" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "REVIEW-TO-PLAN MISMATCH"; then
  pass "gate exited 1 on stale review plan hash"
else
  fail_test "gate exit=$GATE_EXIT (expected 1)"
fi

# ── TEST 16: Dynamic path traversal defense ───────────────────────────────────
begin_test "Dynamic path traversal defense — target containing '..' exits 1"
scaffold_evidence "CHG-20261104-016" "v2.0.0"
run_gate "CHG-20261104-016" "${SCAFFOLD_HASH:0:8}" "v2.0.0" "$SANDBOX_DIR/../outside.txt"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "PATH TRAVERSAL DETECTED"; then
  pass "gate detected and rejected path traversal in target argument"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 17: Symlink escape defense ───────────────────────────────────────────
begin_test "Symlink escape defense — gate exits 1 on escaping symlink"
scaffold_evidence "CHG-20261104-017" "v2.0.0"
SYMLINK_PATH="$SANDBOX_DIR/escape_symlink.txt"
ln -sf "/etc/passwd" "$SYMLINK_PATH"
run_gate "CHG-20261104-017" "${SCAFFOLD_HASH:0:8}" "v2.0.0" "$SYMLINK_PATH"
rm -f "$SYMLINK_PATH"

if [[ $GATE_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "SYMLINK ESCAPE DETECTED"; then
  pass "gate detected and rejected symlink escape outside sandbox"
else
  fail_test "gate exit=$GATE_EXIT, output: $GATE_OUT"
fi

# ── TEST 18: Replay attack defense ────────────────────────────────────────────
begin_test "Replay attack defense — duplicate run of same Change ID exits 1"
scaffold_evidence "CHG-20261104-018" "v2.0.0"
run_gate "CHG-20261104-018" "${SCAFFOLD_HASH:0:8}" "v2.0.0"
FIRST_EXIT=$GATE_EXIT

run_gate "CHG-20261104-018" "${SCAFFOLD_HASH:0:8}" "v2.0.0"
SECOND_EXIT=$GATE_EXIT

if [[ $FIRST_EXIT -eq 0 ]] && [[ $SECOND_EXIT -eq 1 ]] && echo "$GATE_OUT" | grep -q "REPLAY DETECTED"; then
  pass "second execution of same Change ID rejected with REPLAY DETECTED"
else
  fail_test "first=$FIRST_EXIT, second=$SECOND_EXIT (expected 0 then 1 with REPLAY DETECTED)"
fi

# ── TEST 19: Automatic rollback on health check failure ───────────────────────
begin_test "Automatic rollback — gate restores backup when check.sh fails"
scaffold_evidence "CHG-20261104-019" "v2.0.0"
CHECK_BAK="$SANDBOX_DIR/check.sh.bak"
cp "$SANDBOX_DIR/check.sh" "$CHECK_BAK"

cat > "$SANDBOX_DIR/check.sh" << 'FAILCHECK'
#!/usr/bin/env bash
echo "HEALTH CHECK SIMULATED FAILURE"
exit 1
FAILCHECK
chmod +x "$SANDBOX_DIR/check.sh"

run_gate "CHG-20261104-019" "${SCAFFOLD_HASH:0:8}" "v2.0.0"
mv "$CHECK_BAK" "$SANDBOX_DIR/check.sh"

if [[ $GATE_EXIT -eq 1 ]] && grep -q "version: v1.0.0" "$APP_FILE" && echo "$GATE_OUT" | grep -q "check.sh FAILED"; then
  pass "gate exited 1, caught check failure, and reverted app to v1.0.0"
else
  fail_test "gate exit=$GATE_EXIT, app version=$(grep '^version' "$APP_FILE" 2>/dev/null || echo 'unknown')"
fi

# ── TEST 20: Clean execution.log without ANSI codes ───────────────────────────
begin_test "Clean execution.log — strips ANSI escape sequences from log file"
scaffold_evidence "CHG-20261104-020" "v2.0.0"
run_gate "CHG-20261104-020" "${SCAFFOLD_HASH:0:8}" "v2.0.0"

LOG_FILE="$REPO_ROOT/evidence/CHG-20261104-020/execution.log"
if [[ -f "$LOG_FILE" ]] && ! grep -q $'\x1b' "$LOG_FILE"; then
  pass "execution.log is clean and contains no ANSI color escape codes"
else
  fail_test "execution.log contains ANSI escape characters"
fi

# ── TEST 21: approve.sh refuses --yes bypass flag ─────────────────────────────
begin_test "approve.sh security — refuses --yes bypass flag"
APPROVE_EXIT=0
APPROVE_OUT=$(bash "$APPROVE_TOOL" "CHG-20261104-020" "v2.0.0" --yes 2>&1) || APPROVE_EXIT=$?

if [[ $APPROVE_EXIT -eq 1 ]] && echo "$APPROVE_OUT" | grep -q "disabled for security"; then
  pass "approve.sh strictly refused --yes flag"
else
  fail_test "approve.sh exited $APPROVE_EXIT (expected 1 with refusal)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  RESULT: ${PASS_COUNT}/${TEST_NUM} passed"
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "  ${GREEN}ALL ${TEST_NUM} TESTS PASSED${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  exit 0
else
  echo -e "  ${RED}${FAIL_COUNT} TESTS FAILED${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  exit 1
fi
