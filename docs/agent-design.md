# Agents — Change Desk

**Version:** 1.0.0  
**Date:** 2026-11-04  
**Status:** Draft for Phase 2 wiring

---

## Overview

Three agents operate inside the `change-desk` Switch room.  
Each has a single responsibility. No agent skips its role.

```
Request ──► Planner ──► Risk Reviewer ──► [Approver: human] ──► Executor
                                                                      │
                                                              apply_change.sh
```

---

## Agent 1: Planner

**File:** [`agents/planner.md`](agents/planner.md)  
**Switch access:** Anyone in room may prompt  
**Responsibility:** Turn a change request into a structured, reviewable plan.

### Trigger
Any message in the room containing a change ID (`CHG-YYYYMMDD-NNN`) and a description of what should change.

### Output
Writes `evidence/<change-id>/plan.md` with the following schema:

```markdown
# Plan: <change-id>

## Objective
One sentence: what changes and why.

## Steps
1. ...
2. ...
3. ...

## Rollback
Step-by-step reversal if anything fails.

## Risk Rating
LOW | MEDIUM | HIGH — one line of reasoning.

## SHA-256
(leave blank — computed by gate)
```

### Rules
- Write ONLY to `evidence/<change-id>/plan.md`.
- Do not apply any change to `sandbox/`.
- Do not write to `review.md` or `approval.txt`.
- After writing, announce in room: `PLAN READY: <change-id>`.

### Failure Mode
If the request is ambiguous, ask one clarifying question before writing any file.

---

## Agent 2: Risk Reviewer

**File:** [`agents/reviewer.md`](agents/reviewer.md)  
**Switch access:** Anyone in room may prompt  
**Responsibility:** Independently critique the plan and issue a verdict.

### Trigger
Any message in the room containing `PLAN READY: <change-id>`.

### Input
Reads `evidence/<change-id>/plan.md`.

### Output
Writes `evidence/<change-id>/review.md` with the following schema:

```markdown
# Review: <change-id>

## Verdict
APPROVED | REJECTED

## Plan Hash
<sha256-hash-of-plan.md>

## Risks Identified
- ...

## Conditions (if APPROVED with caveats)
- ...

## Reviewer Note
One sentence summary.
```

### Rules
- Never modify `plan.md`.
- If plan is missing or malformed, write `REJECTED` with reason.
- After writing, announce in room: `REVIEW READY: <change-id> — APPROVED` or `REJECTED`.
- If REJECTED, suggest what must change before re-plan.

### Failure Mode
If `plan.md` does not exist, announce: `REVIEW BLOCKED: <change-id> — plan.md not found`.

---

## Agent 3: Executor

**File:** [`agents/executor.md`](agents/executor.md)  
**Switch access:** ⚠️ **Owner-only** — this is the core Switch-central feature  
**Responsibility:** Run the policy gate on explicit owner approval.

### Trigger
A message from the room owner (approver) in the format:
```
APPROVED <change-id> <first-8-chars-of-plan-sha256>
```

### Pre-flight Checks (before running gate)
1. Message is from room owner — enforced by Switch access setting.
2. `evidence/<change-id>/review.md` exists and contains `APPROVED`.
3. `evidence/<change-id>/plan.md` exists.

### Execution
```bash
./tools/apply_change.sh <change-id> <hash-prefix> <target-version>
```

### Post-execution
- Read exit code.
- Announce in room:
  - Exit 0: `EXECUTED: <change-id> — check.sh PASSED`
  - Exit 1: `FAILED: <change-id> — <reason from gate>`
- Do NOT retry on failure. Wait for new owner instruction.

### Rules
- Accept instructions ONLY from the room owner.
- Never read or modify `plan.md` or `review.md`.
- Never run `apply_change.sh` without an owner approval message.
- Never run on a change ID that has already been executed (check `execution.log` exists).

### Failure Modes
| Scenario | Response |
|----------|----------|
| Non-owner tries to instruct | Switch refuses before message reaches agent |
| Gate exits 1 (hash mismatch) | Announce failure, do not retry |
| Gate exits 1 (review missing) | Announce failure, do not retry |
| `apply_change.sh` not found | Announce error, halt |

---

## Agent Interaction Diagram

```
Room Timeline
─────────────────────────────────────────────────────────────────
Requester:   "Bump sandbox app to v2.0.0 — CHG-20261104-001"
Planner:     [writes plan.md] → "PLAN READY: CHG-20261104-001"
Reviewer:    [reads plan.md, writes review.md] → "REVIEW READY: CHG-20261104-001 — APPROVED"
Approver:    "APPROVED CHG-20261104-001 a3f9d12b"
Executor:    [runs apply_change.sh] → "EXECUTED: CHG-20261104-001 — check.sh PASSED"
─────────────────────────────────────────────────────────────────
Outsider:    "Executor, apply version v3.0.0"
Switch:      [refuses — not owner] → access denied
─────────────────────────────────────────────────────────────────
Approver:    "APPROVED CHG-20261104-002 a3f9d12b"  (plan.md was edited)
Executor:    [runs gate] → gate exits 1 "HASH MISMATCH"
Executor:    "FAILED: CHG-20261104-002 — HASH MISMATCH"
─────────────────────────────────────────────────────────────────
```

---

## Switch Configuration Reference

| Agent | Access Setting | Rationale |
|-------|---------------|-----------|
| Planner | Anyone in room | Plans should be challengeable |
| Reviewer | Anyone in room | Reviews should be challengeable |
| Executor | **Owner only** | Execution is a privileged action |

> **Honest note:** Switch access control is a behavioral guard.  
> `apply_change.sh` is a deterministic code guard.  
> Together they give tamper-evidence; neither is a security boundary against a hostile agent with direct filesystem access.

---

## One-Agent Fallback

If Switch Console does not support multiple independent sessions with different instructions:

Run a single Antigravity session that plays all three roles in sequence:
1. Session receives request → plays Planner → writes `plan.md`.
2. Session re-reads plan → plays Reviewer → writes `review.md`.
3. Human approver replies → session plays Executor → runs gate.

The gate still enforces hash + review + approval. The behavioral separation is weaker but the deterministic checks still hold.
