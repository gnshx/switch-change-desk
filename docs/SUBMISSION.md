# Hackathon Submission — Change Desk

## Project Overview

| Field | Value |
|---|---|
| **Project Name** | Change Desk |
| **One-Line Pitch** | A collaborative multi-agent change management workflow in Switch that enforces a verifiable approval trail and deterministic policy gate checks before any change can touch application state. |
| **Primary Track** | **Track 1: Best Business Workflow** |
| **Side Tracks** | Best Blog (#HowISwitch) |
| **Repository** | [https://github.com/gnshx/switch-change-desk](https://github.com/gnshx/switch-change-desk) |
| **Demo Video** | `[VIDEO_LINK_PLACEHOLDER]` (~2:45 walkthrough) |
| **Blog Post** | `[BLOG_LINK_PLACEHOLDER]` (available in `docs/blog.md`) |
| **Runtime & Tooling** | Developed with Antigravity; live run on Switch Console v0.40.1 with OpenCode runtime (nemotron-3.5-lightning-free) |

---

## Switch Features & Configuration

Change Desk relies on Switch as its core multi-agent operating environment:

| Switch Feature | Exact Configuration | Workflow Function |
|---|---|---|
| **Room Environment** | Room name: `change-desk` | Shared context where all change requests, plans, and approvals are visible to the team. |
| **Room Knowledge** | `policy/change-policy.md` | Attaches policy rules, change schemas, and approval formats directly into all agents' contexts. |
| **Room Instructions** | `room-instructions.md` | Defines the turn-taking order and message schemas across all participants. |
| **Addressing Control** | Executor addressing: `owner` | Restricts executor addressing strictly to human room owner (verified in Switch core protocol). |
| **Agent Specialization** | Planner (`@change-desk-planner`), Reviewer (`@change-desk-reviewer`), Executor (`@change-desk-executor`) | Divides proposal, critique, and privileged execution into independent agent personas. |
| **Template Import** | `switch-change-desk.template.yaml` | One-step reproducible room creation in Switch Console. |

---

## Evaluation Criteria Self-Assessment

### 1. Use of Switch
Switch serves as the central coordination fabric and security perimeter for Change Desk. Rather than running agents as disconnected scripts, the entire lifecycle takes place in a visible Switch room (`change-desk`). Room instructions (`room-instructions.md`) and workspace policies eliminate prompt drift by anchoring all agents to a single source of truth. Most crucially, we leverage Switch's **addressing: owner restriction** on the Executor agent. This ensures that non-owner messages are not treated as instructions and cannot trigger privileged execution, providing behavioral access control directly at the collaboration layer. The entire environment is packaged as `switch-change-desk.template.yaml` for 1-click reproduction in Switch Console.

### 2. Technical Execution
The core technical contribution is `tools/apply_change.sh`, a deterministic policy gate enforcing 8 invariants before any change is applied: strict Change ID schema validation, replay attack prevention via run ledgers, SemVer target validation, human approval presence, SHA-256 plan hash prefix and full 64-hex matching, reviewer verdict confirmation, review-to-plan cryptographic binding, and directory containment within `sandbox/` (with path traversal and symlink escape defenses). We also built `tools/approve.sh`, which displays the diff to the human operator, prompts for interactive confirmation on a TTY, and cryptographically signs an HMAC operator token outside the agent workspace binding Change ID, Plan Hash, and Target Version. The gate includes automatic rollback on health-check failure and is validated by a 21-test automated regression suite (`make test`) that runs offline without external dependencies.

### 3. Creativity and Impact
In enterprise engineering, the danger of AI agents is not that they are slow, but that they can apply unvetted changes instantly. Change Desk turns this problem upside down by introducing cryptographic tamper-evidence into agent workflows. Our key insight is that instructions given to LLMs are merely behavioral; a hostile or drifting agent can still violate them. By pairing Switch's room-level access controls with a deterministic, local SHA-256 policy gate and a human-bound signing CLI, we guarantee that the plan that runs is byte-for-byte identical to the plan the human reviewed. If a plan is tampered with post-approval—even by adding a single space—the gate catches the hash mismatch and halts.

### 4. Presentation
The submission is structured for rapid evaluation and reproduction. Evaluators can reproduce the entire offline regression suite in under 30 seconds via `make test` (21/21 passing) and `make ci`. For judges reviewing offline without executing code, [`examples/evidence/CHG-DEMO-001/`](../examples/evidence/CHG-DEMO-001/) contains a complete, committed audit trail of a real run, including plan, review, HMAC approval, execution trace, and backup state. The project includes a 2.5-minute video demo structured across 5 distinct beats (problem statement, happy path, tamper rejection, automatic rollback, and audit trail inspection), a GitHub-rendered Mermaid architecture diagram, and comprehensive documentation organized in `docs/`.

---

## Final Submission Checklist

- [x] Repository public and pushed: `https://github.com/gnshx/switch-change-desk`
- [x] Template YAML provided for one-click Switch room setup: `switch-change-desk.template.yaml`
- [x] Offline regression suite passes 100%: `make test` (21/21 PASS)
- [x] Offline demo fixtures pass: `make demo-happy`, `make demo-tamper`, `make demo-rollback`
- [x] Committed live-run evidence trail provided: `examples/evidence/live-run-CHG-20261104-001/` and offline fixture `examples/evidence/CHG-DEMO-001/`
- [x] Comprehensive documentation organized in `docs/` (`prd.md`, `mvp.md`, `plan.md`, `agent-design.md`, `blog.md`)
- [ ] Record 2.5-min walkthrough video following `demo/script.md` and replace placeholder link
- [ ] Publish blog draft and replace placeholder link
- [ ] Submit before deadline: Nov 7, 2026, 11:59 PM IST
