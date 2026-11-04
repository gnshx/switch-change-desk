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
## Risks Identified
## Conditions
## Reviewer Note
```

---

## Approval Format

The approver must post this exact format in the room:

```
APPROVED <change-id> <first-8-or-more-chars-of-sha256-of-plan.md>
```

The hash prefix is computed by:
```bash
sha256sum evidence/<change-id>/plan.md | cut -c1-8
```

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

## Honesty Notes

- **Switch access control** (owner-only executor) is a behavioral guard. It prevents accidental instruction from non-owners in normal use.
- **`apply_change.sh`** is a deterministic code guard. It enforces hash + review + approval checks regardless of who calls it.
- Neither guard is a security boundary against a hostile agent with direct filesystem access.
- The evidence log is append-only by convention, not by technical enforcement.

---

## Violations

If any agent deviates from this policy, announce in the room:
```
POLICY VIOLATION: <agent-name> — <description>
```
and halt until the room owner intervenes.
