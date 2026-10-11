# Template: task card

One per task, in `parts/31-<WU>-<task>.md`. The **In plain English** rules are
in `tt-common/breakdown-rules.md` ("The plain-English summary").

```markdown
### <ID> — <imperative title>

**In plain English:** <2–4 sentences, per the rules>

| | |
|---|---|
| **Executor** | Agent · Engineer |
| **Work unit** | <WU ID> |
| **Depends on** | <IDs, or —> |
| **Plan step** | <link to the plan section> |
| **Traces to** | <IDs> |

**Goal:** <one technical sentence>

**Read first**
- Plan: <section link>, for <what to take from it>
- Plan IDs: `R23` "<one-line excerpt>"; `C1` "<one-line excerpt>"
- Precedent: `<repo path>:<lines>`, for <the pattern to copy>
- Repo rules: <only the ones that apply here: a section of the agent instructions, a guard test, .editorconfig>
- API docs: <official docs matching the version the repo pins, for any API with no precedent in the repo>

**Files** (nothing outside this list)
- new `<path>`: <purpose>
- change `<path>`: <what changes>

**Steps**
1. <Concrete and ordered. Include the plan's signatures, constants and snippets, with no planning IDs in their code comments.>
2. …
3. **Confirm:** <anything the plan left open: what, how, and what to do with each answer>

**Not in this task**
- <adjacent work, naming the task that owns it, or the Non-Goal it falls under>

**Validated in:** <WU ID>, checks <which of the unit's checks cover this task>
```

Rules for writing a card:

- Put every detail the implementer needs on the card: signatures, constants,
  exact strings, snippets, gotchas, precedent file and line. Copy the plan's
  wording where it is exact. The card must never send the agent back to
  re-derive something the plan already settled.
- Copy snippets **without planning IDs in their code comments**: no task, unit,
  plan or decision IDs (`T07`, `WU3`, `R14`, `CD1`, `NB7`, `D2`) and no
  planning-level names (`L0`). Reword such a comment so it reads on its own, or
  drop it if it was only an ID, and cite the IDs in the card text instead. Code
  copied from a card ends up committed.
- Use only the plan, the verification notes and code verified at `BASE_SHA`.
  Where they don't say, write a **Confirm** step or return an escalation; never
  fill the gap yourself.
- Use the precedent `path:line` as verified (corrected references from the
  verification notes, not the plan's original line if it moved).
