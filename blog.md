# How I Built Change Desk with Switch and Antigravity

*A hackathon story about giving every AI-assisted change a paper trail.*

---

## The Problem I Was Trying to Solve

It was a simple thought experiment: what happens when an AI agent can apply a production change with a single prompt? The speed is incredible. The accountability is not.

When something breaks — and something always breaks — nobody can answer the basic questions:
- Who approved this change?
- Did they read the plan before they approved it?
- Is the plan that ran the same one that was reviewed?

This is not a hypothetical. Teams using AI agents for infrastructure changes are already running into this. The fix shouldn't be to slow down — it should be to make the trail automatic.

That's what Change Desk does.

---

## What I Built

Change Desk is a structured change workflow that runs inside a **Switch room**. Every change goes through five steps — request, plan, review, human approval, execution — and every step leaves a file on disk that any auditor can read later.

The core idea is two layers of protection:

**Layer 1 — Switch:** The Executor agent's access is set to **owner-only**. A non-owner's instruction to the Executor is refused by Switch before the message is ever delivered. No code required.

**Layer 2 — `apply_change.sh`:** A deterministic bash gate that refuses to run unless four things are true simultaneously: the approval ID matches, the plan's SHA-256 hash matches what was approved (so a plan edited after approval is caught), the reviewer's verdict is `APPROVED`, and the target path is inside `sandbox/`. This is tamper-evidence, not tamper-proof — and the README says so explicitly.

---

## How Switch Made It Possible

Before Switch, I would have needed to build a custom webhook, a permissions system, and a message routing layer just to get "only the owner can instruct the executor." With Switch, I changed one setting.

The **owner-only access control on the Executor** is the cornerstone of the demo. It means the "outsider refusal" beat in the demo isn't a code check — it's Switch enforcing access before anything else runs. That's a fundamentally cleaner guarantee than application-level checking.

**Room knowledge** let me attach `change-policy.md` to the room once. Every agent sees the rules — the change ID format, the plan schema, the verdict format — without me having to re-explain them in every system prompt.

**Agent system instructions** gave each agent a single, focused role. The Planner only plans. The Reviewer only reviews. The Executor only executes on owner approval. The specialization makes the workflow auditable: you can read any agent's instruction file and understand exactly what it's allowed to do.

---

## The Aha Moment: Plan Hash

The tamper-evidence insight came from a simple question: *what if someone edits the plan after I approve it?*

The fix is elegant: when the approver posts their approval, they include the first 8 characters of `sha256sum plan.md`. The gate recomputes the hash at execution time. If the plan changed — even by one whitespace character — the prefix won't match, and the gate refuses.

```bash
# Approver computes:
sha256sum evidence/CHG-20261104-001/plan.md | cut -c1-8
# → a3f9d12b

# Posts in room:
APPROVED CHG-20261104-001 a3f9d12b

# Gate verifies at execution time:
ACTUAL_HASH=$(sha256sum plan.md | awk '{print $1}')
# If first 8 chars don't match a3f9d12b → GATE REFUSED: HASH MISMATCH
```

This is not cryptographically strong (8 hex chars = 32 bits), but it's enough to catch accidental or casual tampering in a sandbox context — which is exactly what the README claims.

---

## Architecture

```
Requester ──► Switch room: change-desk ◄── Approver (owner)   Outsider (refused)
                        │
               ┌────────┴─────────┐
            Planner          Risk Reviewer
            plan.md           review.md
               └────────┬─────────┘
                   Executor (owner-only)
                        │
                apply_change.sh (policy gate)
                        │
               ┌────────┴─────────┐
          Sandbox app          Evidence log
          v1→v2                plan/review/approval/test
```

---

## What Surprised Me

I expected the hardest part to be the gate script. It wasn't — bash + sha256sum handles it cleanly in ~100 lines.

The hardest part was writing the **agent instruction files** in a way that made the agents predictably follow the protocol. The key insight: give each agent a single trigger format and a single output schema. If the trigger doesn't match, the agent asks a clarifying question instead of guessing. If the schema is violated, the reviewer catches it. The workflow is self-correcting.

---

## Try It Yourself

```bash
git clone https://github.com/YOUR_USERNAME/switch-change-desk
cd switch-change-desk
chmod +x sandbox/check.sh tools/apply_change.sh demo/*.sh tools/test_gate.sh
make test          # all 5 gate tests
make demo-happy    # happy path
make demo-tamper   # tamper beat
```

The whole demo takes about 10 minutes to reproduce from scratch. That was a design goal.

---

*Built in 4 days for the Switch Hackathon using Antigravity, Switch Console, and Wispr Flow.*
