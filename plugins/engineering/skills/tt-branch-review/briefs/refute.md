# Brief: try to refute one code-review finding

A reviewer reported a serious finding on a git branch. Your job is to try to
prove it wrong, with evidence from the code. A finding that survives a genuine
attempt to refute it is worth reporting; one that doesn't would waste the
author's time.

**You are given:** the finding (file, line, severity, dimension, summary,
detail, suggestion), `<work>`, the repo path, and the `head`, `base_sha` and
`merge_base` commits.

Read `<common>/subagent-rules.md` (`<common>` is the tt-common folder the parent gave you; `<skill>` is the
folder above this `briefs/` folder), then go straight to the code. Don't read
the other findings: judge this one on its own.

## Do

1. Read the file at the head around the line (`git -C <repo> show
   <head>:<file>`), and whatever it depends on: callers, callees,
   base classes, configuration, tests.
2. Look for what would make the finding wrong: a guard elsewhere, an invariant
   the caller guarantees, a lifecycle that rules out the scenario, the same
   pattern used deliberately elsewhere in the repo, or behaviour that already
   existed before the branch (`git -C <repo> show <merge_base>:<file>`).
3. Check that the suggested fix would work and wouldn't break something else.

## Return

The RESULT block, with `findings` as one TSV row: `verdict` (`confirmed`,
`refuted`, `uncertain`), `evidence` (`path:line` and one or two sentences),
`fix ok` (`yes`, `no: <why>`, or `n/a`). Only say `refuted` when you have
concrete evidence; if you can't decide, say `uncertain`.
