---
name: tt-execute
description: >
  Work through a Task Breakdown (from tt-task-breakdown) one work unit at a
  time, from its Task Status document: reconcile the status with the repo,
  report progress, run each Agent task in its own tt-coder subagent and each
  Engineer task as a checklist, then validate the unit (the agent checks by
  script, the engineer's inline in chat). It is the only writer of the Task
  Status while it runs, and amends the breakdown only through logged
  amendments. Never writes production code itself and never commits. Use when
  asked to continue, resume, execute or report progress on an existing
  breakdown.
metadata:
  version: "1.0"
---

# tt-execute

## Usage

```
/tt-execute <task status doc>          # report, then work the current unit
/tt-execute status <task status doc>   # report only (steps 1–3)
```

If the argument is missing, or isn't a Task Status document, ask and stop. Do
not guess from the working tree. If you're handed a Comprehensive Tech Plan,
that's `/tt-task-breakdown`.

## How to run this skill

The Task Status document is the resume point. Assume the session starting now
knows nothing else. `<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`),
`<common>` is `<skill>/../tt-common`, `<scripts>` is `<common>/scripts`, and
`<run>` is `<doc folder>/.tt/<Prefix> - Task Status/` (snapshots, result files
and validation logs).

1. Read `<common>/orchestration.md`: the output budget, stall recovery,
   subagents and scripts.
2. Read `<common>/breakdown-rules-compact.md`. Consult only the matching
   sections of `<common>/breakdown-rules.md` when a definition or example is
   needed. Read the task/work-unit and plain-English sections only when
   writing a fix task.
3. Then follow the steps below. Briefs are in `<skill>/briefs/` and templates
   in `<skill>/templates/` and `<common>/templates/`.

You are the orchestrator and the **only writer of the Task Status**. Keep your
context small: never load cards you aren't about to hand over, never implement
a task yourself, never read whole documents when a section will do, and
**never type into a document or a prompt what a script can write**. Every
routine update is one script call:

| Update | Script |
|---|---|
| A task's or unit's status (with the unit and header following) | `status-set.sh <status> <ID> "<Status>" [--note <text>]` |
| A task's Step Log entry, risks and improvements, from its result file | `status-log.sh <status> <run>/results/<ID>.md` |
| A decision, breakdown change, risk, improvement, validation attempt or one check's result | `status-record.sh <status> <kind> …` |

