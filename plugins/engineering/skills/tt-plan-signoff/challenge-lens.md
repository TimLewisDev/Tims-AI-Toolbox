# Challenge lens: Whole plan

Used by the adversary (`tt-adversarial-plan/briefs/challenge.md`) on the
whole draft plan, after every stage has been challenged and closed, and before
the sign-off gate. You also get the Tech Proposals' **At a glance** and the
Challenges doc. Earlier challenges looked at one stage at a time; look for what
only shows across stages:

1. **Contradictions across stages.** An `R`, `S`, `C`, `A`, `CD` or `NB` that
   conflicts with an entry from another stage, including ones reworded after
   their stage closed.
2. **Coverage.** An `R` that no outline step's Done when proves; an outline
   step that serves no `R`; an in-scope item nothing implements.
3. **Drifted IDs.** An entry citing an ID that no longer exists, was removed,
   or now means something else (`ids.sh cited` against `ids.sh defined`).
4. **Unapplied challenges.** A challenge marked `Accepted` whose change isn't
   in the plan, or a `Deferred` one with no line in `fi-notes.md` or Open
   Items.
5. **Stale facts.** A Repo Fact or Familiarisation description that a later
   decision made untrue or irrelevant.
6. **The plan as a handover.** A place where a fresh reader (the task
   breakdown) couldn't act without the conversation: an undefined term, a
   decision recorded without its outcome, a step outline with no files.

**Applying an accepted challenge** follows the owning stage's rules, with the
protocol's Contradiction handling when it touches a closed stage.
