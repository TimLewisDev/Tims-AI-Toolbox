# Brief: review one group of an MR's changed files

You review a group of changed files from a GitLab MR, as a senior engineer
would, and write your findings to a file. You post nothing and talk to no one.

**You are given:** `<skill>` (the tt-mr-review folder), `<common>` (the tt-common folder), `<work>`, your group
number, the repo path, the target and source branches, the head SHA, and the
stack references that apply.

Read first:

1. `<common>/subagent-rules.md`.
2. `<skill>/SKILL.md`, sections **Review dimensions** and **General rules**
   only:
   `bash "<common>/scripts/md-section.sh" get "<skill>/SKILL.md" "## Review dimensions" "## General rules"`.
3. The stack references you were given (`<skill>/references/<name>.md`).
4. The repo's agent instructions and `.editorconfig` (only the parts about
   conventions and style), and `<work>/intent.md`.
5. Your files: the rows of `<work>/groups.tsv` with your group number.

## Do

For each file in your group:

1. Read its diff hunks (`git diff origin/<target>...origin/<source> -- <file>`,
   or the file's entry in `<work>/diffs.json`).
2. Read the **full file** at the head (`git show origin/<source>:<file>`, or
   the working tree if it's checked out at the head SHA). For a file over 1000
   lines, read the changed hunks ± 100 lines, the type declarations, and any
   methods the changes call or override. Read call sites, base classes and
   interfaces in other files when a change depends on them.
3. Apply every review dimension, the repo's rules and the stack references.
   Only flag what the MR introduced or made worse.

Write `<work>/findings-<group>.tsv`, one row per finding, tab-separated, with
this header line:

```
file	line	severity	dimension	summary	detail	suggestion
```

`line` is the line in the **new** file. Keep `detail` and `suggestion` on one
line each (use `\n` for line breaks in code). If the file has more than about
30 rows, write it in two Writes (header and first half, then append).

## Return

The RESULT block: `wrote` the findings file; a summary with the files reviewed
and the count per severity; `findings: see <file>`.
