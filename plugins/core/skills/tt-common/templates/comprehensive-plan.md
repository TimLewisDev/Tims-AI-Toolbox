# Template: Comprehensive Tech Plan

The plan file is created at **Setup** (see `planning-protocol.md`) as the
**draft**: the Consensus Ledger lives in it, and every agreed item is a small
Edit. While it is a draft, its Status line and **Stages** table read:

```markdown
- **Status:** Draft (not signed off; not for breakdown) · **Stage:** <stage> · **Next:** <the next probe or step, in a few words>

**Stages** (draft only; removed at sign-off)

| Stage | Status | Output | Challenges |
|---|---|---|---|
| Familiarisation | <status> | <link to the Familiarisation doc, or "Skipped: <reason>"> | <link to its section in the Challenges doc> |
| Requirements | Not started | Requirements (`R`) | |
| Scope & Constraints | Not started | Scope / Non-Goals (`S`), Constraints (`C`) | |
| Approach | Not started | Chosen Approach (`A`), Rejected Alternatives | |
| Technical Design | Not started | Repo Facts, `CD`/`NB`, Implementation outline | |
| Whole plan | Not started | the whole draft | |
| Sign-off | Not started | signed-off plan, Tech Plan, Future Iterations | — |
```

Stage statuses: `Not started` · `In progress` · `Challenge pending` ·
`Closed` · `Reopened` · `Skipped`. The Challenges cell links the stage's
section in the Challenges doc once it has been challenged.

The draft starts with the header, the Stages table, the Context paragraph and
the section headings below, empty. Requirements, Chosen Approach, Rejected
Alternatives, Scope / Non-Goals, Constraints, Resolved Critical Decisions and
Non-Blocking Review Items fill as items are agreed; Repo Facts Verified fills in
the Technical Design stage; Implementation Plan holds only the step outline
(titles, Files, one-line Done when) until hand-off, when each step is written in
full. At sign-off the Status line becomes the signed-off form below and the
Stages table is deleted.

```markdown
<header or tag block matching sibling docs>

# <Feature>: Comprehensive Tech Plan

- **Status:** Signed off <YYYY-MM-DD> · **Revision:** 1 (see Change Log)
- **Tech Plan (summary for review):** <link> · **Tech Proposals:** <link> · **Future Iterations:** <link>
- **Familiarisation:** <link; omit if the stage was skipped> · **Challenges:** <link>
- **Ticket:** <issue key; omit this line if there isn't one>
- **Base branch:** `<base>` · **Verified against:** `<base>` @ `<short sha>` on <YYYY-MM-DD>
- **ID key:** `R` Requirements · `A` Chosen Approach · `S` Scope / Non-Goals · `C` Constraints · `CD` Resolved Critical Decisions · `NB` Non-Blocking Review Items · `P` Tech Proposals · `CH` Challenges · `§N` Implementation Plan step N
- Each `R`, `A`, `S` and `C` bullet ends with its lowercase ID as a block id (` ^r1`), in a vault or not, so other documents can link to it; `ids.sh anchor` checks and adds them.

**Context.** <What is being built, for whom, and why now. Links to parent docs,
including the Familiarisation doc. What earlier material is, and is not, a
source of truth.>

---

## Requirements
### <short group heading>
- **R1:** <agreed statement> ^r1

## Chosen Approach
- **A1:** <agreed statement> (P1) ^a1

**Implied consequences, agreed:** <if any>

## Rejected Alternatives
| Alternative | Why rejected | Proposal |
|---|---|---|

## Scope / Non-Goals
**In scope:** <IDs, with a one-line summary>

**Not in scope:**
- **S1:** <statement> ^s1
  - Why: <reason>

## Constraints
### <short group heading>
- **C1:** <statement> ^c1

## Repo Facts Verified
Checked on `<base>` @ `<short sha>` on <YYYY-MM-DD>. Paths are relative to the repo root.
- <fact>: `<path>:<lines>`

## Resolved Critical Decisions
| # | Decision | Outcome | Proposal |
|---|---|---|---|

## Non-Blocking Review Items
| # | Item | Applied in plan | Alternative | Proposal |
|---|---|---|---|---|

## Architectural Pressure Points
| Area | Pressure | Handling |
|---|---|---|

## Implementation Plan
**Prerequisites:** <ticket, branch, setup, or "none">

<Step order, and which steps can run in parallel.>

### §1. <title>
**Files:**
- new `<path>`: <purpose>
- change `<path>`: <what changes>

**Work:** <signatures, constants, snippets, precedent `path:line`>

**Done when:**
- <observable check> (<IDs it proves>)

## Affected Files
| File | Status | Assembly / area |
|---|---|---|
| `<path>` | new · changed · **unchanged** | |

## Open Items (don't block)
- <item, or "None">

## Change Log
| Rev | Date | Change | IDs | Source |
|---|---|---|---|---|
| 1 | <YYYY-MM-DD> | Signed off | — | tt-adversarial-plan |
```

