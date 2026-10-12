---
name: tt-requirements
description: >
  Stage 1 of tt-adversarial-plan: lock down a feature's requirements by
  interrogating the engineer with hypothetical questions (missing or repeated
  preconditions, triggers, concurrency, worst inputs, observable success),
  starting from the Familiarisation doc's description of the code and its open
  questions, or from a spec or ticket. Writes each agreed requirement (R) into
  the draft Comprehensive Tech Plan as soon as it is agreed, so the stage can
  be resumed, and ends on the engineer's confirmation that the requirements
  are complete, ready for the stage's adversary challenge. Normally run by
  tt-adversarial-plan; can be run on its own to work on a plan's
  requirements in a session of their own.
metadata:
  version: "1.0"
---

# tt-requirements

## Usage

```
/tt-requirements <draft plan | familiarisation doc | spec or ticket>
```

Normally invoked by `tt-adversarial-plan`, which passes the draft plan.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`<skill>/../tt-common`; `<plan>` and `<draft>` are as in the protocol.

- Read `<common>/orchestration.md` and `<common>/planning-protocol.md` first.
  The protocol's Role, Ledger, Stage contract, Interview conduct,
  Contradiction handling, Critical Decisions and Proposals rules apply
  throughout; this file adds only what is specific to requirements.
- `<skill>/challenge-lens.md` is for the adversary that runs after this stage;
  you don't need it.

## Inputs (read only these)

- The plan's Status line, Stages table and `## Requirements`
  (`md-section.sh get`). No plan yet: run the protocol's **Setup**.
- The Familiarisation doc, if there is one: **The question**, **In short**,
  **How it works today**, **Rules the code imposes**, **Open questions**.
- Intake documents (spec, design doc, brief, ticket): read every one in full
  before the first probe.

**No Familiarisation doc** (the stage was `Skipped`): start a **landscape**
subagent in the background (model and effort from
`model-config.sh get landscape`, brief
`<skill>/briefs/landscape.md`) with the feature summary, intake paths, repo and
`BASE_SHA`. It maps the systems the feature touches while you question the
engineer, and writes `<draft>/research/landscape.md`. Read its digest when it
arrives; it is orientation, not agreement.

## Procedure

Probe with hypotheticals to pull out what the feature must actually do:

- "What happens if <precondition> is missing / empty / already true when this
  fires?"
- "Who or what triggers this? Can it happen twice, concurrently, or out of
  order?"
- "How do we know it worked? What does success look like, observably?"
- "What's the worst input this could receive?"

Drive out functional requirements, actors, triggers, success criteria, and edge
cases. Record each agreed point under **Requirements** (grouped under short
headings), one small Edit each, as soon as it's agreed.

**Building on the Familiarisation doc.**

- Start from its **Open questions**: each one becomes a probe (one at a time).
- Use **How it works today** as the baseline. For each behaviour the feature
  touches, establish whether it is kept, changed or replaced, and pin the
  change in a requirement. Quote the doc when you ask.
- Treat **Rules the code imposes** as facts to probe against ("the code only
  allows one active X per Y (`path:line`); does the feature need more?").
  Whether a rule becomes a Constraint is decided in the next stage.
- The doc is description, never agreement: nothing in it becomes an `R` until
  the engineer agrees it.

A choice between real alternatives (for example two behaviours a requirement
could specify) goes through a proposal (type `Requirement or scope`) per the
protocol. A scope question that comes up ("is X in?") is noted in `Next` for
the Scope & Constraints stage rather than settled here, unless the requirement
can't be stated without it.

## Stage exit

Continue until the requirements feel complete to you **and** the engineer
agrees they are. Before asking (protocol, Stage contract step 5):

- List any Familiarisation **Open questions** that no `R` answers. For each,
  the engineer chooses: answer it now, carry it to Scope & Constraints, or drop
  it (recorded in `fi-notes.md` if it's excluded work).
- Show the requirement IDs with one line each, and ask for confirmation that
  the Requirements are complete.

Then hand over (Stage contract step 6).
