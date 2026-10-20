---
name: tt-plan-signoff
description: >
  Final stage of tt-adversarial-plan: the termination gate and the hand-off.
  Once every planning stage and the whole-plan challenge are closed, it
  presents the full Consensus Ledger for the engineer's explicit sign-off
  ("looks fine" doesn't count), then completes the Comprehensive Tech Plan one
  part per response (full implementation steps, Affected Files, Open Items),
  audits the plan and the Tech Proposals with subagents, marks the plan signed
  off at Revision 1, and has subagents write the brief Tech Plan and the
  Future Iterations doc. Normally run by tt-adversarial-plan; can be run on
  its own to finish, or resume finishing, a plan whose stages are closed.
metadata:
  version: "1.0"
---

# tt-plan-signoff

## Usage

```
/tt-plan-signoff <draft plan>
```

Normally invoked by `tt-adversarial-plan`.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`<skill>/../tt-common`; `<plan>` and `<draft>` are as in the protocol.

- Read `<common>/orchestration.md` and `<common>/planning-rules.md` first.
- The hand-off procedure is `<skill>/handoff.md`; its briefs are in
  `<skill>/briefs/` and the Future Iterations template in `<skill>/templates/`.
  Read each only when you reach it.
- `<skill>/challenge-lens.md` is the lens for the **whole-plan** challenge,
  which `tt-adversarial-plan` runs before this stage starts.

## Entry check

Read the plan's Status line and Stages table.

- If the plan already says `Signed off`, or `<draft>/parts/` has step files,
  go straight to the **Resume** section of `handoff.md`.
- Every stage from Requirements to Whole plan must be `Closed` (Familiarisation
  may be `Skipped`). If one isn't, say which, and point to
  `/tt-adversarial-plan resume <plan>`. Don't run the gate on an
  unchallenged plan unless the engineer explicitly says to, and record that in
  `Next`.
- Set Sign-off `In progress` and `Stage: Sign-off`.

## Termination gate

Planning ends **only** when the engineer explicitly confirms they are happy with
the full Consensus Ledger.

Before ending:

- Make sure no `Blocking decision` proposal is still `Open` (check **At a
  glance**), and no blocking challenge is unresolved (check the Challenges
  doc's rows).
- Present a sign-off summary: the count of entries in each Ledger section with
  their IDs and the words from `ids.sh gloss`, every entry added or changed since the engineer last saw it (in
  full), the proposals with their statuses, the challenges by outcome
  (accepted, rebutted, deferred, dismissed), and the draft plan's path, where
  the whole Ledger can be read. Offer to show any section in full, one per
  turn.
- Ask for explicit sign-off of the **whole** draft.

Silence, "looks fine", "sure", or your own sense that it looks complete are
**not** sufficient — require an affirmative confirmation that they are happy
with the whole thing. If any hesitation or new information surfaces, treat it
as another answer: settle it under the owning stage's rules (and the
protocol's Contradiction handling), then return to the gate.

## Output & handoff

On explicit confirmation, follow `<skill>/handoff.md`: write the full
implementation steps one per response, audit the plan and proposals with
subagents, mark the plan signed off at `Revision 1`, have subagents write the
Tech Plan and Future Iterations in parallel, and hand off. Set Sign-off
`Closed` before the Stages table is deleted (step 4 of `handoff.md`).

### Plan content rules

These are in `handoff.md` §1 and apply to every step you write: concise,
engineer-executable steps with every detail the implementer needs, no planning
IDs in snippets, a **Done when** list citing IDs, and none of the excluded
content (test plans, rollout plans and the rest) unless the engineer asked for
it.
