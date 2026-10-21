---
name: tt-task-status
description: >
  Own the Task Status document: the single resume point for work done from a
  task breakdown (or, standalone, from a plan). Defines its template and status
  values, and performs every update to it: initialise it, set task and work
  unit statuses, write Step Log entries (including "To validate" notes for
  later inline validation), record decisions, risks, improvements, breakdown
  changes and work-unit validation results, keep the header, boards and Resume
  Here consistent, and reconcile the document with the repo. Called by
  tt-task-breakdown, tt-execute and tt-coder whenever they change the
  status; run directly to get a resume summary and a reconcile. Never commits.
metadata:
  version: "2.0"
---

# tt-task-status

## Usage

```
/tt-task-status <task status doc>
```

Run directly, it gives a **resume summary**, checks the document is internally
consistent, then **reconciles** it with the repo (see Operations). It changes
nothing without the engineer's confirmation.

Normally it's invoked by another skill, and the operation follows from what that
skill needs:

| Caller | Uses |
|---|---|
| `tt-task-breakdown` | `init` (through `status-init.sh`; `briefs/init.md` is the fallback) |
| `tt-execute` | `summary` and `reconcile` (the read-only part through `continue-preflight.sh`, `briefs/reconcile.md` the fallback); `set` at every task and unit state change; `log` from each coder subagent's result file; `record` for decisions, risks, improvements, breakdown changes and work-unit validation runs |
| `tt-coder` | Standalone only: `init`, `set`, `log` and `record` for its own steps. In delegated mode it never calls this skill. |

A caller that has already loaded this skill follows its rules for later
updates; it re-invokes it if they've dropped out of context.

`<common>` is `~/.claude/tt-plugins/core/skills/tt-common` (or
`${CLAUDE_SKILL_DIR}/../tt-common` when the skills are linked into one folder);
the scripts are `<common>/scripts/<name>.sh`.

## Role

You keep one document true. A fresh session reads it first and trusts it, so:

- **One document.** Never create a second Task Status doc for the same work.
  If one exists, use it.
- **Save at every state change**, not at the end of a session. A session can end
  at any moment. When a task starts, the `In Progress` state is saved **before
  any code change**.
- **Consistent after every write.** The `# Status` header, the boards, the
  progress counts, Resume Here and each Step Log entry's **Status** line must
  agree. These are *derived* fields: recompute them on every write, without
  asking, and never update one and leave the others. Changing a *recorded fact*
  (a task or unit status, a file list, a decision, a validation result) is
  different: that only happens as the caller or the engineer reports it, or as
  a confirmed reconcile correction.
- **Stable records.** IDs are never renumbered or reused, and rows are never
  deleted. A removed task is `Dropped` with its reason.
- **No fabrication.** Record what happened, as reported by the caller or the
  engineer, with evidence where there is any. Unknowns are left blank or asked,
  never guessed.
- Never stage, commit, push or create branches. Whether work is committed is the
  engineer's business.

### How to write

The document grows long; rewriting it whole is slow and can be cut off
mid-response. So:

- **`init` is the only operation that writes the whole document.** Every other
  operation makes targeted Edits: the board row, the Step Log entry, the
  section entry, and the header lines and Resume Here.
- **Recorded fact first, derived fields second.** Edit the board row, entry or
  result first, then the header, progress counts and Resume Here. If a session
  ends between the two, only derived fields are stale, and `reconcile` repairs
  those without asking.
- **Read only what you need:** `md-section.sh get <doc> "# Status" "# Resume Here"
  "# Work Unit Board" "# Task Board"` (in `<common>/scripts/`) for the
  header and boards; the one Step Log entry you are changing.
- **One writer.** When `tt-execute` runs coder subagents, it
  is the only writer of this document; subagents return their Step Log content
  instead of writing it.
