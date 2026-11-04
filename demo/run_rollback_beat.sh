#!/usr/bin/env bash
# run_rollback_beat.sh — Demo: automatic rollback on health check failure
# Simulates a change where the resulting app state fails check.sh,
# demonstrating the deterministic gate's automatic backup restoration.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGE_ID="CHG-20261104-003"
FIXTURE_DIR="$REPO_ROOT/demo/fixtures/CHG-20261104-001"
EVIDENCE_DIR="$REPO_ROOT/evidence/$CHANGE_ID"
SANDBOX_DIR="$REPO_ROOT/sandbox"
CHECK_SCRIPT="$SANDBOX_DIR/check.sh"

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
echo -e "${BLUE}  Demo: Automatic Rollback Beat — $CHANGE_ID${NC}"
echo -e "${BLUE}  (Health check failure after apply → gate automatically reverts)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "Step 1: Resetting to clean state..."
bash "$REPO_ROOT/demo/reset.sh"
echo ""

echo "Step 2: Copying fixtures and setting up approved change..."
mkdir -p "$EVIDENCE_DIR"
cp "$FIXTURE_DIR/plan.md"   "$EVIDENCE_DIR/plan.md"
cp "$FIXTURE_DIR/review.md" "$EVIDENCE_DIR/review.md"
sed -i "s/CHG-20261104-001/$CHANGE_ID/g" "$EVIDENCE_DIR/review.md"

HASH=$(sha256 "$EVIDENCE_DIR/plan.md")
PREFIX="${HASH:0:8}"
echo "APPROVED $CHANGE_ID $PREFIX" > "$EVIDENCE_DIR/approval.txt"
echo "  Approval: APPROVED $CHANGE_ID $PREFIX"
echo ""

echo "Step 3: Simulating downstream health failure in check.sh..."
CHECK_BAK="$CHECK_SCRIPT.demo_bak"
cp "$CHECK_SCRIPT" "$CHECK_BAK"

cat > "$CHECK_SCRIPT" << 'FAILEOF'
#!/usr/bin/env bash
echo "=== Sandbox Health Check ==="
echo "ERROR: Application runtime crashed! Exit code: 1"
exit 1
FAILEOF
chmod +x "$CHECK_SCRIPT"
echo "  check.sh temporarily configured to fail runtime verification"
echo ""

echo "Step 4: Running policy gate (expecting apply followed by auto-rollback)..."
echo ""
GATE_EXIT=0
"$REPO_ROOT/tools/apply_change.sh" "$CHANGE_ID" "$PREFIX" v2.0.0 || GATE_EXIT=$?
echo ""

# Restore original check.sh
mv "$CHECK_BAK" "$CHECK_SCRIPT"

CURRENT_VERSION=$(grep '^version:' "$SANDBOX_DIR/app.txt" | awk '{print $2}')
if [[ "$GATE_EXIT" == "1" ]] && [[ "$CURRENT_VERSION" == "v1.0.0" ]]; then
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  DEMO PASS — Automatic rollback verified!${NC}"
  echo -e "${GREEN}  Sandbox restored to baseline: $CURRENT_VERSION${NC}"
  echo -e "${GREEN}  Evidence backup preserved in evidence/$CHANGE_ID/app.txt.backup${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  exit 0
else
  echo -e "${RED}  DEMO FAIL — Gate returned exit $GATE_EXIT, version is $CURRENT_VERSION${NC}"
  exit 1
fi
