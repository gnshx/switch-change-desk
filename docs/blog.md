# Change Desk: How I Built a Tamper-Evident AI Change-Management System on Switch

*Submitted for the Best Blog side track and #HowISwitch — Hackathon 2026*

---

## The Problem: Velocity Without Verification Is an Outage Waiting to Happen

We are at an inflection point in software operations. I can open a chat with an AI coding agent, type *"bump the sandbox app to v2.0.0"*, and it will gladly edit files, run scripts, and push changes.

The speed is exhilarating, but the operational blast radius is terrifying:
- Nobody can prove which agent proposed which diff.
- Nobody can verify whether the plan that was discussed matches the code that actually executed.
- Prompt injection or rogue room participants could trick an agent into executing unauthorized operations.

The engineering challenge I set out to solve:  
**How can we give autonomous multi-agent teams the speed to plan and prepare changes while making execution deterministic, cryptographically tamper-evident, and strictly gated by human approval?**

---

## What I Built: Change Desk

**Change Desk** is a collaborative multi-agent change management workflow orchestrated inside **Switch** and enforced by a deterministic, local policy gate (`tools/apply_change.sh`).

The system divides operational duties among three specialized agent personas and a human operator:
1. **The Human Requester:** Submits a change request with a structured Change ID (`CHG-YYYYMMDD-NNN`) in the `#change-desk` Switch room.
2. **The Planner Agent (`@change-desk-planner`):** Scopes the objective, steps, and rollback procedure into `evidence/<id>/plan.md` and computes its exact SHA-256 fingerprint via `./tools/hash_plan.sh`.
3. **The Risk Reviewer Agent (`@change-desk-reviewer`):** Audits the plan against room policy (`policy/change-policy.md`), binds the plan's 64-hex SHA-256 hash into its review, and stamps an `APPROVED` verdict into `evidence/<id>/review.md`.
4. **The Human Operator:** Inspects the plan and review in a real terminal using `./tools/approve.sh`, confirms on an interactive TTY, and cryptographically signs an HMAC token using an operator key (`~/.config/change-desk/operator.key`) located outside the workspace.
5. **The Executor Agent (`@change-desk-executor`):** Configured with Switch's `Addressing: Owner` policy, restricting instructions strictly to the room owner.
6. **The Deterministic Policy Gate (`tools/apply_change.sh`):** Validates all 8 cryptographic invariants outside the LLM: replay ledger check, HMAC operator signature, SHA-256 plan hash matching, review-to-plan cryptographic binding, and directory containment inside `sandbox/`. It applies the change, executes `sandbox/check.sh`, records the execution in the ledger, and automatically rolls back if health checks fail.

---

## Live Run Numbers: What We Measured

During live verification in Switch Console v0.40.1:
- **Agents:** 3 specialized personas running concurrently on local toolchains.
- **Planner Handoff:** Picked up `@change-desk-planner`, wrote `plan.md`, generated 64-hex SHA-256 hash (`19bacc11...`), and mentioned `@change-desk-reviewer`.
- **Reviewer Audit:** Bound exact plan hash and posted `REVIEW READY: CHG-20261104-001 — APPROVED`.
- **Executor Run:** Upon receiving `@change-desk-executor APPROVED ...`, executed the policy gate across **4 tool calls in 23 seconds**, verified all 8 invariants, bumped `sandbox/app.txt` from `v1.0.0` to `v2.0.0`, verified runtime health checks, and recorded the change in `evidence/.applied_ledger`.
- **Automated Regression Suite:** 21/21 passing tests verifying tamper rejection, symlink escape defense, replay protection, and automated rollback.

---

## How Switch Made It Possible

Three core Switch platform primitives made this architecture practical:

### 1. Delivery-Layer Access Control (`Addressing: Owner`)
In collaborative rooms, anyone can post messages. If an executor agent responded to anyone, an outsider or compromised room bot could trigger production changes. Switch solves this at the protocol layer: setting `Addressing: Owner` on the Executor ensures messages from non-owners never reach the agent prompt.

