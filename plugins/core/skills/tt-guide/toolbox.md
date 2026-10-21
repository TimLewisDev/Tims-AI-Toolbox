# The tt toolbox

The catalogue behind `tt-guide`: what each skill does, how they fit together,
and the ideas behind them. `tt-guide` reads this file to answer "how do I…",
so keep its headings; the install and update steps are in the repository's
top-level `README.md`.

Skills come in two plugins today: **core** (`tt-guide`, `tt-config`,
`tt-connections`, `tt-metrics`, and the shared `tt-common`) and
**engineering** (everything else). Core is needed by every discipline;
engineering skills need it to run.

## The skills

| Skill | What it does |
|---|---|
| [`tt-guide`](../tt-guide/SKILL.md) | New here? Tatty, the toolbox's guide: says where your documents stand, which command comes next, and answers "how do I…". |
| [`tt-workflow`](../../../engineering/skills/tt-workflow/SKILL.md) | One entry point: link a feature folder, type `tt-workflow`, and it works out the stage and runs the skill that comes next. |
| [`tt-workflow-lite`](../../../engineering/skills/tt-workflow-lite/SKILL.md) | The same single entry for small work: asks bug or feature, then runs the lite route below. |
| [`tt-familiarise`](../../../engineering/skills/tt-familiarise/SKILL.md) | Explores a part of the codebase with you, a question at a time, until you've pinned down what you actually care about. |
| [`tt-familiarisation-doc`](../../../engineering/skills/tt-familiarisation-doc/SKILL.md) | Writes up only the part of that exploration you said you're interested in, as a readable doc. |
| [`tt-adversarial-plan`](../../../engineering/skills/tt-adversarial-plan/SKILL.md) | Runs planning stage by stage, has an adversary challenge each stage, and gets you to a signed-off plan. |
| [`tt-requirements`](../../../engineering/skills/tt-requirements/SKILL.md) | Planning stage 1: pins down what the feature must do. |
| [`tt-scope`](../../../engineering/skills/tt-scope/SKILL.md) | Planning stage 2: what the feature is and isn't, and the hard constraints. |
| [`tt-approach`](../../../engineering/skills/tt-approach/SKILL.md) | Planning stage 3: weighs candidate approaches against the repo and records the choice. |
| [`tt-technical-design`](../../../engineering/skills/tt-technical-design/SKILL.md) | Planning stage 4: verifies repo facts, resolves critical decisions, outlines the steps. |
| [`tt-plan-signoff`](../../../engineering/skills/tt-plan-signoff/SKILL.md) | Final stage: your sign-off, then the finished plan, Tech Plan and Future Iterations. |
| [`tt-tech-proposals`](../../../engineering/skills/tt-tech-proposals/SKILL.md) | Lays out each decision's options side by side for review, and records what was chosen. |
| [`tt-tech-plan`](../../../engineering/skills/tt-tech-plan/SKILL.md) | Writes a short, five-minute summary of the plan for reviewers. |
| [`tt-tech-plan-review`](../../../engineering/skills/tt-tech-plan-review/SKILL.md) | Talks a written plan through with you, answers questions, and makes the changes you confirm. |
| [`tt-task-breakdown`](../../../engineering/skills/tt-task-breakdown/SKILL.md) | Splits the plan into small tasks grouped into work units. |
| [`tt-execute`](../../../engineering/skills/tt-execute/SKILL.md) | Works through the breakdown one unit at a time: hands each task to a coder, then validates the unit with you. |
| [`tt-task-status`](../../../engineering/skills/tt-task-status/SKILL.md) | Keeps the progress record that lets any new session pick up where the last one stopped. |
| [`tt-coder`](../../../engineering/skills/tt-coder/SKILL.md) | Writes the code for one task (or a small plan), strictly within scope. |
| [`tt-lite-brief`](../../../engineering/skills/tt-lite-brief/SKILL.md) | Lite route: turns a short exploration or a found root cause into one brief (goal, acceptance, decisions, tasks, checks). |
| [`tt-execute-lite`](../../../engineering/skills/tt-execute-lite/SKILL.md) | Lite route: builds the brief the way `tt-execute` builds a breakdown, with no plan to drift from. |
| [`tt-debug`](../../../engineering/skills/tt-debug/SKILL.md) | A pair-programming debugging companion: you drive, it navigates, hunting the root cause. |
| [`tt-debug-doc`](../../../engineering/skills/tt-debug-doc/SKILL.md) | Renders the debugging session into a short Debug Report, by script. |
| [`tt-mr-review`](../../../engineering/skills/tt-mr-review/SKILL.md) | Reviews a GitLab merge request and posts only the comments you approve. |
| [`tt-config`](../tt-config/SKILL.md) | Chooses the model and thinking effort for each stage, ranked by where a stronger model pays off, and saves the choices as modes you can swap. |
| [`tt-connections`](../tt-connections/SKILL.md) | Checks the MCP servers, logins and git settings a project needs, from a connection pack kept outside the repo, and sets up the missing ones one at a time (yes or skip). |
| [`tt-common`](../tt-common/SKILL.md) | Not run directly: the shared rules for long runs and for planning, shared templates, and the helper scripts the other skills call. |

## How they fit together

```text
"I want to explore how X works"          Spec or ticket
  │                                        │
  ▼                                        │
tt-familiarise ──► Focus Log             │
tt-familiarisation-doc ──► Familiarisation
  │                                        │
  ▼                                        ▼
tt-adversarial-plan (orchestrator), one stage at a time:
  ├─ tt-requirements       ┐ each writes into the draft
  ├─ tt-scope              │ Comprehensive Tech Plan, with
  ├─ tt-approach           │ decisions via tt-tech-proposals ──► Tech Proposals
  ├─ tt-technical-design   ┘
  │    after every stage (and the whole plan): an adversary subagent ──► Challenges
  │    then a break point: carry on, or resume in a fresh session
  └─ tt-plan-signoff, on your sign-off, writes:
       ├─► Comprehensive Tech Plan   (the authority)
       ├─► Future Iterations         (only if work was left out)
       └─► tt-tech-plan ──────────► Tech Plan (brief summary for review)
  │
  ▼
You review the Tech Plan and Proposals
  └─ tt-tech-plan-review: questions and changes, at any time
  │
  ▼
tt-task-breakdown
  ├─► Task Breakdown            (task cards, grouped into work units)
  └─► tt-task-status ────────► Task Status (progress and resume point)
  │
  ▼
tt-execute, one work unit at a time:
  ├─ Agent tasks    ──► tt-coder
  ├─ Engineer tasks ──► a checklist for you
  └─ validate the unit, then stop and report

tt-mr-review stands apart: run it on any open GitLab MR.
```

