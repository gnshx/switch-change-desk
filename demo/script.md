# Demo Script — change-desk (~2.5 minutes)

**Video target:** 2 minutes 30 seconds  
**Recording tool:** Screen recorder of your choice  
**Prep:** Run `./demo/reset.sh` before recording

---

## Before You Hit Record

- [ ] Terminal open in repo root
- [ ] Switch room `change-desk` open in browser/app
- [ ] Planner, Reviewer, Executor agents loaded with correct instructions
- [ ] Executor addressing set to owner
- [ ] `sandbox/app.txt` shows `version: v1.0.0` (run `./demo/reset.sh`)
- [ ] `evidence/` is empty (run `./demo/reset.sh`)
- [ ] Wispr Flow running (for the dictation side track)

---

## Beat 1 — Problem (0:00–0:15)

**Say:**
> "Every AI-assisted team faces the same risk: a change gets applied, something breaks, and nobody can say who approved it or whether the right plan ran. Change Desk fixes that."

**Show:** Just your face or a blank screen. Keep it punchy.

---

## Beat 2 — Happy Path (0:15–1:15)

**Say:**
> "Here's the happy path. I post a change request in the Switch room."

**Do:**
1. Type in Switch room:
   ```
   @change-desk-planner Change request: CHG-20261104-001
   What: Bump sandbox app from v1.0.0 to v2.0.0
   Target: sandbox/app.txt
   Target version: v2.0.0
   ```

**Say:**
> "The Planner picks it up, writes a structured plan, and hands it off to the Risk Reviewer."

**Do:**
2. Show Planner response in room: `@change-desk-reviewer PLAN READY: CHG-20261104-001 (Plan SHA-256: <hash>)`
3. Run in terminal: `cat evidence/CHG-20261104-001/plan.md`

**Say:**
> "The Risk Reviewer independently critiques it, binds the plan's exact SHA-256 hash, and announces approval."

**Do:**
4. Show Reviewer response: `REVIEW READY: CHG-20261104-001 — APPROVED (Plan Hash: <hash>). Awaiting human operator sign-off.`
5. Run: `cat evidence/CHG-20261104-001/review.md`

**Say:**
> "I read both. I'm satisfied. I run our local operator CLI to inspect and cryptographically sign the change."

**Do:**
6. Run: `./tools/approve.sh CHG-20261104-001 v2.0.0`
   - Show the CLI summary of the full plan, reviewer verdict, and HMAC signature generation.
   - Type `approve` to confirm.
7. Post paste line in Switch room: `@change-desk-executor APPROVED CHG-20261104-001 <hash-prefix>`

**Say:**
> "The Executor, configured with addressing: owner so only I can instruct it, runs the deterministic policy gate."

**Do:**
8. Show Executor response: `EXECUTED: CHG-20261104-001 — check.sh PASSED`
9. Run: `cat sandbox/app.txt` → shows `version: v2.0.0`
10. Run: `cat evidence/CHG-20261104-001/execution.log` (scroll to bottom)

---

## Beat 3 — Owner Addressing Configuration (1:15–1:35)

**Say:**
> "To prevent rogue or unvetted instructions from other participants, the Executor is configured with addressing set to owner in Switch."

**Do:**
1. Show Switch Console Agent Settings screen for `change-desk-executor`.
2. Highlight `Addressing: Owner` setting.

**Say:**
> "Switch's core addressing policy restricts mentions of the Executor strictly to the room owner, blocking prompt injection or unauthorized change triggers from other participants before they reach the model."

---

## Beat 4 — Tamper (1:45–2:15)

**Say:**
> "What if someone edits the plan after it was approved? The gate catches it."

**Do:**
1. Run: `./demo/reset.sh && mkdir -p evidence/CHG-20261104-002`
2. Copy and show plan.md being written (or use the fixture)
3. Compute hash and post approval in room
4. Edit `plan.md` — add one character anywhere
5. Run: `./tools/apply_change.sh CHG-20261104-002 <original-hash> v2.0.0`
6. Show terminal output: `GATE REFUSED: HASH MISMATCH`

**Say:**
> "The hash doesn't match. The gate refuses. The sandbox is untouched."

---

## Beat 5 — Automatic Rollback (2:15–2:30)

**Say:**
> "What if a change passes review, but fails runtime health checks in production? Watch the gate catch the failure and automatically roll back."

**Do:**
1. Run: `./demo/run_rollback_beat.sh`
2. Show output: health check crashes → gate catches failure → restores `app.txt.backup` → sandbox preserved at `v1.0.0`.

**Say:**
> "The bad change is completely rolled back to backup, with the failure trace preserved in the evidence folder."

---

## Beat 6 — Auditor & Evidence Trail (2:30–2:45)

**Say:**
> "Any late-arriving auditor can inspect the Switch room history and the evidence folder to see the complete, tamper-evident audit trail."

**Do:**
1. Run: `ls examples/evidence/CHG-DEMO-001/`
2. Run: `cat examples/evidence/CHG-DEMO-001/approval.txt`

**Say:**
> "Plan, review, human HMAC signature, gate execution log, backup, and test results. That's Change Desk."

---

## After Recording

- [ ] Upload video
- [ ] Paste video link into `README.md`
- [ ] Paste video link into submission form
