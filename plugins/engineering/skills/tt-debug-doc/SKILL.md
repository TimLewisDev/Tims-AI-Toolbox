---
name: tt-debug-doc
description: >
  Write the Debug Report from a finished tt-debug investigation: what the
  problem was, how the root cause was found, what was ruled out and why, and
  the fix direction. A script renders it straight from the Debug Log on disk,
  so no model writes the text; this skill runs the script, checks the
  references, shows the engineer the result and applies their corrections. It
  works from the log alone, so it can run in a fresh session. Reports what was
  found and agrees nothing. Use after tt-debug, or when asked to write up,
  document or summarise a debugging session.
argument-hint: "[debug log]"
metadata:
  version: "1.0"
---

# tt-debug-doc

## Usage

```
/tt-debug-doc [debug log]
```

With no path: if a Debug Log was used earlier in this conversation, use it;
otherwise ask for it and stop.

## How to run this skill

`<common>` is `~/.claude/tt-plugins/core/skills/tt-common` (or `${CLAUDE_SKILL_DIR}/../tt-common` when the skills are linked into one folder) and `<scripts>` is
`<common>/scripts`. `<repo>` is the **Repo** line of the Debug Log (the log is
written beside the documents, which may not be in the repo; if the line is
missing, ask the engineer). The Debug Log is `<doc folder>/.tt/<Prefix> - Debug/debug-log.md`;
the report is `<doc folder>/<Prefix> - Debug Report.md`. Read nothing else first.
This skill is deliberately small: the script does the writing.

## Flow

### 1. Check the log

```
bash "<scripts>/debug-doc.sh" --check "<debug log>"
```

Exit `0`: go on. Exit `1` prints what the log lacks (`missing: …`). Don't write
the gaps yourself. Show them and ask the engineer which they are, and fill them
in the log from their answers with targeted Edits (keep their words); or, for a
log whose investigation isn't finished (Status not `Root cause confirmed` or
`Unresolved`, a draft In short), send them back to `/tt-debug resume "<log>"`.
A temporary edit that isn't `Removed: yes` means the investigation isn't closed:
run `bash "<scripts>/debug-temp.sh" check "<repo>"` (the log's **Repo** line) and show
what is left, then send the engineer back to `/tt-debug resume "<log>"`, which
removes them and closes properly. Re-run the check after.

### 2. Render

```
bash "<scripts>/debug-doc.sh" "<debug log>" "<doc folder>/<Prefix> - Debug Report.md"
```

It refuses to overwrite a report: if one exists, ask whether to replace it
(delete it first) or stop. If sibling documents in the folder begin with a
header or tag block, add the same block to the top of the report with one Edit.

### 3. Verify references

```
bash "<scripts>/verify-refs.sh" --worktree --repo "<repo>" --only-problems "<report>"
```

Fix each broken reference with a targeted Edit, re-reading the code at that
spot. A reference that moved because the code was since changed (the fix may
already be in) is corrected to where the code is now or noted as "before the
fix"; ask the engineer if it isn't obvious.

### 4. Show and correct

Give the path and the **In short** section in chat. Ask whether anything is
wrong or missing. Apply corrections with targeted Edits (a new fact still needs
a cite). Then append ` · Documented <YYYY-MM-DD>: <report path>` to the end of the Debug
Log's Status line, keeping `Root cause confirmed …` or `Unresolved …` in front of it
(later steps read that). Leave the Debug Log in place; the engineer can delete the `.tt` folder
whenever they like (say so). Keep the Debug Log if a fix will be planned from
it with `tt-lite-brief`.

### 5. Hand off

Record that the report is written (silent, best-effort; `<common>/events.md`):
`bash "<scripts>/tt-event.sh" emit debug.report_written --prefix "<Prefix>" --folder "<feature folder>" --skill tt-debug-doc`.

If the root cause is confirmed, remind the engineer of the next step they may
want: `/tt-lite-brief "<debug log>"` to plan the fix, then `/tt-execute-lite`
in a fresh session. Otherwise the report stands on its own.

## Guardrails

- The report says only what the log says; no new findings, no design.
- Never stage, commit or push. Never write production code.
