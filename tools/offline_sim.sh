#!/usr/bin/env bash
# tools/offline_sim.sh — Offline Gate & Protocol Simulation Harness
#
# NOTE ON SWITCH:
# In normal production use, this workflow runs inside a Switch room ("change-desk")
# with live Planner, Reviewer, and Executor agents.
# This offline script simulates the room interactions locally so developers and judges
# can test the deterministic policy gate and safety modes offline without Switch running.
#
# Usage:
#   ./tools/offline_sim.sh [--happy | --tamper | --reject | --rollback]

set -euo pipefail
export CHANGE_DESK_TEST_MODE=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RESET_SCRIPT="$REPO_ROOT/demo/reset.sh"
GATE_SCRIPT="$REPO_ROOT/tools/apply_change.sh"
CHECK_SCRIPT="$REPO_ROOT/sandbox/check.sh"
APP_FILE="$REPO_ROOT/sandbox/app.txt"
APPROVE_TOOL="$REPO_ROOT/tools/approve.sh"

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

MODE="${1:---happy}"
TARGET_VERSION="v2.0.0"
CHANGE_ID="CHG-20261104-101"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  CHANGE DESK — OFFLINE GATE REGRESSION HARNESS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Simulating Switch room interaction offline for gate verification"
echo -e "  Target: ${YELLOW}${CHANGE_ID}${NC} | Mode: ${YELLOW}${MODE}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

bash "$RESET_SCRIPT" > /dev/null

EV_DIR="$REPO_ROOT/evidence/$CHANGE_ID"
mkdir -p "$EV_DIR"

echo -e "${CYAN}1. [Requester]${NC} Simulating request: Bump sandbox to ${TARGET_VERSION}"

# Step 2: Plan
cat > "$EV_DIR/plan.md" << EOF
# Plan: $CHANGE_ID

## Objective
Bump sandbox app from v1.0.0 to $TARGET_VERSION to test change-desk gate.

## Steps
1. Update version field in sandbox/app.txt to $TARGET_VERSION
2. Run sandbox/check.sh to verify

## Rollback
1. Restore sandbox/app.txt from evidence/$CHANGE_ID/app.txt.backup
2. Verify check.sh passes

## Risk Rating
LOW — sandbox version update only.
EOF

PLAN_HASH=$(sha256 "$EV_DIR/plan.md")
PLAN_PREFIX="${PLAN_HASH:0:8}"
echo -e "${GREEN}2. [Planner Agent]${NC} plan.md drafted (SHA-256: ${PLAN_PREFIX}...)"

# Step 3: Review
if [[ "$MODE" == "--reject" ]]; then
  cat > "$EV_DIR/review.md" << EOF
# Review: $CHANGE_ID
## Verdict
REJECTED
## Plan Hash
$PLAN_HASH
## Reviewer Note
Simulated safety policy veto.
EOF
  echo -e "${YELLOW}3. [Reviewer Agent]${NC} Reviewer issued REJECTED verdict"
  echo -e "${RED}Gate refusal expected: pipeline blocked before approval.${NC}"
  exit 0
fi

cat > "$EV_DIR/review.md" << EOF
# Review: $CHANGE_ID
## Verdict
APPROVED
## Plan Hash
$PLAN_HASH
## Risks Identified
- None
## Conditions
- None
## Reviewer Note
Plan verified against policy.
EOF
echo -e "${GREEN}3. [Reviewer Agent]${NC} Review completed (Verdict: APPROVED, Plan Hash bound)"

# Step 4: Human Approval
bash "$APPROVE_TOOL" "$CHANGE_ID" "$TARGET_VERSION" > /dev/null
echo -e "${BLUE}4. [Operator Approval]${NC} Signed approval with HMAC: ${BOLD}@change-desk-executor APPROVED $CHANGE_ID $PLAN_PREFIX${NC}"

# Tamper Injection
if [[ "$MODE" == "--tamper" ]]; then
  echo -e "${RED}⚡ Tampering: Modifying plan.md after human approval was granted...${NC}"
  printf '\n# Unauthorized post-approval edit\n' >> "$EV_DIR/plan.md"
fi

# Step 5: Gate Execution
echo -e "${CYAN}5. [Executor Agent]${NC} Addressing gate: apply_change.sh $CHANGE_ID $PLAN_PREFIX $TARGET_VERSION"
GATE_EXIT=0
bash "$GATE_SCRIPT" "$CHANGE_ID" "$PLAN_PREFIX" "$TARGET_VERSION" || GATE_EXIT=$?

echo ""
if [[ "$MODE" == "--tamper" ]]; then
  if [[ $GATE_EXIT -eq 1 ]]; then
    echo -e "${GREEN}✔ Tamper detection verified: Gate correctly refused tampered plan (exit 1).${NC}"
    exit 0
  else
    echo -e "${RED}✖ Failed: Tampered plan was not rejected!${NC}"
    exit 1
  fi
elif [[ $GATE_EXIT -eq 0 ]]; then
  echo -e "${GREEN}✔ Offline simulation completed successfully (version updated to $(grep '^version' "$APP_FILE" | awk '{print $2}')).${NC}"
  exit 0
else
  echo -e "${RED}✖ Gate exited with unexpected error: $GATE_EXIT${NC}"
  exit $GATE_EXIT
fi
