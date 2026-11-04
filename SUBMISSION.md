# SUBMISSION.md — Change Desk Hackathon Submission

## Project

| Field | Value |
|-------|-------|
| **Project name** | Change Desk |
| **One-line description** | A three-agent AI change-management system that enforces tamper-evident, human-approved changes via a SHA-256 policy gate before anything touches infrastructure. |
| **Track** | #HowISwitch |

---

## Switch Features Used

| Feature | Setting / Location | How it's used |
|---------|-------------------|---------------|
| **Owner-only executor** | Room member role → `owner` | Restricts who can invoke the gate (`tools/apply_change.sh`); planner/reviewer agents cannot call it |
| **Room knowledge** | Room settings → Knowledge files | `policy/change-policy.md` and `agents.md` loaded so every agent knows the protocol without re-prompting |
| **Agent instructions** | Room settings → Agent instructions | Per-role instruction files (`agents/planner.md`, `agents/reviewer.md`, `agents/executor.md`) define each agent's responsibilities and output schema |
| **Room instructions** | Room settings → Room instructions | `room-instructions.md` sets the overall workflow context for all participants |

---

## Links

| Resource | URL |
|----------|-----|
| **Repo** | `[REPO_LINK_PLACEHOLDER]` |
| **Demo video** | `[VIDEO_LINK_PLACEHOLDER]` |
| **Blog post** | `[BLOG_LINK_PLACEHOLDER]` |

---

## Judging Criteria Self-Assessment

### 1. Use of Switch
- [x] Uses Switch rooms as the coordination layer for multi-agent workflow
- [x] Uses room knowledge to share policy documents across agents
- [x] Uses owner-only restriction to enforce executor identity
- [x] Uses per-role agent instructions to specialize agent behavior
- [x] `room-instructions.md` documents Switch setup for reproducibility

### 2. Technical Implementation
- [x] `tools/apply_change.sh` — 4-check policy gate with tamper evidence
- [x] `tools/test_gate.sh` — 5 automated tests; all pass (`5/5`)
- [x] `demo/run_happy_path.sh` — offline fixture demo, verified PASS
- [x] `demo/run_tamper_beat.sh` — tamper detection demo, verified PASS
- [x] `Makefile` — `make test`, `make demo-happy`, `make demo-tamper`, `make check`, `make reset`
- [x] `.gitignore` — evidence run dirs excluded, .gitkeep preserved
- [x] SHA-256 hash stored in `plan-hash.txt` and verified at gate time
- [x] Full audit trail in `evidence/CHG-*/execution.log`
- [x] Automatic rollback on health-check failure

### 3. Demo Quality
- [x] `demo/fixtures/CHG-DEMO-001/` — pre-written fixtures for offline reliability
- [x] `demo/script.md` — step-by-step demo walkthrough
- [x] `demo/reset.sh` — idempotent reset before every demo
- [x] Happy path shows version bump v1.0.0 → v2.0.0 with health check
- [x] Tamper beat shows clear `HASH MISMATCH` rejection with both hashes printed

### 4. Documentation
- [x] `README.md` — project overview and quickstart
- [x] `prd.md` — product requirements document
- [x] `mvp.md` — MVP scope definition
- [x] `plan.md` — build phases
- [x] `agents.md` — agent roles and responsibilities
- [x] `policy/change-policy.md` — full policy definition
- [x] `blog.md` — #HowISwitch blog post (~700 words)
- [x] `demo/fixtures/README.md` — fixture documentation

### 5. Originality / Insight
- [x] SHA-256 tamper evidence on the plan file (the core insight)
- [x] Separation of proposer, reviewer, and executor into distinct agent roles
- [x] Policy gate is stateless and agent-agnostic — works with any LLM
- [x] Reset/fixture pattern solves agentic repeatability problem

---

## Checklist Before Submitting

- [ ] Replace `[REPO_LINK_PLACEHOLDER]` with actual GitHub URL
- [ ] Replace `[VIDEO_LINK_PLACEHOLDER]` with Loom / YouTube URL (≤ 3 min)
- [ ] Replace `[BLOG_LINK_PLACEHOLDER]` with published blog URL
- [ ] Run `make test` one final time and confirm `5/5 passed`
- [ ] Run `make demo-happy` and `make demo-tamper` and confirm both PASS
- [ ] Verify `git log --oneline` shows all 4 commits (phases 0–3)
- [ ] Submit on the hackathon portal before the deadline
