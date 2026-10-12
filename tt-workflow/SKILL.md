---
name: tt-workflow
description: >
  The single entry point to the tt pipeline. Link a feature folder once, then
  type tt-workflow: a script works out where the folder's documents stand
  (exploring, planning, signed off, breakdown, building, complete), says so,
  and after one confirmation runs the skill that comes next
  (tt-familiarise, tt-adversarial-plan, tt-task-breakdown, tt-execute, ...),
  coming back to ask again when it hands back. With no folder linked it asks
  you to link one or start a new feature folder; "new" starts a fresh feature
  and replaces the old link. Orchestrates only: never edits documents,
  stages, commits or pushes. Use when the user wants to start or carry on a
  feature without remembering which tt skill comes next.
argument-hint: "[<feature folder> | new | unlink | status]"
metadata:
  version: "1.0"
---

# tt-workflow

## Usage

```
/tt-workflow                   # carry on with the linked folder
/tt-workflow <feature folder>  # link it (replacing the old link), then carry on
/tt-workflow new               # ignore the link: start a new feature, unlink the old one
/tt-workflow unlink            # forget the link
/tt-workflow status            # say where the linked folder stands; run nothing
/tt-workflow status <folder>   # the same for that folder, read-only: it is not linked
```

The link is per project and kept outside the repo and the folder. The folder
is the one that holds the `<Prefix> - ….md` documents.

## Start

Tatty, the link and where things stand were printed by a script before you were
loaded:

!`bash "${CLAUDE_SKILL_DIR}/scripts/workflow.sh" start`

If there's no output above (the line still starts with `!`), run
`bash "<this skill's folder>/scripts/workflow.sh" start` once. Show the robot
in a code block, once per session; add nothing to the quip. Use the script
for every fact below: `workflow.sh state`, `link <folder>`, `unlink`,
`new <parent> <name>` (`-h` for more). Quote paths; they have spaces.

## 1. Pick the folder

- `status`: read-only. Never link, unlink or create anything. With a folder
  (`status <folder>`), use `workflow.sh state "<folder>"` and leave the link
  as it is; without one, use the linked folder.
- `<folder>`: `workflow.sh link "<folder>"`.
- `new`: ask the parent path (offer the old link's parent) and a feature name,
  with `AskUserQuestion`, then `workflow.sh new "<parent>" "<name>"`. It
  creates the folder, links it and prints `Folder` and `Prefix`.
- `unlink`: `workflow.sh unlink`, say so, stop.
- Nothing given: use the link. If none (or its folder is missing), ask:
  **Link an existing folder** (then ask for the path) · **Start a new feature
  folder** (as for `new`).

## 2. Read the state

`workflow.sh state` prints one block per feature: a line `<Prefix>: <where it
stands>`, then `→ /<skill> …` for the next step, other sensible steps (`→ or …`)
and problems (`!`). If there are several features, ask which one. `status`
ends here with the block.

A folder with no tt documents prints `No tt documents in …` and
`/tt-adversarial-plan <idea, spec or ticket>`: ask what the feature is (a
sentence, a spec or a ticket), then run `tt-adversarial-plan` with it and
"Folder: <folder>. Prefix: <name>" (the folder's name unless `new` printed one).
It asks whether to explore first.

A feature that is built and validated has no next skill: say so. Committing and
the MR are the engineer's.

For a small feature or a bug fix, `tt-workflow-lite` is lighter: say so if the
engineer describes work that small (one request, a few files, or a bug).

## 3. Confirm once

Ask with `AskUserQuestion`: the feature, where it stands, the exact command
(one line), and the options **Continue** · **Continue in a new session** ·
each `→ or …` step · **Stop** (all of it is on disk). A `!` problem is
mentioned, not asked about.

On **Continue in a new session**, follow `<common>/session-handoff.md` with
`--entry tt-workflow` (`<common>` is `<this skill's folder>/../tt-common`): it
opens a terminal tab named `<Prefix> : <Stage>` that starts with
`/tt-workflow`, so the next skill runs there after the same one confirmation.
Then stop.

## 4. Run it

Invoke the skill with the Skill tool, in this conversation, with the arguments
the arrow gave (the same way `tt-adversarial-plan` runs its stages). Do nothing
of that skill's work yourself.

## 5. When it hands back

Go to step 2 and read the state again. After two skills have run in one
conversation, recommend a fresh session: the step 3 question then leads with
**Continue in a new session**. A skill that stops at its own gate (a sign-off,
a validation) is left at it.

## Guardrails

- State comes from the scripts, never from memory or a guess at the files.
- Never edit a document, and never stage, commit, push or create branches.
- Never skip a skill's own gates, and never choose for the engineer.
