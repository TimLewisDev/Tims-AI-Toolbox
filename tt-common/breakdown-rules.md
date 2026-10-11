# Breakdown rules

Shared by `tt-task-breakdown` (which writes the Task Breakdown) and
`tt-execute` (which works through it). Read only the sections you need
(`md-section.sh get <common>/breakdown-rules.md "## <heading>"`). `<common>` is
the `tt-common` folder.

## Authority order

1. Existing codebase, on the plan's base branch
2. Explicit engineer instructions
3. The Comprehensive Tech Plan, then the Future Iterations doc it links
4. The Task Breakdown

A card never overrides the plan. If a card and the plan disagree, the plan
wins: correct the card and log the amendment. If the plan and the codebase
disagree, escalate a Critical Decision. The plan itself only changes through
`tt-tech-plan-review`, so its brief Tech Plan and Proposals stay in sync.

## The two documents

| Document | Written by | Changes | Purpose |
|---|---|---|---|
| **Task Breakdown** | `tt-task-breakdown`; amended by `tt-execute` | rarely, only through logged amendments | The work units and task cards: what the agent does, how each unit is validated, and what it means to a human. |
| **Task Status** | the `tt-task-status` skill (and its scripts), called by `tt-task-breakdown` (init) and `tt-execute` (everything after) | at every state change | The single resume point. A fresh session reads this first. |

**`tt-task-status` owns the Task Status document**: its template, its status
values, and every write to it. Neither skill edits it by hand; each "update the
Task Status" means an operation of that skill (`init`, `set`, `log`, `record`,
`reconcile`, `summary`), usually through its script. Invoke the skill only when
no script covers the operation. While `tt-execute` runs, it is the **only**
writer of the Task Status: coder subagents return their Step Log content in a
result file, and `tt-execute` records it.

There is no separate validation document. Validation instructions are given
to the engineer inline, in chat, when a unit is validated.

**Location and naming.** Put both beside the comprehensive plan and follow its
naming: `<Prefix> - Comprehensive Tech Plan.md` → `<Prefix> - Task
Breakdown.md` and `<Prefix> - Task Status.md`. Match the sibling documents'
conventions: header or tag block, and link style (Obsidian `[[wiki-links]]` in
a vault, relative Markdown links elsewhere). Confirm the location before
writing.

## Tasks and work units

There are two levels, and they have different jobs:

- A **task** is the unit of *implementation*: one handoff to the agent, or one
  checklist for the engineer. Tasks carry **no validation**. A task is finished
  when its Steps are done.
- A **work unit** is the unit of *validation*: a group of consecutive tasks
  whose results are tested and confirmed together. **All validation and
  confirmation happens at work-unit level**, once every task in the unit is
  finished. That includes compile checks, test runs, checks in the running
  app or a tool, and the plan's "Done when" items.

Validating per unit lets the plan's checks land where they can actually be
observed, and keeps the engineer's round trips to one per unit.

### What "atomic" means for a task

A task is atomic when **all** of these hold:

- **One concern.** It can be stated in one sentence without "and also".
- **One session, one reviewable change.** An agent can finish it in a single
  session, and its diff can be reviewed in one sitting.
- **Written to leave the project whole.** The code compiles afterwards and
  nothing that worked before breaks. No task needs a later task in order to
  compile. (This is confirmed when the unit is validated, not per task.)
- **Self-contained.** An agent given only the card, plus the files under "Read
  first", can do it without reading the rest of the breakdown.
- **One executor.** Agent work and work that needs a human in a tool are
  separate tasks.
- **No open design choices.** Everything a design choice needs is decided in
  the plan or on the card. If it isn't, escalate before writing the card.

Split a plan step into several tasks when it creates a contract and its
consumers that can compile in stages; mixes code with content authored in a
tool; spans more than one module or assembly; or wouldn't fit in one session or
one review. Don't split when the pieces can't compile apart, or the split just
mirrors files one-to-one with no gain in reviewability. A task whose output can
only be observed through a later task belongs in the same work unit as that
later task.

### What makes a good work unit

- **Testable as a whole.** Every one of its checks can be run once its last
  task is finished, without any task from a later unit.
- **Complete for its checks.** Every task its checks need is in this unit or an
  earlier one.
- **Leaves the project whole.** After its last task the code compiles and
  nothing that worked before is broken.
- **Something to notice.** Its outcome can be described to a non-technical
  reader as "after this unit you can…".
- **Traceable failures.** Small enough that a failed check can be traced to the
  task that caused it. Prefer 2–5 tasks; a single-task unit is fine when that
  task is testable alone.
- **Consecutive.** Its tasks are consecutive in ID order, and every task
  belongs to exactly one unit.

Draw unit boundaries where the engineer would naturally stop to test: when a
new module first builds, when a test becomes runnable, when something first
appears in the app or a tool. Group checks that need the same engineer action
into the same unit. A unit may contain only Engineer tasks, or mix Agent and
Engineer tasks.

## Executors

