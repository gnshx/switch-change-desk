#!/usr/bin/env python3
"""tools/build_template.py
Builds switch-change-desk.template.yaml from agents/*.md and room-instructions.md.
Guarantees zero-drift between documentation, instructions, and Switch template.
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
    room_instr_md = (REPO_ROOT / "room-instructions.md").read_text(encoding="utf-8")

    template = f"""version: 1
params:
  provider:
    type: provider
    description: Coding agent runtime that powers the room agents
    default: [opencode, antigravity, claude, codex]
    input: advanced
  location:
    type: location
    description: Machine where agents run
    default: local
    input: advanced
  directory:
    type: directory
    description: Shared repository workspace directory for all change-desk agents
    default: "{{$agents_dir}}/change-desk"
    input: advanced
  bridge:
    type: bridge
    label: Messaging App
    description: Connected chat app (Slack, Discord, Teams, or default)
    default: [Discord, Slack, $first]
    required: false

agents:
  - name: "change-desk-planner"
    description: "Drafts scoped execution and rollback plans in evidence/<change-id>/plan.md"
    provider: "{{provider}}"
    location: "{{location}}"
    directory: "{{directory}}"
    addressing: anyone
    instructions: |
{indent(planner_md, 6)}

  - name: "change-desk-reviewer"
    description: "Critiques plans, binds review to plan hash, and issues APPROVED/REJECTED verdict"
    provider: "{{provider}}"
    location: "{{location}}"
    directory: "{{directory}}"
    addressing: anyone
    instructions: |
{indent(reviewer_md, 6)}

  - name: "change-desk-executor"
    description: "Privileged agent restricted to room owner. Triggers tools/apply_change.sh upon human approval"
    provider: "{{provider}}"
    location: "{{location}}"
    directory: "{{directory}}"
    addressing: owner
    instructions: |
{indent(executor_md, 6)}

room:
  name: "change-desk"
  description: "Human-in-the-loop change management with tamper-evident SHA-256 policy gate"
  channel_type: channel_public
  bridge: "{{bridge}}"
  agents: ["change-desk-planner", "change-desk-reviewer", "change-desk-executor"]
  users: ["{{$creator}}"]
  instructions: |
{indent(room_instr_md, 4)}

kickoff: |
  @change-desk-planner @change-desk-reviewer @change-desk-executor:
  this is the change desk. Ready to process change requests according to policy.
"""
    return template

def main():
    target = REPO_ROOT / "switch-change-desk.template.yaml"
    content = build_template()
    target.write_text(content, encoding="utf-8")
    print(f"Generated {target.name} from agents/*.md and room-instructions.md")

if __name__ == "__main__":
    main()
