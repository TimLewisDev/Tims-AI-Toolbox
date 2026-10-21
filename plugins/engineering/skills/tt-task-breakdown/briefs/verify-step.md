# Brief: verify one plan step against the repo

You check that what one step of a Comprehensive Tech Plan says about the code
is still true at a pinned commit. You do not plan, slice or fix anything.

**You are given:** `<common>/scripts`, the draft folder `<draft>`, the plan path
and the step's line range (`§N`, lines a–b), the repo path and `BASE_SHA`.

Read `<common>/subagent-rules.md` first; it applies to you.

## Do

1. Read the step: `sed -n '<a>,<b>p' "<plan>"` (or `md-section.sh get <plan> "§N."`).
2. Read the mechanical results for its lines from `<draft>/verify/refs.tsv`
   (column 1 is the plan line). Don't redo what it already checked.
3. For each claim the step makes about existing code (a symbol is at a line,
   a method does X, a field has type Y, a file is in assembly Z, a precedent
   shows a pattern, a file marked new doesn't exist yet, a file marked unchanged
   isn't needed by the step), check it at the commit:
   - `git --no-optional-locks show <BASE_SHA>:<path>` (pipe through `sed -n`
     for a range),
   - `git --no-optional-locks grep -n <symbol> <BASE_SHA> -- <path or folder>`.
   Never check the working tree, never fetch.
4. Write `<draft>/verify/§N.md` in one Write:

```markdown
# Verification: §N <title> @ <short sha>

| Plan line | Reference or claim | Result | Evidence | Suggested class |
|---|---|---|---|---|
| 288 | `ProcessQueue` at `OrderService.cs:623-929` | OK | `OrderService.cs:623` | — |
| 301 | `_isPaused` exists | MISSING | not found by `git grep` | content |
| 315 | `Normalise` at `:165` | MOVED → `:168` | `OrderMath.cs:168` | trivial |

<!-- tt:end -->
```

Results: `OK`, `MOVED → <new ref>`, `WRONG` (says something the code
contradicts, with what the code says), `MISSING`, `NEW_EXISTS` (a "new" file
already exists), `UNCHANGED_NEEDED` (the step needs a file the plan marks
unchanged). Suggested class: `trivial` (a moved line, same meaning) or
`content` (it changes what a task would do). The class is a suggestion; the
orchestrator decides.

## Don't

- Don't propose design changes or tasks.
- Don't list claims that are `OK` beyond what's useful: if every reference in
  the step is fine, one row saying so is enough.

## Return

The RESULT block: `wrote` the file, a summary with counts, and `findings` as a
TSV of the non-`OK` rows only (or `none`).
