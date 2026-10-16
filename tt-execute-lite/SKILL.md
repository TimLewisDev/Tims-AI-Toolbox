---
name: tt-execute-lite
description: >
  Build a small change from a Lite Brief (from tt-lite-brief): create or resume
  its Task Status, run each Agent task in its own tt-coder subagent and each
  Engineer task as a checklist, then validate the work unit (the agent checks
  by script, the engineer's inline in chat). The Lite Brief is the only plan, so
  there is no plan to drift from and no breakdown to amend; a change to the
  goal, the acceptance or a decision goes back to tt-lite-brief. It is the only
  writer of the Task Status while it runs. Never writes production code itself
  and never commits. Use when asked to build, continue, resume or report on a
  Lite Brief. For a Task Breakdown or Task Status from the full pipeline, use
  tt-execute.
argument-hint: "[status] <lite brief>"
metadata:
  version: "1.0"
---

# tt-execute-lite

## Usage

```
/tt-execute-lite <lite brief>          # report, then work the unit
/tt-execute-lite status <lite brief>   # report only (steps 1–3)
```

If the argument is missing, or isn't a Lite Brief (its title doesn't end
"Lite Brief", or `lite-check.sh` can't read it), ask and stop. A Comprehensive
Tech Plan means `/tt-task-breakdown`; a Task Breakdown or Task Status means
`/tt-execute`. Do not guess from the working tree.

## How to run this skill

The Lite Brief is the plan, the breakdown and the source of every card; the
Task Status beside it (`<doc folder>/<Prefix> - Task Status.md`) is the resume
point. Assume the session starting now knows nothing else. `<skill>` is this
skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is `<skill>/../tt-common`,
`<scripts>` is `<common>/scripts`, and `<run>` is
`<doc folder>/.tt/<Prefix> - Task Status/` (snapshots, result files and
validation logs).

1. Read `<common>/orchestration.md`: the output budget, stall recovery,
   subagents and scripts.
2. Read `<common>/breakdown-rules-compact.md`. Consult only the matching
   sections of `<common>/breakdown-rules.md` when a definition or example is
   needed.
3. Then follow the steps below. The handoff template is
   `<skill>/../tt-execute/templates/handoff.md` (`handoff.sh` fills it).

You are the orchestrator and the **only writer of the Task Status**. Keep your
context small: never load cards you aren't about to hand over, never implement
a task yourself, never read whole documents when a section will do, and
**never type into a document or a prompt what a script can write**. In every
script call below the Lite Brief is the `<brief>`; it plays the breakdown and
the plan. Routine updates:

| Update | Script |
|---|---|
| A task's or unit's status (the unit and header follow) | `status-set.sh <status> <ID> "<Status>" [--note <text>]` |
| A task's Step Log entry, risks and improvements, from its result file | `status-log.sh <status> <run>/results/<ID>.md` |
| A decision, change, risk, improvement, validation attempt or one check's result | `status-record.sh <status> <kind> …` |

Each prints one line per change, never the document. Run any with `-h`. If one
exits `2` (it can't parse the document), make that update by hand under
`tt-task-status`'s rules and tell the engineer which script failed.

## 1. Load

- Check the brief: `bash "<scripts>/lite-check.sh" "<brief>"`. Findings mean the
  brief isn't ready: show them and send the engineer to
  `/tt-lite-brief revise "<brief>"`; stop.
- No Task Status beside it yet (with `status`: say so and stop, creating nothing): `bash "<scripts>/status-init.sh" --label "Lite Brief" "<brief>" "<status>"`.
  There is only ever one.
- `bash "<scripts>/execute-load.sh" "<status>" "<brief>"` prints the status
  header, Resume Here and boards, the brief's header and Work Units, and the
  current unit's block. Read the rest of the brief only when a step needs it.
- `git fetch` once and pin `BASE_SHA`.

## 2. Pre-flight

```
bash "<scripts>/continue-preflight.sh" "<status>" "<brief>" --plan "<brief>"
```

It checks, without a model: the boards against the brief, the branch, files on
disk for Implemented, Done and Todo tasks, git changes to In Progress tasks'
files, validation evidence made stale by later commits, and the header's derived
fields. The plan line will say the document is its own plan; ignore it.

- `derived` rows: fix with `status-set.sh <status> --refresh`, no confirmation.
- `fact` rows: present each with its proposed correction; apply it only after
  the engineer confirms (through the scripts), and log it with
  `status-record.sh <status> change …`.
- `judge` rows (an In Progress task): read `git diff` on that task's card files
  against its Steps and say how far it got.
- `needs_model: no` and no rows: say so in one line.

If the script exits `2`, reconcile by hand with `tt-task-status` and tell the
engineer. There are no reconcile or plan-drift subagents here.

## 3. Report and confirm

Give the `tt-task-status summary` (from what `execute-load.sh` printed): the
goal in a line, the unit's outcome and who validates it, the tasks with their
executors, and what is done. For a unit that is `Ready to Validate`, go
straight to step 5. With `status`, stop here: it never creates anything, so if no Task Status exists
yet (step 1), say so, give the `lite-check.sh` result and the task list from the
brief, and stop.

Otherwise ask **once** (`AskUserQuestion`): **Start** · **Stop**. After that,
work the tasks in ID order as their dependencies allow, back to back, without
per-task confirmation. Stop at every Critical Decision and every Engineer task.
Tasks run one at a time.

## 4. Each task

1. **Pre-flight.** `md-section.sh get "<brief>" "### T01 —" | verify-refs.sh --worktree --only-problems -`.
   If something moved, correct the card, log it, and escalate if it changed
   materially.
2. **Start.** `task-files.sh snapshot "<brief>" "<run>" T01`, then
   `status-set.sh "<status>" T01 "In Progress"`. Both **before** the subagent.
3. **Execute.**
   - **Agent task:** `handoff.sh "<brief>" "<status>" T01 --run "<run>" --base-sha "<BASE_SHA>" --plan "<brief>"`
     prints the whole prompt. Spawn one coder subagent (model and effort from `model-config.sh get coder`)
     (general-purpose, foreground) with that output, unchanged. It reads the
     card from the brief and writes `<run>/results/T01.md`. If the script
     fails, fill in `<skill>/../tt-execute/templates/handoff.md` by hand.
   - **Engineer task:** show the card's Steps as a checklist and wait. Then
     `result-scaffold.sh "<brief>" T01 --run "<run>" > "<run>/results/T01.md"`,
     fill in its markers with what the engineer reports.
4. **Scope check.** `task-files.sh diff "<brief>" "<run>" T01`. Exit `1` means a
   file changed that isn't on the card: name it; the engineer keeps it (log a
   card correction) or reverts it. A card file left `untouched` with the task
   `implemented` is worth one question.
5. **Record.** `status-log.sh "<status>" "<run>/results/T01.md"`. Don't read the
   result file back unless the script reports a critical decision or fails.
6. **Escalation.** If it reports `critical decision: yes`: read only that
   section, check its evidence, present it with
   `<common>/templates/critical-decision.md`, record the choice with
   `status-record.sh … decision …`, name it on the task
   (`status-set.sh … T01 Blocked --note "<D-ID>: <line>"`, then
   `"In Progress" --note ""` once decided). Continue the same subagent with
   SendMessage, giving the decision; if it can't be continued, spawn a new one
   with the handoff, the decision and "inspect `git diff` on the card's Files to
   see the work so far". If the decision changes the goal, the acceptance or an
   earlier decision, stop and send the engineer to `/tt-lite-brief revise`.
7. **Next.** The unit's next task, or step 5 if this was the last.

## 5. Validate the unit

A brief usually has one unit (`WU1`); if it has two, finish and validate the first
before starting the second (Load shows the current one). `<WU>` below is the
current unit. When every task in it is `Implemented`:

1. `status-set.sh "<status>" <WU> "Ready to Validate"`.
2. **Agent checks:**
   ```
   bash "<scripts>/run-checks.sh" "<brief>" <WU> "<run>/validation/<WU>-attempt<n>" --why "<first run | after fix T03 | evidence stale>"
   ```
   It runs the unit's `checks` block, saves each output, prints one row per
   check, and writes `attempt.md`. Check by hand any it reports `blocked`. If it
   exits `2` (no `checks` block), run the Agent checks by hand and write the
   attempt file in the same format.
3. **Record and report.** `status-record.sh "<status>" validation <WU> --file "<run>/validation/<WU>-attempt<n>/attempt.md"`;
   report each agent check inline: what was run, passed or failed, the evidence.
4. If the unit needs the engineer, `validation-checklist.sh "<brief>" "<status>" <WU>`
   gathers the open Engineer checks, the unit's engineer steps and the tasks'
   To validate notes. Turn it into the checklist **in chat**: numbered, one
   check per item; for each, exactly what to open and do, what they should see
   and what to report back; concrete file paths, menu items, field names and
   values (look the target up with a quick `git grep` if the draft is vague);
   edge cases as their own items; end with "Ask me about any step if you need
   more detail." An **Agent + Engineer** check passes only when both parts pass.
5. Wait for the answers; a question isn't a result. Record each as it arrives:
   `status-record.sh "<status>" check <WU> <n> passed|failed|waived --evidence "<what they reported>"`.
6. **All pass:** `status-set.sh "<status>" <WU> Done`.
7. **Any check fails:** `status-set.sh "<status>" <WU> Failed --note "check <n>"`.
   Trace it to the task that caused it and propose a fix task:
   `fix-card.sh "<brief>" <WU> --after <cause> --check <n>` prints its ID, the
   rows for the tables and boards, and the card with the known fields filled.
   Fill in the rest (card rules in `tt-task-breakdown/templates/task-card.md`),
   dropping the **Plan step** and **Traces to** rows and the plan lines under
   **Read first**, which a Lite Brief doesn't have, and once the engineer approves, add the card to the brief, run
   `lite-index.sh "<brief>"`, add the board rows, and log it with
   `status-record.sh … change …`. When it is implemented, re-run the **whole**
   unit's validation as a new attempt.

## 6. Done

If the brief has a later unit whose dependencies are now `Done`, report it as the
next one and, after the engineer confirms, go back to step 4 for it. Otherwise
say what was built, what the checks showed, and anything left (risks and
improvements recorded in the Step Log). Do not offer to commit: the engineer
decides what to commit and when.

If that was the last unit and `status-set.sh` reported `header State: Complete`,
the change is finished: run `bash "<scripts>/tatty.sh" celebrate`, show its
output in a code block, and congratulate the engineer in a sentence or two
before the summary. Say plainly that the change is finished and that
committing is theirs.

## Amending the brief

A path, a line reference or a card step the code has outgrown may be corrected
on the card and logged with `status-record.sh … change …`; fixing a reference
needs no approval, but is still logged. Anything that changes the goal, an
acceptance item, a decision or a unit's checks stops the run: the engineer
amends it with `/tt-lite-brief revise "<brief>"`, then resumes here. IDs are
stable; a removed task is marked `Dropped`, never deleted.

## Guardrails

The shared guardrails in `<common>/breakdown-rules-compact.md` apply. In
addition:

- One unit at a time, one task at a time. Never mark a unit `Done` while a
  check still needs the engineer.
- Never write production code, even for a one-line fix: that is a task for a
  coder subagent, or a fix task.
- Never stage, commit, push or create branches, and never offer to.
