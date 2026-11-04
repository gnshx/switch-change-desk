#!/usr/bin/env bash
# check.sh — Sandbox app health check
# Reads sandbox/app.txt, validates version format, exits 0 if healthy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_FILE="$SCRIPT_DIR/app.txt"

echo "=== Sandbox Health Check ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

if [[ ! -f "$APP_FILE" ]]; then
  echo "ERROR: $APP_FILE not found."
  exit 1
fi

echo "Reading: $APP_FILE"
cat "$APP_FILE"
echo ""

VERSION=$(grep '^version:' "$APP_FILE" | awk '{print $2}' || true)
if [[ -z "$VERSION" ]]; then
  echo "FAIL: No version field found in app.txt"
  exit 1
fi

# Validate version format: vX.Y.Z
if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "FAIL: Version '$VERSION' does not match vX.Y.Z format"
  exit 1
fi

echo "Version:  $VERSION  ✓"
echo "Format:   valid  ✓"
echo ""
echo "=== HEALTH CHECK PASSED ==="
exit 0
