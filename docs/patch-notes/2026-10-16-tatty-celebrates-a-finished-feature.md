# Tatty celebrates a finished feature

- **Date:** 2026-10-16

## Added
- `tatty.sh celebrate`: Tatty with raised arms and confetti, and a congratulation picked from `tt-common/celebrate-quips.txt`.
- `tt-execute` and `tt-execute-lite` show it, and congratulate the engineer, when the last work unit is Done and the Task Status reads `State: Complete`.

## Changed
- `workflow.sh start` (and so `lite.sh start`) shows the party Tatty instead of the plain one when the linked folder holds a single feature that is built and validated.
- `tt-workflow`, `tt-workflow-lite`, `tt-common` and the README describe the finish.
- `tools/test-scripts.sh` covers `celebrate` and the finished-feature start.