- **Use the scripts for every routine write.** They are in
  `<common>/scripts/`. Each makes the
  targeted edit and recomputes the derived fields in one atomic write, keeps
  the document's line endings, and prints one line per change, never content:

  | Operation | Script |
  |---|---|
  | `set` | `status-set.sh <doc> <ID> "<Status>" [--note <text>]`: the board row, the unit or tasks it moves, the Step Log Status lines, the header and Resume Here |
  | `log` | `status-log.sh <doc> <result file>`: the Step Log entry, its risks and improvements, then `set` (a delegated subagent's result file, or one you write in the same format) |
  | `record` | `status-record.sh <doc> decision \| change \| risk \| improvement \| validation \| check …` |
  | derived fields only | `status-set.sh <doc> --refresh` |
  | `reconcile` (read-only part) | `continue-preflight.sh <doc> <breakdown>` |

  Run each with `-h` for its options. A script that exits `2` changed nothing;
  make that update by hand, following the rules here.
- **Compute the derived fields; don't work them out by hand.** The scripts do
  it through `status-counts.sh`. When you edit by hand, run
  `bash "<common>/scripts/status-counts.sh" "<doc>"` and copy its State,
  Progress, Current Unit, Current Task and Next into the header. Any line
  starting with `!` is a board inconsistency: fix the derived ones; report the
  rest.
- **Boards at `init` come from the breakdown:**
  `bash "<common>/scripts/status-boards.sh" "<breakdown>"` prints both
  boards with every row `Todo`.

## Status values

Tasks:

| Status | Meaning |
|---|---|
| `Todo` | Not started. |
| `In Progress` | Started. Work may be on disk. |
| `Blocked` | Waiting on a Critical Decision or external input. The board says which. |
| `Implemented` | Its Steps are done. Not yet validated; that happens with its unit. |
| `Done` | Its work unit passed validation. |
| `Dropped` | Removed from scope by an engineer decision. Kept on record with the reason. |

Work units:

| Status | Meaning |
|---|---|
| `Todo` | No task started. |
| `In Progress` | At least one task started; not every task is `Implemented`. |
| `Blocked` | A task in it is `Blocked`. |
| `Ready to Validate` | Every task is `Implemented`; validation is running or waiting on the engineer. |
| `Failed` | At least one check failed. A fix task is proposed or in progress. |
| `Done` | Every check in its Validation passed. |

Rules that tie them together:

- A task becomes `Done` only when its unit becomes `Done`, and then all of the
  unit's non-`Dropped` tasks do (their boards and Step Log Status lines
  included).
- A unit is never `Done` while any of its engineer checks is unanswered.
- The header **State** follows from the boards: `Not Started` (all `Todo`),
  `Blocked` (any unit `Blocked`), `Ready to Validate` (the current unit is),
  `Complete` (every unit `Done`), otherwise `In Progress`.

In **standalone** mode there are no work units: a task goes `Todo` →
`In Progress` → `Done` (or `Blocked` / `Dropped`), and State follows the tasks.

## Operations

### `init`

- **From a Task Breakdown** (called by `tt-task-breakdown`): write the full
  template. Every unit and task is `Todo`, every board row is filled from the
  breakdown's Work Units and Task Map, and Resume Here points at the first unit.
  Name and place it per the breakdown (`<Prefix> - Task Status.md`), matching
  the sibling documents' header or tag block and link style.
  `status-init.sh <breakdown> <status>` does all of this; use
  `briefs/init.md` only if it can't read the breakdown.
- **Standalone, from a plan** (called by `tt-coder` when there
  is no breakdown): write the minimal variant. Its tasks are the plan's steps,
  numbered as the plan numbers them. Put it beside the plan. Confirm the
  location first.
- If a Task Status doc already exists for this work, don't initialise. Use it.

### `set`

Set a task's or unit's status, with a note when there's a reason (the
blocking decision, the failed check, the drop reason). Then recompute the
header (State, Progress, Current Unit, Current Task, Next, Last Updated,
Blocking Decisions) and Resume Here, and save.

