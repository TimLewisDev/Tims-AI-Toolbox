# Brief: find plan changes since the breakdown was written

You report how a Comprehensive Tech Plan changed after its Task Breakdown was
written, and which cards and unit checks each change touches. Read-only. You
propose nothing.

The orchestrator spawns you only when `continue-preflight.sh` reports drift
(the plan's revision is above "Plan read") or couldn't read either revision.

**You are given:** the plan path, the breakdown path, the breakdown's "Plan
read" revision, the current unit's ID, and the IDs of the later units.

Read `<common>/subagent-rules.md` first (`<common>` is the
`tt-common` folder next to this skill's folder).

## Do

1. Read the plan header's `Revision`. If it equals the "Plan read" revision,
   return `findings: none` and stop.
2. Read the plan's Change Log (`md-section.sh get <plan> "## Change Log"`). Take
   every row with a revision above "Plan read".
3. For each row, read the amendment notes it points to (search the plan for
   `rev <N>`), and note which IDs changed.
4. For the current and later units only, find the cards and checks that cite
   those IDs or the steps they changed: `grep -n` the breakdown for each ID,
   and `md-section.sh get` the cards that match.

## Return

The RESULT block. `findings`: one TSV row per affected item: `rev`, `change`
(one line), `IDs`, `affects` (card or unit check, e.g. `T08 Steps`,
`WU3 check 2`), `already Implemented or Done?` (from the breakdown's Task Map
and the Task Status board if given). Changes that affect only `Done` units go
in the summary, not the findings.
