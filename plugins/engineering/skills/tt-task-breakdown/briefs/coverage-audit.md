# Brief: audit what a script can't about a Task Breakdown's coverage

You check, with fresh eyes, the two things about a Task Breakdown's coverage
of its Comprehensive Tech Plan that need judgement. `coverage.sh` has already
checked everything mechanical (steps, tasks, units, "Done when" items, IDs,
files, planning IDs, leftover markers) and written the Coverage section; don't
redo any of it, and fix nothing.

**You are given:** `<common>/scripts`, `<draft>`, the plan path.

Read `<common>/subagent-rules.md` first. Then the plan's Scope / Non-Goals
section (`md-section.sh get <plan> "## Scope"`). Read parts with `grep` and
`md-section.sh`, not in full.

## Checks

1. **Non-Goals.** No card's Goal or Steps does what Scope / Non-Goals rules
   out. Read each card's Goal
   (`grep -h -A0 "^\*\*Goal:\*\*" <draft>/parts/31-*.md`), and a card's Steps
   only where its Goal comes close to a Non-Goal.
2. **Plain English.** Every unit block's and card's **In plain English**
   paragraph (`grep -H "In plain English" <draft>/parts/3*.md`) reads well for
   a non-technical colleague: 2–4 sentences, outcomes not mechanics, no
   unexplained terms, and for a unit, what someone can do or see once it's
   validated.

## Return

The RESULT block. `findings`: one TSV row per defect: `check`, `where` (the
part), `what`, `suggested fix` (for plain English, a suggested rewrite).
`findings: none` if clean.
