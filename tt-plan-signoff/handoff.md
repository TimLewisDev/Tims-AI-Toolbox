# Hand-off: from signed-off Ledger to finished plan set

Run this after the engineer's explicit sign-off. `<skill>`, `<common>` and
`<draft>` are as in `SKILL.md`. Every step follows the output budget: the plan
is completed one part per response, never written whole.

## 1. Implementation steps (main, one step per response)

For each step in the draft's outline, in order, write the full step to
`<draft>/parts/§<N>.md`, ending with `<!-- tt:end -->`, using the step
layout in `<common>/templates/comprehensive-plan.md`. Then replace the outline
entry with it: delete the step's outline lines from the draft (a small Edit),
and when every part is complete,

```
bash "<common>/scripts/assemble.sh" insert "<plan>" "## Affected Files" "<draft>/parts/§1.md" "<draft>/parts/§2.md" …
```

If drafting a step surfaces a decision that isn't settled, stop: it goes
through a proposal and the engineer before the step is written. Never resolve
it silently, and get the engineer's sign-off on the change.

### Plan content rules

The Implementation Plan should:

- be concise and skimmable;
- contain coherent, engineer-executable steps (call them **steps**, never "work
  units", which belong to `tt-task-breakdown`);
- avoid excessive micro-steps, and avoid vague high-level statements;
- clearly identify affected systems/components, and impacted contracts,
  schemas, services or infrastructure where relevant;
- preserve sequencing where sequencing matters, and say which steps can run in
  parallel (in the Implementation Plan's opening lines);
- put every detail the implementer needs in the step: signatures, constants,
  exact strings, snippets, gotchas, precedent `path:line`;
- keep planning IDs out of snippets' code comments (no `// R14`, `(CD1)`, `L0`):
  snippets are copied into cards and then into committed code. Cite the IDs in
  the prose around the snippet instead;
- give every step a **Done when** list of observable checks, each citing the
  IDs it proves.

Do **not** include the following unless the engineer explicitly asked for them:
test plans, QA procedures, rollout plans, monitoring plans, generic
documentation tasks, project-management process, speculative future work,
unrelated refactors, architectural redesign proposals.

## 2. Closing sections (main, one response)

Write **Affected Files**, **Architectural Pressure Points** (if not already
filled) and **Open Items** into the draft with targeted Edits.

## 3. Audits (subagents, in parallel, read-only)

- `<skill>/briefs/plan-audit.md` (`model-config.sh get plan-audit`): the plan, the Challenges
  doc, `<common>`, repo and `BASE_SHA`.
- `<skill>/briefs/proposals-audit.md` (`model-config.sh get plan-audit`): the plan, the
  proposals doc and `<common>`.

Fix each defect with a targeted Edit. A defect that needs a decision goes back
to the loop: a proposal, the engineer's choice, and their sign-off on the
change.

## 4. Sign off the plan (main)

Edit the header: Status `Signed off <YYYY-MM-DD> · Revision: 1`, the
`Verified against` commit and date, the links lines (Tech Plan, Tech Proposals,
Future Iterations, Familiarisation, Challenges), and the Change Log row
(`| 1 | <date> | Signed off | — | tt-adversarial-plan |`). Delete the draft-only
**Stages** table.

## 5. Tech Plan and Future Iterations (subagents, in parallel)

- **Tech Plan:** a subagent (`model-config.sh get doc-writer`) following
  `<skill>/../tt-tech-plan/briefs/write.md`, mode `Write`, with the plan's
  path.
- **Future Iterations:** only if `<draft>/research/fi-notes.md` has entries. A
  subagent (`model-config.sh get doc-writer`) following
  `<skill>/briefs/write-future-iterations.md`, with the notes, the plan path and
  the template `<skill>/templates/future-iterations.md`. Don't blend it into the
  plan.

When both return, check the Tech Plan's IDs:

```
bash "<common>/scripts/ids.sh" xref --prefixes R,S,§,A,CD,NB "<tech plan>" "<plan>" "<proposals>" "<challenges>"
```

Report anything either subagent escalated (the Tech Plan writer reports gaps it
found in the plan; don't patch them in the Tech Plan).

## 6. Hand off

Delete `<draft>` and, if there is one, the Familiarisation draft folder
(`.tt/<Prefix> - Familiarisation/`, holding the Focus Log), and say so. Never
delete the Familiarisation or Challenges docs. Give the engineer the paths of
every document in the set (plan, Tech Plan, Tech Proposals, Future Iterations if
written, Familiarisation if any, Challenges) and the next steps:

- review the Tech Plan and the Tech Proposals;
- amend anything with `/tt-tech-plan-review <tech plan> <comprehensive tech plan>`;
- then `/tt-task-breakdown <comprehensive tech plan>`.

## Resume

If a session stops during hand-off:

- the plan still says `Draft` and `<draft>/parts/` has step files: run
  `assemble.sh status` on them (or check each ends with `<!-- tt:end -->`),
  write the missing ones, and carry on from step 1;
- the plan says `Signed off`: check which of the Tech Plan and Future
  Iterations exist, and carry on from step 5.
