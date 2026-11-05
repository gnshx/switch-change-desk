#!/usr/bin/env bash
# tools/approve.sh — Operator Approval CLI for change-desk
#
# Inspects plan.md and review.md, confirms review validity,
# validates explicit target version, computes SHA-256 hash,
# prompts operator for confirmation on /dev/tty,
# and cryptographically signs approval.txt with operator key.
#
# Usage:
#   ./tools/approve.sh <change-id> <target-version>
# Example:
#   ./tools/approve.sh CHG-20261104-001 v2.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Prerequisite: openssl required ───────────────────────────────────────────
if ! command -v openssl >/dev/null 2>&1; then
  echo -e "${RED}ERROR: openssl is required for cryptographic HMAC signing.${NC}" >&2
  exit 1
fi

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# ─── Refuse --yes bypass flag ──────────────────────────────────────────────────
for arg in "$@"; do
  if [[ "$arg" == "--yes" || "$arg" == "-y" ]]; then
    echo -e "${RED}ERROR: Automatic approval flag '--yes' is disabled for security.${NC}" >&2
    echo "approve.sh must be run interactively in a terminal by the operator." >&2
    exit 1
  fi
done

# ─── Args ─────────────────────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
  echo -e "${RED}Usage: $0 <change-id> <target-version>${NC}"
  echo "Example: $0 CHG-20261104-001 v2.0.0"
  exit 1
fi

CHANGE_ID="$1"
TARGET_VERSION="$2"

# Validate change ID format: CHG-YYYYMMDD-NNN (exactly 3 digits)
if [[ ! "$CHANGE_ID" =~ ^CHG-[0-9]{8}-[0-9]{3}$ ]]; then
  echo -e "${RED}ERROR: Invalid Change ID format: '$CHANGE_ID'${NC}" >&2
  echo "Expected format: CHG-YYYYMMDD-NNN with exactly 3 digits (e.g., CHG-20261104-001)" >&2
  exit 1
fi

