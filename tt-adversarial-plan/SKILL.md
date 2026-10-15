---
name: tt-adversarial-plan
description: >
  Orchestrate adversarial planning from an idea, exploration, spec, ticket or
  brief into a Comprehensive Tech Plan, the single authority for
  tt-task-breakdown. Use to align on a feature or request a tech plan, tech
  design or implementation plan before coding. Runs stage skills in order,
  each with an on-disk handover: optional familiarisation (tt-familiarise,
  tt-familiarisation-doc), requirements (tt-requirements), scope/constraints
  (tt-scope), approach (tt-approach), technical design (tt-technical-design),
  sign-off (tt-plan-signoff). After each stage an adversary subagent attacks
  the stage's reasoning and assumptions using only written documents and code;
  challenges go to the engineer one at a time and into a Challenges doc.
  Offers breaks after each stage; resumes from the plan's on-disk Stages table.
  Only the engineer's explicit sign-off ends planning.
metadata:
  version: "4.0"
---

# tt-adversarial-plan

## Usage

```
/tt-adversarial-plan [feature description | familiarisation doc | spec or ticket]
/tt-adversarial-plan resume <draft comprehensive tech plan | familiarisation doc | focus log>
```

Seed input is optional. With none, ask one question: "What are we planning?
A short description, a spec or ticket, or a Familiarisation doc."

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`<skill>/../tt-common`; `<plan>` and `<draft>` are as in the protocol.

- Read `<common>/orchestration.md` and `<common>/planning-rules.md` first.
  The compact rules hold the mandatory stage, Ledger, contradiction, Critical
  Decision and safety rules. Consult `<common>/planning-protocol.md` only for
  explanatory detail or sections not covered by the compact rules. This file
  adds only the orchestration.
- The adversary brief is `<skill>/briefs/challenge.md`, the Challenges
  template `<skill>/templates/challenges.md`. Each stage's lens is the
  `challenge-lens.md` in that stage's skill folder.
- **You run the stages; the stages hold the interview.** Invoke each stage
  skill with the Skill tool, in this conversation, because stages talk to the
  engineer. Subagents (research, verification, the adversary) never talk to
  the engineer and never decide.
- If you can't spawn subagents, do the adversary's brief yourself at the same
  point, as a separate response, from the written documents only.

## Where this fits

```
tt-familiarise ──► tt-familiarisation-doc ──► Familiarisation
        │ (stage 0, or skipped)
        ▼
tt-adversarial-plan (orchestrator) ── after every stage: adversary ──► Challenges
  ├─ 1 tt-requirements      ┐
  ├─ 2 tt-scope             │ each writes its Ledger sections into the
  ├─ 3 tt-approach          │ draft Comprehensive Tech Plan, and its
  ├─ 4 tt-technical-design  ┘ proposals (tt-tech-proposals) ──► Tech Proposals
  ├─ 5 whole-plan challenge
  └─ 6 tt-plan-signoff ──► Comprehensive Tech Plan (signed off) ──► tt-task-breakdown
                         ├─► Future Iterations
                         └─► tt-tech-plan ──► Tech Plan (brief, for human review)
tt-tech-plan-review (any time after) keeps Comprehensive ⇄ Tech Plan ⇄ Proposals in sync
```

The documents, their naming, and the ID table are in the protocol's
**Documents** section.

## Start: work out where things stand

**With a draft plan** (`resume <plan>`, or a plan path): read its Status line
and Stages table, then go to **The loop**.

**With a Focus Log or Familiarisation doc** (and no plan yet):

- Focus Log not `Documented`: invoke `tt-familiarise` with `resume <log>` if
  the focus isn't confirmed, otherwise `tt-familiarisation-doc` with the log.
- Familiarisation doc: run the protocol's **Setup**, offering the doc's
  folder, prefix and base branch. If the newly pinned `BASE_SHA` differs from
  the doc's **Read at** commit, run
  `bash "<common>/scripts/verify-refs.sh" --ref "$BASE_SHA" --only-problems "<doc>"`
  and treat each problem as a challenge to raise in the Familiarisation
  challenge. Link the doc from the plan's header and the plan from the doc's
  header. Familiarisation is `Challenge pending`.

**With a description**: ask, with `AskUserQuestion`, whether to explore the
code first: **Explore first (Recommended)** when the engineer or the code area
is unfamiliar · **Skip to requirements** when they already know the area or
have a spec. Exploring invokes `tt-familiarise` with the description; when
it and `tt-familiarisation-doc` finish, continue as for a Familiarisation
doc. Skipping runs **Setup** with Familiarisation `Skipped: <reason>`.

**With a spec, ticket or brief**: read every intake document in full, then ask
the same question; the recommendation is usually **Skip**, unless the intake
leaves the code's current behaviour unclear.

