# MVP Scope — Change Desk

**Version:** 1.0.0  
**Date:** 2026-11-04  
**Status:** In Progress (Phase 1 → 2)

---

## What MVP Means Here

MVP = the minimum that makes the demo compelling and judges can reproduce it.  
Everything else is polish.

---

## Must Have (MVP Gate)

| # | Item | Why it's MVP |
|---|------|-------------|
| M1 | `sandbox/app.txt` with version string | The thing being changed |
| M2 | `sandbox/check.sh` that reads and validates version | Proves the change worked |
| M3 | `tools/apply_change.sh` policy gate | Core tamper-evidence claim |
| M4 | `evidence/<id>/plan.md` written by planner | Audit trail |
| M5 | `evidence/<id>/review.md` written by reviewer | Audit trail |
| M6 | `evidence/<id>/approval.txt` written on approval | Audit trail |
| M7 | `evidence/<id>/execution.log` written by gate | Audit trail |
| M8 | `agents/planner.md` instruction file | Agent behavioral config |
| M9 | `agents/reviewer.md` instruction file | Agent behavioral config |
| M10 | `agents/executor.md` instruction file | Agent behavioral config |
| M11 | `room-instructions.md` | Room workflow rules |
| M12 | `policy/change-policy.md` | Knowledge file attached to room |
| M13 | `README.md` with setup + demo steps | Judge reproducibility |
| M14 | Tamper beat works (hash mismatch → gate refuses) | "No" path in demo |

---

## Should Have (Time Permitting)

| # | Item | Effort |
|---|------|--------|
| S1 | Outsider refusal beat (second account) | Low if helper available |
| S2 | Architecture diagram in README | Low (image already exists) |
| S3 | Wispr Flow dictation evidence (screenshot) | Low |
| S4 | Demo video | Medium |
| S5 | Blog draft | Medium |

---

## Won't Have (Out of Scope for MVP)

- Multi-cloud agent support
- Real infrastructure (actual server, container, etc.)
- Persistent immutable log (blockchain, append-only store)
- Automated scheduling of agents
- Fine-grained RBAC beyond Switch owner-only setting

---

## Acceptance Tests

```bash
# Test 1: Happy path
./tools/apply_change.sh CHG-20261104-001 <correct-hash> v2.0.0
# → exits 0, evidence populated, check.sh passes

# Test 2: Tamper (edit plan.md after approval, re-run)
./tools/apply_change.sh CHG-20261104-001 <original-hash> v2.0.0
# → exits 1 with "HASH MISMATCH" error

# Test 3: Missing review
rm evidence/CHG-20261104-001/review.md
./tools/apply_change.sh CHG-20261104-001 <correct-hash> v2.0.0
# → exits 1 with "REVIEW NOT FOUND" error

# Test 4: Path traversal attempt
./tools/apply_change.sh CHG-20261104-001 <correct-hash> v2.0.0 --target ../../../etc/passwd
# → exits 1 with "INVALID TARGET PATH" error
```

---

## MVP Build Sequence

```
Phase 1 (Nov 4 — today)
  └── scaffold/            ← git init, dir structure
  └── sandbox/             ← app.txt v1.0.0, check.sh
  └── tools/               ← apply_change.sh (gate logic)
  └── evidence/            ← .gitkeep placeholder

Phase 2 (Nov 5)
  └── agents/              ← planner.md, reviewer.md, executor.md
  └── policy/              ← change-policy.md
  └── room-instructions.md
  └── Wire agents in Switch room, run first full scenario

Phase 3 (Nov 6)
  └── README.md            ← final, self-contained
  └── demo/                ← script.md, video link
  └── Two clean runs from cold state
```
