# Change Desk: How I Built a Tamper-Evident AI Change-Management System on Switch

*Submitted for the Best Blog side track and #HowISwitch — Hackathon 2026*

---

## The Problem: Trust Is the Bottleneck in AI Operations

We are at a strange inflection point in software engineering. I can open a chat with an AI coding agent, type *"bump the production app to v2.0.0"*, and it will happily update files, run migration scripts, and push code. There is no ticket, no peer review, and no verifiable audit trail.

The speed is intoxicating, but the blast radius is terrifying. When an unvetted change lands in production at 2 AM on a Friday, nobody can say who approved it, whether the team agreed on the rollback plan, or whether the code that executed matched the plan that was discussed.

The fundamental engineering question I set out to solve:  
**How can we give autonomous AI agents the velocity to plan and prepare changes while making it deterministic, tamper-evident, and impossible for unapproved changes to reach production?**

---

## What I Built: Change Desk

**Change Desk** is a collaborative multi-agent change management workflow hosted inside [Switch](https://github.com/sandbox-quantum/switch) and paired with an invariant policy gate (`tools/apply_change.sh`).

The workflow divides responsibilities among three specialized agent personas and a human operator:
1. **The Requester:** Broadcasts a change request with a structured Change ID (`CHG-YYYYMMDD-NNN`).
2. **The Planner Agent:** Analyzes the scope, draft steps, rollback procedures, and blast radius into `evidence/<change-id>/plan.md`, computing its SHA-256 fingerprint.
3. **The Risk Reviewer Agent:** Reads the plan, verifies safety conditions against room knowledge (`policy/change-policy.md`), binds the plan's hash into its review, and stamps an `APPROVED` or `REJECTED` verdict into `evidence/<change-id>/review.md`.
4. **The Human Approver:** Inspects the diff and review using a local CLI (`tools/approve.sh`), confirms the plan, and signs an HMAC token that agents cannot forge.
5. **The Executor Agent (Owner-Only Access):** Authorized only by the room owner to invoke the policy gate.
6. **The Policy Gate (`apply_change.sh`):** A deterministic 8-invariant bash gate that checks the human approval, verifies the SHA-256 plan hash, confirms the reviewer verdict and plan binding, guards against path traversal, checks replay protection ledgers, executes the change, runs `sandbox/check.sh`, and automatically rolls back if health checks fail.

---

## How Switch Made It Possible

Three specific Switch capabilities made this architecture clean and practical:

### 1. Owner-Only Agent Access Control
In Switch room settings, each agent can have distinct addressing and role permissions. By configuring the **Executor agent as `owner-only`**, Switch guarantees that guests or non-owner members in the room cannot instruct the Executor to trigger execution. The platform refuses non-owner messages before they ever touch the model's context window.

### 2. Room Knowledge as Institutional Memory
Instead of re-injecting 50 lines of policy rules into every prompt, I uploaded `policy/change-policy.md` as **Room Knowledge**. Every agent that enters the `change-desk` room immediately inherits the required Change ID schemas, file path conventions, and verification steps. This eliminated context drift across long conversations.

### 3. One-Click Reproducibility via Template YAML
Switch supports room templating. By packaging the entire architecture into [`switch-change-desk.template.yaml`](../switch-change-desk.template.yaml), anyone can import the room, agents, instructions, and knowledge files into Switch Console in a single click.

---

## What Broke & What I Learned: A Guide for First-Time Switch Users

If you are building your first multi-agent workflow on Switch, here are the real pitfalls I hit and how to avoid them:

### Pitfall 1: Behavioral Prompts Are Not Security Boundaries
My initial naive design assumed that instructing the Executor agent with *"Only execute if the user says APPROVED"* was enough. It wasn't. In edge-case testing, an agent could be socially engineered, or prompt drift could lead to executing changes before the reviewer had stamped a verdict.

**The Fix:** Separate behavioral coordination from deterministic execution. Switch provides the human-agent collaboration layer, but the final execution *must* pass through a deterministic code gate (`tools/apply_change.sh`) that validates cryptographic hashes outside the LLM.

### Pitfall 2: The Stale Review Attack
What happens if an agent drafts a plan, gets it reviewed, and then someone edits `plan.md` to slip in an unvetted step before human approval? Or what if a reviewer approves Plan A, but the human approves Plan B?

**The Fix:** Cryptographic review-to-plan binding. The Reviewer agent must record the exact SHA-256 hash of the plan it inspected inside `review.md`. The policy gate checks that:
```
Review Bound Plan Hash == Actual Current plan.md SHA-256 == Approved Fingerprint Prefix
```
If anything changed by even a single byte after review, the gate refuses execution with `REVIEW-TO-PLAN MISMATCH`.

### Pitfall 3: Agent Approval Forgery
If the approval file (`evidence/<id>/approval.txt`) is just a text file in the workspace, any agent with filesystem access could theoretically write that file.

**The Fix:** I wrote `tools/approve.sh`, a local CLI for the human operator. It displays the plan diff, prompts the human for confirmation, and signs the approval using an HMAC key stored in `~/.config/change-desk/operator.key` (outside the repo). The policy gate verifies this signature, ensuring an agent cannot forge valid approvals.

### Pitfall 4: Test Repeatability & Cold-State Resets
Multi-agent testing creates dirty state fast. Evidence folders accumulate, version numbers bump, and previous runs cause false positives. Writing an idempotent reset script (`demo/reset.sh`) and building pre-packaged offline fixtures (`demo/fixtures/`) allowed me to build a 12-test automated regression suite (`make test`) that runs offline in seconds.

---

## Try It in 60 Seconds

The full repository is open-source at:  
👉 **[https://github.com/gnshx/switch-change-desk](https://github.com/gnshx/switch-change-desk)**

You can run the entire regression suite offline right now without API keys:

```bash
git clone https://github.com/gnshx/switch-change-desk.git
cd switch-change-desk

# Run the 12-test policy gate regression suite
make test

# Watch the happy path demo fixture (v1.0.0 → v2.0.0)
make demo-happy

# Watch the tamper detection demo (post-approval edit rejected)
make demo-tamper

# Watch the automatic rollback demo (runtime check failure reverts state)
make demo-rollback
```

To run it live with agents, import `switch-change-desk.template.yaml` into Switch Console and follow `demo/script.md`.

---

## Conclusion

The promise of AI agents is velocity. But in production engineering, velocity without verification is just an outage waiting to happen. By combining Switch's collaborative room controls with deterministic, tamper-evident policy gates, Change Desk shows how we can give agents real operational power while keeping humans firmly and verifiably in control.
