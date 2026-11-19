# Breaks answered outside the chat

- **Date:** 2026-11-19
- **Plugins:** core 0.10.0, engineering 0.8.0

## Why
Where a skill stops and asks "Continue, or stop here?" (after each planning stage, before the next skill, and before an adversary challenge), a companion app can show the choice as Continue, Skip and Stop buttons. For that the skill must not ask in the chat, and a skip must be carried out by script, not by the model editing a table. Decisions already work this way (`TT_DECIDE`); breaks now do too.

## Added
- `TT_BREAK=elsewhere` and `tt-common/scripts/breaks.sh` (`mode`, `wait`, `show`, `answer`, `take`, `clear`). A skill records the wait, says so in a line and ends its turn; the answer is recorded by `breaks.sh answer`, and the skill reads it with `take` when it is next started. Without `TT_BREAK` nothing changes. The protocol is `tt-common/breaks.md`.
- `stages.sh skip-challenge [--check] <folder> <stage> [reason]`: closes a stage of the draft plan whose adversary challenge is pending, as `Closed (challenge skipped: <reason>)`. Any planning stage's challenge may be skipped; the stages that can't be left out (Requirements, Technical Design, Sign-off, Build) still can't.
- Ledger event `workflow.waiting` (`qualifier` is `<kind>:<step>`), written by `breaks.sh wait`.
- `tt-adversarial-plan` (before each challenge, and at its break point), `tt-workflow` and `tt-workflow-lite` (their one confirmation) follow it in `elsewhere` mode.

## Notes
- `tt-execute` and `tt-execute-lite` still offer to continue after a work unit in the chat; a companion app has its own break for that.
- A wait whose answer is `skip` has already been carried out when the skill starts again: it goes on from the documents' state.
