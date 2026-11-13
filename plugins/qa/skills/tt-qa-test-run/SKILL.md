---
name: tt-qa-test-run
description: >
  Work through a Test Plan with a QA tester, one area at a time: shows the
  area's checklist (how to test, what a pass looks like), takes each item's
  verdict (pass, fail, blocked, skip) and note, records it by script, turns a
  failing item into a bug through tt-qa-bug (steps and expectation copied from
  the item), and reports what is tested, passed and failed. Records only what
  the tester says happened; never marks an item itself. Never commits. Use
  when asked to run, continue, resume, validate or report on a feature's test
  plan.
argument-hint: "<plan.md> [<bug folder>] | summary <plan.md> | area <plan.md> <A-id>"
metadata:
  version: "1.0"
---

# tt-qa-test-run

## Usage

```
/tt-qa-test-run <plan.md> [<bug folder>]    # report, pick an area, work through it
/tt-qa-test-run summary <plan.md>           # the dashboard in words, nothing else
/tt-qa-test-run area <plan.md> <A-id>       # go straight to one area
```

The bug folder defaults to a `Bugs` folder beside the plan. With no argument,
ask for the plan and stop.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`). `<test>` is
`bash "<skill>/../tt-qa-test-plan/scripts/test.sh"` and `<bug>` is
`bash "<skill>/../tt-qa-bug/scripts/bug.sh"`: both sit in this plugin. Run each
with `--help` once to see its commands and spec format.

- **Only the tester decides a result.** Record `pass`, `fail`, `blocked` or
  `skip` only after they say so. Never run the feature yourself and call it
  tested, never infer a result from the code.
- Results go in through `<test> check`, one call per item, the full script path
  written out, no `;` or `&&` chains. Never edit the plan or results file.
- Read state with `<test> list "<plan>" --tsv` and `<test> summary "<plan>" --tsv`.
- Ask with `AskUserQuestion`, two to four named options, recommended first.
  Where it isn't available, ask in chat as a numbered list.

## Run

1. **Where it stands.** Show the summary: items, tested %, passed, failed,
   blocked, skipped, untested, and per area the same in one line each. Say
   which failing items have no bug yet (a `fail` row with no bug ID).
2. **Pick an area.** Ask which to work on: the first area with untested items
   (recommended), another area, **Raise bugs for the failures**, or **Stop for
   now**.
3. **Walk the area.** For each untested item in order show: the ID and title,
   the numbered how-to-test steps, and what a pass looks like. Then ask:
   **Pass**, **Fail**, **Blocked**, **Skip** (two to four options; offer
   "Back to the areas" as the way out). Ask for a short note only on Fail,
   Blocked and Skip; a note is one line.
4. **Record** the verdict: `<test> check "<plan>" <item> <result> --note "<note>"`.
5. **On Fail**, offer: **Raise a bug now** (recommended), **Later**. To raise
   one, run `/tt-qa-bug`'s rules: build the spec from the item (title from the
   item and what failed; steps from the item's steps; expected from its
   Expected; actual from the tester's note, asking one question if there is
   none; feature, area and `source: <item id>` filled), save it with `<bug> new`,
   then link it: `<test> check "<plan>" <item> fail --note "<note>" --bug <BUG-id>`.
6. **Finish an area** with its one-line counts and go back to step 2. When no
   untested items remain, say so, give the final summary, and list the open
   failures. Commit nothing.

`summary` mode prints the report in words and stops. `area` mode starts at
step 3.
