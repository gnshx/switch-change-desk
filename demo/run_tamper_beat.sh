#!/usr/bin/env bash
# run_tamper_beat.sh — Demo: tamper beat using pre-written fixtures
# Copies fixtures, writes approval, then tampers plan.md before running gate.
# Expects gate to REFUSE with exit 1 and "HASH MISMATCH".
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGE_ID="CHG-20261104-002"
FIXTURE_DIR="$REPO_ROOT/demo/fixtures/CHG-20261104-001"
EVIDENCE_DIR="$REPO_ROOT/evidence/$CHANGE_ID"

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

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
cp "$FIXTURE_DIR/review.md" "$EVIDENCE_DIR/review.md"
sed -i "s/CHG-20261104-001/$CHANGE_ID/g" "$EVIDENCE_DIR/review.md"

ORIGINAL_HASH=$(sha256 "$EVIDENCE_DIR/plan.md")
ORIGINAL_PREFIX="${ORIGINAL_HASH:0:8}"
echo "  Pre-tamper SHA-256: $ORIGINAL_HASH"
echo "  Pre-tamper prefix:  $ORIGINAL_PREFIX"
echo ""

echo "Step 3: Writing approval with pre-tamper hash..."
cat > "$EVIDENCE_DIR/approval.txt" << EOF
APPROVED $CHANGE_ID $ORIGINAL_PREFIX
plan_hash: $ORIGINAL_HASH
approved_by: human-operator
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
echo "  Approval: APPROVED $CHANGE_ID $ORIGINAL_PREFIX"
echo ""

echo "Step 4: TAMPERING — appending unauthorized line to plan.md after approval..."
printf '\n# Malicious modification injected post-approval\n' >> "$EVIDENCE_DIR/plan.md"
TAMPERED_HASH=$(sha256 "$EVIDENCE_DIR/plan.md")
TAMPERED_PREFIX="${TAMPERED_HASH:0:8}"
echo "  Post-tamper SHA-256: $TAMPERED_HASH"
echo "  Prefix now: $TAMPERED_PREFIX (was: $ORIGINAL_PREFIX)"
echo ""

echo "Step 5: Running gate with ORIGINAL hash (expect HASH MISMATCH)..."
echo ""
GATE_EXIT=0
"$REPO_ROOT/tools/apply_change.sh" "$CHANGE_ID" "$ORIGINAL_PREFIX" v2.0.0 || GATE_EXIT=$?
echo ""

if [[ "$GATE_EXIT" == "1" ]]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  DEMO PASS — Gate correctly refused the tampered plan (exit 1)${NC}"
  echo -e "${GREEN}  sandbox/app.txt unchanged: $(grep '^version' "$REPO_ROOT/sandbox/app.txt")${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 0
else
  echo -e "${RED}  DEMO FAIL — Gate returned exit $GATE_EXIT (expected 1)${NC}"
  exit 1
fi
