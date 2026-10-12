---
name: tt-approach
description: >
  Stage 3 of tt-adversarial-plan: choose how a feature will be built, once
  its requirements, scope and constraints are agreed. Identifies at least two
  candidate approaches, has parallel subagents research each against the
  actual repository (precedents at path:line, conflicts with existing
  patterns, effort signals, unknowns), weighs the tradeoffs and probes the
  ones the engineer favours, then writes the choice as a proposal in the Tech
  Proposals doc and asks the engineer to decide. Records the Chosen Approach
  (A) and the Rejected Alternatives in the draft Comprehensive Tech Plan, with
  a proposal for every real sub-choice. Ends on the engineer's confirmation,
  ready for the stage's adversary challenge. Normally run by
  tt-adversarial-plan; can be run on its own.
metadata:
  version: "1.0"
---

# tt-approach

## Usage

```
/tt-approach <draft plan>
```

Normally invoked by `tt-adversarial-plan`.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`<skill>/../tt-common`; `<plan>` and `<draft>` are as in the protocol.

- Read `<common>/orchestration.md` and `<common>/planning-protocol.md` first.
  The protocol's rules apply throughout; this file adds only what is specific
  to choosing the approach.
- `<skill>/challenge-lens.md` is for the adversary that runs after this stage;
  you don't need it.

## Inputs (read only these)

- The plan's Status line, Stages table, `## Requirements`,
  `## Scope / Non-Goals`, `## Constraints`, `## Chosen Approach` and
  `## Rejected Alternatives`.
- The Familiarisation doc's **How it works today** and **Key parts**, if there
  is one, or `<draft>/research/landscape.md`.
- The Tech Proposals doc's **At a glance**, if the doc exists.

## Procedure

Identify at least two candidate approaches. Where the scope allows it, one of
them should be the smallest change that meets the requirements. **Research them
in parallel:** one subagent per candidate (at most 4, model and effort from
`model-config.sh get approach-research`, brief
`<skill>/briefs/research-approach.md`), each given the approach in a few
lines, the agreed requirements' IDs and text, the repo and `BASE_SHA`. Each
writes `<draft>/research/approach-<x>.md`: precedents at `path:line`, where it
conflicts with existing patterns, effort signals, and unknowns. They don't rank
the options; you do.

Then weigh the tradeoffs yourself, grounded in those findings, aligned to the
repo's existing patterns, avoiding idealised redesigns and generic advice, and
checked against every `S` and `C`. Adversarially probe the tradeoffs the
engineer seems to favour.

For the approach choice:

1. Write it as a proposal (the next free `P`, status `Open`, type `Approach`)
   in the Tech Proposals doc (see the protocol's **Proposals**). The first
   proposal in a session creates the doc from `tt-tech-proposals`'
   template.
2. Ask with **`AskUserQuestion`**: the approaches as options in the same order
   as the proposal, recommended first and labelled as recommended. Tell the
   engineer the proposal's path so they can read the full breakdown there.
3. Record the answer: the proposal's Decision, and the chosen approach plus
   rejected alternatives (with rationale and the `P` link) under **Chosen
   Approach** and **Rejected Alternatives**. Record any implied consequences
   the engineer agrees to under **Implied consequences, agreed**.

An approach usually breaks into several sub-choices. Give each real choice its
own proposal, decided the same way. A sub-choice that is a Critical Decision
follows the protocol's Blocking or Non-Blocking procedure.

If the research shows an `R`, `S` or `C` can't be met by any candidate, that
is a contradiction: follow the protocol's Contradiction handling.

## Stage exit

When the approach and its sub-choices are settled, show the `A` IDs, the
Rejected Alternatives (one line each) and the proposals decided in this stage
with their statuses, and ask the engineer to confirm that the Approach is
complete. No `Blocking decision` proposal from this stage may still be `Open`.
Then hand over (Stage contract step 6).
