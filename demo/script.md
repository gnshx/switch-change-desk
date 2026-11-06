# Demo Video Script — Change Desk (~2:45)

**Target Duration:** ~2 minutes 45 seconds  
**Prep Before Recording:**
1. Run `make reset` in terminal (resets `sandbox/app.txt` to `v1.0.0` and clears evidence).
2. Ensure Switch Console is open to `#change-desk` with all 3 agents showing online.
3. Keep terminal clean and readable; close any tabs/windows containing keys, tokens, or environment dumps.
4. Silence system notifications (enable Do Not Disturb).

---

## Beat 1: The Problem (0:00–0:15)

*Screen: Title card / terminal banner "Change Desk — Tamper-Evident AI Change Management"*

> "AI agents can change production state with a single prompt. Nothing proves someone reviewed the plan, who approved it, or that the plan that ran is the plan that was approved. Change Desk fixes that, using Switch."

---

## Beat 2: Live Run in Switch (0:15–1:20)

*Screen: The Switch Console `#change-desk` room.*

**Action 1 (User in Switch chat):**
Type and send:
```text
@change-desk-planner Change request: CHG-20261106-001
What: Bump sandbox app from v1.0.0 to v2.0.0
Target: sandbox/app.txt
Target version: v2.0.0
```

**Narration:**
> "I post a change request in a Switch room. The planner writes a plan and hands it to the reviewer by name."

*Screen: Planner replies with `@change-desk-reviewer PLAN READY: CHG-20261106-001` and SHA-256 hash. Reviewer inspects policy and replies with `REVIEW READY: CHG-20261106-001 — APPROVED`.*
*(In video editing: show a visible "4x" badge during agent thinking time).*

**Narration:**
> "The reviewer checks it against policy and records the plan's hash. Now it's my turn."

**Action 2 (Terminal):**
Switch to terminal and run:
```bash
./tools/approve.sh CHG-20261106-001 v2.0.0
```
Show the formatted CLI output displaying the plan, reviewer verdict, and full 64-hex SHA-256 hash. Type `y` or `approve` to confirm.

**Narration:**
> "In my terminal I read the full plan and review, and sign the approval, tied to this change ID, this exact plan, and this version. I paste the approval line back into the room."

**Action 3 (Switch chat):**
Copy and paste the output line into the room:
```text
@change-desk-executor APPROVED CHG-20261106-001 <hash-prefix>
```

*Screen: Executor runs 4 tool calls across 23 seconds, then posts `EXECUTED: CHG-20261106-001 — check.sh PASSED`.*

**Action 4 (Terminal):**
Run `cat sandbox/app.txt` to show `version: v2.0.0`.

**Narration:**
> "The executor runs a policy gate, applies the change, and runs the health check. Version one to version two, with the evidence saved."

---

## Beat 3: Owner Addressing in Switch (1:20–1:40)

*Screen: Click the **Configuration** tab for `change-desk-executor` in Switch Console. Highlight the `Addressing: Owner` setting on screen.*

**Narration:**
> "Here's the Switch part. The executor's addressing is set to owner, so only the room owner is admitted to instruct it. The planner and reviewer can't tell it to run anything."

---

## Beat 4: Tamper Detection (1:40–2:05)

*Screen: Terminal running `make demo-tamper` (labeled on-screen as **[Offline Fixture]**).*

**Action:**
Run:
```bash
make demo-tamper
```
Point to the refusal message: `GATE REFUSED: HASH MISMATCH`.

**Narration:**
> "Now the gate. After approval, someone changes one character in the plan. The gate recomputes the hash, sees it differs from what was approved, and refuses. Approval is bound to the exact plan."

---

## Beat 5: Automatic Rollback (2:05–2:25)

*Screen: Terminal running `make demo-rollback` (labeled on-screen as **[Offline Fixture]**).*

**Action:**
Run:
```bash
make demo-rollback
```
Point to the terminal output showing health check failure, backup restoration, and rollback to `v1.0.0`.

**Narration:**
> "If the health check fails after a change, the gate restores the backup automatically."

---

## Beat 6: Tests and Evidence Trail (2:25–2:45)

*Screen: Terminal running `make test`, followed by showing `examples/evidence/live-run-CHG-20261104-001/`.*

**Action:**
1. Run:
   ```bash
   make test
   ```
   Show `21/21 passed — ALL 21 TESTS PASSED`.
2. Run:
   ```bash
   ls examples/evidence/live-run-CHG-20261104-001/
   ```

**Narration:**
> "Twenty-one regression tests cover replay, traversal, unsigned approvals, and more. Every change leaves a trail: plan, review, approval, and execution log. This is a sandbox prototype, and the README lists its limits. It's open source, and the link is below."
