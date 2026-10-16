---
name: tt-workflow-lite
description: >
  The entry point for small work: a single-request feature or a bug, where the
  full tt-workflow would be too heavy. It asks whether you are working on a bug
  or a feature, links one folder for the task, and runs the lite route. A
  feature goes tt-familiarise (lite mode) → tt-lite-brief → tt-execute-lite; a
  bug goes tt-debug, then the debug doc (tt-debug-doc) and/or a fix through
  tt-lite-brief → tt-execute-lite. A script reads where the folder's documents
  stand and, after one confirmation, the next skill is run; it comes back to
  ask again when that skill hands back. Keeps its own folder link, so it never
  replaces the one tt-workflow keeps. Orchestrates only: never edits documents,
  stages, commits or pushes. Use when the user wants to start or carry on a
  small feature or a bug fix without remembering which tt skill comes next.
argument-hint: "[<task folder> | bug | feature | new | unlink | status]"
metadata:
  version: "1.0"
---

# tt-workflow-lite

## Usage

```
/tt-workflow-lite                   # carry on with the linked task
/tt-workflow-lite bug               # start a new bug
/tt-workflow-lite feature           # start a new small feature
/tt-workflow-lite <task folder>     # link it (replacing the old link), then carry on
/tt-workflow-lite new               # start something new: ask bug or feature
/tt-workflow-lite unlink            # forget the link
/tt-workflow-lite status            # say where the linked task stands; run nothing
/tt-workflow-lite status <folder>   # the same for that folder, read-only: it is not linked
```

A task folder holds the documents of **one** small task (a Focus Log or Debug
Log, a Lite Brief, a Task Status). The link is per project and kept outside the
repo, in a file of its own: it never touches the folder `tt-workflow` links.
For a large feature (several stages, a signed-off plan), use `tt-workflow`.

## Start

Tatty, the link and where things stand were printed by a script before you were
loaded:

!`bash "${CLAUDE_SKILL_DIR}/scripts/lite.sh" start`

If there's no output above (the line still starts with `!`), run
`bash "<this skill's folder>/scripts/lite.sh" start` once. Show the robot in a
code block, once per session; add nothing to the quip. Use the script for every
fact below: `lite.sh state`, `link <folder>`, `unlink`, `new <parent> <name>`
(`-h` for more). Quote paths; they have spaces.

## 1. Pick the task

- `status`: read-only. Never link, unlink or create anything. With a folder
  (`status <folder>`), use `lite.sh state "<folder>"` and leave the link as it
  is; without one, use the linked folder.
- `<folder>`: `lite.sh link "<folder>"`.
- `unlink`: `lite.sh unlink`, say so, stop.
- `bug`, `feature` or `new`: a new task. If the word isn't `bug` or `feature`,
  ask with `AskUserQuestion`: **Bug** (something is wrong and you want to find
  out why) · **Feature** (a small change you want to make). Then ask, in one
  open question, what it is, in a sentence. Then the folder: the parent path
  (offer the old link's parent) and a name for the task (propose one from the
  sentence), with `AskUserQuestion`; then `lite.sh new "<parent>" "<name>"`. It
  creates the folder, links it and prints `Folder` and `Prefix`.
- Nothing given: use the link. If there is none (or its folder is missing),
  ask: **Link an existing task folder** (then ask for the path) · **Start a new
  task** (as above).

## 2. Read the state

`lite.sh state` prints one block per task: a line `<Prefix>: <where it
stands>`, then `→ /<skill> …` for the next step, other sensible steps
(`→ or …`) and problems (`!`). If there are several, ask which one. `status`
ends here with the block.

- **`No tt documents in …`**: a new task. If you don't know yet whether it is a
  bug or a feature, ask; if you don't have the sentence, ask for it. Then run
  - a **feature**: `tt-familiarise` with the arguments
    `lite <the sentence>. Mode: lite. Folder: <folder>. Prefix: <prefix>.`
  - a **bug**: `tt-debug` with
    `<the sentence>. Folder: <folder>. Prefix: <prefix>.`

  (The prefix is the folder's name unless `new` printed another.) The script
  prints `a new task: is it a bug or a feature?` for such a folder.
- **The lite route**, by the state's phase words:

  | State | Next |
  |---|---|
  | exploring (lite) | `/tt-familiarise resume <focus log>` |
  | lite exploration done | `/tt-lite-brief <focus log>` |
  | lite brief written; not started · building | `/tt-execute-lite <lite brief>` |
  | debugging | `/tt-debug resume <debug log>` |
  | debugging finished | `/tt-debug-doc <debug log>`, or the fix: `/tt-lite-brief <debug log>` |
  | debugged | nothing left; or the fix: `/tt-lite-brief <debug log>` |
  | built and validated | nothing left; congratulate the engineer if `start` showed the party Tatty; the commit and the MR are theirs |

- **Anything else** (a Comprehensive Tech Plan, a Task Breakdown, a plan being
  drafted, a Familiarisation doc): this folder is on the full pipeline. Say so,
  point at `/tt-workflow "<folder>"`, and stop.

## 3. Confirm once

Ask with `AskUserQuestion`: the task, where it stands, the exact command (one
line), and the options **Continue** · **Continue in a new session** · each
`→ or …` step · **Stop** (all of it is on disk). A `!` problem is mentioned,
not asked about.

For `tt-execute-lite`, building is better in a fresh session than after an
exploration's long context: lead with **Continue in a new session** and
recommend it.

On **Continue in a new session**, follow `<common>/session-handoff.md` with
`--entry tt-workflow-lite` (`<common>` is `<this skill's folder>/../tt-common`):
it opens a terminal tab named `<Prefix> : <Stage>` that starts with
`/tt-workflow-lite`, so the next skill runs there after the same one
confirmation. Then stop; the new session carries on.

## 4. Run it

First run `bash "<common>/scripts/model-config.sh" stage-note <the skill>`. If it
prints a line and the model you are running on is not the one it names, say so
once, in one line with the `/model` and `/effort` commands it gives, and carry on;
say nothing if you already match. It is a recommendation from `tt-config`;
only the engineer can change the session's model.
Then invoke the skill with the Skill tool, in this conversation, with the arguments
the arrow gave (the same way `tt-adversarial-plan` runs its stages). Do nothing
of that skill's work yourself.

## 5. When it hands back

Go to step 2 and read the state again. After two skills have run in one
conversation, recommend a fresh session: the step 3 question then leads with
**Continue in a new session**. A skill that stops at its own gate (a confirmation, a
validation) is left at it.

## Guardrails

- State comes from the scripts, never from memory or a guess at the files.
- Never edit a document, and never stage, commit, push or create branches.
- Never skip a skill's own gates, and never choose for the engineer.
- Open a new session only after the engineer says yes.
