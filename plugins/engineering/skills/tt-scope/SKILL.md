---
name: tt-scope
description: >
  Stage 2 of tt-adversarial-plan: force a feature's boundary into the open
  once its requirements are agreed. Drives explicit is / is-not statements,
  the smallest version still worth shipping, what the feature must not do or
  break, and the hard constraints (performance, platform, compatibility,
  ownership, sequencing, repo rules, base branch), seeding non-goals from what
  the Familiarisation doc deliberately left out. Writes Scope / Non-Goals (S)
  and Constraints (C) into the draft Comprehensive Tech Plan as they are
  agreed, and notes excluded work for Future Iterations. Ends on the
  engineer's confirmation, ready for the stage's adversary challenge. Normally
  run by tt-adversarial-plan; can be run on its own.
metadata:
  version: "1.0"
---

# tt-scope

## Usage

```
/tt-scope <draft plan>
```

Normally invoked by `tt-adversarial-plan`.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`~/.claude/tt-plugins/core/skills/tt-common` (or `<skill>/../tt-common` when the skills are linked into one folder); `<plan>` and `<draft>` are as in the protocol.

- Read `<common>/orchestration.md` and `<common>/planning-rules.md` first.
  The protocol's rules apply throughout; this file adds only what is specific
  to scope and constraints.
- `<skill>/challenge-lens.md` is for the adversary that runs after this stage;
  you don't need it.

## Inputs (read only these)

- The plan's Status line and Stages table (including `Next`, where the
  Requirements stage may have carried scope questions forward),
  `## Requirements`, `## Scope / Non-Goals` and `## Constraints`.
- The Familiarisation doc's **Not covered** and **Rules the code imposes**, if
  there is one.
- `<draft>/research/landscape.md`'s **Repo rules that apply**, if it exists.
- The repo's agent instructions (`AGENTS.md`, `CLAUDE.md` or equivalent), for
  repo rules: tool-managed files, modules or assemblies, branch rules.

## Procedure

Force the boundary into the open:

- "Is <capability> in scope, or explicitly out?"
- "What is the smallest version of this that is still worth shipping?"
- "What must this **not** do or break?"

Drive explicit **is / is-not** statements and non-goals, and surface hard
constraints. Record under **Scope & Non-Goals** (the **In scope** line cites
the `R` IDs it covers; each Non-Goal is an `S` with its **Why**) and
**Constraints** (grouped under short headings), one small Edit each.

**Seeds, each needing the engineer's agreement:**

- **Scope questions carried forward** from the Requirements stage (`Next`).
- **Not covered** topics from the Familiarisation doc: ask, in one multi-select
  `AskUserQuestion`, which are explicitly out of scope. Each one they pick
  becomes an `S`; ask about the rest one at a time.
- **Rules the code imposes**, the landscape's repo rules and the agent
  instructions: candidate Constraints. Put each to the engineer ("the repo
  says X is edited only in its tool (`path`); a constraint for this feature?").
- **The base branch** pinned at Setup is always a Constraint.

**Excluded work.** Every time something is ruled out of scope, add one line to
`<draft>/research/fi-notes.md` (what, why, the `S`/`NB`/`P` that excluded it).

A real choice between scope options goes through a proposal (type
`Requirement or scope`). A new requirement that surfaces is a contradiction or
an addition to a `Closed` stage: follow the protocol's Contradiction handling.

## Stage exit

When scope and constraints feel complete to you, show the `S` and `C` IDs with
one line each (the words from `ids.sh gloss`) and the **In scope** line, and ask the engineer to confirm that
Scope & Constraints are complete. Then hand over (Stage contract step 6).
