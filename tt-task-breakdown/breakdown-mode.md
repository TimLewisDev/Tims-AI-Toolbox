# Breakdown mode

Produce the Task Breakdown and initialise the Task Status, without any one
response writing more than a part. `<skill>` is this skill's folder,
`<common>` is `<skill>/../tt-common`, `<scripts>` is `<common>/scripts`,
`<draft>` is the draft folder: `<plan folder>/.tt/<Prefix> - Task Breakdown/`.

The engineer reviews and approves a **skeleton** (units, tasks, files,
dependencies, check placement) before any card is written, so cards are
written once. Everything that is a copy of the skeleton, the plan or the
glossary is written by a script; models write only what needs judgement.

## Resume first

If `<draft>` already exists, this is a resumed run:

1. Read `<draft>/context.md` and the header of `<draft>/skeleton.md`.
2. Run `assemble.sh status "<draft>/manifest.txt"` if the manifest exists.
3. Continue from the first incomplete step below: no skeleton → step 6; skeleton
   not `Approved` → step 8; parts missing or incomplete → step 9 for those
   units only (a scaffolded part with `<!-- fill:` markers left counts as
   incomplete); all parts complete → step 11.

Tell the engineer what was found and where you're resuming.

## 1. Setup (main)

- Read the plan's header (`md-section.sh get <plan> "# "` or its first 30 lines)
  and its heading index (`md-section.sh index <plan>`). Note the `Revision`
  ("Plan read"), the base branch, prerequisites, step order and which steps can
  run in parallel.
- **Stop** if the plan's Status is `Draft`, or the plan has unresolved Blocking
  Decisions, or its Tech Proposals' **At a glance** table shows an `Open`
  `Blocking decision` (read only that table:
  `md-section.sh get <proposals> "## At a glance"`). They belong to
  `tt-adversarial-plan` or `tt-tech-plan-review`.
- Confirm the documents' location with the engineer, and create `<draft>`.
- `git fetch` once and pin `BASE_SHA=$(git rev-parse origin/<base>)`.
- Read the repo's agent instructions (`AGENTS.md`, `CLAUDE.md` or equivalent)
  for the Build check, tool-managed files and branch rules. If they don't say
  how to compile-check, ask the engineer once.
- Check the state the work will start from: the current branch, whether the
  working tree is clean, and anything holding the project open. A prerequisite
  the engineer must resolve goes on the prerequisite task and into the review.

## 2. Context pack (main, one response)

- `ids.sh defined <plan> > "<draft>/glossary.tsv"`: every ID the plan defines,
  with a one-line excerpt.
- `donewhen.sh <plan>`: every "Done when" item, numbered `§N #k`. This
  numbering is the only one: a bullet with sub-bullets is a heading, and each
  sub-bullet is an item whose text is "<parent text> <child text>". Use it in
  the Done-when map.
- Write `<draft>/context.md` (about 100 lines; no plan content beyond
  pointers): plan, Future Iterations, Tech Plan and Proposals paths; plan
  revision; repo path, base branch and `BASE_SHA`; the link style (say
  "Obsidian [[wiki-links]]" or "Markdown links": the scripts read it) and a
  sample header block from the sibling docs; the Build check; the repo rules
  that apply (tool-managed files, assemblies or modules, guard tests); and each
  plan step's line range from the heading index (`§3: lines 445–521`), plus the
  line ranges of Affected Files and Scope / Non-Goals.

## 3. Mechanical verification

```
bash "<scripts>/verify-refs.sh" --ref "$BASE_SHA" "<plan>" > "<draft>/verify/refs.tsv"
```

Read only its problem rows (`--only-problems` or `grep`) and the summary.

## 4. Semantic verification (subagents, batched)

Group the plan steps that still need a read into batches, and spawn one
subagent per batch, at most 4 at a time, model and effort from
`model-config.sh get unit-writer`, brief
`<skill>/briefs/verify-step.md`:

- Skip a step whose `refs.tsv` rows are all `OK` and that cites no symbols.
- Batch by size: up to three steps per subagent, keeping the batch under
  about 300 plan lines. Each subagent costs a fixed start-up, so many small
  ones cost more than a few full ones.
- If three steps or fewer need a read, and their `refs.tsv` problem rows are
  few, do them yourself with the brief instead of spawning anything.

Give each subagent: the brief path, `<scripts>`, `<draft>`, the plan path and
each step's line range, the repo path and `BASE_SHA`. It writes
`<draft>/verify/§N.md` for each step and returns a RESULT with its problems.

## 5. Triage (main)

- Trivial drift (a moved line, a renamed-but-identical reference): goes in
  Plan Verification Notes with the corrected reference.
- Anything that changes a task's content, boundary or order: a Critical
  Decision for the engineer. Do not edit the plan; if it needs correcting, the
  engineer amends it with `tt-tech-plan-review`, then re-read the amended
  sections.

## 6. Skeleton (main, one plan step per response)

Read `<skill>/templates/skeleton.md` once. Then, for each plan step in order,
read that step (`md-section.sh get <plan> "§N."`) and append its tasks to
`<draft>/skeleton.md`, applying the atomic rules in `<common>/breakdown-rules.md`:

- prerequisites (ticket, branch, setup) become `T00`, `T00a`…; point to the
  repo skill that performs one where it exists;
