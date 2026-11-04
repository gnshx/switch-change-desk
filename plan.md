# Plan — Change Desk Build

**Version:** 1.0.0  
**Date:** 2026-11-04  
**Team:** Principal Engineering (solo)  
**Status:** Active

---

## Phase 0 — Tooling (Nov 3) ✅

**Goal:** Every required tool runs without errors.

### Steps
- [x] Install Switch Console (desktop app)
- [x] Install Docker Desktop
- [x] Install Antigravity CLI (`agy`)
- [x] Install Wispr Flow
- [x] Create personal Discord server for outsider test
- [x] Skim Switch docs: rooms, agents, access settings

### Done When
- `agy --version` returns a version string
- Switch Console opens and shows a room
- `docker run hello-world` exits 0

---

## Phase 1 — Core Infrastructure (Nov 4) ✅ COMPLETED

**Goal:** You can run a change by hand and see the test pass.

### Steps

#### 1.1 — Repository Scaffold
- [x] Repository structured with `agents/`, `policy/`, `sandbox/`, `tools/`, `evidence/`, `demo/`

#### 1.2 — Sandbox App
- [x] Created `sandbox/app.txt` baseline (`v1.0.0`)

#### 1.3 — Health Check Script
- [x] Created `sandbox/check.sh` with strict format validation and exit code gating

#### 1.4 — Policy Gate Script
- [x] Created `tools/apply_change.sh` verifying 4 safety invariants:
  1. Approval ID match
  2. SHA-256 plan hash match
  3. Reviewer verdict `APPROVED`
  4. Sandbox directory containment

#### 1.5 — Evidence Placeholder
- [x] `evidence/.gitkeep` tracking configured

#### 1.6 — Manual End-to-End Test
- [x] Verified full happy path, tamper refusal, and automatic rollback

### Done When
- [x] `./tools/apply_change.sh` exits 0 on valid inputs
- [x] `sandbox/check.sh` validates upgraded state
- [x] `execution.log` records deterministic trace

---

## Phase 2 — Agent Workflow (Nov 5) ✅ COMPLETED

**Goal:** Full scenario works end to end via agents in the Switch room.

### Steps

#### 2.1 — Agent Instruction Files
- [x] `agents/planner.md` — Produces structured plan with hash calculation
- [x] `agents/reviewer.md` — Rigorous risk analysis and verdict stamping
- [x] `agents/executor.md` — Owner-only access enforcement and gate invocation

#### 2.2 — Room Policy
- [x] `policy/change-policy.md` — Change request schema, evidence layout, and gate rules

#### 2.3 — Room Instructions
- [x] `room-instructions.md` — Switch room workflow instructions and protocols

#### 2.4 — Switch Room Configuration
- [x] System prompts and policy knowledge defined for zero-drift deployment

#### 2.5 — First Full Run (Agents)
- [x] Full request-to-execution pipeline validated with tamper detection

---

## Phase 3 — Demo Polish & Automated Testing (Nov 6) ✅ COMPLETED

**Goal:** Clean test suite, reproducible demo scripts, and fixtures.

### Steps
- [x] `demo/reset.sh` — Idempotent cold-state reset
- [x] `tools/test_gate.sh` — 5-test comprehensive automated test suite (5/5 PASS)
- [x] `demo/run_happy_path.sh` — Pre-packaged offline happy path demonstration
- [x] `demo/run_tamper_beat.sh` — Post-approval hash mismatch demonstration
- [x] `demo/fixtures/` — Verified fixture plans and approved verdicts
- [x] `Makefile` — Standard targets (`check`, `test`, `demo-happy`, `demo-tamper`, `reset`, `clean`)

---

## Phase 4 — Submission & Continuous Integration (Nov 7) ✅ COMPLETED

**Goal:** Complete submission artifacts, blog post, and GitHub Actions CI.

### Steps
- [x] `SUBMISSION.md` — Full hackathon submission package with rubric alignment
- [x] `blog.md` — #HowISwitch article with technical deep-dive
- [x] Automated CI validation pipeline (`make ci`) testing policy gates across multiple runs
- [x] GitHub repository tracking configured: `https://github.com/gnshx/switch-change-desk`

---

## Phase 5 — Principal Software Engineer Team Loop ✅ COMPLETED

**Goal:** Autonomous end-to-end continuous loop orchestrator simulating the entire PSE team lifecycle.

### Steps
- [x] `tools/pse_team_loop.sh` — Orchestrates Requester, Planner, Reviewer, Approver, Executor, Gate, and Auditor
- [x] Automated evidence ledger and compliance audit report (`audit-verdict.json`)
- [x] Support for continuous loop across consecutive versions (`--loop <N>`)
- [x] Real-time security beat simulations:
  - Adversarial post-approval tamper detection (`--tamper`)
  - Privilege boundary outsider refusal (`--outsider`)
  - Risk reviewer policy veto (`--reject`)
- [x] Verified via `make ci` and clean cold-state runs

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Switch Tasks not available | High | Low | Use one agent playing all roles in turn |
| Pro plan limits hit during rehearsal | Medium | Medium | Keep prompts short; use `--concise` mode |
| Helper for outsider test unavailable | Medium | Low | Skip beat, don't imply it happened |
| Hash collision (prefix only) | Very Low | Low | Use 16 chars if 8-char collision suspected |
| Agent writes plan to wrong path | Low | Medium | Reviewer instruction checks path before writing verdict |

---

## Rollback (if demo fails live)

1. Reset to known good state: `./demo/reset.sh`
2. Run manually with pre-written `evidence/` files (plant them in `demo/fixtures/`)
3. Gate still runs and verifies — demo is honest even if agents are not live