`tt-workflow` sits over the whole chain: it picks the stage from the documents
in a feature folder and runs the right skill, so you don't have to remember
which one comes next. Every skill below also still runs on its own.

In order:

1. **Explore (optional).** `tt-familiarise` starts from a loose question,
   shows you the code a piece at a time and follows your lead until the focus
   is clear. `tt-familiarisation-doc` writes up just that focus. The doc
   stands on its own, and it's where planning starts.
2. **Plan.** `tt-adversarial-plan` runs the stages in order. Each stage asks
   one question at a time and adds what you agree to the *Consensus Ledger* in
   the draft plan. Each choice between options becomes a proposal you can read
   before deciding. After each stage, an adversary that sees only the written
   documents and the code attacks the stage's reasoning, and you settle each
   challenge. You can stop after any stage and resume later in a fresh
   session. Planning only finishes when you explicitly sign off the whole
   ledger.
3. **Review.** Read the Tech Plan and Tech Proposals. Run
   `tt-tech-plan-review` to walk through the plan, ask about it, or change it.
4. **Break down.** `tt-task-breakdown` checks the plan against the repo,
   proposes tasks and work units, and writes them once you approve.
5. **Build and validate, one unit at a time.** Continue mode picks up from the
   Task Status, does the unit's tasks, then validates the whole unit. It stops
   after each unit.
6. **Commit and publish yourself.** No skill stages, commits, pushes or creates
   branches. Once there's an MR, `tt-mr-review` can review it.

### The lite route (small features and bugs)

The chain above is built for large features. For one request or one bug,
`tt-workflow-lite` asks which you have and runs a shorter route that keeps the
gates that matter (you confirm the focus, every design choice is yours,
references are checked, the unit is validated) and drops the heavy parts (no
adversary rounds, no Proposals, Tech Plan or Future Iterations, no breakdown
stage).

```text
Feature                                          Bug
  tt-familiarise (lite mode) ──► Focus Log         tt-debug ──► Debug Log
  │   + the change you want                        │   hypotheses, evidence, root cause
  ▼                                                ├─► tt-debug-doc ──► Debug Report
tt-lite-brief ◄────────────────────────────────────┘ (to fix it)
  ├─► Lite Brief   (plan + task cards + checks, one document)
  └─ one independent check of the brief against the code
  │
  ▼
tt-execute-lite (best in a fresh session), one unit:
  ├─ Agent tasks    ──► tt-coder
  ├─ Engineer tasks ──► a checklist for you
  └─ validate the unit, then stop and report
```

The Lite Brief is shaped so the same scripts that run a Task Breakdown run it,
and it is its own plan, so `tt-execute-lite` has nothing to drift from: a change
to the goal, the acceptance or a decision goes back through
`tt-lite-brief revise`. If the change grows past about six tasks, use
`tt-workflow`.

## Where to start

| You want to… | Run |
|---|---|
| start or carry on a feature without picking the skill yourself | `/tt-workflow [feature folder \| new]` |
| start or carry on a small feature or a bug fix | `/tt-workflow-lite [bug \| feature \| task folder]` |
| find out which skill to use, or where you left off | `/tt-guide [question]` |
| initialize or refresh the project's selective context/index cache | `/tt-guide init [folder]` or `/tt-guide refresh [folder]` |
| check whether the cached project context is current | `/tt-guide context [folder]` |
| check and set up the project's MCP servers, logins and git settings | `/tt-connections [setup]` (also offered by `/tt-guide init`) |
| say in plain English which connections you want, and save them as a pack | `/tt-guide connections [what to include]` |
| explore how something in the codebase works | `/tt-familiarise <what you want to explore>` |
| write up an exploration | `/tt-familiarisation-doc [focus log]` |
| plan a feature from an idea, exploration, spec or ticket | `/tt-adversarial-plan [description, familiarisation doc, spec or ticket]` |
| carry on planning (next stage, or the pending challenge) | `/tt-adversarial-plan resume <draft plan>` |
| work on one planning stage in its own session | `/tt-requirements`, `/tt-scope`, `/tt-approach`, `/tt-technical-design` or `/tt-plan-signoff` `<draft plan>` |
| review, question or change a written plan | `/tt-tech-plan-review [tech plan] [comprehensive tech plan]` |
| break a signed-off plan into tasks | `/tt-task-breakdown <comprehensive tech plan>` |
| carry on building | `/tt-execute <task status doc>` |
| see where things stand | `/tt-task-status <task status doc>` |
| implement a small plan or ticket without a breakdown | `/tt-coder <plan, spec or ticket>` |
| chase a bug with a pair-programming companion | `/tt-debug <symptom>` |
| write up a debugging session | `/tt-debug-doc [debug log]` |
| plan a small change or a bug fix | `/tt-lite-brief <focus log or debug log>` |
| build a Lite Brief | `/tt-execute-lite <lite brief>` |
| rebuild the brief Tech Plan | `/tt-tech-plan <comprehensive tech plan>` |
| tidy a proposals doc, or create one for an existing plan | `/tt-tech-proposals <proposals doc or comprehensive tech plan>` |
| review a GitLab MR | `/tt-mr-review [MR number or branch]` |

`[…]` is optional and `<…>` is required. If you're new to these skills, start with
`/tt-guide`, or go straight to `tt-adversarial-plan`; it offers to explore the
code first when that helps.

