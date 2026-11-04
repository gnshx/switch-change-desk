# Plan: CHG-20261104-001

## Objective
Bump sandbox app from v1.0.0 to v2.0.0 to demonstrate the Change Desk policy workflow.

## Steps
1. Update the version field in sandbox/app.txt from v1.0.0 to v2.0.0
2. Run sandbox/check.sh to verify the new version is valid and the app is healthy

## Rollback
1. Restore sandbox/app.txt from the backup at evidence/CHG-20261104-001/app.txt.backup
2. Run sandbox/check.sh to confirm the rollback succeeded and version is v1.0.0 again

## Risk Rating
LOW — only a version string in a sandboxed text file is changed; check.sh validates the result immediately after.
