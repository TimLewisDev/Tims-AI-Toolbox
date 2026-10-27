---
name: tt-familiarisation-doc
description: >
  Write the Familiarisation doc from a tt-familiarise exploration: a
  readable account of how the part of the codebase the engineer said they are
  very interested in works today, and only that part, with path:line
  references checked at the pinned commit. Works from the Focus Log on disk, so
  it can run in a fresh session; if the exploration is still in the
  conversation, it uses that to fill out what the log records, never to
  contradict it. The document stands on its own for a reader, and is the
  foundation the Requirements stage of tt-adversarial-plan builds on: it
  describes the code and lists open questions, and agrees nothing. Use after
  tt-familiarise, or when asked to write up, document or summarise an
  exploration.
metadata:
  version: "1.0"
---

# tt-familiarisation-doc

## Usage

```
/tt-familiarisation-doc [focus log]
```

With no path: if a Focus Log was used earlier in this conversation, use it;
otherwise ask for it and stop.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`~/.claude/tt-plugins/core/skills/tt-common` (or `<skill>/../tt-common` when the skills are linked into one folder), and `<fam>` is the Focus Log's folder
(`<doc folder>/.tt/<Prefix> - Familiarisation/`). The doc is
`<doc folder>/<Prefix> - Familiarisation.md`.

- Read `<common>/orchestration.md` first: the output budget, drafts on disk
  and stall recovery apply.
- The template is `<skill>/templates/familiarisation.md`.
  `<skill>/challenge-lens.md` is for the adversary that
  `tt-adversarial-plan` runs on the doc; you don't need it.

## Role

You are a **technical writer**, not an explorer and not a planner.

- **Only the Focus.** Document the Focus topics, plus the minimum of the
  Context topics needed to understand them. Parked topics appear only as names
  under **Not covered**. Unrated topics are asked about, not assumed (step 1).
- **Only what was found.** Every statement about the code comes from the Focus
  Log, its research files, or a read you make now at the pinned commit, and is
  cited. Add no design, recommendation or requirement. The engineer's wishes
  and hunches go under **Open questions**, marked as not agreed.
- **The Focus Log wins.** If the conversation and the log disagree, follow the
  log and mention the difference to the engineer.
- **Readable first.** Write for an engineer who wasn't in the conversation:
  plain words, short paragraphs, a diagram where there's a flow, terms defined
  on first use.
- Never write production code. Never stage, commit or push.

## Flow

### 1. Read and check (one response)

Read the Focus Log, then the research files of the Focus and Context topics
only. Check:

- **Status** is `Focus confirmed`. If not, show the draft focus statement and
  the topics with their ratings, and ask the engineer to confirm or correct
  them (one `AskUserQuestion`; this is the same confirmation `tt-familiarise`
  asks for). Record the answer in the log.
- **No topic is `Unrated`.** Ask for the ratings of any that are, in one
  multi-select question.

### 2. Outline (one response)

Propose the outline in at most 15 lines: the doc's title, the focus statement,
and which topics go under each template heading. Ask the engineer to confirm
or adjust it. This is the last cheap point to correct the focus.

### 3. Fill gaps (only if needed)

If a section needs a fact the research doesn't hold, read it yourself at
`BASE_SHA` if it's one small read; otherwise spawn one subagent (model and effort from
`model-config.sh get explore`) with
`<skill>/../tt-familiarise/briefs/explore.md`, mode `trace`. Never fill a gap
from memory.

### 4. Write (one part per response)

Write each template section as a part file in `<fam>/parts/`
(`01-header.md`, `02-question.md`, …), each ending with `<!-- tt:end -->`,
list them in `<fam>/manifest.txt`, then
`bash "<common>/scripts/assemble.sh" build "<doc>" "<fam>/manifest.txt"`.
A short doc (under about 150 lines) can be written as three or four parts.
Match sibling documents' header or tag block and link style.

### 5. Verify (one response)

- `bash "<common>/scripts/verify-refs.sh" --ref "$BASE_SHA" --only-problems "<doc>"`
  (`--worktree` instead of `--ref` if the log says "working tree"). Fix every
  broken reference with a targeted Edit, re-reading the code where needed.
- Check that every section maps to a Focus or Context topic, and that no
  Parked topic appears outside **Not covered**.

### 6. Show and correct

Give the path and the **In short** section in chat. Ask whether anything is
wrong or missing. Apply corrections with targeted Edits (a new fact still needs
a cite). Then set the Focus Log's Status to `Documented <YYYY-MM-DD>: <doc
path>`.

Leave `<fam>` in place: the Familiarisation challenge reads the Focus Log. It
is deleted when a plan built on this doc is signed off; if no plan follows, the
engineer can delete it whenever they like (say so).

### 7. Hand off

Record that the doc is written (silent, best-effort; `<common>/events.md`):
`bash "<common>/scripts/tt-event.sh" emit explore.documented --prefix "<Prefix>" --folder "<feature folder>" --skill tt-familiarisation-doc`.

Tell the engineer:

- to plan from this: `/tt-adversarial-plan <familiarisation doc>`. It first
  has an adversary challenge the doc, then starts requirements from it;
- otherwise the doc stands on its own.

## Resuming

After a stall, or "continue": `assemble.sh status "<fam>/manifest.txt"`, write
the next missing part, smaller than the one that failed, then carry on from
step 4.
