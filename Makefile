# ─────────────────────────────────────────────────────────────────────────────
# change-desk Makefile
# Targets for running tests, demo fixtures, approval CLI, and offline simulation.
# Default target: help
# ─────────────────────────────────────────────────────────────────────────────

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

REPO_ROOT := $(shell pwd)
CHANGE_ID ?= CHG-$(shell date +%Y%m%d)-001

.PHONY: help check reset test demo-happy demo-tamper demo-rollback approve sim ci clean

## help: Print all available targets with descriptions (default)
help:
	@echo ""
	@echo "  change-desk — Makefile targets"
	@echo "  ──────────────────────────────────────────────────────────"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /'
	@echo ""

## check: Run sandbox health check (sandbox/check.sh)
check:
	@bash $(REPO_ROOT)/sandbox/check.sh

## reset: Reset sandbox to v1.0.0 and clear evidence/ (demo/reset.sh)
reset:
	@bash $(REPO_ROOT)/demo/reset.sh

## test: Run the 12-test policy gate regression suite (tools/test_gate.sh)
test:
	@bash $(REPO_ROOT)/tools/test_gate.sh

## demo-happy: Run happy-path offline fixture demo (demo/run_happy_path.sh)
demo-happy:
	@bash $(REPO_ROOT)/demo/run_happy_path.sh

## demo-tamper: Run tamper-beat offline fixture demo (demo/run_tamper_beat.sh)
demo-tamper:
	@bash $(REPO_ROOT)/demo/run_tamper_beat.sh

## demo-rollback: Run automatic rollback beat demo (demo/run_rollback_beat.sh)
demo-rollback:
	@bash $(REPO_ROOT)/demo/run_rollback_beat.sh

## approve: Run interactive human approval CLI (tools/approve.sh <id>)
approve:
	@bash $(REPO_ROOT)/tools/approve.sh $(CHANGE_ID)

## sim: Run offline simulation harness (tools/offline_sim.sh)
sim:
	@bash $(REPO_ROOT)/tools/offline_sim.sh --happy

## ci: Run entire offline regression & demo suite
ci: check test demo-happy demo-tamper demo-rollback sim
	@echo ""
	@echo "  ★ ALL REGRESSION SUITE & DEMO FIXTURES PASSED ★"
	@echo ""

## clean: Alias for reset
clean: reset