### 2. Multi-Agent Turn-Taking via Shared Workspaces
Switch allows multiple agents to share a repository directory (`/home/ganesh/Desktop/switch-change-desk`). This allowed the Planner to produce `evidence/<id>/plan.md`, the Reviewer to inspect that exact file on disk, and the Executor to run the deterministic gate—all coordinated visibly in `#change-desk`.

### 3. One-Click Reproducibility via Template YAML
By packaging the entire system into `switch-change-desk.template.yaml`, anyone can import the room, instructions, agent personas, and workspace mappings into Switch Console in a single click.

---

## What Broke & What I Learned: A Field Guide for Switch Builders

Building a multi-agent system on real infrastructure is full of edge cases. Here are the four biggest challenges I hit and how to solve them:

### 1. The Template Schema Trap
*The Problem:* Early drafts assumed custom template keys like `handle`, `role`, and external file references for instructions. Switch Console strictly expects the official schema: top-level `params`, `agents`, `room`, and `kickoff`, with inline instructions and platform-recognized parameters (`directory`, `provider`, `location`).  
*The Fix:* Use `make template` to compile markdown instructions into the official YAML schema, and validate it using Switch's internal template linter before importing.

### 2. Silent Stalls: Agents Need Explicit @mentions
*The Problem:* Agents in a room don't act on broadcast messages unless they are addressed. Early test runs stalled because agents announced `PLAN READY` without an `@mention`.  
*The Fix:* Wire explicit `@mentions` into the handoff protocol: the user mentions `@change-desk-planner`, the planner mentions `@change-desk-reviewer`, and the approval CLI prints `@change-desk-executor APPROVED <id> <hash>`.

### 3. Agent Sandboxing & `XDG_CONFIG_HOME`
*The Problem:* When Switch launches an agent runtime, it sandboxes the process environment, redirecting `XDG_CONFIG_HOME` to a temporary directory in `/tmp/`. When the Executor ran `apply_change.sh`, the gate failed-closed because it couldn't find `operator.key` in `/tmp/.../change-desk/`.  
*The Fix:* Update the gate script to resolve the key from the real user home directory (`getent passwd` / `$HOME`), preserving the fail-closed check while allowing sandboxed agents to verify host-signed HMAC tokens.

### 4. Hash Typos: LLMs Cannot Calculate SHA-256
*The Problem:* Asking an LLM to "compute the plan hash" leads to hallucinations or typos. If the reviewer's hash differs from the real hash by a single character, the gate refuses execution.  
*The Fix:* Create `./tools/hash_plan.sh <change-id>`, a deterministic helper tool that agents execute via bash to obtain the exact 64-character hash.

---

## Honest Security Limits & Residual Risks

No engineering system is infallible, and credibility requires honesty about boundaries:
1. **Same-User Residual Risk:** In this prototype, agents run under the same OS user (`ganesh`). While file permissions (`600`) protect `operator.key` from accidental room-level reads, they do not provide process isolation against same-user inspection. In enterprise production, the approver CLI should run under a separate OS user or hardware token (YubiKey).
2. **Addressing Policy Scope:** The `Addressing: Owner` setting was verified in Switch Console configuration. For complete production defense, combine room-level addressing with network-isolated execution runners.
3. **Sandbox Scope:** The policy gate strictly confines changes to files inside `sandbox/` and rejects directory traversal (`..`) or escaping symlinks.

---

## Reproduce It in Under 60 Seconds

The complete repository, sanitized live-run evidence, and offline regression suite are open-source at:  
👉 **[https://github.com/gnshx/switch-change-desk](https://github.com/gnshx/switch-change-desk)**

Run the test suite offline right now without API keys:

```bash
git clone https://github.com/gnshx/switch-change-desk.git
cd switch-change-desk

# Run the 21-test policy gate regression suite
make test

# Run the offline tamper-detection demo
make demo-tamper

# Run the automated rollback demo
make demo-rollback
```

To run it live with Switch:
1. Import `switch-change-desk.template.yaml` in Switch Console.
2. Select your provider runtime and workspace directory.
3. Click **Create all** and follow [`demo/script.md`](../demo/script.md).

---

## Conclusion

Multi-agent AI systems do not have to be reckless. By pairing Switch's collaborative room controls with deterministic, local cryptographic policy gates, Change Desk demonstrates that autonomous speed and enterprise-grade rigor can live in the same room.
