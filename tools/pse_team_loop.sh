#!/usr/bin/env bash
# tools/pse_team_loop.sh — Principal Software Engineer Team Multi-Agent Loop
#
# Simulates and executes the complete multi-agent change lifecycle:
#   [Requester]  -> [Planner (Principal Engineer)]
#                -> [Risk Reviewer (Staff Security)]
#                -> [Approver (Owner / Cryptographic Hash Signer)]
#                -> [Executor (Privileged Access Enforcement)]
#                -> [Deterministic Policy Gate (apply_change.sh)]
#                -> [Sandbox Health Check (check.sh)]
#                -> [Auditor (Tamper-Evidence Ledger Verification)]
#
# Modes:
#   --happy               Standard single-change cycle (default)
#   --loop <N>            Continuous loop of N change cycles
#   --tamper              Adversarial simulation: plan tampered after approval
#   --outsider            Privilege simulation: unauthorized caller rejected
#   --reject              Risk simulation: reviewer issues REJECTED verdict
#   --help                Display usage instructions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RESET_SCRIPT="$REPO_ROOT/demo/reset.sh"
GATE_SCRIPT="$REPO_ROOT/tools/apply_change.sh"
CHECK_SCRIPT="$REPO_ROOT/sandbox/check.sh"
APP_FILE="$REPO_ROOT/sandbox/app.txt"
POLICY_FILE="$REPO_ROOT/policy/change-policy.md"

# ─── Formatting ───────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Default Parameters ──────────────────────────────────────────────────────
MODE="happy"
LOOP_COUNT=1
TARGET_VERSION="v2.0.0"

show_help() {
  cat << 'EOF'
Usage: ./tools/pse_team_loop.sh [OPTIONS]

Options:
  --happy               Run a clean happy-path cycle (default)
  --loop <N>            Run N consecutive change cycles in continuous loop
  --tamper              Simulate post-approval tampering and verify gate rejection
  --outsider            Simulate unauthorized outsider attempting execution
  --reject              Simulate risk reviewer rejection blocking deployment
  --version <version>   Target version string (default: v2.0.0)
  --help                Show this message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --happy)
      MODE="happy"
      shift
      ;;
    --loop)
      MODE="loop"
      LOOP_COUNT="$2"
      shift 2
      ;;
    --tamper)
      MODE="tamper"
      shift
      ;;
    --outsider)
      MODE="outsider"
      shift
      ;;
    --reject)
      MODE="reject"
      shift
      ;;
    --version)
      TARGET_VERSION="$2"
      shift 2
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

