# Room Instructions — change-desk

**Paste this into your Switch room description or pin it as the first message.**

---

## Welcome to change-desk

This room runs a structured change workflow. Every change is planned, reviewed, approved, and executed with a full evidence trail.

---

## Who is in this room

| Agent / Person | Role | Switch Access |
|----------------|------|---------------|
| You (owner) | Approver | Owner |
| Planner | Writes plan.md | Anyone |
| Risk Reviewer | Writes review.md | Anyone |
| Executor | Runs the gate script | **Owner only** |

---

## How to Request a Change

Post a message in this format:

```
Change request: CHG-YYYYMMDD-NNN
What: <one sentence describing the change>
Target: sandbox/app.txt
```

Example:
```
Change request: CHG-20261104-001
What: Bump sandbox app from v1.0.0 to v2.0.0
Target: sandbox/app.txt
```

The Planner will respond with `PLAN READY: <change-id>`.

---

## Workflow

```
You post a request
  → Planner writes plan.md and announces PLAN READY
  → Reviewer reads plan, writes review.md, announces REVIEW READY
  → You read both files, then post: APPROVED <change-id> <hash-prefix>
  → Executor runs the gate and announces EXECUTED or FAILED
```

---

## How to Approve a Change

Use the human approval CLI in your terminal:

```bash
./tools/approve.sh <change-id>
```

This tool:
1. Displays the plan diff and reviewer verdict
2. Verifies that the reviewer's recorded plan hash matches `plan.md`
3. Asks for your `y/N` confirmation
4. Computes the SHA-256 fingerprint
5. Cryptographically signs an HMAC operator token in `evidence/<change-id>/approval.txt`
6. Prints the exact line to paste into the Switch room

You then post that output line in the room:

```
APPROVED CHG-YYYYMMDD-NNN <first-8-chars-of-hash>
```

Example:
```
APPROVED CHG-20261104-001 a3f9d12b
```

---

## If the Reviewer Rejects

The reviewer will announce `REVIEW READY: <change-id> — REJECTED` and explain what needs to change.  
The requester must post a revised request (new Change ID recommended) and the planner will re-plan.

---

## If the Gate Refuses

The executor will announce `FAILED: <change-id> — <reason>`.  
Common reasons:
- **HASH MISMATCH** — plan.md was modified after approval. Re-read plan, recompute hash, re-approve.
- **REVIEW NOT FOUND** — reviewer hasn't written review.md yet.
- **Verdict not APPROVED** — reviewer rejected the plan.

---

## Reading the Evidence

After a successful run:
```
evidence/<change-id>/
  plan.md          ← what was planned
  review.md        ← what the reviewer said
  approval.txt     ← who approved and what hash
  execution.log    ← what the gate did, timestamps, test result
  app.txt.backup   ← sandbox state before the change
```

Any late-arriving auditor can reconstruct the full story from these files.

---

## Outsider Refusal

If someone who is not the room owner tries to instruct the Executor, Switch will refuse the message before it reaches the agent. The Executor will never see it.
