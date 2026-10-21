# Template: Task Breakdown

The final document is assembled from parts (see `skeleton.md` for the
manifest). Each part below ends with `<!-- tt:end -->` in the draft; the
marker is stripped when the document is built.

## `parts/00-header.md`

```markdown
<header or tag block matching sibling docs>

# <Feature>: Task Breakdown

- **Comprehensive tech plan:** <link> (plan read: revision <N>, <YYYY-MM-DD>)
- **Also:** Future Iterations <link> · Tech Plan (summary) <link> · Tech Proposals <link>
- **Task Status (resume here):** <link>
- **Repo:** `<absolute path>` · base `<branch>` · working branch `<branch, or "created in T00">`
- **Plan verified against:** `<base>` @ `<short sha>` on <YYYY-MM-DD>
- **Build check:** <how the agent builds or compile-checks, from the repo's instructions or the engineer; or "engineer only">
- **ID key:** <each prefix the plan uses and where it is defined>

## Overview
<Plain English, 3–6 sentences: what's being built, in what order, and when there
is first something to see.>
```

## `parts/10-work-units.md`

```markdown
## Work Units
| ID | After this unit you can… | Tasks | Validated by | Depends on |
|---|---|---|---|---|
```

## `parts/20-task-map.md`

```markdown
## Task Map
| ID | Task | Executor | Depends on | Work unit | Plan step | Traces to |
|---|---|---|---|---|---|---|

<Which tasks can run in parallel within a unit, or "None: every unit runs its tasks in order.">

## Units and Tasks
```

## `parts/30-<WU>.md` and `parts/31-<WU>-<task>.md`

The unit block (`work-unit.md`), then its cards (`task-card.md`) in ID order.

## `parts/80-coverage.md`

```markdown
## Coverage
| Plan step | Tasks | Its "Done when" items validated in |
|---|---|---|

| Plan ID | Tasks |
|---|---|

| Affected file | Created / changed by |
|---|---|

Not covered by design: see the plan's Non-Goals (<link>).
```

## `parts/90-verification.md`

```markdown
## Plan Verification Notes
| Plan reference | Checked on `<base>` | Result | Resolution |
|---|---|---|---|
```
