# Change Policy — change-desk

**Version:** 1.0.0  
**Attached to:** `change-desk` Switch room as room knowledge  
**Applies to:** All agents and participants in this room

---

## Purpose

This policy ensures every change to the sandbox is planned, reviewed, approved, and executed in a verifiable sequence. No step may be skipped.

---

## Change ID Format

Every change request must include a Change ID in this format:

```
CHG-YYYYMMDD-NNN
```

Examples: `CHG-20261104-001`, `CHG-20261105-003`

No change may proceed without a valid Change ID.

---

## Mandatory Sequence

```
1. Requester posts request with Change ID
2. Planner writes plan.md → announces PLAN READY
3. Risk Reviewer writes review.md → announces REVIEW READY
4. Approver (owner) posts: APPROVED <change-id> <hash-prefix>
5. Executor runs apply_change.sh → announces EXECUTED or FAILED
```

No step may be skipped. No step may be repeated for the same Change ID unless:
- The reviewer returned REJECTED (new plan required, new Change ID recommended)
- The gate returned FAILED due to plan tampering (new approval required)

---

## Plan Schema

The plan must be written to `evidence/<change-id>/plan.md` and contain these sections exactly:

```markdown
# Plan: <change-id>
## Objective
## Steps
## Rollback
## Risk Rating
```

---

## Review Schema

The review must be written to `evidence/<change-id>/review.md` and contain:

```markdown
# Review: <change-id>
## Verdict
APPROVED   ← or REJECTED (this exact word on its own line)
## Plan Hash
<sha256-hash-of-plan.md>
## Risks Identified
## Conditions
## Reviewer Note
```

The review is cryptographically bound to the plan via `## Plan Hash`. If the plan is modified after review, the gate will refuse execution.

---

## Approval Format

The approver signs the approval locally using `tools/approve.sh <change-id>`. This verifies the plan and review, computes the SHA-256 fingerprint, signs the approval using a local human key, and produces:

```
APPROVED <change-id> <first-8-or-more-chars-of-sha256-of-plan.md>
```

The approver then posts this exact line in the Switch room to authorize the Executor.

---

## Evidence Files

After a successful execution, `evidence/<change-id>/` must contain:

| File | Written by | Contents |
|------|-----------|---------|
| `plan.md` | Planner agent | Plan schema above |
| `review.md` | Reviewer agent | Review schema above |
| `approval.txt` | Approver (owner writes or gate records) | Approval message |
| `execution.log` | Gate script | Timestamps, checks, check.sh output |
| `app.txt.backup` | Gate script | Sandbox state before change |

---

## Scope Restriction

All changes are restricted to `sandbox/` only.  
The gate script refuses any target path outside `sandbox/`.

---

## Honesty Notes & Security Boundaries

- **Role separation is behavioral:** Planner, reviewer, and executor are separated by instruction only in this configuration. Any agent with direct filesystem access could write any file. A production deployment requires OS-level process isolation and distinct sandbox write permissions per agent.
- **Switch access control** (owner-only executor) is configured as owner-only in Switch room settings. It prevents non-owners from addressing the executor in normal room interaction.
- **`apply_change.sh`** is a deterministic code gate. It enforces hash integrity, review-to-plan binding, human signature verification, replay protection, and sandbox containment regardless of agent prompting.
- **`approve.sh` binds approval to a human:** Generates an HMAC signature using a local operator secret stored outside the repository (`~/.config/change-desk/operator.key`). This defends against prompt-level injection and accidental room approval forging. (Residual risk: on single-user workstations, agents running as the same OS user could access the file; production environments require containerized privilege separation or hardware signing tokens).
- The evidence log is append-only by convention and tracked by a run ledger, not by an immutable hardware ledger.

---

## Violations

If any agent deviates from this policy, announce in the room:
```
POLICY VIOLATION: <agent-name> — <description>
```
and halt until the room owner intervenes.
