#!/usr/bin/env bash
# tools/hash_plan.sh — Deterministic plan hashing helper for agents
#
# Usage:
#   ./tools/hash_plan.sh <change-id> [--prefix]
#
# Computes the exact SHA-256 digest of evidence/<change-id>/plan.md.
# Used by Planner and Reviewer agents to prevent manual hash typos and hallucination.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <change-id> [--prefix]" >&2
  exit 1
fi

CHANGE_ID="$1"
PLAN_FILE="$REPO_ROOT/evidence/$CHANGE_ID/plan.md"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "ERROR: Plan file not found: $PLAN_FILE" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  FULL_HASH=$(sha256sum "$PLAN_FILE" | awk '{print $1}')
else
  FULL_HASH=$(shasum -a 256 "$PLAN_FILE" | awk '{print $1}')
fi

if [[ "${2:-}" == "--prefix" ]]; then
  echo "${FULL_HASH:0:8}"
else
  echo "$FULL_HASH"
fi
