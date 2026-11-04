# Change Desk: How I Built an AI Change-Management System on Switch

*Posted for the #HowISwitch track — Hackathon 2026*

---

## The Problem: Trust Is the Bottleneck

We're at an inflection point with AI-assisted operations. I can prompt an agent to "bump the app to v2.0.0" and it will happily do it — no ticket, no review, no audit trail. That's terrifying. The speed gains from AI are real, but so is the blast radius when an unreviewed change lands in production at 2 AM on a Friday.

The question I kept coming back to: *how do you give an AI agent the authority to execute changes while keeping a human meaningfully in the loop?*

## What I Built

**Change Desk** is a three-agent change-management workflow that enforces tamper-evident, human-approved changes before anything touches infrastructure. A Planner agent drafts a structured change plan. A Reviewer agent reads that plan and issues an APPROVED or REJECTED verdict. An Executor agent runs a policy gate that cryptographically verifies the plan has not been modified since it was reviewed — and only then applies the change. The entire audit trail lives in `evidence/CHG-*/` alongside SHA-256 hashes, approval records, and execution logs. No approval, no run. Tampered plan, no run.

## How Switch Made It Possible

Three Switch features were load-bearing for this project.

**Owner-only executor.** The executor role is restricted to a single owner identity. This means only my approved agent session can invoke `tools/apply_change.sh`. An AI operating in planner or reviewer mode literally cannot call the gate — the room won't route that message. This is enforcer-at-the-platform-level, not just a convention in a prompt.

**Room knowledge.** I uploaded `policy/change-policy.md` and `agents.md` as room knowledge. Every agent that enters the room instantly knows the approval protocol, the evidence directory structure, and the hash-verification requirement. I don't have to re-explain the rules in every prompt. The room carries the institutional memory.

**Agent instructions per role.** Each agent (`agents/planner.md`, `agents/reviewer.md`, `agents/executor.md`) has its own instruction file loaded as room context. The planner knows to produce structured Markdown with a specific schema. The reviewer knows to check risk, rollback procedure, and emit a `## Verdict` section the gate script can grep. The executor knows it is the *last* safeguard and must refuse any invocation that bypasses the evidence chain.

## The Tamper-Evidence Insight

The aha moment came when I realized the review process only matters if the reviewed artifact is *the same one that gets executed*. An agent (or a human, for that matter) could get a plan approved and then silently modify it before execution.

The fix is embarrassingly simple: `sha256sum`. When the reviewer approves a plan, the hash of `plan.md` is recorded in `approval.txt`. The gate recomputes the hash at execution time. If they differ by even one byte — a blank line appended, a word changed, a date swapped — the gate prints `HASH MISMATCH` and exits 1. No rollback needed because the change never ran.

```
Approved prefix:  3f390029dfc888...
Actual prefix:    663f0019ff08e9...
GATE REFUSED: HASH MISMATCH — plan was modified after approval.
```

That's tamper evidence with zero cryptographic libraries.

## Architecture Walkthrough

```
Planner Agent          Reviewer Agent         Executor Agent
    │                       │                       │
    ▼                       ▼                       ▼
evidence/CHG-*/        evidence/CHG-*/        tools/apply_change.sh
  plan.md    ──sha256──► review.md ──────────►  [1] approval.txt ✓
  plan-hash.txt          approval.txt           [2] hash matches ✓
                                                [3] verdict APPROVED ✓
                                                [4] path in sandbox/ ✓
                                                     │
                                                     ▼
                                               sandbox/app.txt (changed)
                                               sandbox/check.sh (run)
                                               evidence/execution.log
```

The gate script runs four sequential checks. Any failure short-circuits with `exit 1` and a human-readable refusal message. All output is tee'd into `execution.log` so the audit trail is complete regardless of outcome.

## What Surprised Me

I expected the hard part to be the agent prompt engineering. It wasn't. The agents mostly got it right once the room knowledge was correct. The hard part was **the reset problem**: every test run needed a clean slate or the evidence from a previous run would bleed into the next. Writing `demo/reset.sh` and baking it into every test fixture taught me that *repeatability* is a first-class requirement for agentic systems, not an afterthought.

The second surprise: the policy gate is nine lines of grep and two lines of sed. The complexity lives in the *process*, not the code. That's probably true of most compliance systems.

## Try It Yourself

The repo is at: **[REPO_LINK_PLACEHOLDER]**

Ten-minute setup:
```bash
git clone <repo>
cd switch-change-desk
make test          # runs all 5 gate tests
make demo-happy    # watch the happy path
make demo-tamper   # watch the tamper detection
```

No external dependencies. No API keys required for the demo path. The fixture files provide a fully offline demo experience. If you want to run the live agent workflow, load the room knowledge files into Switch and follow `demo/script.md`.

The core insight scales: any agentic system that modifies state needs a gate that is (1) separate from the agent that proposes the change, (2) cryptographically tied to the reviewed artifact, and (3) owned by an identity the proposing agent cannot impersonate. Switch gave me all three primitives. I just wired them together.
