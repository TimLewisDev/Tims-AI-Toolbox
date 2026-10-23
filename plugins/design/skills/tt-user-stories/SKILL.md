---
name: tt-user-stories
description: >
  Turn a design document into a User Stories document: user stories with a
  title, an "As a … I want … so that …" line, details and acceptance
  criteria, each tagged with a group. Finds the groups the stories fall into,
  stories that overlap and can be merged, and stories the design seems to have
  missed; merges and suggestions are written as Proposed stories that the
  designer accepts, rejects or asks to alter (the story is rewritten and
  proposed again), one at a time. A script writes every story from a template,
  so they always read the same; the model never writes the document itself.
  Also runs unattended (draft, alter) for tools that show the stories
  elsewhere. Never commits. Use when asked to write, extract, update or review
  user stories from a design document, spec or brief.
argument-hint: "<design doc> [<stories doc>] | draft <design doc> <stories doc> | alter <stories doc> <US-id> <note file> | resume <stories doc>"
metadata:
  version: "1.0"
---

# tt-user-stories

## Usage

```
/tt-user-stories <design doc> [<stories doc>]          # write or update, then review with the designer
/tt-user-stories draft <design doc> <stories doc>      # unattended: write everything, ask nothing
/tt-user-stories alter <stories doc> <US-id> <note>    # unattended: rewrite one Proposed story from a note file
/tt-user-stories resume <stories doc>                  # carry on: review what is still Proposed
```

