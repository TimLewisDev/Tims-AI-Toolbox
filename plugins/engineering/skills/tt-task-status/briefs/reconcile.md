# Brief: reconcile a Task Status document with the repo (read-only)

You check whether a Task Status document still matches reality, and report
every discrepancy with a proposed correction. You change nothing: the
orchestrator presents your findings to the engineer and applies what they
confirm.

`continue-preflight.sh` does these checks mechanically and is used first. You
are the fallback, for a document it can't parse (it exited `2`), or when the
caller asks for a reconcile by hand.

**You are given:** the Task Status path, the Task Breakdown path (if any), the
repo path, and `<scripts>` (the `tt-common/scripts` folder).

Read `<scripts>/../subagent-rules.md` first, then only the `reconcile`
operation in `<skill>/SKILL.md` (`<skill>` is the folder above `briefs/`):
`` bash "<scripts>/md-section.sh" get "<skill>/SKILL.md" "### \`reconcile\`" ``.

## Do

Read the status header and boards with `md-section.sh get`. Read Step Log
entries one at a time, only for the tasks you're checking. Use
`git --no-optional-locks` for every git command; never change anything.

1. **Branch:** the current branch matches the header's Branch.
2. **Files:** files created by `Implemented` or `Done` tasks exist (from their
   Step Log's Files Modified); files a `Todo` task will create (from its card's
   Files, `md-section.sh get <breakdown> "### <ID> —"`) don't exist yet.
3. **In-progress work:** for each `In Progress` task, `git status --short` and
   `git diff --stat` on its card's files, compared with its Steps: how far it
   got.
4. **Changed since validation:** for each `Done` unit, and each unit whose
   latest validation attempt has results, `git log --since=<attempt run time>
   --name-only` and `git status --short` on its tasks' files. A change after
   the run means its evidence is stale.
5. **Breakdown agreement:** the boards have the breakdown's task and unit IDs,
   executors and unit membership.
6. **Internal consistency:** header State, Progress, Current Unit, Current
   Task, Next, Resume Here and each Step Log Status line agree with the boards.

Report whether work is committed only where it explains a discrepancy.

## Return

The RESULT block. `findings`: one TSV row per discrepancy: `check`, `item`
(task, unit or field), `found`, `expected`, `proposed correction`, `kind`
(`fact`: needs the engineer's confirmation; `derived`: can be fixed directly).
`findings: none` if everything agrees.