### Selective project knowledge

`/tt-guide init` performs a bounded metadata scan and writes a compact project
profile plus a knowledge index outside the repository, under
`~/.claude/tt-projects/`. It does not summarise the source tree. Use
`/tt-guide refresh` after instruction files or manifests change, and
`/tt-guide context` to check freshness.

After the scan, `init` also checks the project's connections against its
[connection pack](#tt-connections-set-up-a-projects-connections), if one is
installed, and offers to set up what is missing. No pack, no extra step.

Skills remain the executable control layer. Mandatory gates, escalation,
approval and state rules are loaded explicitly from compact rule files.
Optional references are routed by workflow scope and topic through
`tt-common/scripts/knowledge.sh`, then read from their authoritative source.
If the index is missing or stale, a skill falls back to direct source
inspection rather than trusting a cached summary.

## Key ideas

### The documents

All the documents for a feature sit in one folder (an Obsidian vault or a
folder in the repo, agreed during planning) and share a prefix, usually the
feature name. Links are `[[wiki-links]]` in a vault and relative Markdown links
elsewhere.

| Document | File name | Written by | What it's for |
|---|---|---|---|
| Familiarisation | `<Prefix> - Familiarisation.md` | `tt-familiarisation-doc` | How the part of the code you care about works today, with open questions. Description only; where planning starts. |
| Comprehensive Tech Plan | `<Prefix> - Comprehensive Tech Plan.md` | the planning stages, run by `tt-adversarial-plan`; changed only through `tt-tech-plan-review` once signed off | The authority: requirements, approach, scope, constraints, decisions, verified repo facts and step-by-step design. While it's a draft, its **Stages** table records where planning is. |
| Tech Proposals | `<Prefix> - Tech Proposals.md` | `tt-tech-proposals` | Each decision's options, the recommendation, and the outcome. |
| Challenges | `<Prefix> - Challenges.md` | `tt-adversarial-plan` | What each stage's adversary attacked, the evidence, and how you settled it. |
| Tech Plan | `<Prefix> - Tech Plan.md` | `tt-tech-plan` | A brief view of the comprehensive plan. Adds nothing of its own. |
| Future Iterations | `<Prefix> - Future Iterations.md` | `tt-plan-signoff` | Work that came up and was deliberately left out. |
| Task Breakdown | `<Prefix> - Task Breakdown.md` | `tt-task-breakdown` | Task cards and work units, each with an *In plain English* summary for non-technical readers. |
| Task Status | `<Prefix> - Task Status.md` | `tt-task-status` | Progress, logs, decisions and validation results. A new session reads this first. |
| Lite Brief | `<Prefix> - Lite Brief.md` | `tt-lite-brief` | The lite route's plan and task breakdown in one: goal, acceptance, decisions, one work unit with its checks, and the task cards. `tt-execute-lite` builds from it; its Task Status sits beside it. |
| Debug Report | `<Prefix> - Debug Report.md` | `tt-debug-doc`, from the Debug Log in `.tt/<Prefix> - Debug/` | What was wrong, how the root cause was found, what was ruled out and why, and the fix direction. |

### IDs and revisions

Everything agreed in planning gets a stable ID that is never renumbered or
reused: `R` requirements, `A` approach, `S` scope and non-goals, `C`
constraints, `CD` blocking decisions, `NB` non-blocking review items, `P`
proposals, `CH` challenges, `§N` plan steps. Every line of the Tech Plan cites
the IDs it summarises.

A bare `R12` means nothing without the plan open, so the skills say what an ID
means. In chat, the first mention in a message reads `R12 (settings are kept
between runs)`, with the words taken from the plan by `ids.sh gloss`, never from
memory. In the Challenges, Tech Proposals and Tech Plan documents, `ids.sh
linkify` turns the cites into links. In an Obsidian vault the `R`, `A`, `S` and
`C` bullets of the plan end in a block id (`^r12`) so a link lands on the bullet;
`ids.sh anchor --fix` adds them to a plan written before they existed.

The comprehensive plan has a `Revision` and a Change Log. Each review session
that changes its meaning bumps the revision once, and every change leaves an
amendment note quoting the old text. The Tech Plan records the revision it
mirrors, and the breakdown records the revision it was built from, so later
plan changes show up as drift.

### Tasks, work units and who does what

- A **task** is one change: one concern, small enough for one session and one
  review. Every task has one **executor**:
  - **Agent**: code and text files the agent can write.
  - **Engineer**: work done by hand in a tool (an editor, a designer tool, an
    admin console), plus tickets and branches.
- A **work unit** is a few consecutive tasks (usually 2–5) that are **validated
  together**. Tasks are never validated on their own: compile checks, tests and
  the plan's "Done when" checks all run per unit, where their results can
  actually be seen.
- A unit is validated by the **Agent**, or by **Agent + Engineer** when some
  checks need you. Your checks are given inline in chat as numbered steps, with
  what you should see.
- A task is `Implemented` when its steps are done, and `Done` only when its
  unit passes validation. If a check fails, a fix task is added to the unit and
  the whole unit is validated again.

### Long runs: small responses, drafts on disk, subagents

A single model response has a time limit (a few minutes, thinking included),
and one ever-growing conversation gets slow. So the skills follow
[`tt-common/orchestration.md`](../tt-common/orchestration.md) (subagents read
only its short subset,
[`tt-common/subagent-rules.md`](../tt-common/subagent-rules.md), and only the
sections of a `SKILL.md` their brief needs):

- **No response writes a whole document.** Large documents are built from part
  files in a hidden draft folder beside them (`.tt/<Prefix> - <Doc>/`) and
  stitched together by a script. If a session stalls, re-running the skill (or
  saying "continue") picks up at the first missing part instead of starting
  again.
- **Reading, verifying and mechanical writing run in subagents**, up to four at
  a time, mostly on Sonnet: repo research while you're being interviewed,
  checking every reference a plan cites, writing task cards from a skeleton
  you've approved, audits, and rendering the Tech Plan. Questions, decisions
  and design writing always stay in the main conversation.
- **The adversary is a subagent too**, on the strongest model by default because it weighs
  reasoning. It gets only the documents and the code, never the conversation,
  so it also tests whether each stage's handover stands on its own.
- **Planning is split into stages** so no session has to hold all of it. Each
  stage reads only the sections it needs from disk, and the draft plan's
  Stages table says where to pick up.
- **Implementation is one subagent per task**, so the conversation that
  coordinates a work unit stays small. The coordinator is the only writer of
  the Task Status.
- **Scripts do the mechanical checks** (bash and git only):
  `verify-refs.sh` (every path and `path:line` a doc cites, at a commit),
  `check-planning-ids.sh`, `assemble.sh`, `md-section.sh`, `ids.sh`,
  `status-boards.sh` and `status-counts.sh`.
- **Scripts write the Task Status, not the model.** In `tt-execute` every
  routine update is one call: `status-set.sh` (a status change, with the unit,
  header and Resume Here following), `status-log.sh` (applies the result file
  a coder subagent writes, so its report is never re-typed) and
  `status-record.sh` (decisions, risks, validation attempts, each check's
  answer). `continue-preflight.sh` does the reconcile and the plan-drift check
  without a subagent, `run-checks.sh` runs a unit's `checks` block, and
  `validation-checklist.sh` drafts the engineer's checklist. `execute-load.sh`
  prints everything a session starts from in one call, `handoff.sh` writes
  each coder's prompt, `task-files.sh` checks the files a task changed against
  its card, `result-scaffold.sh` pre-writes result files, and `fix-card.sh`
  drafts a fix task after a failed check. Subagents are
  spawned only when a script reports something that needs judgement, or
  can't parse an older document.
- **Scripts write the copied parts of a breakdown.** `donewhen.sh` numbers the
  plan's "Done when" items one way; `skeleton-check.sh` checks the skeleton
  against the plan before the engineer sees it; `skeleton-render.sh` writes
  the manifest, Work Units and Task Map; `card-scaffold.sh` pre-writes each
  unit block and card (tables, links, verbatim Done-when items, Plan ID
  excerpts, Files) so card writers fill in only what needs judgement;
  `coverage.sh` does the mechanical coverage audit; `status-init.sh` creates
  the Task Status. Verification subagents are batched, up to three plan steps
  each.

Agents that can't spawn subagents do the same steps themselves, still one part
per response.

[`docs/script-workflow.md`](https://github.com/TimLewisDev/Tims-AI-Toolbox/blob/main/docs/script-workflow.md) is a one-page summary of
which work moved into scripts, why, and what it changes for you.

### Repo rules come from the repo

The skills don't assume a language or engine. How to build or compile-check,
which files are owned by a tool and must not be hand-edited, and branch rules
are read from the repo's agent instructions (`AGENTS.md`, `CLAUDE.md` or
equivalent). If they don't say how to compile-check, the breakdown asks once
and records the answer.

## Skill reference

### [`tt-guide`](../tt-guide/SKILL.md): ask Tatty

A guide, not a doer. Tatty, a small ASCII robot, says hello with a quip, tells
you where the tt documents in the current folder stand and which command comes
next, then answers questions about the toolbox.

- **Run it:** `/tt-guide [question]`, e.g. "how do I change a signed-off
  plan?". For the greeting and the next command with no model tokens at all,
  type `! bash "<tt-guide folder>/scripts/guide.sh"` in Claude Code.
- **Scripted:** the greeting, the quip (from `tt-common/quips.txt`), the
  "where things stand" check and the catalogue sections it answers from all come
  from `tt-guide/scripts/guide.sh` (`hello`, `where [folder]`, `start`,
  `about <skill or topic>`). The model only holds the conversation.
- **Connections:** `/tt-guide connections` (optionally followed by what you
  want) asks you, in plain English, which MCP servers, logins and git settings
  you use. Tatty plays them back, and only when you say yes does
  `guide.sh pack save` write a machine-wide [connection
  pack](#tt-connections-set-up-a-projects-connections) for you. She never sets
  anything up; `/tt-connections setup` does.
- **Updates:** `/tt-guide update` says whether the toolbox plugins auto-update
  and, on your yes, turns it on by adding `"autoUpdate": true` to the
  `tims-ai-toolbox` entry in your `settings.json`. It also lists how to update
  right now. `/tt-guide migrate` removes the old `~/.claude/skills` links.
- **Won't:** run other skills (the one exception is `tt-connections`, offered
  after `init` and started only on your yes), edit documents, or touch git.
  Besides the project cache, the only things she changes are the connection pack
  and the auto-update switch in `settings.json`, and the old skill links that
  `migrate` removes, each after you confirm it.

### [`tt-connections`](../tt-connections/SKILL.md): set up a project's connections

Works out which connections a project needs (an issue tracker or wiki MCP
server, a source host, a design tool, CLI logins, git settings) and which are
missing, then walks through the missing ones **one at a time**, asking yes or
skip for each. On yes it runs the pack's `claude mcp add` (or fix) command, then
walks you through the step it can't do for you, signing in through `/mcp`, and
stays on that connection until it checks out as connected or you stop. A running
session doesn't list servers added after it started, so it tells you to sign in
from a second terminal or after restarting, and checks from where you left off.
It never asks for a token in chat.

The list is not in this repo or in the project's repo. It is a **connection
pack**, a small tab-separated `.pack` file shared on its own and installed once
per machine. Each pack names the git remotes it applies to, so a different
project gets a different list.

- **Run it:** `/tt-connections` (status) or `/tt-connections setup`. It is also
  offered at the end of `/tt-guide init`. `/tt-guide connections` is for
  writing a pack in plain English (the script `guide.sh connections` only
  reports).
- **Packs:** `pack install <file or folder>`, `pack save <name> [--replace]`
  (the pack text on stdin; exit 4 if the name exists), `list`, `which`,
  `link <pack>` (use a pack whatever the remote), `unlink`. They live in
  `~/.claude/tt-connections/packs/`, with links in `links.tsv` beside them.
- **Pack format:** `# name:` and one or more `# match:` globs on the git remote
  URL (a bare `*` applies to every project, but only when no other pack
  matches; a pack with a specific match always wins), then one row per connection: `id`, `kind`, `label`, `check`, `setup`,
  `next step` (tab-separated, `-` for empty). `kind` is `mcp` (check = the MCP
  server's name in `claude mcp list`) or `cmd` (check = a shell command that
  exits 0 when it works, e.g. `git config user.email` or `glab auth status`).
  An example is `tools/fixtures/connections/example.pack`.
- **Scripted:** `tt-connections/scripts/connections.sh` does the matching and
  every check; the model only asks and runs the commands you approve. MCP setup
  uses the `claude` CLI, so it is Claude Code only.
- **Won't:** accept a secret, edit settings files by hand, or run a setup
  command you haven't said yes to.

### [`tt-workflow`](../../../engineering/skills/tt-workflow/SKILL.md): one entry point

Wraps the whole chain. A script reads which documents a feature folder holds,
so it knows whether the feature is being explored, planned, broken down, built
or finished, and runs the skill that comes next after one confirmation. When
that skill hands back, it looks again. Tatty greets you, without the guide,
and when the feature is finished (here, or when the last work unit passes in
`tt-execute`) she raises her arms and congratulates you.

- **Run it:** `/tt-workflow <feature folder>` the first time (this links the
  folder to the current project), then just `/tt-workflow`. `/tt-workflow new`
  ignores the link, asks where to create a new feature folder and what it is,
  and replaces the old link. `/tt-workflow status` reports without running
  anything; `/tt-workflow unlink` forgets the link.
- **Scripted:** the link (`tt-workflow/scripts/workflow.sh`, kept per project in
  `~/.claude/tt-workflow/links.tsv`, never in your repo or documents) and the
  stage check (`tt-common/scripts/workflow-state.sh`, also behind
  `tt-guide`'s "where things stand").
- **Won't:** edit documents, skip a skill's own gates (sign-off, challenges,
  validation), or stage, commit or push.

### [`tt-familiarise`](../../../engineering/skills/tt-familiarise/SKILL.md): explore the code

A guide, not a planner: you start with a loose question, and it shows you the
code a piece at a time until you've boiled it down to what you care about.

- **Run it:** `/tt-familiarise <what you want to explore>`, e.g. "how
  notifications are sent when an order ships"; carry on later with
  `/tt-familiarise resume <focus log>`.
- **How a session goes:** it asks why you're exploring (to change, debug,
  plan or learn), maps the area with read-only subagents, describes what it
  finds in plain words with `path:line` references and small diagrams, then
  asks which way to dig. Every few turns it plays back what it thinks you're
  really after and asks you to rate the topics: **Focus**, **Context** or
  **Parked**.
- **Writes:** a Focus Log in `.tt/<Prefix> - Familiarisation/`, updated
  every turn, so a fresh session can carry on or write it up.
- **Won't:** design, recommend or plan, or decide for you what you're
  interested in.

### [`tt-familiarisation-doc`](../../../engineering/skills/tt-familiarisation-doc/SKILL.md): write up the exploration

- **Run it:** `/tt-familiarisation-doc [focus log]`, straight after
  exploring or in a fresh session.
- **Writes:** `<Prefix> - Familiarisation.md`, covering only your Focus
  topics and the context needed to read them: the question, the answer in
  short, how it works today, key parts, data and contracts, rules the code
  imposes, gotchas, open questions (not agreed), and what was left out. Every
  reference is checked at the pinned commit.
- **Then:** read it on its own, or plan from it with
  `/tt-adversarial-plan <familiarisation doc>`.

### [`tt-adversarial-plan`](../../../engineering/skills/tt-adversarial-plan/SKILL.md): plan a feature

An orchestrator. It runs the planning stages in order, has an adversary
challenge each one, and only finishes on your explicit sign-off.

- **Run it:** `/tt-adversarial-plan [description, familiarisation doc, spec
  or ticket]`; carry on with `/tt-adversarial-plan resume <draft plan>`.
- **Stages:** familiarisation (optional) → `tt-requirements` →
  `tt-scope` → `tt-approach` → `tt-technical-design` → a whole-plan
  challenge → `tt-plan-signoff`. Each stage is a skill of its own that writes
  its Ledger sections into the draft plan. Shared rules live in
  [`tt-common/planning-protocol.md`](../tt-common/planning-protocol.md).
- **The adversary:** after each stage, a subagent that sees only the written
  documents and the code attacks that stage's assumptions, using the stage's
  own `challenge-lens.md`. Every challenge is put to you: accept and change,
  rebut, or defer. The outcomes are kept in `<Prefix> - Challenges.md`. A
  stage closes only when no blocking challenge is still unresolved.
- **Break points:** after each stage it summarises, gives the resume command,
  and asks whether to carry on or stop. The draft plan's Stages table is the
  handover.
- **The Ledger is on disk:** the Comprehensive Tech Plan exists from Setup
  with Status `Draft`, and fills in as items are agreed. Chat shows only what
  changed. Other skills refuse to work from a `Draft` plan.
- **Key rules:** one question at a time; a contradiction stops progress until
  you resolve it, even if it reopens a closed stage; blocking decisions wait
  for your choice, while review items apply the recommendation and stay open
  for review; it never decides you're finished, and "looks fine" doesn't count
  as sign-off.
- **Won't:** write production code, or add test plans, rollout plans or
  speculative work unless you ask.

### The planning stages

Normally run by `tt-adversarial-plan`. Each can also be run on its own with
the draft plan's path, to work on one stage in a session of its own. It then
ends by pointing you to `/tt-adversarial-plan resume <plan>`, so that the
stage still gets challenged.

| Stage | Settles | Notes |
|---|---|---|
| [`tt-requirements`](../../../engineering/skills/tt-requirements/SKILL.md) | `R`: what the feature must do | Probes with hypotheticals; builds on the Familiarisation doc's description and open questions; maps the repo in the background if there's no Familiarisation doc. |
| [`tt-scope`](../../../engineering/skills/tt-scope/SKILL.md) | `S`, `C`: what it is and isn't; hard constraints | Seeds non-goals from what the exploration left out, and constraints from the repo's rules; records excluded work for Future Iterations. |
| [`tt-approach`](../../../engineering/skills/tt-approach/SKILL.md) | `A`, Rejected Alternatives | At least two candidates, each researched against the repo by a subagent; the choice is a proposal you decide. |
| [`tt-technical-design`](../../../engineering/skills/tt-technical-design/SKILL.md) | Repo Facts, `CD`, `NB`, step outline | Verifies every claim at the pinned commit; hunts critical decisions; outlines the steps in dependency order. |
| [`tt-plan-signoff`](../../../engineering/skills/tt-plan-signoff/SKILL.md) | sign-off, finished plan set | The termination gate, then the full steps, audits, Revision 1, Tech Plan and Future Iterations. |

### [`tt-tech-proposals`](../../../engineering/skills/tt-tech-proposals/SKILL.md): present decisions

Makes each decision easy to review later without the conversation that
produced it: the question, a side-by-side table, each option under the same
headings, the recommendation, and the decision.

- **Run it:** normally called by the planner or plan review. Run directly to
  tidy a proposals doc and check it against its plan, or to create proposals
  for a plan that has none, using only the alternatives the plan records.
- **Statuses:** `Open`, `Default applied` (recommendation in use, open for
  review), `Decided`, `Superseded`.
- **Key rules:** the calling skill supplies every option and fact, and this
  skill only arranges them; proposals are never deleted, and reopening a
  decided one creates a new proposal that supersedes it.
- **Won't:** invent options, benefits or risks; change plan content (it
  reports mismatches to `tt-tech-plan-review`).

