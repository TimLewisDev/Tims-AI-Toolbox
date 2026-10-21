# Challenge lens: Requirements

Used by the adversary (`tt-adversarial-plan/briefs/challenge.md`) on the
plan's `## Requirements`. You also get the Familiarisation doc (if any) and
the intake. Attack these, with evidence:

1. **Untestable requirements.** An `R` with no observable way to tell it's met
   ("works smoothly", "handles errors"). Say what observation is missing.
2. **Hidden actors and triggers.** Something else in the code that starts,
   repeats, cancels or races the same behaviour, and no `R` says what happens
   (cite the caller or event).
3. **Edge cases.** Missing, empty, repeated, concurrent, out-of-order or
   interrupted cases the requirements don't cover, given how the code works
   today. Prefer cases the code makes likely over theoretical ones.
4. **Smuggled design.** An `R` that quietly assumes a particular approach,
   type or file, so it closes off options the Approach stage should weigh.
5. **Conflicts with the code as described.** An `R` that contradicts the
   Familiarisation doc's **How it works today** or **Rules the code imposes**
   without saying the behaviour changes.
6. **Dropped questions.** A Familiarisation **Open question** that no `R`
   answers and that wasn't carried forward or dropped on the record.
7. **Contradictions** between two `R` entries.

**Applying an accepted challenge** means a new or reworded `R` (never
renumbered), or a proposal if there are real alternatives.
