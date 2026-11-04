#!/usr/bin/env bash
# apply_change.sh — Policy gate for change-desk
#
# Usage: ./tools/apply_change.sh <change-id> <plan-hash-prefix> <target-version>
#
# Refuses to run unless ALL of the following hold:
#   1. Approval file exists and change-id matches
#   2. SHA-256 of plan.md starts with the approved hash prefix
#   3. review.md exists and verdict is APPROVED
#   4. Target path is inside sandbox/
#
# This gives tamper-evidence in a sandbox context.
# It is NOT a security boundary against a hostile agent with filesystem access.

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
SANDBOX_DIR="$REPO_ROOT/sandbox"
APP_FILE="$SANDBOX_DIR/app.txt"
CHECK_SCRIPT="$SANDBOX_DIR/check.sh"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EXIT_CODE=0

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
log ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "${BLUE}apply_change.sh — Policy Gate${NC}"
log "Change ID:        $CHANGE_ID"
log "Hash prefix:      $PLAN_HASH_PREFIX"
log "Target version:   $TARGET_VERSION"
log "Timestamp:        $TIMESTAMP"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Check 1: Approval file ───────────────────────────────────────────────────
log ""
log "${YELLOW}[1/4] Checking approval file...${NC}"
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

# ─── Check 2: Plan file + hash ────────────────────────────────────────────────
log ""
log "${YELLOW}[2/4] Verifying plan hash...${NC}"
if [[ ! -f "$PLAN_FILE" ]]; then
  fail "Plan file not found: $PLAN_FILE"
fi

ACTUAL_HASH=$(sha256sum "$PLAN_FILE" | awk '{print $1}')
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

# ─── Check 3: Review file + verdict ───────────────────────────────────────────
log ""
log "${YELLOW}[3/4] Checking reviewer verdict...${NC}"
if [[ ! -f "$REVIEW_FILE" ]]; then
  fail "Review file not found: $REVIEW_FILE"
fi

VERDICT=$(grep -i '^## Verdict' "$REVIEW_FILE" -A 1 | tail -1 | tr -d '[:space:]' || true)
log "Verdict in review: $VERDICT"

if [[ "$VERDICT" != "APPROVED" ]]; then
  fail "Reviewer verdict is not APPROVED (found: '$VERDICT')"
fi
log "${GREEN}  ✓ Reviewer verdict: APPROVED${NC}"

# ─── Check 4: Target path safety ──────────────────────────────────────────────
log ""
log "${YELLOW}[4/4] Validating target path...${NC}"
REAL_APP_FILE=$(realpath "$APP_FILE" 2>/dev/null || echo "$APP_FILE")
REAL_SANDBOX=$(realpath "$SANDBOX_DIR" 2>/dev/null || echo "$SANDBOX_DIR")

if [[ "$REAL_APP_FILE" != "$REAL_SANDBOX"* ]]; then
  fail "INVALID TARGET PATH — target is outside sandbox/: $REAL_APP_FILE"
fi
log "${GREEN}  ✓ Target path is inside sandbox/${NC}"

# ─── All checks passed — Apply change ─────────────────────────────────────────
log ""
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

# ─── Run health check ─────────────────────────────────────────────────────────
log ""
log "${YELLOW}Running health check...${NC}"
log ""

if bash "$CHECK_SCRIPT" 2>&1 | tee -a "$EXEC_LOG"; then
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
