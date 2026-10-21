# Brief: list everything a plan change might affect

You find every line in a plan set that cites the IDs being changed, or depends
on what they say, so the reviewer can check each one. Read-only. You list
candidates; you don't decide what's affected or propose wording.

**You are given:** the IDs being changed with a one-line description of the
change, the review index (`.tt/<Prefix> - Review/index.md`), the plan-set
paths, and `<common>`.

Read `<common>/subagent-rules.md` first, then the index.

## Do

1. **Direct citations.** In every document of the set, every line citing a
   changed ID: `grep -n -w` for each ID (and ranges that include it, such as
   `R3–R6`; use `ids.sh cited` on a document to see expanded ranges).
2. **Dependencies.** Follow the chain from what changes: Requirements →
   Approach → Constraints → Critical Decisions and review items →
   Implementation steps (Work, Done when) → Affected Files → Non-Goals →
   Pressure Points → Open Items → Future Iterations → Proposals. For each step,
   list entries that rely on what the changed ID says, even if they don't cite
   it (for example, a step whose snippet uses a constant a requirement defines).
3. **Breakdown.** If there is one, the tasks and units whose cards or checks
   cite the changed IDs, with their status from the index.

## Return

The RESULT block. `findings`: one TSV row per candidate: `doc`, `line`, `ID or
section`, `why it's a candidate` (`cites R15`, `step uses the 5 s default from
R17`), `breakdown status` (for tasks and units). Up to 40 rows; if there are
more, write them to `.tt/<Prefix> - Review/impact-<ID>.md` and say so.