### [`tt-tech-plan`](../../../engineering/skills/tt-tech-plan/SKILL.md): summarise the plan

A renderer, not a planner: it turns the comprehensive plan into a five-minute
read (about 60–120 lines, no code blocks).

- **Run it:** `/tt-tech-plan <comprehensive tech plan>`. Usually called by
  other skills.
- **Modes:** *Write* (new), *Regenerate* (full rewrite), *Update* (only the
  lines citing changed IDs).
- **Key rules:** every line cites its IDs; records `Mirrors revision`; anything
  missing from the plan is reported, not patched into the summary.
- **Won't:** add, infer or reinterpret anything. Given a spec or ticket, it
  points you to `tt-adversarial-plan`.

### [`tt-tech-plan-review`](../../../engineering/skills/tt-tech-plan-review/SKILL.md): review and change a plan

A conversational review partner, and the only way a written plan changes.

- **Run it:** `/tt-tech-plan-review [tech plan] [comprehensive tech plan]`.
  Either order works; one path is enough if it links the other; with none, it
  asks.
- **How a session goes:** it reads the whole plan set (and any breakdown,
  read-only), then gives a short orientation: revision, whether the Tech Plan
  is in sync, open proposals and breakdown progress. Then it asks what you'd
  like: a section-by-section walkthrough, the open proposals, a specific
  change, or questions. It loops until you say you're done, then summarises.
