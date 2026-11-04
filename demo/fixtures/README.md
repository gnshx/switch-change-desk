# Demo Fixtures — CHG-20261104-001 / CHG-DEMO-001

These are pre-written fixture files for offline demo execution and regression testing.

They allow evaluators to verify the policy gate, tamper detection, and automatic rollback without needing live AI agents or Switch Console running.

## Files

| File | Purpose |
|------|---------|
| `plan.md` | Pre-written plan for bumping v1.0.0 → v2.0.0 |
| `review.md` | Pre-written APPROVED review with cryptographically bound plan hash |
| `plan-hash.txt` | The SHA-256 digest of `plan.md` |

## How to Run

Use the automated demo scripts:

```bash
make demo-happy      # Runs demo/run_happy_path.sh (happy path)
make demo-tamper     # Runs demo/run_tamper_beat.sh (tamper detection)
make demo-rollback   # Runs demo/run_rollback_beat.sh (automatic rollback)
```

Or run the full 12-test regression suite:

```bash
make test
```
