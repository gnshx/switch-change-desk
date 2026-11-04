# ─────────────────────────────────────────────────────────────────────────────
# change-desk Makefile
# Principal Software Engineer Team — Build, Test, Demo & CI Targets
# Default target: help
# ─────────────────────────────────────────────────────────────────────────────

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Repo root is the directory containing this Makefile
REPO_ROOT := $(shell pwd)

# Change ID for the live happy-path demo target
DEMO_ID := CHG-$(shell date +%Y%m%d)-001

# ─── Targets ──────────────────────────────────────────────────────────────────

.PHONY: help check reset test demo-happy demo-tamper loop loop-tamper loop-outsider loop-reject loop-continuous ci clean

## help: Print all available targets with descriptions (default)
help:
	@echo ""
	@echo "  change-desk — Principal Engineering targets"
	@echo "  ──────────────────────────────────────────────────────────"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /'
	@echo ""

## check: Run the sandbox health check (sandbox/check.sh)
check:
	@bash $(REPO_ROOT)/sandbox/check.sh

## reset: Reset sandbox to v1.0.0 and clear evidence/ (demo/reset.sh)
reset:
	@bash $(REPO_ROOT)/demo/reset.sh

## test: Run the 5-test gate test suite (tools/test_gate.sh)
test:
	@bash $(REPO_ROOT)/tools/test_gate.sh

## demo-happy: Run the happy-path fixture demo (uses CHG-DEMO-001)
demo-happy:
	@bash $(REPO_ROOT)/demo/run_happy_path.sh

## demo-tamper: Run the tamper-beat demo (expects gate to reject tampered plan)
demo-tamper:
	@bash $(REPO_ROOT)/demo/run_tamper_beat.sh

## loop: Run full Principal Software Engineer team multi-agent lifecycle
loop:
	@bash $(REPO_ROOT)/tools/pse_team_loop.sh --happy

## loop-tamper: Run PSE team loop with post-approval tamper injection
loop-tamper:
	@bash $(REPO_ROOT)/tools/pse_team_loop.sh --tamper

## loop-outsider: Run PSE team loop simulating non-owner access refusal
loop-outsider:
	@bash $(REPO_ROOT)/tools/pse_team_loop.sh --outsider

## loop-reject: Run PSE team loop simulating risk reviewer rejection
loop-reject:
	@bash $(REPO_ROOT)/tools/pse_team_loop.sh --reject

## loop-continuous: Run continuous loop across multiple consecutive changes
loop-continuous:
	@bash $(REPO_ROOT)/tools/pse_team_loop.sh --loop 3

## ci: Run entire validation suite (checks, tests, fixtures, and PSE loops)
ci: check test demo-happy demo-tamper loop loop-tamper loop-outsider loop-reject
	@echo ""
	@echo "  ★ ALL CI & POLICY GATE TARGETS PASSED ★"
	@echo ""

## clean: Alias for reset — same as 'make reset'
clean: reset