- **Changes:** one at a time. It shows the impact and a before/after for every
  affected document, and writes only after you confirm. The comprehensive plan
  changes first, then the Tech Plan, Proposals and Future Iterations.
- **Key rules:** one revision per session however many changes it makes;
  confirming a `Default applied` proposal records the decision without a new
  revision; switching a decision's option goes through a proposal.
- **Won't:** edit the Task Breakdown or Task Status. Changes show up as drift
  the next time `tt-task-breakdown` continues.

### [`tt-task-breakdown`](../../../engineering/skills/tt-task-breakdown/SKILL.md): slice the plan

Turns the plan into tasks and work units. It slices the design but never
changes it.

- **Run it:** `/tt-task-breakdown <comprehensive tech plan>`.
- **What it does:** verifies every path and symbol the plan cites on its base
  branch (a script, then batched subagents); drafts a skeleton (units, tasks,
  files, where each "Done when" check lands and who checks it), checks it with
  a script, and gives it to you to approve; scaffolds every unit block and
  card from it, then has subagents fill in what needs judgement, one unit
  each; runs the coverage audit as a script; assembles the documents and
  creates the Task Status.
- **Calls:** `tt-task-status` to create the Task Status.
- **Shares** its rules for tasks, work units, amendments and Critical
  Decisions with `tt-execute` (`tt-common/breakdown-rules.md`).