| Executor | Use for | In `tt-execute` |
|---|---|---|
| **Agent** | Code and text files the agent can write. | A coder subagent running `tt-coder` in delegated mode. |
| **Engineer** | Work that must be done in a tool (an editor, a designer tool, an admin console); creating tickets; creating branches; anything the plan or the repo's instructions say must not be hand-edited. | Present the card's Steps as a checklist, wait for the engineer, record what they report. |

| Validated by | Use when |
|---|---|
| **Agent** | Every check can be run by the agent (a build or compile check, a grep, reading a file). |
| **Agent + Engineer** | At least one check needs the engineer (a build or test run only they can start, or behaviour seen in the running app or a tool). The agent runs its checks first, then hands the engineer the rest as a checklist. |

**Repo rules decide executors and validation.** Read the repo's agent
instructions (`AGENTS.md`, `CLAUDE.md` or equivalent) before deciding either.
Where they cover something below, they win over these defaults:

- **Tool-managed files.** Files a tool generates or owns are authored in that
  tool, so authoring them is an **Engineer** task unless the plan and the
  engineer explicitly say otherwise. The agent never writes generated files.
- **Build and compile checks.** Find out how the agent can build or
  compile-check the code, and what needs a human. A check only the engineer can
  run makes the unit **Agent + Engineer**. If the repo's instructions don't
  say, ask the engineer once, and record the answer in the breakdown's header
  (**Build check**).
- **Things that must arrive together.** If the build ignores something until
  another piece exists, create them in the same task, or at least the same
  unit.
- **Git.** Follow the repo's branch naming rules. Branches, commits and pushes
  are the engineer's.

## The plain-English summary

Every work unit and every task card opens with **In plain English**, written
for a non-technical colleague such as a producer or designer:

- 2–4 short sentences. For a task: what it adds or changes and why it's
  needed. For a unit: what someone can do or see once it's validated. If
  nothing is visible yet, say so and say what it makes possible.
- No code names, file paths, class names or acronyms. If a term can't be
  avoided, explain it in the same sentence.
- Describe outcomes, not mechanics.

Good: *"Adds the place where each user's saved filters are kept, so they're
still there next time the app opens. Nothing is visible yet; a later task adds
the screen that uses them."*

Bad: *"Implements `FilterStore` with `Load`/`Save` over a
`Dictionary<string, FilterSet>` serialised to JSON."*

## Amending the breakdown

- IDs are stable. Never renumber or reuse a task or unit ID.
- Split a task into `T07a`, `T07b`. Give a new task the next unused number and
  place it in the Task Map by dependency and in its unit.
- Mark a removed task `Dropped` with the reason. Never delete a card.
- Moving a task or a check between units is an amendment.
- Log every amendment with `tt-task-status record` (a breakdown change), and
  change the breakdown and the boards together. Edit only the affected card or
  rows (`md-section.sh get` to read them); never rewrite the whole breakdown.
- Amendments that change scope, contracts, behaviour or a unit's checks need
  engineer approval first. Fixing a path or line reference doesn't, but is
  still logged.
- If an amendment shows the plan itself is wrong, escalate. Don't edit the plan
  from here; the engineer amends it with `tt-tech-plan-review`.

## Critical Decisions

Escalate when:

- the plan conflicts with the codebase on its base branch;
- a plan step can't be made atomic without choosing between designs;
- the plan is ambiguous in a way that changes a task's content, boundary or
  order;
- a plan "Done when" item can't be met as written by any unit;
- a subagent returns an escalation of type `blocking` or `question`;
- anything on `tt-adversarial-plan`'s or `tt-coder`'s
  Critical Decision lists comes up.

Placing a plan check on a later unit than its plan step, because that's where
it can first be observed, is normal grouping, not a Critical Decision.

A Blocking Decision marks the affected tasks `Blocked` and pauses them. A
Non-Blocking Review Item is recorded and work continues. Only the main agent
presents decisions to the engineer, using `<common>/templates/critical-decision.md`.
Record every resolution with `tt-task-status record` (a decision), with the
tasks and units it affects.

## Status values

Task and work-unit statuses (`Todo`, `In Progress`, `Blocked`, `Implemented`,
`Ready to Validate`, `Failed`, `Done`, `Dropped`) and the rules tying them
together are defined in `tt-task-status`.


## Shared guardrails

- Slice the design; never change it.
- Never fabricate. Every card and unit detail traces to the comprehensive plan
  or code verified on the base branch. Unknowns become questions.
- Validate only at work-unit level. Never validate, or mark `Done`, a single
  task on its own.
- Update the Task Status document through `tt-task-status` (or its scripts) at
  every state change, not only at the end of a session. A session can end at
  any moment.
- Give validation instructions inline, never in a separate document.
- Keep the breakdown and the status document in step.
- Keep planning IDs out of code: never put them in a snippet's code comments on
  a card, and tell the coder not to write them.
- Never stage, commit, push or create branches, and never offer to. Git is the
  engineer's. Don't create tickets without the engineer's go-ahead.
