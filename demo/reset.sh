#!/usr/bin/env bash
# reset.sh — Reset sandbox to v1.0.0 and clear evidence for a clean demo run.
# Run before every demo rehearsal and before recording.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== change-desk demo reset ==="
echo ""

# Reset sandbox/app.txt
echo "Resetting sandbox/app.txt to v1.0.0..."
cat > "$REPO_ROOT/sandbox/app.txt" << 'EOF'
version: v1.0.0
name: change-desk-sandbox
status: running
last_updated: 2026-11-04
EOF
echo "  ✓ sandbox/app.txt → v1.0.0"

# Clear evidence (keep .gitkeep)
echo "Clearing evidence/..."
find "$REPO_ROOT/evidence" -mindepth 1 -not -name '.gitkeep' -exec rm -rf {} + 2>/dev/null || true
touch "$REPO_ROOT/evidence/.gitkeep"
echo "  ✓ evidence/ cleared"

echo ""
echo "=== Reset complete. Ready for demo. ==="
bash "$REPO_ROOT/sandbox/check.sh"
