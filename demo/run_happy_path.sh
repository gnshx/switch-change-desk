#!/usr/bin/env bash
# run_happy_path.sh — Demo: happy path using pre-written fixtures
# Copies CHG-DEMO-001 fixtures, computes hash, runs gate. Expects exit 0.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGE_ID="CHG-DEMO-001"
FIXTURE_DIR="$REPO_ROOT/demo/fixtures/$CHANGE_ID"
EVIDENCE_DIR="$REPO_ROOT/evidence/$CHANGE_ID"

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Demo: Happy Path — $CHANGE_ID${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Step 1: Resetting to clean state..."
bash "$REPO_ROOT/demo/reset.sh"
echo ""

echo "Step 2: Copying pre-approved fixture plan and review..."
mkdir -p "$EVIDENCE_DIR"
cp "$FIXTURE_DIR/plan.md"   "$EVIDENCE_DIR/plan.md"
cp "$FIXTURE_DIR/review.md" "$EVIDENCE_DIR/review.md"
echo "  plan.md   copied"
echo "  review.md copied (verdict: $(grep -A1 '## Verdict' "$EVIDENCE_DIR/review.md" | tail -1 | xargs))"
echo ""

echo "Step 3: Computing plan hash and writing approval..."
HASH=$(sha256sum "$EVIDENCE_DIR/plan.md" | awk '{print $1}')
HASH_PREFIX="${HASH:0:8}"
echo "APPROVED $CHANGE_ID $HASH_PREFIX" > "$EVIDENCE_DIR/approval.txt"
echo "  SHA-256:  $HASH"
echo "  Approval: APPROVED $CHANGE_ID $HASH_PREFIX"
echo ""

echo "Step 4: Running policy gate..."
echo ""
GATE_EXIT=0
"$REPO_ROOT/tools/apply_change.sh" "$CHANGE_ID" "$HASH_PREFIX" v2.0.0 || GATE_EXIT=$?
echo ""

if [[ "$GATE_EXIT" == "0" ]]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  DEMO PASS — Happy path completed successfully${NC}"
  echo -e "${GREEN}  sandbox/app.txt: $(grep '^version' "$REPO_ROOT/sandbox/app.txt")${NC}"
  echo -e "${GREEN}  evidence/$CHANGE_ID/ populated${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 0
else
  echo -e "${RED}  DEMO FAIL — Gate returned exit $GATE_EXIT (expected 0)${NC}"
  exit 1
fi
