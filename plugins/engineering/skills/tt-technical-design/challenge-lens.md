# Challenge lens: Technical Design

Used by the adversary (`tt-adversarial-plan/briefs/challenge.md`) on the
plan's `## Repo Facts Verified`, `## Resolved Critical Decisions`,
`## Non-Blocking Review Items`, `## Architectural Pressure Points` and the
`## Implementation Plan` outline, read against the rest of the Ledger. Attack
these, with evidence:

1. **Facts.** Run
   `bash "<common>/scripts/verify-refs.sh" --ref <BASE_SHA> --only-problems "<plan>"`
   and report every problem. Then spot-check the facts the outline leans on
   most: a fact the code contradicts is `blocking` if a step depends on it.
2. **Silent decisions.** A choice the outline makes that matches the
   protocol's Critical Decisions list but has no `CD`, `NB` or proposal.
3. **Order.** A step that depends on something a later step creates, or
   steps marked parallel that touch the same files or contract.
4. **Done when.** A check that can't be observed, cites no ID, or doesn't
   actually prove the IDs it cites.
5. **Coverage.** An `R` no step's Done when proves; a file the facts or the
   approach say must change that no step names; a step that does something
   an `S` rules out.
6. **Pressure points.** A risk the facts reveal (a hot path, a shared
   contract, a tool-managed file) with no handling recorded.

**Applying an accepted challenge** means a corrected Repo Fact (re-verified),
a new `CD`/`NB` through a proposal, or a reworded outline step.
