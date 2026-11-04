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
git clone <your-repo-url> change-desk
cd change-desk

# 2. Make scripts executable
chmod +x sandbox/check.sh tools/apply_change.sh demo/reset.sh

# 3. Verify sandbox health
bash sandbox/check.sh

# 4. Configure Switch room
#    - Create a room called "change-desk"
#    - Attach policy/change-policy.md as room knowledge
#    - Add Planner agent with agents/planner.md as system instructions
#    - Add Reviewer agent with agents/reviewer.md as system instructions
#    - Add Executor agent with agents/executor.md as system instructions
#    - Set Executor agent access to: Owner only  ← critical Switch setting

# 5. Run the demo reset to confirm clean state
bash demo/reset.sh
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

## Roadmap

| Phase | Date | Status |
|-------|------|--------|
| Phase 0: Tooling install | Nov 3 | ✅ Done |
| Phase 1: Sandbox + gate | Nov 4 | 🔄 In progress |
| Phase 2: Agent workflow | Nov 5 | ⬜ Planned |
| Phase 3: Two clean runs + README + video | Nov 6 | ⬜ Planned |
| Phase 4: Submission | Nov 7 | ⬜ Planned |

---

## Contributing

This is a solo hackathon project. Issues and PRs welcome after submission.

---

## License

MIT
