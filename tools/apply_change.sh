#!/usr/bin/env bash
# apply_change.sh — Policy gate for change-desk
#
# Usage: ./tools/apply_change.sh <change-id> <plan-hash-prefix> <target-version>
#
# Refuses to run unless ALL of the following invariants hold:
#   1. Change ID strictly matches CHG-YYYYMMDD-NNN
#   2. Replay check: Change ID has not already been executed
#   3. Target version adheres to SemVer format (vX.Y.Z)
#   4. Approval file exists and change-id matches
#   5. SHA-256 of plan.md matches approved hash prefix
#   6. review.md exists, verdict is APPROVED, and referenced plan hash matches
#   7. If HMAC key is present, verify cryptographic human signature
#   8. Target path is strictly contained within sandbox/ (no ../ escapes, no symlink escape)
#   9. Atomic execution with health check (sandbox/check.sh) and automatic rollback
#
# This provides tamper-evidence and policy enforcement in a sandbox context.
# Role separation between agents is behavioral/instructional.

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ─── Portable SHA-256 Helper (Linux + macOS) ──────────────────────────────────
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# ─── Args ─────────────────────────────────────────────────────────────────────
if [[ $# -lt 3 ]]; then
  echo -e "${RED}ERROR: Usage: $0 <change-id> <plan-hash-prefix> <target-version>${NC}"
  exit 1
fi

CHANGE_ID="$1"
PLAN_HASH_PREFIX="$2"
TARGET_VERSION="$3"

# ─── Paths ────────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIR="$REPO_ROOT/evidence/$CHANGE_ID"
PLAN_FILE="$EVIDENCE_DIR/plan.md"
REVIEW_FILE="$EVIDENCE_DIR/review.md"
APPROVAL_FILE="$EVIDENCE_DIR/approval.txt"
EXEC_LOG="$EVIDENCE_DIR/execution.log"
APPLIED_LEDGER="$REPO_ROOT/evidence/.applied_ledger"
SANDBOX_DIR="$REPO_ROOT/sandbox"
APP_FILE="$SANDBOX_DIR/app.txt"
CHECK_SCRIPT="$SANDBOX_DIR/check.sh"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ─── Log helpers ──────────────────────────────────────────────────────────────
log() { echo -e "$1" | tee -a "$EXEC_LOG"; }
fail() {
  log "${RED}GATE REFUSED: $1${NC}"
  log "Exit: 1 | Timestamp: $TIMESTAMP"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
}

# ─── Init log ─────────────────────────────────────────────────────────────────
mkdir -p "$EVIDENCE_DIR"
touch "$APPLIED_LEDGER"
log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "${BLUE}apply_change.sh — Policy Gate${NC}"
log "Change ID:        $CHANGE_ID"
log "Hash prefix:      $PLAN_HASH_PREFIX"
log "Target version:   $TARGET_VERSION"
log "Timestamp:        $TIMESTAMP"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Check 1: Change ID Schema Validation ─────────────────────────────────────
log ""
log "${YELLOW}[1/8] Validating Change ID format...${NC}"
if [[ ! "$CHANGE_ID" =~ ^CHG-[0-9]{8}-[0-9]{3,}$ ]]; then
  fail "INVALID CHANGE ID: '$CHANGE_ID'. Must match format CHG-YYYYMMDD-NNN (e.g., CHG-20261104-001)"
fi
log "${GREEN}  ✓ Change ID format valid${NC}"

# ─── Check 2: Replay Prevention ───────────────────────────────────────────────
log ""
log "${YELLOW}[2/8] Checking replay protection ledger...${NC}"
if grep -q "^${CHANGE_ID}:" "$APPLIED_LEDGER" 2>/dev/null; then
  fail "REPLAY DETECTED — change '$CHANGE_ID' has already been applied. Replaying approvals is prohibited."
fi
log "${GREEN}  ✓ No prior execution detected${NC}"

# ─── Check 3: Target Version Schema ───────────────────────────────────────────
log ""
log "${YELLOW}[3/8] Validating target version format...${NC}"
if [[ ! "$TARGET_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  fail "INVALID TARGET VERSION: '$TARGET_VERSION'. Must follow SemVer (e.g., v2.0.0)"
fi
log "${GREEN}  ✓ Target version format valid${NC}"

# ─── Check 4: Approval file ───────────────────────────────────────────────────
log ""
log "${YELLOW}[4/8] Checking approval file...${NC}"
if [[ ! -f "$APPROVAL_FILE" ]]; then
  fail "Approval file not found: $APPROVAL_FILE"
fi

APPROVAL_CONTENT=$(cat "$APPROVAL_FILE")
log "Approval content:"
log "  $APPROVAL_CONTENT"

if ! echo "$APPROVAL_CONTENT" | grep -q "APPROVED $CHANGE_ID"; then
  fail "Approval ID mismatch. Expected 'APPROVED $CHANGE_ID' in $APPROVAL_FILE"
fi
log "${GREEN}  ✓ Approval ID matches${NC}"

# Optional HMAC verification if operator key is present on host
KEY_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/change-desk/operator.key"
if [[ -f "$KEY_FILE" ]] && grep -q '^hmac_sig:' "$APPROVAL_FILE"; then
  log "Verifying human operator HMAC signature..."
  OPERATOR_SECRET=$(cat "$KEY_FILE")
  RECORDED_SIG=$(grep '^hmac_sig:' "$APPROVAL_FILE" | awk '{print $2}')
  RECORDED_HASH=$(grep '^plan_hash:' "$APPROVAL_FILE" | awk '{print $2}' || true)
  if [[ -n "$RECORDED_HASH" ]]; then
    EXPECTED_SIG=$(echo -n "${CHANGE_ID}:${RECORDED_HASH}" | openssl dgst -sha256 -hmac "$OPERATOR_SECRET" 2>/dev/null | awk '{print $NF}' || true)
    if [[ -n "$EXPECTED_SIG" && "$RECORDED_SIG" == "$EXPECTED_SIG" ]]; then
      log "${GREEN}  ✓ Human operator HMAC signature verified${NC}"
    else
      fail "INVALID OPERATOR SIGNATURE: approval was not signed by a valid operator key"
    fi
  fi
fi

# ─── Check 5: Plan file + hash ────────────────────────────────────────────────
log ""
log "${YELLOW}[5/8] Verifying plan hash...${NC}"
if [[ ! -f "$PLAN_FILE" ]]; then
  fail "Plan file not found: $PLAN_FILE"
fi

ACTUAL_HASH=$(sha256 "$PLAN_FILE")
ACTUAL_PREFIX="${ACTUAL_HASH:0:${#PLAN_HASH_PREFIX}}"
log "Actual SHA-256:   $ACTUAL_HASH"
log "Approved prefix:  $PLAN_HASH_PREFIX"
log "Actual prefix:    $ACTUAL_PREFIX"

if [[ "$ACTUAL_PREFIX" != "$PLAN_HASH_PREFIX" ]]; then
  fail "HASH MISMATCH — plan was modified after approval.
  Approved: $PLAN_HASH_PREFIX
  Actual:   $ACTUAL_PREFIX"
fi
log "${GREEN}  ✓ Plan hash matches${NC}"

# ─── Check 6: Review file + verdict + Plan Hash Binding ───────────────────────
log ""
log "${YELLOW}[6/8] Checking reviewer verdict and plan binding...${NC}"
if [[ ! -f "$REVIEW_FILE" ]]; then
  fail "Review file not found: $REVIEW_FILE"
fi

VERDICT=$(grep -i '^## Verdict' "$REVIEW_FILE" -A 1 | tail -1 | tr -d '[:space:]' || true)
log "Verdict in review: $VERDICT"

if [[ "$VERDICT" != "APPROVED" ]]; then
  fail "Reviewer verdict is not APPROVED (found: '$VERDICT')"
fi

# Check review-to-plan cryptographic binding
REVIEW_PLAN_HASH=$(grep -i '^## Plan Hash' "$REVIEW_FILE" -A 1 | tail -1 | tr -d '[:space:]' || true)
if [[ -n "$REVIEW_PLAN_HASH" ]]; then
  log "Review bound plan hash: $REVIEW_PLAN_HASH"
  if [[ "$REVIEW_PLAN_HASH" != "$ACTUAL_HASH" && "$REVIEW_PLAN_HASH" != "${ACTUAL_HASH:0:${#REVIEW_PLAN_HASH}}" ]]; then
    fail "REVIEW-TO-PLAN MISMATCH — review was conducted on a different version of plan.md.
  Review hash: $REVIEW_PLAN_HASH
  Actual hash: $ACTUAL_HASH"
  fi
  log "${GREEN}  ✓ Review cryptographically bound to current plan.md${NC}"
fi
log "${GREEN}  ✓ Reviewer verdict: APPROVED${NC}"

# ─── Check 7: Target path safety, path traversal & symlinks ───────────────────
log ""
log "${YELLOW}[7/8] Validating target path and containment...${NC}"
if [[ "$APP_FILE" == *".."* ]]; then
  fail "PATH TRAVERSAL DETECTED: Target file path contains '..' escape sequence: $APP_FILE"
fi

REAL_APP_FILE=$(realpath "$APP_FILE" 2>/dev/null || echo "$APP_FILE")
REAL_SANDBOX=$(realpath "$SANDBOX_DIR" 2>/dev/null || echo "$SANDBOX_DIR")

if [[ "$REAL_APP_FILE" != "$REAL_SANDBOX"/* && "$REAL_APP_FILE" != "$REAL_SANDBOX" ]]; then
  fail "INVALID TARGET PATH — target escapes sandbox/: $REAL_APP_FILE"
fi

# Reject if target path is a symlink pointing outside sandbox
if [[ -L "$APP_FILE" ]]; then
  SYMLINK_TARGET=$(readlink -f "$APP_FILE")
  if [[ "$SYMLINK_TARGET" != "$REAL_SANDBOX"/* ]]; then
    fail "SYMLINK ESCAPE DETECTED — symlink points outside sandbox: $SYMLINK_TARGET"
  fi
fi
log "${GREEN}  ✓ Target path is strictly contained inside sandbox/${NC}"

# ─── Check 8: Apply change & health check with auto-rollback ──────────────────
log ""
log "${YELLOW}[8/8] Applying change and executing verification check...${NC}"
log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${GREEN}ALL CHECKS PASSED — Applying change${NC}"
log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log ""

# Backup current state
BACKUP_FILE="$EVIDENCE_DIR/app.txt.backup"
cp "$APP_FILE" "$BACKUP_FILE"
log "Backup saved: $BACKUP_FILE"

# Apply the version change
OLD_VERSION=$(grep '^version:' "$APP_FILE" | awk '{print $2}')
sed -i "s/^version:.*/version: $TARGET_VERSION/" "$APP_FILE"
sed -i "s/^last_updated:.*/last_updated: $(date +%Y-%m-%d)/" "$APP_FILE"
log "Version changed: $OLD_VERSION → $TARGET_VERSION"

# Run health check
log ""
log "${YELLOW}Running health check...${NC}"
log ""

if bash "$CHECK_SCRIPT" 2>&1 | tee -a "$EXEC_LOG"; then
  # Record in replay ledger upon successful completion
  echo "${CHANGE_ID}:${TIMESTAMP}:${ACTUAL_HASH}:${TARGET_VERSION}" >> "$APPLIED_LEDGER"

  log ""
  log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  log "${GREEN}EXECUTION COMPLETE: $CHANGE_ID${NC}"
  log "${GREEN}check.sh: PASSED${NC}"
  log "${GREEN}Exit: 0 | Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)${NC}"
  log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 0
else
  # Rollback
  log ""
  log "${RED}check.sh FAILED — rolling back${NC}"
  cp "$BACKUP_FILE" "$APP_FILE"
  log "Rolled back to: $OLD_VERSION"
  fail "Health check failed after apply — change rolled back"
fi
