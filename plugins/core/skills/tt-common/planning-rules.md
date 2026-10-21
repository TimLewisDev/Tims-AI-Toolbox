# Mandatory planning rules

This is the compact operational layer for planning skills. The longer
`planning-protocol.md` remains the explanatory reference and source for
examples.

## Stage contract

- Read the current plan Status and Stages table before acting.
- Set the active stage to `In progress` before work and keep `Next` current.
- Write each agreed item to the Consensus Ledger immediately.
- Ask one focused question at a time.
- A stage closes only after the engineer explicitly confirms its sections and
  the orchestrator resolves all blocking challenges.
- Planning ends only after explicit engineer sign-off.

## Authority and contradictions

- The existing codebase is the primary architectural constraint.
- Never fabricate consensus. Unknowns become questions.
- After every answer, cross-check the Ledger and the Familiarisation document.
- Stop forward progress when an answer contradicts an agreed item; reconcile it
  before continuing.

## Decisions and proposals

- Escalate architectural, API/contract, dependency, security, operational,
  behavioural, sequencing, extensibility and other consequential choices.
- Blocking decisions require an open proposal and engineer choice.
- Non-blocking review items may use the repository-consistent recommendation but
  must be recorded.
- Every real alternative and its outcome is recorded in Tech Proposals.

## Citing IDs

- In chat, write a plan ID the first time it appears in a message as
  `R12 (what it says)`, bare afterwards. Take the words from
  `ids.sh gloss "<doc>" R12 C16`; never write them from memory. An ID it prints
  `?` for is not defined: say so, do not guess.
- In a document, `ids.sh linkify` makes the cites links; do not hand-write them.
- In a vault, `R`, `A`, `S` and `C` bullets end with their lowercase ID as a
  block id (` ^r12`); `ids.sh anchor` checks them. See `planning-protocol.md`.

## Safety

- Do not write production code.
- Do not stage, commit, push, create branches or create worktrees.
- Do not silently change a closed stage.

## Optional knowledge

- If a stage needs background beyond these rules, check the project context
  status and route the stage/topic through `knowledge.sh get`.
- Load no more than two optional references initially.
- Treat the indexed path and source hash as routing evidence only; read the
  authoritative source before relying on a fact.