### `log`

Write or update one task's Step Log entry, under `## <ID> — <title>`:

- **Status**: the task's status.
- **Files Modified**: every file created or changed.
- **Summary**: what was done, in a few lines.
- **Validation**: `Deferred to <WU ID>` when the task belongs to a work unit;
  otherwise (standalone) what was actually run and its result.
- **To validate**: what the engineer or the agent should check for this task,
  how, the expected result, and edge cases worth trying. This feeds the unit's
  inline validation checklist, and survives a session ending. Write it so it
  can be read out as steps.
- **Follow-up Concerns**: anything the next task or the engineer should know.

Then recompute the derived fields and save.

### `record`

Add one entry to the right section, then recompute and save:

- **Decision** → Decisions Taken (decision, resolution, tasks and units
  affected, date).
- **Risk** → Outstanding Risks in the header (add it, or mark it closed with the
  date and how).
- **Improvement** → Identified Improvements (description, benefits,
  risks/tradeoffs, why high impact).
- **Breakdown change** → Breakdown Changes (date, tasks/units, change, why,
  approved by).
- **Unit validation run** → Work Unit Validation, under the unit. One block per
  **attempt**, numbered 1, 2… per unit. An attempt covers all of the unit's
  checks, agent and engineer; a new attempt starts only when validation is
  re-run after a fix task or because earlier evidence went stale. Each block
  (`### Attempt <n>` under `## <WU> — <name>`) has the run time, one
  `  - Check <n> (<text>) [<who>]: <result>. <evidence>` line per check
  (passed / failed / pending / blocked / waived), and an outcome: `Done`,
  `Failed` (with the fix task once there is one), or `Pending (checks <n>, …)`
  while answers are outstanding. Update the same block as answers arrive
  (`status-record.sh <doc> check <WU> <n> <result>` recomputes the outcome).

### `reconcile`

The document may be stale, since a session can end mid-task. Check it against
the repo before anyone trusts it:

- **Branch:** the current branch matches the Status header.
- **Files:** files created by `Implemented` or `Done` tasks exist; files a
  `Todo` task will create don't yet.
- **In-progress work:** for an `In Progress` task, compare `git status` and
  `git diff` on its files against its card's Steps to see how far it got.
- **Changed since validation:** for each `Done` unit, and a unit whose
  validation attempt has recorded results, check `git log` and `git status` for
  changes to its tasks' files after that attempt's run time. Code can change
  outside a task (review fixes, renames). Report each one: the unit's evidence
  is stale, and the proposed correction is a new validation attempt (for a
  `Done` unit, the engineer decides whether to re-validate) plus a recorded
  risk.
- **Breakdown agreement:** the boards match the Task Breakdown: the same task
  and unit IDs, the same executors, the same unit membership.
- **Internal consistency:** the derived fields agree (see Role). Fix those
  directly; they aren't corrections.

Report whether work is committed only if it bears on a discrepancy (e.g. a
`Done` task's files are missing from the working tree). Report every
discrepancy with a proposed correction. Apply corrections only after the
engineer confirms, and log each one under Breakdown Changes (or, standalone,
Decisions Taken).

Plan drift is not this skill's job; `tt-execute` checks it.

### `summary`

A short resume summary, from the header, Resume Here and the boards only:

- progress (`n of m` units Done, `n of m` tasks Implemented or Done) and the
  current unit;
- anything `In Progress` or `Blocked`, and why;
- a unit that is `Ready to Validate`, and which checks are still waiting on the
  engineer;
- the next action, from Resume Here.

## Templates and briefs

- `templates/task-status.md`: the full and standalone templates. Read it only
  for `init`.
- `briefs/init.md`: `init` from a Task Breakdown by a subagent, the fallback
  when `status-init.sh` can't read the breakdown.
- `briefs/reconcile.md`: the read-only part of `reconcile`, run by a subagent;
  it returns discrepancies and proposed corrections for the caller to present.
