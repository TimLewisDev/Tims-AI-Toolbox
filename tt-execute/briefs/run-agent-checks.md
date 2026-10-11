# Brief: run a work unit's Agent checks

You run exactly the checks a work unit's Validation marks as **Agent** (and the
agent part of **Agent + Engineer** checks), and report each result with
evidence. You fix nothing, and you run nothing that isn't listed.

The orchestrator uses you only when `run-checks.sh` can't: the unit has no
`checks` block (breakdowns written before it existed). Write your results in
the attempt format that script writes, so `status-record.sh` can record them.

**You are given:** `<common>/scripts`, the breakdown path, the unit ID, the
Build check, a log folder, and the repo path.

Read `<common>/subagent-rules.md` first.

## Do

1. Read the unit block: `md-section.sh get <breakdown> "## <WU> —"` (the unit
   heading through its How to validate).
2. For each Agent check, in order, run exactly what **How to validate** says
   (or, for a compile check, the Build check). Save full output to
   `<log folder>/check-<n>.log`.
3. A check you can't run (a tool is missing, it needs the engineer, the command
   is ambiguous) is `blocked`, with the reason. Don't improvise a substitute.
4. Never change files, never run git commands that change anything, and never
   retry a failed check with different commands.
5. Write `<log folder>/attempt.md` in one Write, one line per Validation item
   (`<n>` its place in the list, `<who>` its Agent / Engineer / Agent + Engineer
   tag; Engineer items `pending`, an Agent + Engineer item `pending` once its
   agent part passed):

   ```
   - Run: <YYYY-MM-DD HH:MM> (<why, as given>)
   - Results:
     - Check <n> (<check text>) [<who>]: <passed | failed | blocked | pending>. `<command>` → <one-line evidence> (log: check-<n>.log)
   - Outcome: <Failed if any failed, else "Pending (checks <n>, …)" if any is pending or blocked, else Done>
   ```

## Return

The RESULT block: `wrote` the attempt file. `findings`: one TSV row per check:
`n`, `check` (as written), `result` (passed / failed / blocked), `command`,
`evidence` (up to 10 lines: the error or the line that shows success; point to
the log for the rest).
