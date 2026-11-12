# The quick route: the smallest change, with one question

- **Date:** 2026-11-12
- **Plugins:** core 0.8.0, engineering 0.6.0

## Why
The lite route still asks for a conversation: an exploration a question at a time, a confirmation of the focus, an outline, an independent check. For one small request that is more effort than the change. A quick route does the reading itself, tells you what it found, and asks once.

## Added
- `/tt-workflow-quick` (engineering): given a task in words, it links a folder (the lite route's own link file and documents), runs `tt-familiarise` in **quick mode**, reports what it found and assumes, and asks **Go** · **Adjust** · **Stop**. After Go it runs `tt-lite-brief` in **quick mode** and `tt-execute-lite … confirmed`. Review (`tt-branch-review`) is offered at the end, never run.
- `tt-familiarise` quick mode (`Pace: quick` in the prompt): no questions; mapping and trace subagents fill in the Change facts; acceptance the task did not state is written `(proposed)` and confirmed by the Go. The Focus Log header gains `**Pace:** quick`.
- `tt-lite-brief` quick mode (`quick` after the Focus Log): no confirmation, outline or independent-check questions; the recommended answer is taken for each small design choice and recorded as "Default applied (quick)". **A Critical Decision is still put to the engineer.** More than about six tasks is not quick and is handed back.
- `quick.sh` (`tt-workflow-quick/scripts`): `start`, `state`, `link`, `unlink`, `new` and `linked` are `lite.sh`'s; `confirm <focus log>` writes `Focus confirmed <date>` (LF or CRLF logs) and the `**Pace:** quick` marker, and records `explore.focus_confirmed`.

## Changed
- `workflow-state.sh`: a lite Focus Log marked `**Pace:** quick` names `tt-workflow-quick "<folder>"` as the next step (in place of `tt-lite-brief` or `tt-familiarise resume`), so Continue resumes in quick style. Logs without the marker are unchanged.
- `session-handoff.sh`: a quick task's next session starts `/tt-workflow-quick "<folder>"` directly instead of through the lite entry.
- `tt-workflow-lite` hands a quick task back to `tt-workflow-quick`; `toolbox.md`, the guide's fallback list, the READMEs and `model-roles.tsv` list the new skill.

## Notes
- `tt-workflow-quick` calls `tt-execute-lite "<brief>" confirmed`. The `confirmed` argument arrives with the "questions are asked with options" change (`2026-11-12-ask-with-buttons.md`, core 0.9.0 / engineering 0.7.0). On the quick route's own release (core 0.8.0 / engineering 0.6.0) `tt-execute-lite` still works without it and asks its one Start question.
- Nothing in the quick route is specific to a front end. A caller starts it with `/tt-workflow-quick "<folder>" <the task, or a document naming it>`.
- A bug does not go this way: use `/tt-workflow-lite bug`.
