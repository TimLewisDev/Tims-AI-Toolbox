# Brief: write one work unit's block and task cards

You complete the parts of a Task Breakdown for one work unit, from a skeleton
the engineer has already approved. You do not slice, regroup or redesign
anything: every decision about tasks, files, dependencies and check placement
is in the skeleton. Your job is to put every detail the implementer needs on
each card, taken from the plan and the verified code.

The mechanical parts are already written: `card-scaffold.sh` has written
`<draft>/parts/30-<WU>.md` and one `<draft>/parts/31-<WU>-<task>.md` per card,
with the unit table, the Validation list (unit checks, then the plan's "Done
when" items copied verbatim, in their final order), the card tables and plan
links, the Plan IDs with their excerpts, the Files lists and the Confirm
items. You replace each `<!-- fill: … -->` marker with content and leave the
rest as it is.

**You are given:** `<skill>` (the tt-task-breakdown folder),
`<common>/scripts`, `<draft>`, the unit ID, the plan path, and the line ranges
of the plan steps the unit's tasks come from.

Read first, in this order:

1. `<common>/subagent-rules.md` (applies to you).
2. Only these sections of `<common>/breakdown-rules.md`:
   `bash "<common>/scripts/md-section.sh" get "<common>/breakdown-rules.md" "## Tasks and work units" "## Executors" "## The plain-English summary"`.
3. `<skill>/templates/work-unit.md` and `<skill>/templates/task-card.md` (the
   notes under each, on what each field holds).
4. Your unit's scaffolded parts, and `<draft>/context.md`.
5. The plan steps (by line range), and `<draft>/verify/§N.md` for each.

If a part has no markers and already ends with `<!-- tt:end -->`, it is done:
leave it. If a part is missing, say so in your RESULT; don't write it from
scratch.

## Do

Complete one part per Write (or Edit the markers in place), and end each with
the line `<!-- tt:end -->` once no marker is left:

1. `<draft>/parts/30-<WU>.md`, the unit block:
   - the heading's name, In plain English, and Why these tasks are validated
     together;
   - the `checks` block: one `<n> | <expect> | <command>` line (`<expect>`
     is `ok`, `empty` or `nonempty`) for each Agent or Agent + Engineer item
     **a command fully decides**, `<n>` being its place in the Validation list
     as scaffolded (compile checks use the Build check in `context.md`). Leave
     the block empty if none is a command;
   - the Agent inspections the block can't express, and numbered Engineer
     steps, each with its expected result.
   - Don't reorder, reword or drop a Validation item: the check numbers and
     the verbatim plan text depend on it. If one is wrong, escalate.
2. `<draft>/parts/31-<WU>-<task>.md` for each task, in ID order:
   - Goal; Read first (what to take from the plan link; the Precedent, Repo
     rules and API docs lines, or delete that marker line); each file's
     purpose or change; Steps; Not in this task; which unit checks cover it;
   - Steps carry the plan's signatures, constants, exact strings and snippets.
     References use the corrected line from the verification notes where one
     moved. Snippets lose planning IDs in their code comments (reword or drop);
   - In plain English last, once the technical content is fixed.
   - Don't change the scaffolded Files, dependencies, traces, Plan IDs or
     Confirm items. If the plan and the skeleton disagree, escalate.
3. Check your parts:
   `grep -n "<!-- fill:" <your parts>` (nothing may be left), and
   `bash "<common>/scripts/check-planning-ids.sh" --md <your parts>`. Fix every
   hit inside a snippet; IDs in card text outside code blocks are expected.

## Escalate, don't decide

Return an escalation (and leave that card's Steps with a `**Confirm:**` or stop
the card) when:

- the skeleton and the plan disagree about a task's files or content;
- the plan doesn't give what a step needs, and the verified code doesn't settle
  it;
- a "Done when" item can't be checked by anything in this unit;
- a snippet can't be copied without changing what it does.

Type `question` for a gap the engineer can answer, `blocking` for anything that
would need a design choice.

## Return

The RESULT block: every part you completed, a summary (cards completed, checks
lines written), escalations, and `findings: none` or the planning-ID hits you
couldn't resolve.
