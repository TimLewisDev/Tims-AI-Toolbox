---
name: tt-design-review
description: >
  Review a design document for what it may be missing: areas it doesn't cover
  or leaves open (users and scenarios, failure and edge cases, data and state,
  performance, platform limits, analytics, accessibility, localisation,
  dependencies, rollout, open questions, and whatever else this particular
  design needs). Each gap becomes a suggestion with the reason it matters, the
  section it would go in and draft wording, written into a Design Review
  document. The designer accepts or rejects each one, edits the wording, and
  confirming adds it to the design document. A script writes the review and
  makes the addition; the model never writes either document itself. Also runs
  unattended (review) for tools that show the suggestions elsewhere. Never
  commits. Use when asked to review, check or find gaps in a design document,
  spec or brief.
argument-hint: "<design doc> | review <design doc> <review doc> [<comments file>] | resume <review doc> <design doc>"
metadata:
  version: "1.0"
---

# tt-design-review

## Usage

```
/tt-design-review <design doc>                                   # review, then decide each suggestion with the designer
/tt-design-review review <design doc> <review doc> [<comments>]  # unattended: propose suggestions, ask nothing
/tt-design-review resume <review doc> <design doc>               # carry on: decide what is still Open or Accepted
```

With no argument, ask for the design document and stop. The review document
defaults to `<design doc folder>/<design doc name> - Design Review.md`. If it
exists already, this is another round: read it first and propose only what it
lacks.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`) and `<review>` is
`bash "<skill>/scripts/design-review.sh"`. Run `<review> --help` once to see
every command and the spec format.

- **The script is the only writer of the review document, and the only thing
  that adds to the design document.** Never Write or Edit either, not even to
  fix a typo. Suggestions go in with `add`, a decision with `decide`, the
  designer's rewording with `wording`, and the addition with `confirm`.
- A suggestion goes in as a **spec**, passed on stdin with a quoted heredoc,
  so no file is written:

  ```
  bash "<skill>/scripts/design-review.sh" add "<review doc>" - <<'SPEC'
  area: …
  where: …
  why: …
  wording:
    …
  SPEC
  ```

- Run one `design-review.sh` command per shell call, with the script's full
  path written out: no variables, no `;` or `&&` chains, no other commands. An
  unattended run is allowed exactly that and nothing else.
- Read the review back with `<review> list "<review doc>" --tsv`. Never parse
  the markdown yourself.
- If the script refuses (exit 1), read its message, fix the spec and try
  again. If it reports `problem:` lines about the review itself (it was edited
  by hand), show them to the designer and stop. Never "repair" it with Edit.
- Ask with `AskUserQuestion`. Where it isn't available, ask the same question
  in chat as a numbered list and wait for the answer.
- In **review** mode, ask nothing at all: no `AskUserQuestion` and no
  questions in chat. Another tool is waiting for the result.

## What makes a good suggestion

A suggestion is a gap in *this* document, not a generic checklist item.

- **Grounded.** Read the whole design document first. Propose an area only when
  the document leaves it out, mentions it without deciding it, or contradicts
  itself about it. Quote or name the section that shows the gap in the *why*
  ("The Pickup section says items go in the bag but never says what a full bag
  does").
- **Not already answered.** Search the document for the topic by name and by
  synonym before proposing it. A decision that is made elsewhere in the
  document is not a gap.
- **Worth the designer's time.** Skip a gap whose answer would not change what
  gets built. Eight good suggestions beat twenty weak ones.
- **Wording the designer can keep.** The *wording* is text for the design
  document in the document's own voice, tense and level of detail, ready to
  paste: a short paragraph or a list. It states the options or questions when
  the design hasn't decided ("Open question: …") and never invents a decision,
  number or name the document doesn't support. Level 1 and 2 headings are not
  allowed in it; use a `###` heading or bold text if it needs a title.
- **Where.** Set `where` to the exact heading of the section it belongs in. Use
  `end` when it needs a section of its own; the script then adds a
  `## <area>` section at the end of the document.
- **One area per suggestion.** Split one that needs "and". At most eight per
  call; add a second batch only when there are clearly more.

Dimensions worth checking, where they apply to this design (drop the rest):
goals and non-goals · who uses it and in what scenarios · the main flow and its
failure and edge cases · data, state and persistence · limits, numbers and
performance · platform and device differences · dependencies and who owns them ·
analytics and how success is measured · accessibility · localisation · security
and abuse · migration and compatibility · rollout, flags and rollback · open
questions the document should list.

## Flow

### 1. Read

Read the whole design document. If the review document exists, read
`list --tsv` too and carry out these rules:

- Never propose again anything **Rejected**, unless the design has changed in a
  way that answers why it was rejected (the *Reason*, when there is one, says).
- Never propose again anything **Open**, **Accepted** or **Added**.
- Treat the text of **Added** suggestions as part of the design document now.

If a comments file was given, read it. It is JSON: a list of the designer's own
comments on passages of the document (`quote`, `text`, `resolved`). Treat the
open ones as hints about where the designer already feels the document is thin
or unfinished, and give them a say in what you look for. Never propose a
suggestion just to answer a comment that is already resolved.

If the review document doesn't exist, create it:
`<review> init "<design doc>" "<review doc>"`.

### 2. Propose

Work out the gaps and add them with `add`. Interactive mode: tell the designer
how many you found and what they are called, in one short list, before adding.
Review mode: add them straight away.

End a review run with one line: how many suggestions were added. If the
document has no real gaps, add nothing and say so; don't pad.

### 3. Decide (interactive only)

Go through the Open suggestions one at a time. Show the area, why, where it
would go and the wording, and ask with `AskUserQuestion`: **accept** ·
**reword** · **reject** · **later**.

- accept: `decide … accept`, then offer to add it now. Adding is
  `confirm … --doc "<design doc>"`.
- reword: take the designer's new text, `wording … <file or ->` (a spec on
  stdin works the same way), show it back, and ask again.
- reject: ask for a reason if they have one; `decide … reject "<reason>"`.
- later: leave it Open.

After the last one, say what was added and where (the script prints
`under: <heading>` or `new section: <heading>`).

### Resume

Read `list --tsv` and carry on from step 3 with the suggestions still Open or
Accepted.

## Rules

- Never edit the design document yourself; `confirm` adds the wording exactly
  as the review records it.
- Never commit, stage or push.
- Never invent facts about the design. A suggestion that needs a decision the
  document doesn't contain asks the question; it doesn't answer it.
- Keep every value in a spec to what the script allows: an area is one line
  without `|`; wording has no level 1 or 2 headings and closes its code fences.