- **Won't:** start any work, redesign the feature, edit the plan (it sends you
  to `tt-tech-plan-review`), or offer to commit.

### [`tt-execute`](../../../engineering/skills/tt-execute/SKILL.md): work through the breakdown

Drives the build one work unit at a time, from the Task Status.

- **Run it:** `/tt-execute <task status doc>`, or `/tt-execute status <task
  status doc>` for the report only.
- **What it does:** loads everything it needs in one script call; runs a
  pre-flight script that reconciles the Task Status with the repo and flags
  plan changes since the breakdown (a subagent only if the plan changed);
  confirms the next unit with you once; runs each task in its own coder
  subagent, back to back, with a prompt a script writes, checks the files each
  one changed against its card, and applies its result file with a script;
  then validates the unit: the agent checks from its `checks` block, then your
  checklist inline in chat. A failed check becomes a fix task, drafted by a
  script, which you approve.
- **Calls:** `tt-coder` for each Agent task; `tt-task-status` (mostly through
  its scripts) for every status change.
- **Won't:** write code itself, redesign the feature, edit the plan, or offer
  to commit.

### [`tt-task-status`](../../../engineering/skills/tt-task-status/SKILL.md): keep the resume point

Owns every write to the Task Status doc, so it stays something a fresh session
can trust.

- **Run it:** `/tt-task-status <task status doc>` for a summary, a
  consistency check and a reconcile with the repo. Usually called by other
  skills.
