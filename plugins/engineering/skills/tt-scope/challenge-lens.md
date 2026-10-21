# Challenge lens: Scope & Constraints

Used by the adversary (`tt-adversarial-plan/briefs/challenge.md`) on the
plan's `## Scope / Non-Goals` and `## Constraints`, read against
`## Requirements`. You also get the Familiarisation doc (if any). Attack
these, with evidence:

1. **Bigger than it looks.** An in-scope item whose footprint in the code is
   much larger than the plan implies: many callers, serialised data,
   tool-managed files, other teams' modules (cite them).
2. **Non-goals the requirements need.** An `S` that rules out something an
   `R` can't be met without.
3. **Unrecorded constraints.** Rules the repo imposes that the feature will
   hit but no `C` records: files owned by a tool, module or assembly
   boundaries, serialised-data or save compatibility, platform limits, branch
   rules in the agent instructions.
4. **"Smallest shippable" that isn't.** A claimed minimum that still carries
   optional work, or one so small it doesn't meet the requirements.
5. **Unsettled boundaries.** A Familiarisation **Not covered** topic, or a
   neighbour the requirements touch, that is neither in scope nor an `S`.
6. **Constraints that contradict each other,** or contradict an `R`.

**Applying an accepted challenge** means a new or reworded `S` or `C`, a line
in `fi-notes.md` for newly excluded work, or a proposal if there are real
alternatives.
