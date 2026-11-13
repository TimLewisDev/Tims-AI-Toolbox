---
name: tt-qa-bug
description: >
  Turn a plain-English description of a bug into a well-formed bug: a short
  title, severity, environment, numbered steps to reproduce, expected and
  actual results and evidence. Asks only for what the description leaves out
  and can't be worked out, shows the bug for the tester's approval, then a
  script writes it from one template so every bug reads the same; the model
  never writes the bug file itself. Also runs unattended (draft) for tools that
  show bugs elsewhere: it writes a spec for the tool to review and saves
  nothing. Never commits. Use when asked to write up, log, raise or format a
  bug, defect or issue found while testing.
argument-hint: "<bug folder> [<description>] | draft <description file> <spec file> | edit <bug folder> <BUG-id>"
metadata:
  version: "1.0"
---

# tt-qa-bug

## Usage

```
/tt-qa-bug <bug folder> [<description>]       # describe a bug, review it, save it
/tt-qa-bug draft <description file> <spec file>  # unattended: write a spec, ask nothing, save nothing
/tt-qa-bug edit <bug folder> <BUG-id>          # change a saved bug
```

`<bug folder>` is where the bugs live (one `BUG-NN - <title>.md` each). With no
argument, ask for it and stop. If no description follows, ask the tester to
describe what went wrong in their own words.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`) and `<bug>` is
`bash "<skill>/scripts/bug.sh"`. Run `<bug> --help` once to see every command
and the spec format.

- **The script is the only writer of a bug.** Never Write or Edit a bug file,
  not even to fix a typo: use `new`, `edit` or `set`.
- A bug goes in as a **spec**, on stdin with a quoted heredoc.
- One `bug.sh` command per shell call, the full script path written out, no
  `;` or `&&` chains.
- If the script refuses (exit 1), read its message, fix the spec and try
  again. If it reports `problem:` lines about a file (edited by hand), show
  them to the tester and stop.
- Ask with `AskUserQuestion`, two to four named options, recommended first.
  Where it isn't available, ask the same question in chat as a numbered list.
- In **draft** mode ask nothing at all: no `AskUserQuestion`, no questions in
  chat. Another tool is waiting for the result.

## Turning a description into a bug

1. **Read what the tester said.** Take every fact they gave: what they did,
   what they expected, what happened, where (screen, build, device, account).
   Keep their words for the facts; tidy only the grammar.
2. **Never invent.** A step, a build number, a device or a log line the
   description doesn't give is not written. A missing fact is asked for (or,
   in draft mode, left out or listed in the summary as "Not stated: ...").
3. **Title**: what is wrong, in under 80 characters, no ID, no "bug:" prefix
   ("Login does nothing on the second tap after a wrong password").
4. **Steps**: one action per step, in order, starting from a known state (app
   open, which account, which screen). A tester should be able to repeat them
   without asking. Don't write "etc.".
5. **Expected / Actual**: one sentence each, the difference being the bug.
6. **Severity** (the tester can overrule it):
   - Critical: crash, data loss, security, or blocks the main path with no way round.
   - Major: a feature is broken or wrong, a workaround exists.
   - Minor: wrong behaviour in a rarely used path, or a clear cosmetic fault.
   - Trivial: typo, a few pixels, polish.
7. **Environment** and **evidence**: only what is stated (build, platform,
   device, account; links, screenshot paths, log text).
8. **Feature / area / source** when the bug comes from a test plan: copy the
   feature name, the area and the item ID (`A2.3`) the tester gives you.

## Normal mode

1. Draft the spec from the description.
2. Ask only what blocks a good bug: the usual gaps are the steps' starting
   state, the expected result when the tester didn't say, and the severity if
   it isn't obvious. One question at a time, named options where there are
   natural ones, never more than three questions in all.
3. Show the bug as it will read (title, severity, steps, expected, actual) and
   ask: **Save it** (recommended), **Change something**, or **Not now**.
4. On Save, run `<bug> new "<bug folder>" -` with the spec, and print the ID
   and the file. Offer nothing else: not a commit, not Jira (a tool such as
   Tatty does that).
5. `edit` mode: show the bug (`<bug> show`), ask what to change, apply it with
   `<bug> edit "<bug folder>" <BUG-id> -` (only the fields that change).

## Draft mode (unattended)

`draft <description file> <spec file>`:

1. Read the description file. Write a spec from it exactly as above, asking
   nothing.
2. Write the spec to `<spec file>` with the Write tool (it is a spec, not a
   bug file), then run `<bug> validate "<spec file>"`. If it refuses, fix the
   spec and run it again, up to three times.
3. Save nothing else and create no bug. Finish with one line: `ok <spec file>`
   or `refused: <the message>`.
4. Where the description leaves out something a repeater would need, say so
   in the summary line ("Not stated: the build, the account"), not in a
   made-up step.