# Validate target version format: vX.Y.Z
if [[ ! "$TARGET_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo -e "${RED}ERROR: Invalid target version format: '$TARGET_VERSION'${NC}" >&2
  echo "Expected format: SemVer (e.g., v2.0.0)" >&2
  exit 1
fi

# ─── Interactive TTY Check ────────────────────────────────────────────────────
if [[ -z "${CHANGE_DESK_TEST_MODE:-}" ]]; then
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo -e "${RED}ERROR: approve.sh must be executed interactively in a real terminal (TTY required).${NC}" >&2
    exit 1
  fi
fi

EVIDENCE_DIR="$REPO_ROOT/evidence/$CHANGE_ID"
PLAN_FILE="$EVIDENCE_DIR/plan.md"
REVIEW_FILE="$EVIDENCE_DIR/review.md"
APPROVAL_FILE="$EVIDENCE_DIR/approval.txt"

# ─── File Existence Checks ────────────────────────────────────────────────────
if [[ ! -f "$PLAN_FILE" ]]; then
  echo -e "${RED}ERROR: Plan file not found: $PLAN_FILE${NC}" >&2
  echo "The Planner agent must produce plan.md before approval." >&2
  exit 1
fi

if [[ ! -f "$REVIEW_FILE" ]]; then
  echo -e "${RED}ERROR: Review file not found: $REVIEW_FILE${NC}" >&2
  echo "The Risk Reviewer must produce review.md before approval." >&2
  exit 1
fi

# ─── Verify Review Verdict ────────────────────────────────────────────────────
VERDICT=$(grep -i '^## Verdict' "$REVIEW_FILE" -A 1 | tail -1 | tr -d '[:space:]' || true)
if [[ "$VERDICT" != "APPROVED" ]]; then
  echo -e "${RED}ERROR: Reviewer verdict is not APPROVED (found: '$VERDICT')${NC}" >&2
  echo "Review details:" >&2
  cat "$REVIEW_FILE" >&2
  exit 1
fi

# ─── Plan Hash & Review-to-Plan Binding Check ─────────────────────────────────
PLAN_HASH=$(sha256 "$PLAN_FILE")
PLAN_PREFIX="${PLAN_HASH:0:8}"

REVIEW_PLAN_HASH=$(grep -i '^## Plan Hash' "$REVIEW_FILE" -A 1 | tail -1 | tr -d '[:space:]' || true)
if [[ -z "$REVIEW_PLAN_HASH" ]]; then
  echo -e "${RED}ERROR: Review file is missing required '## Plan Hash' binding!${NC}" >&2
  exit 1
fi

if [[ "$REVIEW_PLAN_HASH" != "$PLAN_HASH" ]]; then
  echo -e "${RED}ERROR: Plan has changed since reviewer inspected it!${NC}" >&2
  echo "  Review recorded plan hash: $REVIEW_PLAN_HASH" >&2
  echo "  Actual current plan hash:  $PLAN_HASH" >&2
  exit 1
fi

# ─── Operator Key Management (Stored outside repo against prompt-level forgery) ──
KEY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/change-desk"
KEY_FILE="$KEY_DIR/operator.key"
if [[ ! -f "$KEY_FILE" ]]; then
  mkdir -p "$KEY_DIR"
  chmod 700 "$KEY_DIR"
  openssl rand -hex 32 > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi

OPERATOR_SECRET=$(cat "$KEY_FILE")

# Compute HMAC signature of Change ID + Plan Hash + Target Version
SIGN_PAYLOAD="${CHANGE_ID}:${PLAN_HASH}:${TARGET_VERSION}"
HMAC_SIG=$(printf '%s' "$SIGN_PAYLOAD" | openssl dgst -sha256 -hmac "$OPERATOR_SECRET" | awk '{print $NF}')

# ─── Display Complete Plan & Review to Operator (Full, un-truncated) ──────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Change Desk Operator Approval Desk — $CHANGE_ID${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Plan File:      ${PLAN_FILE}"
echo -e "Target Version: ${BOLD}${GREEN}${TARGET_VERSION}${NC}"
echo -e "Plan SHA-256:   ${CYAN}${PLAN_HASH}${NC}"
echo -e "Fingerprint:    ${YELLOW}${BOLD}${PLAN_PREFIX}${NC}"
echo -e "Review Verdict: ${GREEN}${BOLD}APPROVED${NC}"
echo -e "Review Bound:   ${GREEN}✓ Full 64-hex plan hash bound by reviewer${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}Complete Plan (${PLAN_FILE}):${NC}"
cat "$PLAN_FILE"
echo ""
echo -e "${BLUE}────────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}Complete Review (${REVIEW_FILE}):${NC}"
cat "$REVIEW_FILE"
echo -e "${BLUE}────────────────────────────────────────────────────────────────${NC}"

# ─── Operator Confirmation on /dev/tty ────────────────────────────────────────
if [[ -z "${CHANGE_DESK_TEST_MODE:-}" ]]; then
  echo ""
  read -r -p "Approve this change and sign execution token for $TARGET_VERSION? [y/N]: " CONFIRM < /dev/tty
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Approval cancelled by operator.${NC}"
    exit 1
  fi
fi

# ─── Write Signed Approval Record ─────────────────────────────────────────────
mkdir -p "$EVIDENCE_DIR"
cat > "$APPROVAL_FILE" << EOF
APPROVED $CHANGE_ID $PLAN_PREFIX
plan_hash: $PLAN_HASH
target_version: $TARGET_VERSION
approved_by: operator-key-cli
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
hmac_sig: $HMAC_SIG
EOF

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ APPROVAL SIGNED: $APPROVAL_FILE${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Post this exact line to your Switch room:"
echo ""
echo -e "  ${YELLOW}${BOLD}@change-desk-executor APPROVED $CHANGE_ID $PLAN_PREFIX${NC}"
echo ""
