#!/usr/bin/env bash
# run_tamper_beat.sh — Demo: tamper beat
# Copies fixture, approves with original hash, edits plan.md, then
# runs gate with original hash → expects HASH MISMATCH (exit 1).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGE_ID="CHG-DEMO-002"
FIXTURE_DIR="$REPO_ROOT/demo/fixtures/CHG-DEMO-001"
EVIDENCE_DIR="$REPO_ROOT/evidence/$CHANGE_ID"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Demo: Tamper Beat — $CHANGE_ID${NC}"
echo -e "${BLUE}  (Plan edited after approval → gate must refuse)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Step 1: Resetting to clean state..."
bash "$REPO_ROOT/demo/reset.sh"
echo ""

echo "Step 2: Copying fixtures..."
mkdir -p "$EVIDENCE_DIR"
cp "$FIXTURE_DIR/plan.md"   "$EVIDENCE_DIR/plan.md"
# Write a correct review for this change ID
cat > "$EVIDENCE_DIR/review.md" << EOF
# Review: $CHANGE_ID

## Verdict
APPROVED

## Risks Identified
- None identified

## Conditions
- None

## Reviewer Note
Plan is clear, scoped to sandbox/ only, and fully reversible.
EOF

PRE_TAMPER_HASH=$(sha256sum "$EVIDENCE_DIR/plan.md" | awk '{print $1}')
PRE_TAMPER_PREFIX="${PRE_TAMPER_HASH:0:8}"
echo "  Pre-tamper SHA-256: $PRE_TAMPER_HASH"
echo "  Pre-tamper prefix:  $PRE_TAMPER_PREFIX"
echo ""

echo "Step 3: Writing approval with pre-tamper hash..."
echo "APPROVED $CHANGE_ID $PRE_TAMPER_PREFIX" > "$EVIDENCE_DIR/approval.txt"
echo "  Approval: APPROVED $CHANGE_ID $PRE_TAMPER_PREFIX"
echo ""

echo -e "${YELLOW}Step 4: TAMPERING — appending blank line to plan.md after approval...${NC}"
echo "" >> "$EVIDENCE_DIR/plan.md"
POST_TAMPER_HASH=$(sha256sum "$EVIDENCE_DIR/plan.md" | awk '{print $1}')
echo "  Post-tamper SHA-256: $POST_TAMPER_HASH"
echo "  Prefix now: ${POST_TAMPER_HASH:0:8} (was: $PRE_TAMPER_PREFIX)"
echo ""

echo "Step 5: Running gate with ORIGINAL hash (expect HASH MISMATCH)..."
echo ""
GATE_EXIT=0
"$REPO_ROOT/tools/apply_change.sh" "$CHANGE_ID" "$PRE_TAMPER_PREFIX" v2.0.0 || GATE_EXIT=$?
echo ""

if [[ "$GATE_EXIT" != "0" ]]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  DEMO PASS — Gate correctly refused the tampered plan (exit $GATE_EXIT)${NC}"
  echo -e "${GREEN}  sandbox/app.txt unchanged: $(grep '^version' "$REPO_ROOT/sandbox/app.txt")${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 0
else
  echo -e "${RED}  DEMO FAIL — Gate returned exit 0 on tampered plan (expected 1)${NC}"
  echo -e "${RED}  Hash check is broken!${NC}"
  exit 1
fi
