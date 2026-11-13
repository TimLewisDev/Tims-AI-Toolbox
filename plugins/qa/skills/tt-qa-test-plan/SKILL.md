---
name: tt-qa-test-plan
description: >
  Break a feature into areas to validate for a QA tester: reads the feature's
  documents (ticket, requirements, tech plan, brief, acceptance criteria) and
  proposes areas, each with test items that say how to test and what a pass
  looks like. The tester accepts, changes or drops each area; a script writes
  the Test Plan from one template, so the plan always reads the same and the
  model never writes it itself. Results are recorded elsewhere by
  tt-qa-test-run. Also runs unattended (draft) for tools that show the plan
  elsewhere. Never commits. Use when asked to plan the testing of a feature,
  write a test plan or checklist, or work out what to validate.
argument-hint: "<plan.md> <feature folder or source> | draft <plan.md> <feature name> <source...> | resume <plan.md>"
metadata:
  version: "1.0"
---

# tt-qa-test-plan

## Usage

```
/tt-qa-test-plan <plan.md> <source...>          # propose areas, review them, write the plan
/tt-qa-test-plan draft <plan.md> <feature> <source...>   # unattended: write every area, ask nothing
/tt-qa-test-plan resume <plan.md>               # carry on with an existing plan
```

`<source...>` is one or more files or folders that describe the feature (a
ticket, requirements, a tech plan, a brief, a design doc, acceptance
criteria). With no argument, ask for the plan path and the sources and stop.
`<plan.md>` is the Test Plan; its results live beside it.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`) and `<test>` is
`bash "<skill>/scripts/test.sh"`. Run `<test> --help` once to see every
command and the spec format.

- **The script is the only writer of the plan.** Never Write or Edit the plan
  or its results file: use `init`, `area add`, `item add`, `edit`, `remove`,
  `status`.
- Specs go in on stdin with a quoted heredoc. One `test.sh` command per shell
  call, the full script path written out, no `;` or `&&` chains.
- Read the plan back with `<test> list "<plan>" --tsv`. Never parse the
  markdown yourself.
- If the script refuses (exit 1), read its message, fix the spec and try
  again. If `verify` prints `problem:` lines, show them and stop.
- Ask with `AskUserQuestion`, two to four named options, recommended first.
  Where it isn't available, ask in chat as a numbered list.
- Read the sources and the code with read-only tools. Change nothing but the
  plan, through the script.
- In **draft** mode ask nothing: no `AskUserQuestion`, no questions in chat.

## What makes a good plan

- **Areas are things a tester can sit down and validate in one go**: a flow,
  a screen, a rule, an integration, a state. Usually 3 to 8 areas, each with
  a one-line `why` (what could go wrong there). Not one area per source file.
- **Cover the feature's own promises first**: every requirement and
  acceptance criterion in the sources lands in at least one item. Then the
  edges: empty and maximum inputs, cancelling half way, repeating an action,
  losing connection, the wrong order, permissions and roles, upgrading from
  old data, and what must NOT change. Add an "Existing behaviour" area for
  neighbours the feature could break.
- **An item is one check with one verdict.** Title: what is checked. How to
  test: numbered steps a tester can follow cold (starting state included).
  Expected: what a pass looks like, observable, with numbers and exact text
  where the sources give them.
- **Ground it.** Every item traces to a statement in a source or to the code
  you read. Don't invent behaviour; where the sources don't say what should
  happen, make the item's Expected "Not specified: ask <who/what>" rather
  than guess, and list those in your closing summary.
- No duplicates across areas; no implementation-internal checks a tester
  can't see (unit-level assertions).

## Normal mode

1. Read the sources and, where the feature has code, the relevant code.
2. Propose the **areas** first: title and why, in a short list. Ask: **Looks
   right** (recommended), **Change the areas**, or **Not now**. Apply changes.
3. `init` the plan (`<test> init "<plan>" --feature <name>`) and add the areas.
4. Per area, one at a time: propose its items, show them, ask: **Add these**
   (recommended), **Change them**, or **Skip this area**. Add the accepted
   ones with `item add`.
5. Run `<test> verify`, set the plan **Ready** with `<test> status "<plan>"
   Ready` once the tester agrees, and finish with the summary
   (`<test> summary "<plan>" --tsv`) and the "Not specified" list. Say that
   `/tt-qa-test-run <plan>` is the next step; commit nothing.

## Draft mode (unattended)

`draft <plan.md> <feature> <source...>`:

1. Read the sources and the relevant code. Write the whole plan exactly as
   above: `init`, then `area add` and `item add` for everything, asking nothing.
2. Leave the plan **Draft** (the tester reviews it elsewhere). Run `verify`.
3. Finish with one line: `ok <areas> areas, <items> items` or
   `refused: <message>`.

## Resume

Run `<test> list` and `<test> summary`, say where the plan stands (areas,
items, which areas have no items, how many results exist), then carry on from
the first area that has no items or ask what the tester wants to change. Never
remove an item that has results without asking: **Remove it anyway**,
**Keep it**.
