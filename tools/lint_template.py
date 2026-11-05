#!/usr/bin/env python3
"""tools/lint_template.py
Validates switch-change-desk.template.yaml using Switch Console's internal template linter.
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Inject Switch core and site-packages from local-server
SWITCH_PYTHON_ROOT = Path.home() / ".local/opt/switch-console/opt/Switch Console/resources/local-server"
if not SWITCH_PYTHON_ROOT.exists():
    print(f"Warning: {SWITCH_PYTHON_ROOT} not found. Trying system python...")
else:
    sys.path.insert(0, str(SWITCH_PYTHON_ROOT / "switch/site-packages"))
    sys.path.insert(0, str(SWITCH_PYTHON_ROOT / "switch/src/core"))

try:
    from switch_core.template_lint import lint_template
except ImportError as e:
    print(f"Error importing switch_core: {e}")
    sys.exit(1)

template_path = REPO_ROOT / "switch-change-desk.template.yaml"
if not template_path.exists():
    print(f"Template not found: {template_path}")
    sys.exit(1)

text = template_path.read_text(encoding="utf-8")
res = lint_template(text)

print(f"Template: {template_path.name}")
print(f"Status:   {'VALID (0 errors)' if res.ok else 'INVALID'}")
print(f"Blocked:  {res.blocked}")

if res.errors:
    print(f"\nErrors ({len(res.errors)}):")
    for err in res.errors:
        print(f"  [ERROR] {err.subject}: {err.message}")

if res.warnings:
    print(f"\nWarnings ({len(res.warnings)}):")
    for warn in res.warnings:
        print(f"  [WARN]  {warn.subject}: {warn.message}")

if not res.ok or res.errors:
    sys.exit(1)

print("\n✓ Template lint passed with 0 errors!")
sys.exit(0)
