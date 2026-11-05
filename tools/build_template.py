#!/usr/bin/env python3
"""tools/build_template.py
Builds switch-change-desk.template.yaml from agents/*.md instructions.
Guarantees zero-drift between agent doc files and Switch template.
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

def indent(text: str, spaces: int = 6) -> str:
    prefix = " " * spaces
    lines = text.strip().splitlines()
    return "\n".join(prefix + line if line.strip() else "" for line in lines)

def build_template() -> str:
    planner_md = (REPO_ROOT / "agents" / "planner.md").read_text(encoding="utf-8")
    reviewer_md = (REPO_ROOT / "agents" / "reviewer.md").read_text(encoding="utf-8")
    executor_md = (REPO_ROOT / "agents" / "executor.md").read_text(encoding="utf-8")

    template = f"""agents:
  - name: "change-desk-planner"
    description: "Drafts scoped execution and rollback plans in evidence/<change-id>/plan.md"
    addressing: anyone
    provider: "{{provider}}"
    instructions: |
{indent(planner_md, 6)}

  - name: "change-desk-reviewer"
    description: "Critiques plans, binds review to plan hash, and issues APPROVED/REJECTED verdict"
    addressing: anyone
    provider: "{{provider}}"
    instructions: |
{indent(reviewer_md, 6)}

  - name: "change-desk-executor"
    description: "Privileged agent restricted to room owner. Triggers tools/apply_change.sh upon human approval"
    addressing: owner
    provider: "{{provider}}"
    instructions: |
{indent(executor_md, 6)}

room:
  name: "change-desk"
  bridge: "{{bridge}}"
  agents: ["change-desk-planner", "change-desk-reviewer", "change-desk-executor"]
  users: ["{{$creator}}"]

kickoff: |
  @change-desk-planner @change-desk-reviewer @change-desk-executor:
  this is the change desk. Follow room-instructions.md.
"""
    return template

def main():
    target = REPO_ROOT / "switch-change-desk.template.yaml"
    content = build_template()
    target.write_text(content, encoding="utf-8")
    print(f"Generated {target.name} from agents/*.md")

if __name__ == "__main__":
    main()