- every task: ID, title, executor, files (new / change), dependencies, the IDs
  it traces to, any **Confirm** items (what the plan leaves to "confirm when
  implementing"; if the answer could change the design, escalate now instead),
  and why it is split the way it is.

Then, in one response each:

- the **Units** table: ID, outcome ("after this unit you can…"), tasks,
  validated by, depends on, and which tasks may run in parallel (only Agent
  tasks the plan allows in parallel, with Files lists that don't overlap);
- the **Done-when map**: every item `donewhen.sh` lists, by its `§N #k`,
  placed on the **first** unit where it can be observed, with who checks it
  (**Checked by**: Agent, Engineer or Agent + Engineer) and the reason if that's
  not the unit holding the step's tasks; and each unit's own checks under
  **Unit checks** (it compiles, guard tests, behaviour its tasks add that the
  plan's items don't cover).

The scripts read the skeleton, so keep the template's headings, table columns
and `- WU1: <check> (<who>)` lines exactly.

## 7. Skeleton check and render (scripts)

```
bash "<scripts>/skeleton-check.sh" "<draft>"
bash "<scripts>/skeleton-render.sh" "<draft>"
```

`skeleton-check.sh` reports each defect as a TSV row: a plan step with no
task; a task in no unit or two; units not consecutive; a bad dependency;
parallel tasks that share files; a Done-when item missing, placed twice,
placed too early or without Checked by; a file outside Affected Files or one
it marks unchanged; an Affected Files row no task touches. Fix each in the
skeleton and re-run until it's clean. It doesn't check Non-Goals: read the
plan's Scope / Non-Goals section against the task titles yourself.

`skeleton-render.sh` writes `<draft>/manifest.txt`, `parts/10-work-units.md`
and `parts/20-task-map.md` from the skeleton. Re-run it after every skeleton
change; never write those three by hand.

## 8. Engineer review

Present the Work Units (ID, outcome, tasks, validated by, depends on) and the
Task Map (ID, title, executor, dependencies, unit), plus any Critical Decisions
and Plan Verification Notes. Point at `parts/10-work-units.md` and
`parts/20-task-map.md` rather than re-typing them. Show a step's tasks or a
unit's checks in full only on request, one at a time. Iterate on splits,
merges, grouping and ordering; edit the skeleton in place, then re-run step 7.
When the engineer approves, set the skeleton's `Approved:` line to the date.

## 9. Card writing (scaffold, then subagents)

For each unit, scaffold its parts:

```
bash "<scripts>/card-scaffold.sh" "<draft>" <WU>
```

It writes `parts/30-<WU>.md` (heading, the unit table, the Validation list in
its final order with every Done-when item copied verbatim from the plan, an
empty `checks` block) and one `parts/31-<WU>-<task>.md` per card (the card
table with the plan link, Plan IDs with their glossary excerpts, the Files
list, the Confirm items, Validated in). Everything that needs judgement is a
`<!-- fill: … -->` marker.

Then one subagent per work unit, at most 4 at a time, model and effort from
`model-config.sh get unit-writer`, brief
`<skill>/briefs/write-unit.md`. Give each: the brief path, `<skill>`,
`<scripts>`, `<draft>`, the unit ID, the plan path, and the line ranges of the
plan steps its tasks come from. Each replaces the markers in its unit's parts
and ends each with `<!-- tt:end -->`.

Handle each RESULT:

- `done`: nothing to do yet.
- escalations: a skeleton fix (re-approve that change with the engineer, edit
  the skeleton, re-run step 7 and `card-scaffold.sh … --force` for that unit,
  re-spawn its writer), or a Critical Decision.
- `partial` or `failed`: re-spawn the writer for the missing parts only.

## 10. Header part (main, one response)

`<draft>/parts/00-header.md`: the header block and **Overview** (plain English,
3–6 sentences) from `<skill>/templates/task-breakdown.md`. The two tables are
already rendered.

## 11. Coverage (script, then a short read)

```
bash "<scripts>/coverage.sh" "<draft>"
```

It writes `parts/80-coverage.md` and reports, as TSV rows: a plan step no
card names; a task with no card, or a card out of place; a Done-when item
found verbatim in no unit block or in two; a plan ID on no card; a file
outside Affected Files or an Affected Files row on no card; a plain-English
paragraph that is missing, has code or paths, or runs over 4 sentences;
planning IDs in snippets; any `<!-- fill:` marker left. Fix each with a small
Edit to the affected part, or re-spawn that unit's writer, and re-run until
it's clean.

What it can't judge, Non-Goals and whether each plain-English paragraph reads
well, still needs fresh eyes: one subagent (model and effort from
`model-config.sh get coverage-audit`,
`<skill>/briefs/coverage-audit.md`, with the plan, `<draft>` and `<scripts>`),
or, for a breakdown of 10 cards or fewer, read the cards' plain-English lines
(`grep -h "In plain English" <draft>/parts/3*.md`) and their Goals against
Scope / Non-Goals yourself.

Write `<draft>/parts/90-verification.md` (Plan Verification Notes) yourself.

## 12. Assemble and initialise

```
bash "<scripts>/assemble.sh" status "<draft>/manifest.txt"
bash "<scripts>/assemble.sh" build "<folder>/<Prefix> - Task Breakdown.md" "<draft>/manifest.txt"
bash "<scripts>/status-init.sh" "<folder>/<Prefix> - Task Breakdown.md" "<folder>/<Prefix> - Task Status.md"
```

`status-init.sh` writes the whole Task Status from the breakdown's tables and
reports the unit and task counts; check them against the Task Map. If it exits
`2` on a breakdown it can't read, fall back to a subagent (`model-config.sh get drift-check`)
following `<skill>/../tt-task-status/briefs/init.md`.

## 13. Finish

Delete `<draft>` and say so. Report the two paths and the unit count, and offer
to start the first ready unit with `/tt-execute <task status doc>`. Never offer to commit.
