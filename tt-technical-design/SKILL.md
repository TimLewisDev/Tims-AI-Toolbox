---
name: tt-technical-design
description: >
  Stage 4 of tt-adversarial-plan: ground the agreed approach in the codebase
  before anything is written. Lists the systems, contracts, schemas and
  services the feature touches and the claims the plan will rely on, has
  parallel subagents verify them at the pinned commit (checked mechanically
  with verify-refs.sh) and records the accepted Repo Facts; hunts
  systematically for Critical Decisions and resolves each through a proposal
  (blocking ones by the engineer's choice); and writes the Implementation Plan
  outline in dependency order. Writes into the draft Comprehensive Tech Plan
  as it goes. Ends on the engineer's confirmation, ready for the stage's
  adversary challenge. Normally run by tt-adversarial-plan; can be run on
  its own.
metadata:
  version: "1.0"
---

# tt-technical-design

## Usage

```
/tt-technical-design <draft plan>
```

Normally invoked by `tt-adversarial-plan`.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`<skill>/../tt-common`; `<plan>` and `<draft>` are as in the protocol.

- Read `<common>/orchestration.md` and `<common>/planning-rules.md` first.
  The protocol's rules apply throughout; this file adds only what is specific
  to the technical design. The protocol's **Critical Decisions** list is this
  stage's main checklist.
- `<skill>/challenge-lens.md` is for the adversary that runs after this stage;
  you don't need it.

## Inputs (read only these)

- The plan's Status line, Stages table, and every Ledger section:
  `## Requirements`, `## Chosen Approach`, `## Rejected Alternatives`,
  `## Scope / Non-Goals`, `## Constraints`, and whatever is already in
  `## Repo Facts Verified`, `## Resolved Critical Decisions`,
  `## Non-Blocking Review Items` and `## Implementation Plan`.
- The Tech Proposals doc's **At a glance**.
- The Familiarisation doc's **Key parts** and **Data and contracts**, and the
  `<draft>/research/approach-<x>.md` file for the chosen approach.

## Procedure

Ground the agreed approach in the codebase before anything is written.

### Repository alignment pass

List the systems, components, contracts, schemas and services the feature
touches, and for each, the claims the plan will rely on. **Verify them in
parallel:** one subagent per area (at most 4, model and effort from
`model-config.sh get verify-area`, brief
`<skill>/briefs/verify-area.md`), each writing
`<draft>/research/facts-<area>.md` in the plan's **Repo Facts Verified**
format. Then check their references mechanically:

```
bash "<common>/scripts/verify-refs.sh" --ref "$BASE_SHA" "<facts file>"
```

Accept each fact yourself (read the cited lines where it matters), then insert
the accepted facts into the draft:

```
bash "<common>/scripts/assemble.sh" insert "<plan>" "## Resolved Critical Decisions" <facts files>
```

A claim a subagent disproves, or can't verify, is a finding to weigh: if the
plan depends on it, it's a question or a Critical Decision, and if it breaks an
earlier stage's entry, it's a contradiction.

### Critical Decisions

Hunt for them systematically (the protocol's list, item by item, against the
approach and the facts) and resolve each one through a proposal, by the
protocol's Blocking or Non-Blocking procedure, before writing anything that
depends on it. Record any **Architectural Pressure Points** the facts reveal
(area, pressure, handling) as you find them.

### Implementation outline

Write the steps into the draft's Implementation Plan in dependency order:
each step's title (`### §N. <title>`), the files it creates or changes, and a
one-line **Done when** citing the IDs it proves. Note which steps can run in
parallel. Anything this surfaces that isn't settled is a question or a
Critical Decision, never an assumption. The full step text is written at
sign-off, by `tt-plan-signoff`.

Prioritise questions early — resolving ambiguity up front avoids invalidating
the plan later.

## Stage exit

When the facts are in, every Critical Decision is resolved and the outline is
written, show: the Repo Facts areas, the `CD` and `NB` IDs with their outcomes
(one line each), and the outline's step titles. Ask the engineer to confirm
that the Technical Design is complete. No `Blocking decision` proposal may
still be `Open`. Then hand over (Stage contract step 6).
