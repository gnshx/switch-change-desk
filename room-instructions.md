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

Post a message addressing the Planner in this format:

```
@change-desk-planner Change request: CHG-YYYYMMDD-NNN
What: <one sentence describing the change>
Target: sandbox/app.txt
```

Example:
```
@change-desk-planner Change request: CHG-20261104-001
What: Bump sandbox app from v1.0.0 to v2.0.0
Target: sandbox/app.txt
```

The Planner will respond addressing the Reviewer:
`@change-desk-reviewer PLAN READY: <change-id>`

---

## Workflow

```
You post request addressing @change-desk-planner
  → @change-desk-planner writes plan.md and announces: @change-desk-reviewer PLAN READY: <id>
  → @change-desk-reviewer reads plan & policy, writes review.md, announces: REVIEW READY: <id> — APPROVED
  → You run ./tools/approve.sh <change-id> <version> in terminal to review diff and sign token
  → You post in chat: @change-desk-executor APPROVED <change-id> <hash-prefix>
  → @change-desk-executor runs gate and announces EXECUTED or FAILED
```

---

## How to Approve a Change

Use the human approval CLI in your terminal:

```bash
./tools/approve.sh <change-id> <target-version>
```

Example:
```bash
./tools/approve.sh CHG-20261104-001 v2.0.0
```

This tool:
1. Displays the complete plan and reviewer risks/verdict
2. Verifies that the reviewer's recorded plan hash matches `plan.md`
3. Asks for your `y/N` confirmation interactively on `/dev/tty`
4. Computes the SHA-256 fingerprint
5. Cryptographically signs an HMAC operator token bound to ID, Plan Hash, and Target Version
6. Prints the exact line to paste into the Switch room

You then post that output line in the room:

```
@change-desk-executor APPROVED CHG-YYYYMMDD-NNN <first-8-chars-of-hash>
```

Example:
```
@change-desk-executor APPROVED CHG-20261104-001 b574a815
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

## Addressing & Access Boundaries

The Executor is configured with `addressing: owner`. Non-owner messages are not treated as instructions; only the room owner may direct the Executor to invoke the deterministic policy gate.