## The loop

Read the Stages table and do the first thing that applies, then read it again:

1. A stage is `Challenge pending` → **Challenge** it.
2. A stage is `Reopened` → it was reopened by a contradiction in this session;
   finish resolving that item, then set it back to `Closed`.
3. The next stage is `Not started` or `In progress` → invoke its skill with
   the plan path (Requirements → `tt-requirements`, Scope & Constraints →
   `tt-scope`, Approach → `tt-approach`, Technical Design →
   `tt-technical-design`). When the skill hands back, its stage is
   `Challenge pending`.
4. Technical Design is `Closed` and Whole plan is `Not started` → set Whole
   plan `Challenge pending` and challenge it with
   `tt-plan-signoff/challenge-lens.md`.
5. Whole plan is `Closed` → invoke `tt-plan-signoff` with the plan path. It
   runs the termination gate and the hand-off. Planning ends there.

After each stage is `Closed`, take a **Break point**.

## Challenge

1. **Number.** The first `CH` number is one more than the highest in the
   Challenges doc (`ids.sh defined "<challenges>" | grep '^CH'`), or `CH1`.
2. **Spawn the adversary**: one subagent, in the foreground (model and effort
   from `model-config.sh get adversary`: it weighs reasoning, so by default it
   is the strongest model, not the mechanical one). The prompt, 10–20
   lines, gives absolute paths only: "Read `<skill>/briefs/challenge.md` and
   follow it", the lens (`<stage skill>/challenge-lens.md`), the target (the
   doc and the sections or IDs the stage wrote), the plan, the Familiarisation
   doc, the Focus Log (Familiarisation stage only), the Challenges doc if it
   exists, the research files the lens names, the repo, `BASE_SHA`, the first
   `CH` number, the output path `<draft>/challenges/<stage>.md`, and
   `<common>`. **Never** pass a summary of the conversation: the adversary
   attacks what is written, which also tests whether the handover stands on
   its own.
3. **Check the output**: the file ends with `<!-- tt:end -->`, and the `CH`
   numbers start where you said. If the subagent failed, re-spawn it once on
   the same brief; if it fails again, tell the engineer and offer to do the
   brief yourself.
4. **Resolve** with the engineer, following the protocol's **Challenge
   resolution**: record, blocking and significant one at a time, minor as a
   batch, apply, record each outcome. Applying a change means following the
   owning stage's rules; for a change to a closed stage, its skill's file
   tells you what an accepted challenge changes (the "Applying" line in its
   lens).
5. **Close**: when no blocking challenge is unresolved, set the stage `Closed`
   and link its Challenges section in the Stages table. For Familiarisation,
   also set the doc's **Challenged** line.

## Break point

After a stage closes:

1. Summarise in at most five lines: what the stage settled (IDs), the
   challenges by outcome, and what comes next.
2. Give the resume command: `/tt-adversarial-plan resume <plan>`.
3. Ask with `AskUserQuestion`: **Continue now** · **Continue in a new session**
   · **Stop here** (everything is on disk). Recommend a new session once this
   conversation has run through two or more stages, or is very long.
   On **Continue in a new session**, follow `<common>/session-handoff.md` (no
   `--entry`; give `--prefix` for this plan's feature). The stage is already
   recorded in the plan's Stages table, so the session is named after the stage
   that comes next.

## Resuming

`/tt-adversarial-plan resume <plan>`, or "continue" after a stall:

1. Read the plan's Status line (`Stage`, `Next`) and Stages table.
2. Read the Tech Proposals' **At a glance**, and the Challenges doc's.
3. If a stage was `In progress`, tell the engineer in a few lines where it
   stands and invoke its skill: it carries on from `Next`.
4. If a challenge was being resolved (rows still `Open` in the stage's
   Challenges section), carry on with the first `Open` challenge.
5. If `<draft>/challenges/<stage>.md` exists but isn't in the Challenges doc
   yet, record it first. If the stage is `Challenge pending` with no file,
   spawn the adversary.
6. If the plan is signed off or in hand-off, invoke `tt-plan-signoff`; it
   resumes from `handoff.md`.

## Behavioural guardrails

- Never end planning yourself: only the engineer's explicit sign-off, in
  `tt-plan-signoff`, does.
- Never skip a stage's challenge without the engineer saying so, and record it
  in the Stages table (`Closed (challenge skipped: <reason>)`).
- Never dismiss, soften or pre-filter the adversary's challenges: every one is
  put to the engineer.
- Never let the adversary see the conversation, and never let it decide.
- Keep the Stages table and the Status line current; they are the handover.
- Never write production code. Never stage, commit or push.
