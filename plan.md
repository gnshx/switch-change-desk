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

## Phase 1 — Core Infrastructure (Nov 4) 🔄 IN PROGRESS

**Goal:** You can run a change by hand and see the test pass.

### Steps

#### 1.1 — Repository Scaffold
```bash
mkdir -p change-desk/{agents,policy,sandbox,tools,evidence,demo}
cd change-desk && git init
```

#### 1.2 — Sandbox App
Create `sandbox/app.txt`:
```
version: v1.0.0
name: change-desk-sandbox
```

#### 1.3 — Health Check Script
Create `sandbox/check.sh`:
- Read `sandbox/app.txt`
- Validate version format (`vX.Y.Z`)
- Exit 0 if valid, 1 if not
- Print result to stdout

#### 1.4 — Policy Gate Script
Create `tools/apply_change.sh`:
- Accept args: `<change-id> <plan-hash-prefix> <target-version>`
- Read approval from `evidence/<change-id>/approval.txt`
- Verify plan hash: `sha256sum evidence/<change-id>/plan.md`
- Verify review exists: `evidence/<change-id>/review.md`
- Verify reviewer verdict is `APPROVED`
- Verify target path is inside `sandbox/`
- On pass: apply version to `sandbox/app.txt`, run `check.sh`
- Write full log to `evidence/<change-id>/execution.log`
- Exit 0 on success, 1 on any failure

#### 1.5 — Evidence Placeholder
```bash
touch evidence/.gitkeep
```

#### 1.6 — Manual End-to-End Test
- Create `evidence/CHG-20261104-001/` manually
- Write `plan.md`, `review.md`, `approval.txt` by hand
- Run `./tools/apply_change.sh CHG-20261104-001 <hash> v2.0.0`
- Confirm: `sandbox/app.txt` updated, `execution.log` written, `check.sh` passes

### Done When
- `./tools/apply_change.sh CHG-20261104-001 <correct-hash> v2.0.0` exits 0
- `sandbox/check.sh` exits 0 after the change
- `evidence/CHG-20261104-001/execution.log` exists with timestamp

---

## Phase 2 — Agent Workflow (Nov 5)

**Goal:** Full scenario works end to end via agents in the Switch room.

### Steps

#### 2.1 — Agent Instruction Files
Create `agents/planner.md`:
- Role: produce `plan.md` from a change request
- Output schema: objective, steps, rollback, risk rating
- Write to `evidence/<change-id>/plan.md`

Create `agents/reviewer.md`:
- Role: critique the plan in `evidence/<change-id>/plan.md`
- Output schema: verdict, risks, conditions
- Write to `evidence/<change-id>/review.md`

Create `agents/executor.md`:
- Role: on approved instruction from owner, run `apply_change.sh`
- Refuse any instruction that is not from the room owner
- Confirm execution result in room

#### 2.2 — Room Policy
Create `policy/change-policy.md`:
- Rules every agent must follow
- Change ID format
- Plan schema
- Review verdict format
- Approval format
- Evidence file naming

#### 2.3 — Room Instructions
Create `room-instructions.md`:
- Step-by-step workflow for the room
- Who speaks when
- Format for each message

#### 2.4 — Switch Room Configuration
- Create room: `change-desk`
- Attach `policy/change-policy.md` as room knowledge
- Configure planner agent with `agents/planner.md` as system instructions
- Configure reviewer agent with `agents/reviewer.md` as system instructions
- Configure executor agent with `agents/executor.md` as system instructions
- **Set executor access to: owner-only**

#### 2.5 — First Full Run (Agents)
- Post request in room
- Planner writes plan
- Reviewer writes review
- Approver (you) posts approval
- Executor runs `apply_change.sh`
- Verify evidence folder complete

### Done When
- Full scenario runs agent-to-agent without manual file creation
- Outsider test: non-owner prompt to executor is refused by Switch

---

## Phase 3 — Demo Polish (Nov 6)

**Goal:** Two clean runs from cold state. README and video complete.

### Steps

#### 3.1 — Cold State Reset Script
Create `demo/reset.sh`:
- Remove `sandbox/app.txt` and restore v1.0.0
- Clear `evidence/` (keep `.gitkeep`)

#### 3.2 — Run 1: Happy Path
- Reset, run full scenario, record screen

#### 3.3 — Run 2: Tamper Beat
- Reset, run up to approval
- Edit `plan.md` (add whitespace or change wording)
- Run gate → verify refusal
- Record screen

#### 3.4 — Outsider Beat (if helper available)
- Get a WeMakeDevs Discord contact
- Have them join your Switch room
- Have them try to instruct the executor
- Record the refusal

#### 3.5 — Auditor Beat
- Late-join the room as a new agent
- Read room history and `evidence/` folder
- Narrate what happened

#### 3.6 — README
Write `README.md` covering:
- Problem (1 paragraph)
- Architecture diagram (embed image)
- Exact Switch settings (screenshots if possible)
- Setup instructions (< 5 commands)
- Demo steps (numbered, < 10 min to reproduce)
- Safety limits and honesty note

#### 3.7 — Video
Record a 2.5-minute demo following `demo/script.md`.

### Done When
- Two clean demo runs recorded
- README self-contained
- `demo/script.md` complete

---

## Phase 4 — Submission (Nov 7)

**Goal:** Submitted by afternoon IST.

### Steps
- [ ] Final README proofread
- [ ] Evidence folder clean (no test artifacts from setup)
- [ ] Submit link
- [ ] Post #HowISwitch
- [ ] Publish blog draft

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
