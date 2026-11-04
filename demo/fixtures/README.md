# Demo Fixtures — CHG-DEMO-001

These are pre-written fixture files for the happy-path demo.

They let you run a clean, reliable demo even if the AI agents are offline or unavailable.

## Files

| File | Purpose |
|------|---------|
| `plan.md` | Pre-written plan for bumping v1.0.0 → v2.0.0 |
| `review.md` | Pre-written APPROVED review |
| `plan-hash.txt` | The SHA-256 of `plan.md` (do not modify plan.md or this will be wrong) |

## How to Use

The `demo/run_happy_path.sh` and `demo/run_tamper_beat.sh` scripts copy these files automatically.

You can also use them manually:

```bash
# Copy fixtures to evidence
mkdir -p evidence/CHG-DEMO-001
cp demo/fixtures/CHG-DEMO-001/plan.md evidence/CHG-DEMO-001/
cp demo/fixtures/CHG-DEMO-001/review.md evidence/CHG-DEMO-001/

# Get hash prefix
HASH_PREFIX=$(cat demo/fixtures/CHG-DEMO-001/plan-hash.txt | cut -c1-8)
echo "APPROVED CHG-DEMO-001 $HASH_PREFIX" > evidence/CHG-DEMO-001/approval.txt

# Run gate
./tools/apply_change.sh CHG-DEMO-001 "$HASH_PREFIX" v2.0.0
```

## ⚠️ Do Not Modify `plan.md`

If you modify `plan.md`, recompute the hash:

```bash
sha256sum demo/fixtures/CHG-DEMO-001/plan.md | awk '{print $1}' > demo/fixtures/CHG-DEMO-001/plan-hash.txt
```