With no argument, ask for the design document and stop. The stories document
defaults to `<design doc folder>/<Prefix> - User Stories.md`, where `<Prefix>`
is the design doc's name before ` - ` (if it has none, ask for a prefix).
If the stories document exists already, this is an update: read it first and
add only what it lacks.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`) and `<stories>` is
`bash "<skill>/scripts/stories.sh"`. Run `<stories> --help` once to see every
command and the spec format.

- **The script is the only writer of the stories document.** Never Write or
  Edit it, not even to fix a typo: use `edit` or `set`. That is what keeps every
  story in the same layout.
- A story goes in as a **spec**, passed on stdin with a quoted heredoc, so no
  file is written:

  ```
  bash "<skill>/scripts/stories.sh" add "<doc>" - --proposed <<'SPEC'
  title: …
  …
  SPEC
  ```

- Run one `stories.sh` command per shell call, with the script's full path
  written out: no variables, no `;` or `&&` chains, no other commands. An
  unattended run is allowed exactly that and nothing else.
- Read the document back with `<stories> list "<doc>" --tsv`. Never parse the
  markdown yourself.
- If the script refuses (exit 1), read its message, fix the spec and try
  again. If it reports `problem:` lines about the document itself (it was
  edited by hand), show them to the designer and stop. Never "repair" the
  document with Edit.
- Ask with `AskUserQuestion`. Where it isn't available, ask the same question
  in chat as a numbered list and wait for the answer.
- In **draft** and **alter** mode, ask nothing at all: no `AskUserQuestion` and
  no questions in chat. Another tool is waiting for the result.

## Writing a good story

- **One need per story.** One role, one capability, one benefit. Split a story
  that needs "and" in its want.
- **as**: a real kind of user the design names (player, guild leader, level
  designer, moderator), never "user" when the design says who.
- **want**: what they can do, in their words ("to sort my inventory by
  rarity"), not how it is built.
- **so_that**: why it matters to them. If the design doesn't say, take the
  plainest reason, never a made-up one.
- **details**: the rules, numbers, limits, states and edge cases the design
  gives for this story, in short sentences or a list. Say what the design
  leaves open ("The design doesn't say how many slots."). Never invent values.
- **criteria**: two to five `Given …, when …, then …` lines that someone could
  test. Cover the main path and the edge cases the design names.
- **source**: the heading of the design's section it came from (`§ Pickup`),
  so the designer can find it.
- **title**: a short verb phrase ("Pick up an item").

## Flow

### 1. Read

Read the whole design document. If the stories document exists, read
`list --tsv` too: its groups, stories and the **Retired** rows (rejected
stories and merged ones). Never propose a retired story again unless the
design has changed in a way that answers why it was rejected.

If the stories document doesn't exist, create it:
`<stories> init "<design doc>" "<stories doc>"`. Its Source line links to the
design doc. The script keeps whatever header the designer adds later.

### 2. Groups

Work out three to eight groups the stories fall into: the design's own areas,
features or player journeys, named the way the design names them. A story
belongs to exactly one group; `Ungrouped` is for the rare one that fits none.

- **Interactive:** show the groups with a one-line description each and ask
  once with `AskUserQuestion`: **use these** (recommended) · **change them**
  (the designer says how; apply it and show them again).
- **Draft:** use them.
- Add each with `<stories> group add "<doc>" "<name>" "<description>"`. On an
  update, keep the existing groups and add only the new ones.

### 3. Stories from the design

Go through the design section by section. For each need it states, write a
spec and `add` it (Accepted, origin `Design doc`). On an update, skip needs an
existing story already covers.

### 4. Duplicates

Compare every story with every other (new and existing). Where two or more
cover the same need, write one merged story that keeps everything each one
says (every rule and criterion), with `origin: Merge of US-02, US-05`, and
`add` it with `--proposed`. Leave the originals alone: accepting the merge
retires them, rejecting it keeps them.

### 5. Gaps

Look for stories the design implies but doesn't spell out, and add each with
`--proposed` and `origin: Suggested`. Check at least:

- what happens when it fails, is empty, is full, or the user has no access
- the first time someone uses it (onboarding, discovery)
- what is saved, and what happens after a restart or on another device
- feedback (how the user knows it worked)
- settings, accessibility, and the people who run it (support, admin tools)

Only suggest what this design makes likely. Put the reason in the details'
first line ("Suggested: the design covers a full bag on pickup but not on
reward.").

### 6. Review (interactive only)

Take each Proposed story in ID order, one per response. Show it in chat: the
title, the story line, the criteria, the details' first line, and for a merge,
which stories it replaces. Then ask with `AskUserQuestion`:

- **Accept** → `<stories> accept "<doc>" <id>` (a merge retires its originals;
  say which).
- **Reject** → `<stories> reject "<doc>" <id> "<reason>"`, with the reason the
  designer gave (none is fine).
- **Alter** → the designer says what to change (in the option's notes, or the
  free-text answer). Rewrite the spec so it does exactly that and nothing else,
  `<stories> edit "<doc>" <id> - --altered` (the spec on stdin), show the story again and ask
  again.

Record each answer straight away, before showing the next story. Never accept,
reject or merge on the designer's behalf, and never batch the questions.

### 7. Finish

Run `<stories> check "<doc>"` (it must exit 0), then
`<stories> status "<doc>" Ready` (`Updated` on an update). Give the path and a
short summary: stories per group, how many are still Proposed, how many were
retired. In draft mode, print the same summary and stop.

## Unattended modes

- **draft**: steps 1 to 5, then step 7. Ask nothing; every merge and
  suggestion stays Proposed for the designer to review elsewhere.
- **alter**: read the story (`<stories> show "<doc>" <id> --tsv`), the note
  file, and the design's section named in the story's Source. Rewrite the spec
  so it does what the note asks and nothing else, run
  `<stories> edit "<doc>" <id> - --altered` (the spec on stdin), then `check`. The story stays
  Proposed. If the note can't be done (it asks for something that isn't a
  story change), change nothing and say why in one line.

## Resuming

`resume <doc>`: read `list --tsv`. If the Status is still `Drafting`, the
writing stopped part-way: read the design again and carry on from step 3,
skipping what is already there. Otherwise go to step 6 with the stories that
are still Proposed.

## Guardrails

- Never Write or Edit the stories document; every change goes through
  `stories.sh`.
- Never renumber, reuse or delete an ID. Rejecting retires a story; it isn't
  deleted.
- Never invent rules, numbers or roles the design doesn't give; say what is
  open instead.
- Never stage, commit or push.
