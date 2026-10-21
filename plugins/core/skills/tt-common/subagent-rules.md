# Rules for tt-* subagents

Read this if you were spawned by a `tt-*` skill to follow a brief or a
handoff. It is all of the orchestration rules that apply to you; the rest
(`orchestration.md`) is for the orchestrator, so don't read it.

`<common>` is the `tt-common` folder this file is in. Scripts are
`<common>/scripts/<name>.sh`.

## You

- **Never talk to the engineer.** Questions and decisions go back as
  escalations in your RESULT.
- **Never decide a Critical Decision**, and never add content the documents
  and the repo don't support.
- **Never run a git command that changes anything** (no fetch, add, commit,
  checkout, stash, branch or worktree). Read with `git --no-optional-locks`,
  at `<BASE_SHA>:<path>` when you were given a `BASE_SHA`, not at
  `origin/<base>`, which may move mid-run.
- **Never write planning IDs into code** (task, unit, plan or decision IDs,
  level names such as `L0`, planning-document names). Check what you changed
  with `check-planning-ids.sh`.
- **Read only what you need.** Use `md-section.sh get <doc> "<heading>"` for a
  section and `sed -n '<a>,<b>p'` for a line range rather than reading whole
  documents.

## Output

- **One part per Write.** At most about 200 lines of document, or 6k tokens of
  output, per response. A long file is several parts or several Writes.
- **Never re-emit what is already on disk.** Point at it, or Edit only the
  lines that change.
- A part file is complete only when its last non-blank line is
  `<!-- tt:end -->`.
- **Details go in files, not in the RESULT.** The RESULT is how the
  orchestrator finds them.

## Scripts

`bash "<common>/scripts/<name>.sh" -h` prints a script's usage. Always quote
paths: document names contain spaces. Exit `0` clean, `1` findings, `2` usage
or environment error.

## RESULT

End with this block, 60 lines or fewer (aim for under 20 unless you return
findings):

```
RESULT
status: done | partial | blocked | failed
wrote: <absolute path per line, or none>
summary: <up to 5 lines>
escalations: <none, or one per line:>
- E1 | blocking | review | question | <where: task, step or ref> | <issue> | <evidence path:line @sha> | <options seen>
findings: <none, a TSV of up to 40 rows, or "see <file>">
END RESULT
```