- **Operations:** `init`, `set`, `log`, `record`, `reconcile`, `summary`.
  Each routine one is a script (`status-init.sh`, `status-set.sh`,
  `status-log.sh`, `status-record.sh`, `continue-preflight.sh`) that makes the
  edit and recomputes the header in one atomic write; the skill's rules cover
  the rest and the fallback when a script can't read a document.
- **Key rules:** saves at every state change, including `In Progress` before
  any code changes; boards, header and *Resume Here* always agree; corrections
  found by reconcile are applied only after you confirm; nothing is deleted.
- **Standalone mode:** when `tt-coder` works from a plan with no breakdown,
  the doc has no work units and a task is `Done` once its compile check
  passes.
- **Won't:** check for plan drift (that's `tt-execute`'s job), or stage,
  commit, push or branch.

### [`tt-coder`](../../../engineering/skills/tt-coder/SKILL.md): write the code

Implements exactly what it's given and escalates everything else.

- **Run it:** called by `tt-execute` with one task card, or directly with a
  plan, spec or ticket (standalone).
- **Via a breakdown:** one task only; no validation. It writes a result file
  (files changed, summary, *To validate* notes for the unit's checks, risks,
  improvements, any Critical Decision), starting from a scaffold a script
  prints, that the coordinator applies to the Task Status with a script.
- **Standalone:** works the plan's steps in order, keeps a minimal Task Status,
  runs a compile check using the repo's method, and gives you inline
  validation steps. Those rules are in `standalone.md`, so a delegated coder
  never loads them.
- **Key rules:** the codebase is the source of truth, ahead of your
  instructions, the task card and the plan; it makes only small local
  decisions itself; anything bigger is a *Critical Decision* that marks the
  task `Blocked` and waits for you; it records improvements it spots instead of
  making them; no planning IDs (`T07`, `R14`, `CD1`…) in code, comments or test
  names.
- **Won't:** expand scope, refactor nearby code, add dependencies, or touch
  git.

### The lite route

Not yet exercised in a live session.

#### [`tt-workflow-lite`](../../../engineering/skills/tt-workflow-lite/SKILL.md): one entry for small work

Like `tt-workflow`, but for one small feature or one bug. It asks which, links a
folder for that task (kept in its own file, `~/.claude/tt-workflow/lite-links.tsv`,
so it never replaces the folder `tt-workflow` links), reads where the documents
stand with the same script, and runs the next skill after one confirmation.

- **Run it:** `/tt-workflow-lite bug`, `/tt-workflow-lite feature`, or just
  `/tt-workflow-lite` to carry on; `status`, `unlink` and `<task folder>` work
  as in `tt-workflow`.
- **Fresh session:** at its confirmation (and before `tt-execute-lite`, where
  it recommends it) it offers **Continue in a new session**. On yes it opens a
  new terminal tab named `<Feature> : <Stage>` that starts with
  `/tt-workflow-lite` (`tt-common/scripts/session-handoff.sh`). A skill can't
  clear its own session, but it can start another. `tt-workflow`, the planning
  break points, the end of an exploration or a debugging session, a lite
  brief and each finished work unit offer the same.

#### [`tt-lite-brief`](../../../engineering/skills/tt-lite-brief/SKILL.md): plan the small change

- **Run it:** `/tt-lite-brief <focus log or debug log>`; change a brief later
  with `/tt-lite-brief revise <lite brief>`.
- **How it goes:** reads the confirmed log, puts every design choice to you with
  options and a recommendation, outlines the tasks for your approval, writes the
  brief from parts, checks it by script (structure, references, planning IDs),
  and has one independent subagent test it against the code before you see the
  command to build it.
- **Writes:** `<Prefix> - Lite Brief.md`: goal, acceptance, how it works today,
  the decisions taken, what's out of scope, one work unit with its checks, and
  the task cards. The two overview tables are written by `lite-index.sh`.
- **Won't:** make a design choice for you, write production code, or commit.

#### [`tt-execute-lite`](../../../engineering/skills/tt-execute-lite/SKILL.md): build the brief

- **Run it:** `/tt-execute-lite <lite brief>`; `status` reports only. Best in a
  fresh session.
- **How it goes:** creates (or resumes) the Task Status, reconciles it with the
  repo, runs each Agent task in its own `tt-coder` subagent and each Engineer
  task as a checklist for you, then validates the unit: the agent's checks by
  script, yours inline in chat. It uses the same scripts as `tt-execute`.
- **Differs from `tt-execute`:** the brief is the only plan, so there is no
  plan-drift or reconcile subagent and no breakdown to amend; a change to the
  goal, acceptance or a decision goes back to `tt-lite-brief revise`.
- **Won't:** write production code itself, or commit.

#### [`tt-debug`](../../../engineering/skills/tt-debug/SKILL.md): a debugging companion

You drive; it navigates. Started from a symptom, it asks for expected versus
actual behaviour, how to reproduce it and what you've tried, maps the failing
path with read-only subagents, and keeps ranked hypotheses with the evidence
for and against each.

- **Run it:** `/tt-debug <symptom>`; carry on with `/tt-debug resume <debug log>`.
- **Following your lead:** after each step it offers two to four next
  experiments with what each result would mean, and takes your idea first,
  recording your hypotheses as yours. Nothing happens without your direction.
- **Root cause, not symptom:** it keeps asking why, and calls it a root cause
  only with a cited mechanism, an observation that tells it apart, and an
  explanation of every observation so far. You confirm.
- **Hands off the code:** it reads and traces. It adds temporary logging only
  when you ask; every such line carries `TT-DEBUG-TEMP` and
  `tt-common/scripts/debug-temp.sh` must find none left before it closes.
- **Ends with:** the Debug Report (`tt-debug-doc`), a fix through `tt-lite-brief`,
  or just stop. The Debug Log in `.tt/<Prefix> - Debug/` lets a fresh session
  resume.
- **Won't:** write the fix, run anything with side effects unasked, or touch git.

#### [`tt-debug-doc`](../../../engineering/skills/tt-debug-doc/SKILL.md): the Debug Report

