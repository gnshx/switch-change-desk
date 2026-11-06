# Demo Script — change-desk (~2.5 minutes)

**Video target:** 2 minutes 30 seconds  
**Recording tool:** Screen recorder of your choice (e.g. OBS, SimpleScreenRecorder, Loom)  
**Prep:** Run `make reset` before recording

---

## Before You Hit Record

- [ ] Terminal open in repo root with clean, readable font size
- [ ] Switch Console open to `#change-desk` room
- [ ] Confirm Planner, Reviewer, and Executor show online
- [ ] Notifications silenced (Do Not Disturb enabled)
- [ ] No API keys, tokens, or environment secrets visible in terminal or tabs
- [ ] Run `make reset` (ensures `sandbox/app.txt` is `v1.0.0` and clean state)
- [ ] Wispr Flow running (if recording dictation for the Wispr side track)

---

## Beat 1 — Problem (0:00–0:15)

**Say:**
> "Every AI-assisted team faces the same risk: an agent applies a change, something breaks, and nobody can verify who approved it or whether the right plan ran. Change Desk fixes that by bringing deterministic tamper-evidence into Switch."

**Show:** Switch Console `#change-desk` room.

---

## Beat 2 — Live Happy Path in Switch (0:15–1:20)

**Say:**
> "Here's the live workflow. In Switch, I post a change request addressing the Planner with a fresh change ID."

**Do:**
1. Type in the Switch room:
   ```text
   @change-desk-planner Change request: CHG-20261106-001
   What: Bump sandbox app from v1.0.0 to v2.0.0
   Target: sandbox/app.txt
   Target version: v2.0.0
   ```

**Say:**
> "The Planner drafts a structured plan, hashes it with SHA-256, and hands off to the Reviewer."

**Do:**
2. Show Planner response in room: `@change-desk-reviewer PLAN READY: CHG-20261106-001 ... (Plan hash: <hash>)`
3. Show Reviewer response in room: `REVIEW READY: CHG-20261106-001 — APPROVED`

*(In video editing: speed up the agent wait time with a visible '4x' label)*

**Say:**
> "The Risk Reviewer independently critiques the plan, binds the plan's exact SHA-256 hash to prevent post-review changes, and posts its approval. Now, as the human operator, I inspect and cryptographically sign the change in my terminal."

**Do:**
4. In terminal, run:
   ```bash
   ./tools/approve.sh CHG-20261106-001 v2.0.0
   ```
5. Show the terminal display: full plan, 64-hex SHA-256 hash, and reviewer verdict. Type `y` (or `approve`) to confirm.
6. Copy the output line:
   ```text
   @change-desk-executor APPROVED CHG-20261106-001 <hash-prefix>
   ```
7. Post that exact line back into Switch Console.

**Say:**
> "The Executor agent receives the instruction and runs our deterministic policy gate."

**Do:**
8. Show Executor response in Switch:
   ```text
   EXECUTED: CHG-20261106-001 — check.sh PASSED
   ```
9. Switch to terminal and run:
   ```bash
   cat sandbox/app.txt
   ```
   *(Shows `version: v2.0.0`)*

---

## Beat 3 — Owner Addressing Configuration (1:20–1:40)

**Say:**
> "To prevent unauthorized instructions from participants or prompt injection from other bots, the Executor is configured with Switch's built-in Addressing: Owner control."

**Do:**
1. In Switch Console, click the **Configuration** tab (or Agent Settings) for `change-desk-executor`.
2. Highlight the **`Addressing: Owner`** setting on screen.

**Say:**
> "Switch enforces this at the delivery layer: only messages from the room owner can address the Executor, protecting the execution gate from unauthorized room participants."

---

## Beat 4 — Tamper Detection [Offline Fixture] (1:40–2:05)

**Say:**
> "What if someone edits the plan after human approval? Even a single byte difference? Here is our offline tamper fixture."

**Do:**
1. Run in terminal:
   ```bash
   make demo-tamper
   ```
2. Highlight the terminal output:
   ```text
   GATE REFUSED: HASH MISMATCH
   Actual plan hash differs from approved hash
   ```

**Say:**
> "The SHA-256 hash doesn't match the signed approval token. The policy gate halts instantly, fail-closed. The application state is untouched."

---

## Beat 5 — Automatic Rollback [Offline Fixture] (2:05–2:25)

**Say:**
> "What if a change passes review, but the runtime application health check fails in production? Here is our automated rollback fixture."

**Do:**
1. Run in terminal:
   ```bash
   make demo-rollback
   ```
2. Highlight the terminal output:
   ```text
   Health check failed → Reverting sandbox/app.txt to pre-execution backup
   Sandbox restored to v1.0.0
   ```

**Say:**
> "The gate catches the health check failure, restores the pre-execution backup, and records the failure trace in the audit log."

---

## Beat 6 — Audit Trail & Wrap Up (2:25–2:45)

**Say:**
> "Every run leaves a complete, reproducible audit trail in the evidence folder—plan, reviewer verdict, human HMAC token, and execution log. All 21 regression tests run offline in seconds. That's Change Desk: multi-agent speed with cryptographic integrity on Switch."

**Do:**
1. Run in terminal:
   ```bash
   make test
   ```
2. Show `21/21 passed — ALL 21 TESTS PASSED`.

---

## After Recording

- [ ] Upload video to YouTube (Unlisted or Public) or Loom
- [ ] Confirm video plays with sound while logged out
- [ ] Paste video link into `README.md` and `docs/SUBMISSION.md`
