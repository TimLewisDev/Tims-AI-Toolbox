---
name: tt-common
description: >
  Shared orchestration rules and helper scripts used by the other tt-* skills
  (output budget, checkpointed drafts, subagent briefs and the RESULT contract,
  the planning protocol shared by the planning stages, shared templates,
  and bash scripts for verifying references, assembling documents, extracting
  sections and cross-checking IDs). Not run directly; the other skills read
  orchestration.md and call scripts/ from here.
user-invocable: false
disable-model-invocation: true
metadata:
  version: "1.0"
---

# tt-common

Support files for the `tt-*` skills. Nothing here runs on its own.

- [`orchestration.md`](orchestration.md): the rules every `tt-*` skill follows
  for output size, drafts on disk, stall recovery, subagents and models. Skills
  that orchestrate read it before they start.
- [`subagent-rules.md`](subagent-rules.md): the short subset a subagent
  follows (no talking to the engineer, no git writes, one part per Write, the
  RESULT block). Every brief and handoff points subagents here instead of at
  `orchestration.md`, so each one reads about 2k characters instead of 5k.
- [`planning-protocol.md`](planning-protocol.md): the rules every planning
  stage follows (role, Consensus Ledger, IDs, Setup, the stage contract,
  contradiction handling, Critical Decisions, proposals and challenge
  resolution). The planning stages and `tt-adversarial-plan` read it.
- [`breakdown-rules.md`](breakdown-rules.md): the rules for tasks, work units,
  executors, amendments and Critical Decisions shared by `tt-task-breakdown`
  (which writes the breakdown) and `tt-execute` (which works through it).
- [`templates/`](templates/): templates shared by more than one skill
  (`comprehensive-plan.md`, created by whichever stage runs Setup;
  `critical-decision.md`, how the breakdown skills present a decision).
- [`scripts/`](scripts/): POSIX bash plus git helpers. Run them as
  `bash "<this folder>/scripts/<name>.sh" …`. Each one prints usage with `-h`.

| Script | Use |
|---|---|
| `verify-refs.sh` | Check every file path and `path:line` a markdown doc cites, at a commit or in the working tree |
| `check-planning-ids.sh` | Find planning IDs (task, unit, plan, decision IDs) in code or in a card's code blocks |
| `assemble.sh` | Build a document from part files; report which parts are missing or incomplete; append or insert parts |
| `md-section.sh` | Index a markdown doc's headings; print one section by heading |
| `ids.sh` | List the IDs a plan defines or a doc cites; cross-check one against another |
| `status-boards.sh` | Build a new Task Status's boards from a Task Breakdown's tables |
| `status-counts.sh` | Recompute a Task Status's derived header fields from its boards; flag inconsistencies |
| `status-set.sh` | Set a task's or unit's status; the unit, tasks, Step Log, header and Resume Here follow |
| `status-log.sh` | Apply a coder subagent's result file: Step Log entry, risks, improvements, then the status |
| `status-record.sh` | Record a decision, breakdown change, risk, improvement, validation attempt or one check's result |
| `continue-preflight.sh` | Reconcile a Task Status with its breakdown, plan and repo without a model; flag plan drift |
| `run-checks.sh` | Run a work unit's `checks` block; save logs and write the validation attempt |
| `validation-checklist.sh` | Draft a unit's engineer checklist from its block, its latest attempt and its tasks' To validate notes |
| `execute-load.sh` | Print what `tt-execute` reads to start: the status header, Resume Here and boards, the breakdown header and Work Units, the current unit's block |
| `handoff.sh` | Print the filled-in coder handoff prompt for one task |
| `task-files.sh` | Snapshot the working tree before a task; afterwards list the files it changed and flag any not on its card |
| `result-scaffold.sh` | Print a task's result file with its heading, unit and changed files written, `<!-- fill: -->` markers for the rest |
| `fix-card.sh` | Draft a fix task for a failed unit: next ID, table rows and the card with its known fields filled |
| `donewhen.sh` | List a plan's "Done when" items, numbered `§N #k` the one way every skill uses (sub-bullets are the items) |
| `skeleton-tsv.sh` | Read a breakdown skeleton's tasks, units, Done-when map and unit checks as TSV (used by the scripts below) |
| `skeleton-check.sh` | Check a skeleton against its plan: steps, units, dependencies, parallel tasks, the Done-when map, Affected Files |
| `skeleton-render.sh` | Write the manifest, the Work Units table and the Task Map from a skeleton |
| `card-scaffold.sh` | Pre-write a unit's block and cards from the skeleton, plan and glossary, with `<!-- fill: -->` markers for the rest |
| `coverage.sh` | The mechanical coverage audit of a breakdown's parts; writes the Coverage section |
| `status-init.sh` | Create a Task Status from a finished breakdown |
| `workflow-state.sh` | Work out where the tt documents in a folder stand and which skill comes next (used by `tt-workflow` and `tt-guide`) |
| `tatty.sh` | Draw Tatty with a quip from `quips.txt` (used by `tt-guide` and `tt-workflow`) |

The status scripts write atomically, keep line endings, and print one line per
change, never the document. `tools/test-scripts.sh` in the repo runs them
against a fixture.

Exit codes for every script: `0` clean, `1` findings (or nothing found), `2`
usage or environment error.