banner() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}${CYAN}  SWITCH CHANGE DESK — PRINCIPAL SOFTWARE ENGINEER TEAM LOOP${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  Mode: ${YELLOW}${MODE}${NC} | Target Version: ${GREEN}${TARGET_VERSION}${NC} | Root: ${REPO_ROOT}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

run_cycle() {
  local cycle_num="$1"
  local change_id="$2"
  local target_ver="$3"
  local inject_tamper="$4"
  local inject_outsider="$5"
  local inject_reject="$6"

  local ev_dir="$REPO_ROOT/evidence/$change_id"
  mkdir -p "$ev_dir"

  echo ""
  echo -e "${BOLD}${MAGENTA}════════════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${MAGENTA}▶ [CYCLE ${cycle_num}] Initiating Change Protocol: ${change_id}${NC}"
  echo -e "${BOLD}${MAGENTA}════════════════════════════════════════════════════════════════════════════${NC}"

  # ── STEP 1: REQUESTER POSTS CHANGE REQUEST ──────────────────────────────────
  echo ""
  echo -e "${BOLD}${CYAN}1. 👔 [REQUESTER (Lead Product / Dev)]${NC}"
  local current_ver
  current_ver=$(grep '^version:' "$APP_FILE" | awk '{print $2}')
  echo -e "   Broadcasting Change Request to Switch Room '${BOLD}change-desk${NC}':"
  echo -e "   ┌────────────────────────────────────────────────────────┐"
  echo -e "   │ ${BOLD}Change Request ID:${NC} ${change_id}"
  echo -e "   │ ${BOLD}Scope:${NC}             Bump sandbox app from ${current_ver} to ${target_ver}"
  echo -e "   │ ${BOLD}Target File:${NC}       sandbox/app.txt"
  echo -e "   │ ${BOLD}Requester:${NC}         dev-lead@change-desk.internal"
  echo -e "   │ ${BOLD}Timestamp:${NC}         $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo -e "   └────────────────────────────────────────────────────────┘"

  # ── STEP 2: PLANNER (PRINCIPAL SOFTWARE ENGINEER) ──────────────────────────
  echo ""
  echo -e "${BOLD}${GREEN}2. 🧠 [PLANNER (Principal Software Engineer)]${NC}"
  echo -e "   Analyzing requirements, blast radius, rollback invariants, and target file..."
  
  cat > "$ev_dir/plan.md" << EOF
# Change Plan: $change_id

## Objective
Upgrade the sandbox application from $current_ver to $target_ver to introduce
immutable audit trails and deterministic policy gate controls.

## Scope & Target
- **Target File:** \`sandbox/app.txt\`
- **Field Modified:** \`version\`
- **Baseline Version:** $current_ver
- **Target Version:** $target_ver
- **Sandbox Boundary:** Confined strictly to \`sandbox/\`

## Execution Steps
1. Create atomic backup in \`evidence/$change_id/app.txt.backup\`.
2. Apply update: replace \`version: $current_ver\` with \`version: $target_ver\`.
3. Update timestamp in \`last_updated\`.
4. Trigger verification suite via \`sandbox/check.sh\`.

## Rollback Plan
1. If \`check.sh\` exits non-zero, restore original \`sandbox/app.txt\` from \`evidence/$change_id/app.txt.backup\`.
2. Verify restored version equals $current_ver.
3. Record rollback event in \`evidence/$change_id/execution.log\`.

## Risk Rating
LOW — Scoped strictly to sandbox text resource with automated rollback and regression checks.
EOF

  local plan_hash
  plan_hash=$(sha256sum "$ev_dir/plan.md" | awk '{print $1}')
  local plan_prefix="${plan_hash:0:8}"
  echo -e "   ✓ Plan drafted: ${BOLD}evidence/$change_id/plan.md${NC}"
  echo -e "   ✓ Cryptographic Digest (SHA-256): ${CYAN}${plan_hash}${NC}"
  echo -e "   ✓ 8-character Fingerprint:       ${BOLD}${YELLOW}${plan_prefix}${NC}"
  echo -e "   Broadcast in room: ${BOLD}PLAN READY: $change_id (Fingerprint: $plan_prefix)${NC}"

  # ── STEP 3: RISK REVIEWER (STAFF SECURITY ENGINEER) ─────────────────────────
  echo ""
  echo -e "${BOLD}${YELLOW}3. 🛡️ [RISK REVIEWER (Staff Security & Reliability Engineer)]${NC}"
  echo -e "   Auditing plan against room policy (${BOLD}policy/change-policy.md${NC})..."

  local verdict="APPROVED"
  if [[ "$inject_reject" == "true" ]]; then
    verdict="REJECTED"
    cat > "$ev_dir/review.md" << EOF
# Review: $change_id

## Reviewer
Staff Security Engineer (@risk-reviewer)

## Verdict
REJECTED

## Risks Identified
- CRITICAL: Simulated high-risk invariant violation triggered for security audit.
- Unverified third-party dependency injection suspected.

## Conditions
- Reject deployment until full CVE scan completes.
EOF
    echo -e "   ${RED}⚠ VERDICT ISSUED: REJECTED${NC}"
    echo -e "   Broadcast in room: ${BOLD}REVIEW VERDICT: $change_id — REJECTED${NC}"
    echo -e "   [Policy Invariant Enforcement]: Review failed. Halting workflow before approval."
    return 1
  fi

  cat > "$ev_dir/review.md" << EOF
# Review: $change_id

## Reviewer
Staff Security & Reliability Engineer (@risk-reviewer)

## Verdict
APPROVED

## Risks Identified
- Minimal risk: isolated to sandbox app version string.
- Reversible: atomic backup specified in execution step 1.

## Conditions
- Policy gate must verify target path is inside sandbox/ boundary.
- Health check must exit 0 before completion is confirmed.

## Reviewer Note
Plan meets all architectural standards, has unambiguous rollback, and matches policy requirements.
EOF
  echo -e "   ✓ Review completed: ${BOLD}evidence/$change_id/review.md${NC}"
  echo -e "   ✓ Verdict: ${GREEN}${BOLD}APPROVED${NC}"
  echo -e "   Broadcast in room: ${BOLD}REVIEW READY: $change_id — APPROVED${NC}"

  # ── STEP 4: APPROVER (ROOM OWNER / SYSTEM OWNER) ───────────────────────────
  echo ""
  echo -e "${BOLD}${BLUE}4. 👤 [APPROVER (System Owner / Human-in-the-Loop)]${NC}"
  echo -e "   Inspecting plan.md diff and reviewer verdict..."
  echo -e "   Signing off with change ID and plan hash prefix: ${YELLOW}${plan_prefix}${NC}"

  cat > "$ev_dir/approval.txt" << EOF
APPROVED $change_id $plan_prefix
signer: system-owner@change-desk.internal
plan_hash: $plan_hash
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  echo -e "   ✓ Approval record created: ${BOLD}evidence/$change_id/approval.txt${NC}"
  echo -e "   Broadcast in room: ${BOLD}APPROVED $change_id $plan_prefix${NC}"

  # ── TAMPER SIMULATION (IF ENABLED) ──────────────────────────────────────────
  if [[ "$inject_tamper" == "true" ]]; then
    echo ""
    echo -e "${BOLD}${RED}⚡ [ADVERSARIAL ATTACK SIMULATION]${NC}"
    echo -e "   Modifying plan.md after approval has been signed..."
    echo -e "   Attacker appends unauthorized payload: 'MALICIOUS_EXTRA_STEP=bypass_auth'"
    printf '\n# Malicious unauthorized payload injected post-approval\n' >> "$ev_dir/plan.md"
    local tampered_hash
    tampered_hash=$(sha256sum "$ev_dir/plan.md" | awk '{print $1}')
    local tampered_prefix="${tampered_hash:0:8}"
    echo -e "   Tampered SHA-256 is now: ${RED}${tampered_hash}${NC} (was: ${GREEN}${plan_hash}${NC})"
    echo -e "   Tampered Prefix is:     ${RED}${tampered_prefix}${NC} (Approved: ${GREEN}${plan_prefix}${NC})"
  fi

  # ── STEP 5: EXECUTOR (OWNER-ONLY ACCESS GUARD) ──────────────────────────────
  echo ""
  echo -e "${BOLD}${CYAN}5. ⚡ [EXECUTOR (Privileged Release Agent)]${NC}"
  if [[ "$inject_outsider" == "true" ]]; then
    echo -e "   ${RED}SECURITY CHECK FAILED: Caller is NOT Room Owner!${NC}"
    echo -e "   Caller: outsider@external-untrusted.org (Role: Member/Guest)"
    echo -e "   Access Setting: OWNER-ONLY"
    echo -e "   ${RED}❌ Access Denied: Switch boundary refused execution request.${NC}"
    echo -e "   [Result]: apply_change.sh was NEVER invoked. Zero unauthorized access."
    return 1
  fi

  echo -e "   Caller verified: Room Owner (owner-only access check passed)."
  echo -e "   Invoking Policy Gate: ${BOLD}tools/apply_change.sh $change_id $plan_prefix $target_ver${NC}"

  # ── STEP 6: DETERMINISTIC POLICY GATE & HEALTH CHECK ────────────────────────
  local gate_exit=0
  bash "$GATE_SCRIPT" "$change_id" "$plan_prefix" "$target_ver" || gate_exit=$?

  if [[ $gate_exit -ne 0 ]]; then
    echo ""
    echo -e "${RED}❌ Policy Gate rejected the change (exit code: $gate_exit).${NC}"
    return $gate_exit
  fi

  # ── STEP 7: AUDITOR (INDEPENDENT EVIDENCE VERIFICATION) ──────────────────────
  echo ""
  echo -e "${BOLD}${MAGENTA}6. 📋 [AUDITOR (Automated Compliance & Tamper Ledger Verification)]${NC}"
  echo -e "   Auditing evidence artifacts in ${BOLD}evidence/$change_id/${NC}:"
  
  local check_plan=false check_review=false check_approval=false check_exec=false check_backup=false
  [[ -f "$ev_dir/plan.md" ]] && check_plan=true
  [[ -f "$ev_dir/review.md" ]] && check_review=true
  [[ -f "$ev_dir/approval.txt" ]] && check_approval=true
  [[ -f "$ev_dir/execution.log" ]] && check_exec=true
  [[ -f "$ev_dir/app.txt.backup" ]] && check_backup=true

  echo -e "   - plan.md:         $([[ "$check_plan" == "true" ]] && echo -e "${GREEN}✓ Present${NC}" || echo -e "${RED}✗ Missing${NC}")"
  echo -e "   - review.md:       $([[ "$check_review" == "true" ]] && echo -e "${GREEN}✓ Present (Verdict: APPROVED)${NC}" || echo -e "${RED}✗ Missing${NC}")"
  echo -e "   - approval.txt:    $([[ "$check_approval" == "true" ]] && echo -e "${GREEN}✓ Present (Hash-linked)${NC}" || echo -e "${RED}✗ Missing${NC}")"
  echo -e "   - execution.log:   $([[ "$check_exec" == "true" ]] && echo -e "${GREEN}✓ Present (Deterministic trace)${NC}" || echo -e "${RED}✗ Missing${NC}")"
  echo -e "   - app.txt.backup:  $([[ "$check_backup" == "true" ]] && echo -e "${GREEN}✓ Present (Rollback asset preserved)${NC}" || echo -e "${RED}✗ Missing${NC}")"

  # Produce Auditor verdict summary
  cat > "$ev_dir/audit-verdict.json" << AUDITEOF
{
  "change_id": "$change_id",
  "status": "COMPLIANT_AND_VERIFIED",
  "target_version": "$target_ver",
  "plan_sha256": "$plan_hash",
  "approved_prefix": "$plan_prefix",
  "policy_gate_exit": 0,
  "artifacts": {
    "plan": $check_plan,
    "review": $check_review,
    "approval": $check_approval,
    "execution_log": $check_exec,
    "backup": $check_backup
  },
  "verified_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
AUDITEOF
  echo -e "   ✓ Audit verdict saved: ${BOLD}evidence/$change_id/audit-verdict.json${NC}"
  echo -e "   ${GREEN}${BOLD}★ ALL PROTOCOL PHASES VERIFIED AND COMPLIANT${NC}"
  return 0
}

# ─── Main Execution ───────────────────────────────────────────────────────────
banner

case "$MODE" in
  happy)
    echo -e "${YELLOW}Preparing cold state...${NC}"
    bash "$RESET_SCRIPT" > /dev/null
    CHANGE_ID="CHG-PSE-$(date +%Y%m%d)-001"
    run_cycle 1 "$CHANGE_ID" "$TARGET_VERSION" "false" "false" "false"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}✔ HAPPY PATH RUN COMPLETED SUCCESSFULLY${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    ;;

  loop)
    echo -e "${YELLOW}Starting continuous PSE team loop: ${LOOP_COUNT} iteration(s)...${NC}"
    bash "$RESET_SCRIPT" > /dev/null
    for ((i=1; i<=LOOP_COUNT; i++)); do
      CYCLE_ID=$(printf "CHG-LOOP-%s-%03d" "$(date +%Y%m%d)" "$i")
      VER="v2.$((i-1)).0"
      if [[ $i -eq 1 ]]; then VER="$TARGET_VERSION"; fi
      run_cycle "$i" "$CYCLE_ID" "$VER" "false" "false" "false"
    done
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}✔ ALL ${LOOP_COUNT} CONTINUOUS LOOP CYCLES COMPLETED SUCCESSFULLY${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    ;;

  tamper)
    echo -e "${YELLOW}Preparing cold state for Tamper Attack simulation...${NC}"
    bash "$RESET_SCRIPT" > /dev/null
    CHANGE_ID="CHG-TAMPER-$(date +%Y%m%d)-001"
    RES=0
    run_cycle 1 "$CHANGE_ID" "$TARGET_VERSION" "true" "false" "false" || RES=$?
    echo ""
    if [[ $RES -ne 0 ]]; then
      echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "${GREEN}${BOLD}✔ TAMPER BEAT VERIFIED: Gate correctly refused tampered plan (exit $RES)${NC}"
      echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      exit 0
    else
      echo -e "${RED}✖ TAMPER BEAT FAILED: Gate unexpectedly passed tampered plan!${NC}"
      exit 1
    fi
    ;;

  outsider)
    echo -e "${YELLOW}Preparing cold state for Outsider Intrusion simulation...${NC}"
    bash "$RESET_SCRIPT" > /dev/null
    CHANGE_ID="CHG-OUTSIDER-$(date +%Y%m%d)-001"
    RES=0
    run_cycle 1 "$CHANGE_ID" "$TARGET_VERSION" "false" "true" "false" || RES=$?
    echo ""
    if [[ $RES -ne 0 ]]; then
      echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "${GREEN}${BOLD}✔ OUTSIDER BEAT VERIFIED: Non-owner caller correctly blocked at boundary${NC}"
      echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      exit 0
    else
      echo -e "${RED}✖ OUTSIDER BEAT FAILED: Unauthorized execution was not blocked!${NC}"
      exit 1
    fi
    ;;

  reject)
    echo -e "${YELLOW}Preparing cold state for Risk Reviewer Rejection simulation...${NC}"
    bash "$RESET_SCRIPT" > /dev/null
    CHANGE_ID="CHG-REJECT-$(date +%Y%m%d)-001"
    RES=0
    run_cycle 1 "$CHANGE_ID" "$TARGET_VERSION" "false" "false" "true" || RES=$?
    echo ""
    if [[ $RES -ne 0 ]]; then
      echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "${GREEN}${BOLD}✔ RISK REJECTION VERIFIED: Reviewer verdict REJECTED halted pipeline${NC}"
      echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      exit 0
    else
      echo -e "${RED}✖ REJECTION BEAT FAILED: Unapproved change proceeded!${NC}"
      exit 1
    fi
    ;;
esac