Each prints one line per change, never the document. Run any of them with `-h`
for its options. If one exits `2` (it can't parse the document), make that
update by hand under `tt-task-status`'s rules and tell the engineer which
script failed.

## 1. Load

- `bash "<scripts>/execute-load.sh" "<status>" "<breakdown>"`. It prints the
  status header, Resume Here and both boards, the breakdown's header and Work
  Units table, and the current unit's block up to its first card. Read the plan
  sections the cards cite only when a step needs them.
- `git fetch` once and pin `BASE_SHA`.
- Invoke `tt-task-status` only when you need an operation no script covers
  (a reconcile correction that needs judgement, a hand-made update after a
  script failed).

## 2. Pre-flight: reconcile and plan drift

```
bash "<scripts>/continue-preflight.sh" "<status>" "<breakdown>"
```

It checks, without a model: the boards against the breakdown, the branch,
files on disk for Implemented, Done and Todo tasks, git changes to In Progress
tasks' files, validation evidence made stale by later commits, the header's
derived fields, and the plan's revision against "Plan read". Read its TSV and
its two summary lines.

- `derived` rows: fix with `status-set.sh <status> --refresh`, no confirmation
  needed.
- `fact` rows: present each with its proposed correction; apply it only after
  the engineer confirms (through the scripts, and log it with
  `status-record.sh <status> change …`).
- `judge` rows (an In Progress task): read `git diff` on that task's card files
  against its Steps and say how far it got.
- `plan: … (drift)`: only now spawn the plan-drift subagent (`model-config.sh get drift-check`,
  `<skill>/briefs/plan-drift.md`), given the plan, the "Plan read" revision,
  the current unit and the later units' IDs. A plan change that affects a card
  or a unit's checks goes through the amendment rules.
- `needs_model: no` and no rows: nothing to reconcile; say so in one line.

If the script exits `2`, fall back to the reconcile subagent (`model-config.sh get drift-check`,
`<common>/../tt-task-status/briefs/reconcile.md`) and, if the plan's revision
can't be read, the plan-drift one.

## 3. Report

Give the engineer the `tt-task-status summary` (from what `execute-load.sh`
printed), plus:

- for a unit that is `Ready to Validate`: go straight to step 6 and give the
  inline validation checklist;
- the next action: the next task in the current unit, or the next unit (ID,
  outcome, plain-English summary, who validates it).

With `status`, stop here.

## 4. Choose the next work

- Finish the current unit (all its tasks, then its validation) before starting
  another.
- Otherwise take the first `Todo` unit whose dependencies are all `Done`.
  Confirm with the engineer **once, before starting the unit**.
- Within the unit, work its tasks in ID order as their dependencies allow,
  back to back, without per-task confirmation. Stop at every Critical Decision
  and every Engineer task. Pause between tasks only if the engineer asks.

## 5. Each task

1. **Pre-flight.** Check the card's references against the working tree:
   `md-section.sh get <breakdown> "### T07 —" | verify-refs.sh --worktree --only-problems -`.
   If something moved, correct the card and log it. If it changed materially,
   escalate.
2. **Start.** `task-files.sh snapshot <breakdown> <run> T07`, then
   `status-set.sh <status> T07 "In Progress"` (the unit follows). Both happen
   **before** the subagent starts.
3. **Execute.**
   - **Agent task:** `handoff.sh <breakdown> <status> T07 --run <run> --base-sha <BASE_SHA>`
     prints the whole prompt. Spawn one coder subagent (model and effort from `model-config.sh get coder`)
     (general-purpose, foreground) with that output, unchanged. It reads the
     card from the breakdown and writes its result to `<run>/results/T07.md`.
     If the script fails, fill in `<skill>/templates/handoff.md` by hand.
   - **Engineer task:** show the card's Steps as a checklist and wait. Then
     `result-scaffold.sh <breakdown> T07 --run <run> > <run>/results/T07.md`,
     fill in its markers with what the engineer reports, and record it as in
     step 4.
4. **Scope check.** `task-files.sh diff <breakdown> <run> T07`. Exit `1` means
   the task changed a file that isn't on its card: name it to the engineer,
   who decides whether to keep it (log a card correction) or revert it. A card
   file left `untouched` with the task `implemented` is worth one question.
5. **Record.** `status-log.sh <status> <run>/results/T07.md`. It writes the
   Step Log entry, adds each risk and improvement, and sets the task
   `Implemented` (`Blocked` or `In Progress` if it stopped early). Don't read
   the result file back unless the script reports a critical decision or
   fails.
6. **Escalation.** If `status-log.sh` reports `critical decision: yes`: read
   only that section of the result file, check its evidence, and present it
   with `<common>/templates/critical-decision.md`. Record the choice with
   `status-record.sh <status> decision …` (it prints the decision's ID), and
   name it on the task: `status-set.sh <status> T07 Blocked --note "<D-ID>: <one line>"`
   while waiting, then `"In Progress" --note ""` once decided. Continue the
   same subagent with SendMessage, giving the decision; it rewrites its result
   file when it finishes. If it can't be continued, spawn a new one with the
   handoff, the decision, and "inspect `git diff` on the card's Files to see
   the work so far".
7. **Next.** Continue with the unit's next task, or go to step 6 of this
   procedure ("Validate the work unit") if this was the last.

**Two at once (optional).** Two Agent tasks may run side by side only when all
of these hold: they're in the same unit, the breakdown marks them as parallel,
their Files lists don't overlap, and neither depends on the other. Never more
than two. Snapshot and set both `In Progress` first; apply each result file as
it returns. Their scope checks can't tell the two apart, so check each against
the union of both cards. If either escalates, start nothing new until it's
resolved. Otherwise, one at a time.

## 6. Validate the work unit

When every task in the unit is `Implemented`:

1. `status-set.sh <status> WU3 "Ready to Validate"`.
2. **Agent checks:**
   ```
   bash "<scripts>/run-checks.sh" "<breakdown>" WU3 "<run>/validation/WU3-attempt<n>" --why "<first run | after fix T09 | evidence stale>"
   ```
   It runs the commands in the unit's `checks` block, saves each output to
   `check-<n>.log`, prints one row per check, and writes `attempt.md`: agent
   checks passed or failed, engineer checks pending. Check by hand any it
   reports `blocked` (an Agent check with no command), and record the result
   as in step 5. If it exits `2` (the unit has no `checks` block, as in
   breakdowns written before it existed), use a subagent (`model-config.sh get drift-check`,
   `<skill>/briefs/run-agent-checks.md`) instead, given the breakdown path and
   unit ID, the Build check, the same log folder and the repo, and write its
   results as an attempt file in the same format. Agent results from an
   earlier session count only if the pre-flight reported nothing stale for the
   unit; otherwise run them again as a new attempt.
3. **Record and report.** `status-record.sh <status> validation WU3 --file <run>/validation/WU3-attempt<n>/attempt.md`.
   Report the agent results inline: the check, what was run, passed or failed,
   and the evidence (the rows `run-checks.sh` printed).
4. If the unit needs the engineer, draft the checklist with
   `validation-checklist.sh <breakdown> <status> WU3`. It gathers the open
   Engineer checks, the unit's engineer steps and its tasks' To validate notes.
   Turn it into the inline checklist, **in chat**:
   - a numbered list, one check per item;
   - each item: what to open and do (exact steps), what they should see, and
     what to report back;
   - name everything concretely: file and asset paths, menu items, field
     names, values to set and expect. If the draft is vague, look the concrete
     target up in the repo first (a quick `git grep`);
   - edge cases worth trying, as their own items;
   - end with: "Ask me about any step if you need more detail."

   A check marked **Agent + Engineer** passes only when both parts pass.
5. Wait for the answers, and answer follow-up questions in the same session. A
   question isn't a result: keep the check open until the engineer reports it.
   Record each answer as it arrives:
   `status-record.sh <status> check WU3 <n> passed|failed|waived --evidence "<what they reported>"`.
   It recomputes the attempt's Outcome.
6. **Outcome Done:** `status-set.sh <status> WU3 Done`, which marks each of its
   tasks `Done`.
7. **Any check fails:** `status-set.sh <status> WU3 Failed --note "check <n>"`.
   Trace the failure to the task that caused it, and propose a fix task:
   `fix-card.sh <breakdown> WU3 --after <cause> --check <n>` prints its ID,
   the rows for the Task Map, the Work Units table and both status boards, and
   the card with every known field filled in. Fill in the rest of the card
   (the card-writing rules in `tt-task-breakdown/templates/task-card.md`
   apply), and once the engineer approves, add it through the amendment rules.
   Once it's implemented, re-run the **whole** unit's validation as a new
   attempt.
8. Stop and report: the unit's check results, what changed, and the next unit.
   If there is a next unit, offer **Continue in a new session**
   (`<common>/session-handoff.md`; the status is already written, so the
   session is named `<Prefix> : Build` and resumes from it).

## Guardrails

The shared guardrails in `<common>/breakdown-rules-compact.md` apply. In
addition:

- One unit at a time. Within it, tasks run one at a time unless the two-at-once
  rules allow two. Never mark a unit `Done` while a check still needs the
  engineer.
- Never write production code, even for a one-line fix: that's a task for a
  coder subagent, or a fix task.
- Never offer to commit. When a unit is `Done`, say so; the engineer decides
  what to commit and when.
