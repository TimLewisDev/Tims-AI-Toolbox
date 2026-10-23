# Template: Lite Brief

One short document that is both the plan and the task breakdown for a small
change: `tt-execute-lite` runs it directly, with the same scripts `tt-execute`
uses. The order and the headings matter: those scripts find things by heading
and table. A brief is usually 80–150 lines.

Write it from part files (`assemble.sh`), then run `lite-index.sh` to write the
two tables. Nothing here is a design review: the Goal, Acceptance and Change
come from the engineer, and the cards only slice the change.

```markdown
<header or tag block matching sibling docs, if any>

# <Feature or fix>: Lite Brief

- **Revision:** 1
- **Repo:** `<absolute path>` · base `<branch>` · working branch `<branch>`
- **Build check:** `<how the agent builds or compile-checks, from the repo's instructions or the engineer; or "engineer only">`
- **Read at:** `<base>` @ `<short sha>` on <YYYY-MM-DD> (or "working tree, <YYYY-MM-DD>")
- **Source:** <Focus Log or Debug Log path, if any>

## Goal
<Plain English, 2–4 sentences: what changes for whom, and why. No code names.>

## Acceptance
- **A1** <an observable "done when", in the engineer's words> ^a1
- **A2** … ^a2

## How it works today
<Only the parts the change touches, cited `path:line` at the commit. Short
paragraphs or a few bullets. Describe; don't propose.>

## The change
<What will be built, and each decision taken to get there. One bullet per
decision: what was chosen, the options considered, and who chose ("chosen by
the engineer"). A decision the code settles says so ("the existing pattern at
`path:line`").>

## Not in scope
- <adjacent work deliberately left out>

## Open items
<Anything still unknown that a card handles as a Confirm step, or "None".>

## Work Units
<written by lite-index.sh>

## Task Map
<written by lite-index.sh>

## WU1 — <outcome: "after this unit you can…">

**In plain English:** <2–4 sentences: what someone can do or see once this is validated>

| | |
|---|---|
| **Tasks** | <IDs> |
| **Depends on** | — |
| **Validated by** | Agent · Agent + Engineer |

**Validation**
- [ ] <check, e.g. "it compiles"> (Agent)
- [ ] <acceptance item, restated as a check> (A1) (Agent | Engineer | Agent + Engineer)
- [ ] … (A2) (…)

**How to validate**

```checks
<n> | <ok | empty | nonempty> | <command, run with bash in the repo>
```

- Agent: <anything the checks block can't express>
- Engineer (read out inline at validation time):
  1. <what to open and do> → expect <what they should see>

### T01 — <imperative title>

**In plain English:** <2–4 sentences>

| | |
|---|---|
| **Executor** | Agent · Engineer |
| **Work unit** | WU1 |
| **Depends on** | <IDs, or —> |

**Goal:** <one technical sentence>

**Read first**
- Precedent: `<repo path>:<lines>`, for <the pattern to copy>
- Repo rules: <only the ones that apply here>

**Files** (nothing outside this list)
- new `<path>`: <purpose>
- change `<path>`: <what changes>

**Steps**
1. <Concrete and ordered. Signatures, constants and snippets, with no planning IDs in code comments.>
2. **Confirm:** <anything left open: what, how, and what to do with each answer>

**Not in this task**
- <adjacent work, and which task or "Not in scope" item owns it>

**Validated in:** WU1, checks <numbers>.
```

## Rules

- **One unit** (`WU1`) unless an Engineer-in-a-tool step has to happen midway;
  then two. Tasks are consecutive (`T01`, `T02`, …) and belong to one unit.
  Prefer 1–4 tasks. If the change needs more than about six, it is not lite:
  stop and suggest `tt-workflow` instead.
- **Cards follow `tt-task-breakdown/templates/task-card.md`**: every detail the
  implementer needs on the card (signatures, constants, exact strings,
  snippets, gotchas, precedent file and line); no planning IDs in code
  snippets; a **Confirm** step instead of a guess.
- **Acceptance IDs (`A1`…) are cited by Validation items** as `(A1)`, so no
  acceptance item goes unchecked. `lite-check.sh` enforces it. Each one ends
  with its lowercase ID as a block id (` ^a1`) so a link can land on it.
- **The checks block** holds one line per Validation item the agent checks with
  a command: `<n>` is the item's position in the list (from 1), `ok` passes on
  exit 0, `empty` when nothing is printed, `nonempty` when something is. Use
  the header's Build check for compile checks. An Agent + Engineer item gets a
  line for its agent part. An item only the engineer checks gets no line.
- **Executors and validation follow the repo's rules** (`AGENTS.md`,
  `CLAUDE.md` or equivalent): tool-managed files are authored by the engineer
  in the tool, and a check only the engineer can run makes the unit
  Agent + Engineer.
- **Never fabricate.** Everything traces to the Focus Log or Debug Log, the
  engineer's words, or code read at the commit. Unknowns become Open items or
  Confirm steps.