- **Run it:** `/tt-debug-doc [debug log]`. `tt-common/scripts/debug-doc.sh`
  renders the report straight from the log (no model writes it), refuses a log
  that isn't finished and lists what's missing; the skill then checks the
  references and applies your corrections.

### [`tt-mr-review`](../../../engineering/skills/tt-mr-review/SKILL.md): review a GitLab MR

A line-by-line review meant to stand in for a senior engineer's review.

- **Run it:** `/tt-mr-review [MR number or branch]`. With no argument, it
  uses the MR for the current branch.
- **Needs:** `glab` (authenticated) or a GitLab MCP server; ideally the repo
  checked out, otherwise it reviews from the diff alone.
- **Checks:** correctness, security, performance, style (the repo's rules and
  `.editorconfig` are the source of truth), test coverage, and stack-specific
  checks from `references/` when the repo uses that stack (Unity and C#
  today). Changed files are reviewed in parallel groups, and every critical or
  major finding is challenged by a separate subagent before it's shown. Each
  finding has a file, line, severity and suggested fix. Binary and generated
  files are skipped.
- **Key rules:** shows every finding before posting anything; posts only the
  inline comments and summary you approve (partial approvals work); flags only
  issues the MR introduced or made worse.
- **Won't:** approve or merge the MR.


### Stage-completion events

Each finished stage or gate (a planning stage closed, the plan signed off, a
work unit validated, the feature complete, and the lite and debug equivalents)
is recorded as one line in an append-only ledger,
`~/.claude/tt-events/events.jsonl`, so a companion app can follow progress and
award experience without reading the documents. The lines are facts only; the
reader decides what they are worth. Writing is silent and best-effort, and
`TT_EVENTS=off` turns it off. `tt-workflow` and `tt-workflow-lite` also
backfill any stage the documents prove but the ledger lacks. The schema, the
event catalog and the rules for a reader are in
[`tt-common/events.md`](../tt-common/events.md); the writer is
`tt-common/scripts/tt-event.sh` (`where`, `tail` and `events` show the path, the
latest lines and the event names).

### Choosing models and effort (`tt-config`)

Every place a skill picks a model for a subagent is a named **role**
(`adversary`, `coder`, `explore`, …), listed in
[`tt-common/model-roles.tsv`](../tt-common/model-roles.tsv) from highest value for
a stronger model to lowest. At each spawn the skill runs
`tt-common/scripts/model-config.sh get <role>` and passes the model and the
thinking effort to the Agent tool, so changing a setting never means editing a
skill.

```
/tt-config                 # ranked table, then questions: change a stage, switch mode, save as a new mode
/tt-config mode economy    # swap the whole set at once
/tt-config save cheap      # keep the current choices under a name
```

- **Modes** are saved sets of choices. Shipped: `recommended` (Opus on the
  adversary and the MR refute pass, Sonnet elsewhere), `economy` (all Sonnet)
  and `thorough` (recommended, plus Opus on the gates before code). Your own
  modes and edits live in `~/.claude/tt-config/`, outside every repo.
- **Subagent roles** take effect from the next spawn. **Advisory rows** are the
  stages that run in your own session (approach and technical design default to
  Opus, high effort): a skill can't change the session's model, so the
  workflow skills show a one-line reminder to run `/model` and `/effort`.
- On Bedrock or a gateway, set `ANTHROPIC_DEFAULT_OPUS_MODEL` (and the Sonnet
  one) in the env block of `settings.json`, or the `opus` alias may not
  resolve; `/tt-config` warns when it looks missing.

### Measuring a run

[`transcript-metrics.sh`](../tt-metrics/scripts/transcript-metrics.sh) (in `tt-metrics/scripts/`) reads Claude Code's
session transcripts and prints, per session and subagent: model minutes, the
largest single response, responses over 8k tokens, the largest context,
responses over 4 minutes, stalls, and subagent calls. Use it to compare runs:

```sh
bash "<tt-metrics folder>/scripts/transcript-metrics.sh" --since 2026-10-08 ~/.claude/projects/<project>
```

For token use, `--tokens` prints one row per session with its subagents added
in (cache write, cache read, input, output, a weighted total and the largest
context), and `--detail <session>` splits one session by thread:

```sh
bash "<tt-metrics folder>/scripts/transcript-metrics.sh" --tokens --since 2026-10-08 ~/.claude/projects/<project>
bash "<tt-metrics folder>/scripts/transcript-metrics.sh" --detail <session id> ~/.claude/projects/<project>
```

The weighted total is cache write × 1.25 + cache read × 0.1 + input + output ×
5: tokens priced relative to plain input on one model, so compare runs on the
same model.

#### Token log

`--record <log.md>` appends the session to a markdown table (most recent
session, or every session in range with `--all`), so the numbers outlive
Claude Code's transcript clean-up. Recording a session again replaces its row.

```sh
bash "<tt-metrics folder>/scripts/transcript-metrics.sh" --record ~/.claude/tt-metrics/token-log.md --all \
  --since 2026-10-06 --match '(^|,)tt-' --label "baseline" ~/.claude/projects/<project>
```

To record every session that uses a `tt-*` skill automatically, turn on
logging with the [`tt-metrics`](../tt-metrics/SKILL.md) skill:

```
/tt-metrics on        # once per machine; persists across sessions
/tt-metrics status
/tt-metrics report --last 10
/tt-metrics off
```

`on` creates a flag file at `~/.claude/tt-metrics/enabled`. The
[`record-session.sh`](../tt-metrics/scripts/record-session.sh) `SessionEnd`
hook comes with the core plugin, so nothing is added to `settings.json`
(a `record-session.sh` entry left there from before the plugin would log
every session twice: remove it). `off` removes the flag and leaves the hook,
which then does nothing. Rows go to `~/.claude/tt-metrics/token-log.md`.
`TT_METRICS=off` overrides the flag, `TT_METRICS_LABEL` labels the rows,
`TT_METRICS_HOME` moves the state directory and `TT_METRICS_LOG` the log. A
session that ends with Claude Code being killed isn't recorded;
`--record --all` picks it up later.
