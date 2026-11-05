#!/usr/bin/env bash
# tools/approve.sh — Human Approval CLI for change-desk
#
# Inspects plan.md and review.md, confirms review validity,
# computes SHA-256 hash, and cryptographically signs approval.txt.
#
# Usage:
#   ./tools/approve.sh <change-id> [--yes]

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

# ─── Portable SHA-256 Helper (Linux + macOS) ──────────────────────────────────
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# ─── Args ─────────────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo -e "${RED}Usage: $0 <change-id> [--yes]${NC}"
  echo "Example: $0 CHG-20261104-001"
  exit 1
fi

CHANGE_ID="$1"
AUTO_CONFIRM=false
if [[ "${2:-}" == "--yes" || "${2:-}" == "-y" ]]; then
  AUTO_CONFIRM=true
fi

# Validate change ID format: CHG-YYYYMMDD-NNN
if [[ ! "$CHANGE_ID" =~ ^CHG-[0-9]{8}-[0-9]{3,}$ ]]; then
  echo -e "${RED}ERROR: Invalid Change ID format: '$CHANGE_ID'${NC}"
  echo "Expected format: CHG-YYYYMMDD-NNN (e.g., CHG-20261104-001)"
  exit 1
fi

EVIDENCE_DIR="$REPO_ROOT/evidence/$CHANGE_ID"
PLAN_FILE="$EVIDENCE_DIR/plan.md"
REVIEW_FILE="$EVIDENCE_DIR/review.md"
APPROVAL_FILE="$EVIDENCE_DIR/approval.txt"

# ─── File Existence Checks ────────────────────────────────────────────────────
if [[ ! -f "$PLAN_FILE" ]]; then
  echo -e "${RED}ERROR: Plan file not found: $PLAN_FILE${NC}"
  echo "The Planner agent must produce plan.md before approval."
  exit 1
fi

if [[ ! -f "$REVIEW_FILE" ]]; then
  echo -e "${RED}ERROR: Review file not found: $REVIEW_FILE${NC}"
  echo "The Risk Reviewer must produce review.md before approval."
  exit 1
fi

# ─── Verify Review Verdict ────────────────────────────────────────────────────
VERDICT=$(grep -i '^## Verdict' "$REVIEW_FILE" -A 1 | tail -1 | tr -d '[:space:]' || true)
if [[ "$VERDICT" != "APPROVED" ]]; then
  echo -e "${RED}ERROR: Reviewer verdict is not APPROVED (found: '$VERDICT')${NC}"
  echo "Review details:"
  cat "$REVIEW_FILE"
  exit 1
fi

# ─── Plan Hash & Review-to-Plan Binding Check ─────────────────────────────────
PLAN_HASH=$(sha256 "$PLAN_FILE")
PLAN_PREFIX="${PLAN_HASH:0:8}"

REVIEW_PLAN_HASH=$(grep -i '^## Plan Hash' "$REVIEW_FILE" -A 1 | tail -1 | tr -d '[:space:]' || true)
if [[ -n "$REVIEW_PLAN_HASH" && "$REVIEW_PLAN_HASH" != "$PLAN_HASH" && "$REVIEW_PLAN_HASH" != "${PLAN_HASH:0:${#REVIEW_PLAN_HASH}}" ]]; then
  echo -e "${RED}ERROR: Plan has changed since reviewer inspected it!${NC}"
  echo "  Review recorded plan hash: $REVIEW_PLAN_HASH"
  echo "  Actual current plan hash:  $PLAN_HASH"
  exit 1
fi

# ─── Operator Key Management (Stored outside repo against prompt-level forgery) ──
KEY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/change-desk"
KEY_FILE="$KEY_DIR/operator.key"
if [[ ! -f "$KEY_FILE" ]]; then
  mkdir -p "$KEY_DIR"
  chmod 700 "$KEY_DIR"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32 > "$KEY_FILE"
  else
    date +%s%N | sha256sum | awk '{print $1}' > "$KEY_FILE"
  fi
  chmod 600 "$KEY_FILE"
fi

OPERATOR_SECRET=$(cat "$KEY_FILE")

# Compute HMAC signature of Change ID + Plan Hash
SIGN_PAYLOAD="${CHANGE_ID}:${PLAN_HASH}"
if command -v openssl >/dev/null 2>&1; then
  HMAC_SIG=$(echo -n "$SIGN_PAYLOAD" | openssl dgst -sha256 -hmac "$OPERATOR_SECRET" | awk '{print $NF}')
else
  HMAC_SIG=$(echo -n "${SIGN_PAYLOAD}:${OPERATOR_SECRET}" | sha256sum | awk '{print $1}')
fi

# ─── Display Plan & Review Summary to Human ───────────────────────────────────
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Human Approval Desk — $CHANGE_ID${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Plan File:      ${PLAN_FILE}"
echo -e "Plan SHA-256:   ${CYAN}${PLAN_HASH}${NC}"
echo -e "Fingerprint:    ${YELLOW}${BOLD}${PLAN_PREFIX}${NC}"
echo -e "Review Verdict: ${GREEN}${BOLD}APPROVED${NC}"
if [[ -n "$REVIEW_PLAN_HASH" ]]; then
  echo -e "Review Bound:   ${GREEN}✓ Plan hash verified by reviewer${NC}"
fi
echo -e "${BLUE}────────────────────────────────────────────────────────────────${NC}"
echo -e "${BOLD}Plan Summary:${NC}"
grep -E '^(## Objective|## Steps|## Rollback|## Risk Rating)' -A 2 "$PLAN_FILE" | head -n 12 || cat "$PLAN_FILE"
echo -e "${BLUE}────────────────────────────────────────────────────────────────${NC}"

# ─── Human Confirmation ───────────────────────────────────────────────────────
if [[ "$AUTO_CONFIRM" != "true" ]]; then
  read -r -p "Approve this change and sign execution token? [y/N]: " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Approval cancelled by human operator.${NC}"
    exit 1
  fi
fi

# ─── Write Signed Approval Record ─────────────────────────────────────────────
mkdir -p "$EVIDENCE_DIR"
cat > "$APPROVAL_FILE" << EOF
APPROVED $CHANGE_ID $PLAN_PREFIX
plan_hash: $PLAN_HASH
approved_by: human-operator
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
hmac_sig: $HMAC_SIG
EOF

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ APPROVAL SIGNED: $APPROVAL_FILE${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Post this exact line to your Switch room:"
echo ""
echo -e "  ${YELLOW}${BOLD}APPROVED $CHANGE_ID $PLAN_PREFIX${NC}"
echo ""
