# Scripts do the routine work: what changed and how to use it

## Why

Every subagent costs a fixed amount before it does anything: it loads its
instructions, its tools and the files it needs, often 70–85k tokens. And
every time the main conversation re-types something that is already on disk,
it pays for those tokens as output, the most expensive kind. Much of what the
skills did was copying and checking: tables from one document into another,
status updates, coverage counts, running a list of commands. Scripts can do
that for almost nothing, and they do it the same way every time.

So the rule now is: **the model does judgement, scripts do copying and
checking, and files on disk carry the results between them.**

## What changed

| Phase | Change | What it's for |
|---|---|---|
| 0. Measure | `transcript-metrics.sh --tokens` (in `plugins/core/skills/tt-metrics/scripts/`), and a hook that logs every `tt-*` session to `~/.claude/tt-metrics/token-log.md` | See what a run costs, before and after a change |
| 1. Continue mode | `status-set.sh`, `status-log.sh` and `status-record.sh` write the Task Status. `continue-preflight.sh` replaces the reconcile and plan-drift subagents. `run-checks.sh` runs a unit's checks. `validation-checklist.sh` drafts your checklist. Implementation subagents write a result file. | No re-typed reports, and no subagents just to compare files or run commands |
| 2. Breakdown mode | `donewhen.sh`, `skeleton-check.sh`, `skeleton-render.sh`, `card-scaffold.sh`, `coverage.sh` and `status-init.sh`. Verification subagents are batched. | Card writers fill in only the parts that need thought; checks and tables come from scripts |
| 3. Smaller reads | Subagents read `tt-common/subagent-rules.md` (2k) instead of `orchestration.md` (5k), and only the `SKILL.md` sections they need | Every subagent starts smaller |

## Why it's better for us

- **Cheaper.** Fewer subagents per session, and less output on the main
  thread.
- **More reliable.** A script counts, copies and checks the same way every
  time. The model used to number "Done when" items three different ways in one
  skeleton.
- **Easier to resume.** Results land in files (result files, attempt files,
  logs), so a stalled session loses nothing.
- **Safe fallback.** If a script can't read an older document, the skill falls
  back to the old subagent and tells you.

## How to use it

Nothing changes in how you start the skills:

1. **Plan:** `/tt-adversarial-plan` as before.
2. **Break down:** `/tt-task-breakdown <comprehensive tech plan>`. You review
   and approve the skeleton as before. The skill now checks it with a script
   before showing you, and the cards come from a scaffold.
3. **Build:** `/tt-execute <task status>`. The pre-flight
   runs first, without subagents. Then come the tasks, then the unit's checks,
   then your checklist in chat. Answer each check as before; the skill records
   it.
4. **Measure.** Once logging is on (`/tt-metrics on`; the `SessionEnd` hook comes with the core plugin, see
   the catalogue's Token log section), every session that uses a `tt-*` skill
   adds a row to `~/.claude/tt-metrics/token-log.md` when it ends. End it with
   `/exit`; a killed window may not record. To label the run:
   - from Git Bash, start with `TT_METRICS_LABEL="<what you're testing>" claude`;
     from PowerShell, `$env:TT_METRICS_LABEL = "<…>"; claude`;
   - or, from anywhere, label it afterwards (this also records a session the
     hook missed):
     `bash plugins/core/skills/tt-metrics/scripts/transcript-metrics.sh --record ~/.claude/tt-metrics/token-log.md --session <id> --label "<…>" ~/.claude/projects/<project>`.
     `--tokens --since <date>` lists recent sessions and their IDs.

   For one session's breakdown by subagent, run `--detail <id>`. To stop
   logging, set `TT_METRICS=off` the same way, or remove the hook.

Two things are new for you to know:

- **A unit's "How to validate" has a `checks` block.** Each line is
  `<check number> | ok, empty or nonempty | <command>`, and the agent runs it.
  Older breakdowns without one still work, the old way.
- **The skeleton's Done-when map has a "Checked by" column**, and "Done when"
  items are numbered one way: a bullet with sub-bullets is a heading, and each
  sub-bullet is an item.

To check the scripts after changing them: `bash tools/test-scripts.sh`.
