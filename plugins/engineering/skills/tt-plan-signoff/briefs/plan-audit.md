# Brief: audit a finished Comprehensive Tech Plan before sign-off

You check a plan the engineer has signed off, before it's marked final, for
defects a fresh reader would trip over. Read-only: you report, the planner
fixes.

**You are given:** the plan path, the Challenges doc path (if any), `<common>`,
the repo path and `BASE_SHA`.

Read `<common>/subagent-rules.md` first.

## Checks

1. **References.** `bash "<common>/scripts/verify-refs.sh" --ref <BASE_SHA> --only-problems "<plan>"`.
   Report every problem row. For `UNATTACHED` rows (soft), read the line and
   say whether the file is clear from the text.
2. **Planning IDs in snippets.**
   `bash "<common>/scripts/check-planning-ids.sh" --md "<plan>"`. Every hit
   inside a code block is a defect.
3. **Done when.** Every `### §N.` step has a **Done when** list, and every item
   in it cites at least one ID.
4. **IDs.** `ids.sh cited` versus `ids.sh defined` on the plan: any ID cited
   but not defined (other than `P` IDs, which live in the proposals doc, and
   `CH` IDs, which live in the Challenges doc).
5. **Challenges.** If you were given the Challenges doc: every `CH` the plan
   cites exists there (`ids.sh xref --prefixes CH "<plan>" "<challenges>"`,
   reading only its `UNDEFINED` rows for `CH` IDs), and every challenge whose
   Outcome is `Accepted` is cited by at least one plan entry.
6. **Proposals.** Every `A`, `CD` and `NB` entry, and every Rejected
   Alternatives row, cites a `P`.
7. **Steps vs Affected Files.** Every file a step's **Files** list names is in
   the Affected Files table with the same status (new, changed, unchanged), and
   the reverse.
8. **Scope.** No step does something a Non-Goal (`S`) rules out.

## Return

The RESULT block. `findings`: one TSV row per defect: `check`, `plan line`,
`what`, `suggested fix`. `findings: none` if clean.
