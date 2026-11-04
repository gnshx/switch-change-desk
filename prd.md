# Product Requirements Document — Change Desk

**Version:** 1.0.0  
**Date:** 2026-11-04  
**Author:** Principal Engineering Team  
**Status:** Approved for MVP Build

---

## 1. Problem Statement

Production changes in AI-assisted teams are fast — but accountability is not.  
When an AI agent can apply a change with a single prompt, there is no native guarantee that:

- the change was reviewed before execution,
- the person who approved it is known,
- the plan that was approved is the plan that ran.

A single unreviewed change in production can cost hours of rollback work, erode customer trust, and leave no audit trail. The status quo is: **changes happen, but nobody can prove who approved what, or whether the right plan was executed.**

---

## 2. Vision

> Give every AI-assisted change a paper trail: request → plan → review → human approval → execution → test evidence. Make it impossible to skip a step, and make the trail readable by any late-arriving auditor.

---

## 3. Goals

| # | Goal | Metric |
|---|------|--------|
| G1 | Every change is planned, reviewed, and approved before execution | 0 un-reviewed executions in demo |
| G2 | Plan tampering is detected and blocked deterministically | Edited plan → gate refuses (hash mismatch) |
| G3 | Outsider instructions to the executor are refused | Non-owner prompt → Switch access denied |
| G4 | Full evidence survives as files, readable offline | `evidence/` contains plan, review, approval, test log |
| G5 | A judge can reproduce the demo in ≤ 10 minutes | README + script sufficient; no hidden steps |

---

## 4. Non-Goals

- **Not a production security system.** The gate is tamper-evident, not tamper-proof against a hostile AI agent with filesystem access.
- **Not multi-cloud.** Antigravity-only; no mixed-provider story.
- **Not real infrastructure.** Sandbox is a version-pinned text file; `check.sh` validates it.

---

## 5. User Personas

| Persona | Role in System | Concern |
|---------|---------------|---------|
| **Requester** | Posts change request in Switch room | "My request gets actioned." |
| **Approver (you)** | Owns executor access; approves by ID + hash | "Nothing runs without my sign-off." |
| **Auditor** | Joins late; reads evidence folder | "I can reconstruct the full story." |
| **Outsider** | Tries to instruct executor | "Why was I refused?" |

---

## 6. Functional Requirements

### FR-1: Change Request
- Requester posts a natural-language request in the `change-desk` Switch room.
- Request contains a change ID in the format `CHG-YYYYMMDD-NNN`.

### FR-2: Plan Generation
- Planner agent reads the request and writes `evidence/<change-id>/plan.md`.
- Plan contains: objective, step-by-step actions, rollback procedure, risk rating.

### FR-3: Risk Review
- Risk reviewer agent reads the plan and writes `evidence/<change-id>/review.md`.
- Review contains: verdict (`APPROVED` / `REJECTED`), risks identified, conditions.

### FR-4: Human Approval
- Approver reads plan and review in room.
- Approver replies: `APPROVED <change-id> <first-8-chars-of-plan-sha256>`.
- Approval is logged to `evidence/<change-id>/approval.txt`.

### FR-5: Execution Gate (`apply_change.sh`)
- Accepts: `<change-id> <plan-hash-prefix> <target-version>`.
- Refuses if any of the following:
  - Approval ID does not match change ID.
  - SHA-256 of `plan.md` does not start with the approved hash prefix.
  - `review.md` does not exist or verdict is not `APPROVED`.
  - Target path is outside `sandbox/`.
- On success: applies change, runs `check.sh`, appends to `evidence/<change-id>/execution.log`.

### FR-6: Evidence Log
- `evidence/<change-id>/` contains: `plan.md`, `review.md`, `approval.txt`, `execution.log`.
- Log includes timestamps and exit codes.

### FR-7: Outsider Refusal
- Executor agent's Switch access is set to **owner-only**.
- Any non-owner instruction to executor is refused by Switch (not by code).

---

## 7. Non-Functional Requirements

| NFR | Requirement |
|-----|------------|
| NFR-1 | Gate script must be deterministic (same inputs → same decision) |
| NFR-2 | Evidence folder must be human-readable with no tooling |
| NFR-3 | Demo end-to-end runtime ≤ 2.5 minutes |
| NFR-4 | README must be self-contained: setup + demo reproducible without asking author |

---

## 8. Architecture Overview

```
Requester ──► Switch room: change-desk ◄── Approver (owner)
                      │
              ┌───────┴────────┐
           Planner        Risk Reviewer
           plan.md         review.md
              └───────┬────────┘
                  Executor (owner-only)
                      │
              apply_change.sh (policy gate)
                      │
              ┌───────┴────────┐
         Sandbox app       Evidence log
         v1→v2             plan/review/approval/test
```

See `architecture.png` for the visual diagram.

---

## 9. Release Criteria

- [ ] Happy path demo runs clean twice from cold state.
- [ ] Tamper beat: edited plan causes gate refusal.
- [ ] Outsider beat: non-owner prompt refused by Switch.
- [ ] README is self-contained and accurate.
- [ ] Evidence folder populated after each run.
- [ ] Video recorded (≤ 2.5 min).

---

## 10. Roadmap

| Phase | Date | Deliverable |
|-------|------|-------------|
| Phase 0 | Nov 3 | Tooling install only |
| Phase 1 | Nov 4 | Sandbox, check.sh, apply_change.sh working manually |
| Phase 2 | Nov 5 | Full agent workflow, approval step, evidence log |
| Phase 3 | Nov 6 | Two clean runs, outsider test, README, video |
| Phase 4 | Nov 7 | Submission, blog, #HowISwitch |
