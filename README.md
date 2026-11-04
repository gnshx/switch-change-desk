# Change Desk

> **Give every AI-assisted change a paper trail: request → plan → review → human approval → execution → test evidence. Make it impossible to skip a step.**

Built for the **Switch Hackathon** using [Antigravity](https://antigravity.dev) and [Switch](https://switch.new).

---

## The Problem

Production changes in AI-assisted teams are fast — but accountability is not. When an AI agent can apply a change with a single prompt, there is no native guarantee that the change was reviewed before execution, the person who approved it is known, or the plan that was approved is the plan that ran.

A single unreviewed change can cost hours of rollback work and leave no audit trail.

---

## Architecture

```
Requester ──► Switch room: change-desk ◄── Approver (owner)   Outsider (refused)
                        │
               ┌────────┴─────────┐
            Planner          Risk Reviewer
            plan.md           review.md
               └────────┬─────────┘
                   Executor (owner-only)
                        │
                apply_change.sh (policy gate)
                        │
               ┌────────┴─────────┐
          Sandbox app          Evidence log
          v1→v2                plan/review/approval/test
```

**Two layers of protection:**
- **Switch access setting** — executor is owner-only. Non-owner messages are refused before they reach the agent.
- **`apply_change.sh` policy gate** — deterministic script that refuses unless approval ID matches, plan hash matches what was approved, reviewer verdict is `APPROVED`, and target path is inside `sandbox/`.

> **Honest note:** This gives tamper-evidence in a sandbox context. It is not a security boundary against a hostile agent with direct filesystem access.

---

## Repo Layout

```
change-desk/
  README.md                 ← you are here
  prd.md                    ← product requirements document
  mvp.md                    ← MVP scope and acceptance tests
  plan.md                   ← build plan (phases, risks, rollback)
  agents.md                 ← agent design and interaction diagram
  room-instructions.md      ← paste into Switch room description
  agents/
    planner.md              ← Planner agent system instructions
    reviewer.md             ← Risk Reviewer agent system instructions
    executor.md             ← Executor agent system instructions
  policy/
    change-policy.md        ← room knowledge file (attach to Switch room)
  sandbox/
    app.txt                 ← the thing being changed (starts at v1.0.0)
    check.sh                ← health check script
  tools/
    apply_change.sh         ← policy gate (the core tamper-evidence mechanism)
  evidence/                 ← populated per change ID during runs
  demo/
    script.md               ← 2.5-minute demo script
    reset.sh                ← resets sandbox to v1.0.0 for a clean run
```

---

## Setup (< 5 minutes)

### Prerequisites
- [Antigravity CLI](https://antigravity.dev) installed (`agy --version`)
- [Switch Console](https://switch.new) installed and signed in
- Bash (macOS/Linux) or WSL

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/gnshx/switch-change-desk.git change-desk
cd change-desk

# 2. Make scripts executable
chmod +x sandbox/check.sh tools/apply_change.sh demo/reset.sh tools/test_gate.sh tools/pse_team_loop.sh demo/run_*.sh

# 3. Verify sandbox health
make check

# 4. Run full test suite & CI verification
make test
make ci
```

---

## Running the Demo

### Happy Path

```bash
# Step 1: Post in Switch room
# "Change request: CHG-20261104-001
#  What: Bump sandbox app from v1.0.0 to v2.0.0
#  Target: sandbox/app.txt"

# Step 2: Wait for Planner → PLAN READY
# Step 3: Wait for Reviewer → REVIEW READY — APPROVED

# Step 4: Compute hash prefix
sha256sum evidence/CHG-20261104-001/plan.md | cut -c1-8

# Step 5: Post in Switch room
# "APPROVED CHG-20261104-001 <hash>"

# Step 6: Executor runs gate, announces EXECUTED
# Step 7: Verify
cat sandbox/app.txt           # → version: v2.0.0
cat evidence/CHG-20261104-001/execution.log
```

### Tamper Beat (hash mismatch)

```bash
# After approval, edit plan.md
echo "" >> evidence/CHG-20261104-001/plan.md

# Try to run gate with original hash
./tools/apply_change.sh CHG-20261104-001 <original-hash> v2.0.0
# → GATE REFUSED: HASH MISMATCH
```

### Manual Gate Test (no agents needed)

```bash
# Reset to clean state
bash demo/reset.sh

# Create test evidence manually
mkdir -p evidence/CHG-TEST-001

cat > evidence/CHG-TEST-001/plan.md << 'EOF'
# Plan: CHG-TEST-001

## Objective
Bump sandbox app from v1.0.0 to v2.0.0 to test the new feature set.

## Steps
1. Update version field in sandbox/app.txt from v1.0.0 to v2.0.0
2. Run sandbox/check.sh to verify the change is valid

## Rollback
1. Restore sandbox/app.txt from evidence/CHG-TEST-001/app.txt.backup
2. Run sandbox/check.sh to confirm rollback succeeded

## Risk Rating
LOW — only a version string in a sandbox file is changed; check.sh validates the result.
EOF

HASH=$(sha256sum evidence/CHG-TEST-001/plan.md | awk '{print $1}')
HASH_PREFIX="${HASH:0:8}"
echo "Plan hash prefix: $HASH_PREFIX"

cat > evidence/CHG-TEST-001/review.md << 'EOF'
# Review: CHG-TEST-001

## Verdict
APPROVED

## Risks Identified
- None identified

## Conditions
- None

## Reviewer Note
Plan is clear, scoped, and reversible; risk rating matches complexity.
EOF

echo "APPROVED CHG-TEST-001 $HASH_PREFIX" > evidence/CHG-TEST-001/approval.txt

# Run the gate
./tools/apply_change.sh CHG-TEST-001 "$HASH_PREFIX" v2.0.0
```

---

## Switch Settings Used

| Setting | Value | Why |
|---------|-------|-----|
| Room name | `change-desk` | Identifies the workflow context |
| Room knowledge | `policy/change-policy.md` | All agents see the rules |
| Planner access | Anyone in room | Plans should be challengeable |
| Reviewer access | Anyone in room | Reviews should be challengeable |
| **Executor access** | **Owner only** | Execution is a privileged action |

The owner-only setting on the Executor is the core Switch-central feature. It means a non-owner's instruction to the Executor is refused by Switch before the message is delivered — no code required for that specific guard.

---

## Evidence Folder After a Run

```
evidence/CHG-20261104-001/
  plan.md           ← what was planned (hash verified by gate)
  review.md         ← reviewer's verdict
  approval.txt      ← "APPROVED CHG-20261104-001 <hash>"
  execution.log     ← gate checks, timestamps, check.sh output
  app.txt.backup    ← sandbox state before the change
```

A late-arriving auditor can read these files and reconstruct the full story without asking anyone.

---

## Demo Video

[→ Watch the 2.5-minute demo](#) *(link added after recording)*

---

## Principal Software Engineer Team Loop

To run the complete end-to-end multi-agent orchestration loop as a Principal Software Engineering team:

```bash
# 1. Run standard happy-path multi-agent lifecycle
make loop

# 2. Run continuous loop across multiple consecutive versions (v1.0.0 → v2.0.0 → v2.1.0 → v2.2.0)
make loop-continuous

# 3. Test post-approval tamper detection (adversarial simulation)
make loop-tamper

# 4. Test non-owner access denial (boundary security simulation)
make loop-outsider

# 5. Test risk reviewer safety veto (policy rejection simulation)
make loop-reject

# 6. Run comprehensive automated CI pipeline
make ci
```

### Lifecycle Trace

Each cycle coordinates 6 specialized personas:
1. **Requester (Lead Dev / Product):** Submits change request with target file and motivation.
2. **Planner (Principal Software Engineer):** Produces `plan.md` with blast-radius analysis, invariants, and rollback steps; computes SHA-256 fingerprint.
3. **Risk Reviewer (Staff Security Engineer):** Audits plan against `policy/change-policy.md`; issues `APPROVED` or `REJECTED` verdict.
4. **Approver (System Owner):** Inspects diff; signs off with change ID and 8-character cryptographic hash prefix in `approval.txt`.
5. **Executor (Owner-Only Access):** Confirms caller identity; executes `tools/apply_change.sh`.
6. **Policy Gate & Auditor:** Deterministically enforces 4 safety invariants, executes change, runs `sandbox/check.sh`, generates immutable audit report `audit-verdict.json`.

---

## Roadmap

| Phase | Description | Status |
|-------|-------------|--------|
| **Phase 0** | Tooling install & verification (Docker, Switch, Antigravity) | ✅ Completed |
| **Phase 1** | Sandbox app, health check (`check.sh`), and deterministic policy gate (`apply_change.sh`) | ✅ Completed |
| **Phase 2** | Multi-agent personas (`planner.md`, `reviewer.md`, `executor.md`), room instructions, policy rules | ✅ Completed |
| **Phase 3** | Automated 5-test suite (`test_gate.sh`), demo runners, fixtures, clean reset | ✅ Completed |
| **Phase 4** | Submission package (`SUBMISSION.md`, `blog.md`), Automated CI verification (`make ci`) | ✅ Completed |
| **Phase 5** | Principal Software Engineer Team continuous loop orchestrator (`tools/pse_team_loop.sh`) | ✅ Completed |

---

## Contributing

This is a solo hackathon project. Issues and PRs welcome after submission.

---

## License

MIT
