# Challenge lens: Familiarisation

Used by the adversary (`tt-adversarial-plan/briefs/challenge.md`) on a
Familiarisation doc. You also get the Focus Log. Attack these, with evidence:

1. **Facts.** Pick the claims the rest of the doc leans on (the flow in **How
   it works today**, **Data and contracts**, **Rules the code imposes**) and
   check them at the commit. A claim the code contradicts, or a cite that
   points at the wrong thing, is at least `significant`.
2. **Fidelity to the engineer.** Compare the doc's question, **In short** and
   the topics it covers with the Focus Log's focus statement, the engineer's
   quoted words and the ratings. Flag a Parked topic written up, a Focus topic
   left thin, or a focus statement reworded so it means something else.
3. **Narrowed too early.** Look for code that affects the Focus but never came
   up: other callers or writers of the same state, configuration or serialised
   data that changes the behaviour, a second path that does the same job,
   tests that pin the behaviour. Name it, cite it, and say why it matters.
4. **Missing context.** A reader who wasn't in the conversation can't follow a
   section without something the doc leaves out.
5. **Open questions.** One the code actually answers (give the answer and the
   cite), or an obvious one missing given the purpose.

**Applying an accepted challenge** means a targeted Edit to the
Familiarisation doc, with a cite (and the Focus Log, if a rating or the focus
statement changes). The doc is a description, so there is no Ledger entry to
change.
