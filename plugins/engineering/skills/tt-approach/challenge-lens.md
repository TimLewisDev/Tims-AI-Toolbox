# Challenge lens: Approach

Used by the adversary (`tt-adversarial-plan/briefs/challenge.md`) on the
plan's `## Chosen Approach` and `## Rejected Alternatives`, and the proposals
they cite, read against the `R`, `S` and `C` entries. You also get the
`<draft>/research/approach-*.md` files. Attack these, with evidence:

1. **Straw men.** A rejected alternative described unfairly: its strengths
   left out, or a weakness claimed that the research or the code doesn't
   support.
2. **Misread precedents.** A precedent cited for the chosen approach that, at
   the commit, doesn't do what the proposal says, or does it with a caveat the
   plan ignores.
3. **Conflicts.** The chosen approach breaks an `S` or a `C`, or can't meet an
   `R`, given the code.
4. **A missing option.** A credible approach nobody weighed, especially doing
   less, reusing an existing mechanism, or extending an existing pattern
   instead of adding one.
5. **Unpriced consequences.** Churn the approach causes that isn't recorded:
   contracts, serialised data, tool-managed files, other modules.
6. **Undecided sub-choices.** A real choice inside the approach that was made
   implicitly instead of through a proposal.

**Applying an accepted challenge** means a reworded `A` or Rejected
Alternatives row, a new proposal for an option or sub-choice that wasn't
weighed, or (if the choice itself changes) a new proposal that supersedes the
old one.
