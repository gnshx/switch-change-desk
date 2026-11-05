#!/usr/bin/env bash
# apply_change.sh — Deterministic Policy Gate for change-desk
#
# Usage:
#   ./tools/apply_change.sh <change-id> <plan-hash-prefix> <target-version> [target-file]
#
# Enforces 8 Deterministic Invariants before applying changes to application state:
#   1. Strict Argument Schema: Change ID (CHG-YYYYMMDD-NNN), Hash Prefix (8-64 hex), SemVer (vX.Y.Z)
#   2. Replay Protection: Atomic ledger check preventing re-execution of applied change IDs
#   3. Approval File Presence: Human approval file existence and Change ID match
#   4. Fail-Closed Cryptographic HMAC Signature: Verification of ID:PlanHash:Version against host operator key
#   5. SHA-256 Plan Hash Integrity: Prefix match against CLI arg AND full 64-hex match against signed hash
#   6. Mandatory Review Binding: Reviewer verdict APPROVED and exact 64-hex review-to-plan binding
#   7. Dynamic Sandbox Containment: Strict boundary enforcement (rejects traversal '..' and symlink escapes)
#   8. Atomic Apply & Verification: Health check execution with automatic rollback on failure

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

# ─── Check 1 (EARLY): Parse and Validate Arguments BEFORE touching disk ────────
if [[ $# -lt 3 ]]; then
  echo "GATE REFUSED: Usage: $0 <change-id> <plan-hash-prefix> <target-version> [target-file]" >&2
  exit 1
fi

CHANGE_ID="$1"
PLAN_HASH_PREFIX="$2"
TARGET_VERSION="$3"
GIVEN_TARGET_FILE="${4:-}"

# Fail immediately without creating any files if arguments are malformed
if [[ ! "$CHANGE_ID" =~ ^CHG-[0-9]{8}-[0-9]{3,}$ ]]; then
  echo "GATE REFUSED: INVALID CHANGE ID: '$CHANGE_ID'. Must match CHG-YYYYMMDD-NNN" >&2
  exit 1
fi

if [[ ! "$PLAN_HASH_PREFIX" =~ ^[0-9a-f]{8,64}$ ]]; then
  echo "GATE REFUSED: INVALID HASH PREFIX: '$PLAN_HASH_PREFIX'. Must be 8 to 64 hex characters" >&2
  exit 1
fi

if [[ ! "$TARGET_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "GATE REFUSED: INVALID TARGET VERSION: '$TARGET_VERSION'. Must follow SemVer (e.g. v2.0.0)" >&2
  exit 1
fi

# ─── Paths ────────────────────────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIR="$REPO_ROOT/evidence/$CHANGE_ID"
PLAN_FILE="$EVIDENCE_DIR/plan.md"
REVIEW_FILE="$EVIDENCE_DIR/review.md"
APPROVAL_FILE="$EVIDENCE_DIR/approval.txt"
EXEC_LOG="$EVIDENCE_DIR/execution.log"
APPLIED_LEDGER="$REPO_ROOT/evidence/.applied_ledger"
SANDBOX_DIR="$REPO_ROOT/sandbox"
CHECK_SCRIPT="$SANDBOX_DIR/check.sh"
APP_FILE="${GIVEN_TARGET_FILE:-$SANDBOX_DIR/app.txt}"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ─── Log helpers (strip ANSI escape codes when writing to execution.log) ───────
log() {
  echo -e "$1"
  echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$EXEC_LOG"
}

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
log "${BLUE}apply_change.sh — Deterministic Policy Gate (8 Invariants)${NC}"
log "Change ID:        $CHANGE_ID"
log "Hash prefix:      $PLAN_HASH_PREFIX"
log "Target version:   $TARGET_VERSION"
log "Target file:      $APP_FILE"
log "Timestamp:        $TIMESTAMP"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log ""
log "${YELLOW}[1/8] Validating argument schemas...${NC}"
log "${GREEN}  ✓ Change ID format valid ($CHANGE_ID)${NC}"
log "${GREEN}  ✓ Hash prefix format valid ($PLAN_HASH_PREFIX)${NC}"
log "${GREEN}  ✓ Target version format valid ($TARGET_VERSION)${NC}"

# ─── Check 2: Atomic Replay Prevention ────────────────────────────────────────
log ""
log "${YELLOW}[2/8] Checking replay protection ledger...${NC}"
LEDGER_LOCK="$APPLIED_LEDGER.lock"
touch "$LEDGER_LOCK"

REPLAY_FOUND=false
if command -v flock >/dev/null 2>&1; then
  (
    flock -s 200
    if grep -q "^${CHANGE_ID}:" "$APPLIED_LEDGER" 2>/dev/null; then
      exit 42
    fi
  ) 200<"$LEDGER_LOCK" || {
    if [[ $? -eq 42 ]]; then REPLAY_FOUND=true; fi
  }
else
  if grep -q "^${CHANGE_ID}:" "$APPLIED_LEDGER" 2>/dev/null; then
    REPLAY_FOUND=true
  fi
fi

if [[ "$REPLAY_FOUND" == "true" ]]; then
  fail "REPLAY DETECTED — change '$CHANGE_ID' has already been applied. Replaying approvals is prohibited."
fi
log "${GREEN}  ✓ No prior execution detected in ledger${NC}"

# ─── Check 3: Human Approval Record ───────────────────────────────────────────
log ""
log "${YELLOW}[3/8] Checking human approval file...${NC}"
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

# ─── Check 4: Fail-Closed Cryptographic HMAC Signature Verification ───────────
log ""
log "${YELLOW}[4/8] Verifying cryptographic human operator signature...${NC}"
KEY_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/change-desk/operator.key"
if [[ ! -f "$KEY_FILE" ]]; then
  fail "FAIL-CLOSED: Operator key missing at $KEY_FILE. Human signing required."
fi

SIG=$(sed -n 's/^hmac_sig: //p' "$APPROVAL_FILE" | tr -d '\r[:space:]')
SIGNED_HASH=$(sed -n 's/^plan_hash: //p' "$APPROVAL_FILE" | tr -d '\r[:space:]')
SIGNED_VERSION=$(sed -n 's/^target_version: //p' "$APPROVAL_FILE" | tr -d '\r[:space:]')

if [[ -z "$SIG" || -z "$SIGNED_HASH" || -z "$SIGNED_VERSION" ]]; then
  fail "FAIL-CLOSED: Approval is unsigned or missing plan_hash / target_version fields"
fi

OPERATOR_SECRET=$(cat "$KEY_FILE")
EXPECTED_SIG=$(printf '%s' "${CHANGE_ID}:${SIGNED_HASH}:${SIGNED_VERSION}" \
  | openssl dgst -sha256 -hmac "$OPERATOR_SECRET" 2>/dev/null | awk '{print $NF}')

if [[ "$SIG" != "$EXPECTED_SIG" ]]; then
  fail "INVALID OPERATOR SIGNATURE: approval was not signed by a valid operator key"
fi

if [[ "$SIGNED_VERSION" != "$TARGET_VERSION" ]]; then
  fail "VERSION MISMATCH: signed version '$SIGNED_VERSION' does not match target version '$TARGET_VERSION'"
fi
log "${GREEN}  ✓ Human operator HMAC signature verified (ID + Plan Hash + Version)${NC}"

# ─── Check 5: Plan Hash Verification (Prefix + Full 64-hex match) ─────────────
log ""
log "${YELLOW}[5/8] Verifying plan hash integrity...${NC}"
if [[ ! -f "$PLAN_FILE" ]]; then
  fail "Plan file not found: $PLAN_FILE"
fi

ACTUAL_HASH=$(sha256 "$PLAN_FILE")
ACTUAL_PREFIX="${ACTUAL_HASH:0:${#PLAN_HASH_PREFIX}}"
log "Actual SHA-256:   $ACTUAL_HASH"
log "Approved prefix:  $PLAN_HASH_PREFIX"
log "Actual prefix:    $ACTUAL_PREFIX"
log "Signed full hash: $SIGNED_HASH"

if [[ "$ACTUAL_PREFIX" != "$PLAN_HASH_PREFIX" ]]; then
  fail "HASH MISMATCH — plan prefix modified after approval.
  Approved: $PLAN_HASH_PREFIX
  Actual:   $ACTUAL_PREFIX"
fi

if [[ "$ACTUAL_HASH" != "$SIGNED_HASH" ]]; then
  fail "PLAN TAMPERING DETECTED — full plan SHA-256 differs from signed approval.
  Signed: $SIGNED_HASH
  Actual: $ACTUAL_HASH"
fi
log "${GREEN}  ✓ Plan hash strictly matches approval (prefix and full 64-hex)${NC}"

# ─── Check 6: Reviewer Verdict & Mandatory 64-Hex Plan Hash Binding ───────────
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

REVIEW_PLAN_HASH=$(grep -i '^## Plan Hash' "$REVIEW_FILE" -A 1 | tail -1 | tr -d '[:space:]' || true)
if [[ -z "$REVIEW_PLAN_HASH" ]]; then
  fail "REVIEW BINDING MISSING: review.md is missing required '## Plan Hash' section"
fi

if [[ ! "$REVIEW_PLAN_HASH" =~ ^[0-9a-f]{64}$ ]]; then
  fail "INVALID REVIEW HASH: plan hash in review.md must be full 64 hex characters (found: '$REVIEW_PLAN_HASH')"
fi

if [[ "$REVIEW_PLAN_HASH" != "$ACTUAL_HASH" ]]; then
  fail "REVIEW-TO-PLAN MISMATCH — review was conducted on a different version of plan.md.
  Review hash: $REVIEW_PLAN_HASH
  Actual hash: $ACTUAL_HASH"
fi
log "${GREEN}  ✓ Review cryptographically bound to current plan.md (64-hex match)${NC}"
log "${GREEN}  ✓ Reviewer verdict: APPROVED${NC}"

# ─── Check 7: Dynamic Target Path Safety, Path Traversal & Symlinks ───────────
log ""
log "${YELLOW}[7/8] Validating target path and containment...${NC}"
if [[ "$APP_FILE" == *".."* ]]; then
  fail "PATH TRAVERSAL DETECTED: target path contains '..' escape sequence: $APP_FILE"
fi

REAL_APP_FILE=$(realpath -m "$APP_FILE" 2>/dev/null || echo "$APP_FILE")
REAL_SANDBOX=$(realpath "$SANDBOX_DIR" 2>/dev/null || echo "$SANDBOX_DIR")

if [[ "$REAL_APP_FILE" != "$REAL_SANDBOX"/* && "$REAL_APP_FILE" != "$REAL_SANDBOX" ]]; then
  fail "INVALID TARGET PATH — target escapes sandbox/: $REAL_APP_FILE"
fi

# Reject if target path is an existing symlink pointing outside sandbox
if [[ -L "$APP_FILE" ]]; then
  SYMLINK_TARGET=$(readlink -f "$APP_FILE")
  if [[ "$SYMLINK_TARGET" != "$REAL_SANDBOX"/* ]]; then
    fail "SYMLINK ESCAPE DETECTED — symlink points outside sandbox: $SYMLINK_TARGET"
  fi
fi
log "${GREEN}  ✓ Target path is strictly contained inside sandbox/ ($REAL_APP_FILE)${NC}"

# ─── Check 8: Apply Change & Health Check with Atomic Auto-Rollback ───────────
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

# Apply the version change using portable sed (Linux + macOS)
OLD_VERSION=$(grep '^version:' "$APP_FILE" | awk '{print $2}')
sed "s/^version:.*/version: $TARGET_VERSION/" "$APP_FILE" > "$APP_FILE.tmp" && mv "$APP_FILE.tmp" "$APP_FILE"
sed "s/^last_updated:.*/last_updated: $(date +%Y-%m-%d)/" "$APP_FILE" > "$APP_FILE.tmp" && mv "$APP_FILE.tmp" "$APP_FILE"
log "Version changed: $OLD_VERSION → $TARGET_VERSION"

# Run health check
log ""
log "${YELLOW}Running health check...${NC}"
log ""

if bash "$CHECK_SCRIPT" 2>&1 | tee -a "$EXEC_LOG"; then
  # Record in replay ledger upon successful completion with atomic flock
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 200
      echo "${CHANGE_ID}:${TIMESTAMP}:${ACTUAL_HASH}:${TARGET_VERSION}" >> "$APPLIED_LEDGER"
    ) 200<"$LEDGER_LOCK"
  else
    echo "${CHANGE_ID}:${TIMESTAMP}:${ACTUAL_HASH}:${TARGET_VERSION}" >> "$APPLIED_LEDGER"
  fi

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
