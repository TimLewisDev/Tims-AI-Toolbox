# Template: Tech Plan


```markdown
<header or tag block matching the comprehensive plan>

# <Feature>: Tech Plan

> A short summary of the <Comprehensive Tech Plan link> for review. The
> comprehensive plan is the authority. To change anything, use
> `/tt-tech-plan-review`.

- **Mirrors revision:** <N> of the comprehensive plan · synced <YYYY-MM-DD, the day this doc was last written or updated>
- **Tech Proposals:** <link> · **Future Iterations:** <link>
- **Ticket:** <issue key, if the comprehensive plan has one> · **Base branch:** `<base>`

## In one paragraph
<3–5 sentences: what is being built, for whom, what it lets them do, and the
overall approach.> (<IDs>)

## Scope
**In**
- <grouped capability> (<R IDs>)

**Out**
- <non-goal> (<S IDs>)

## Key decisions
| ID | Decision | Why | Options |
|---|---|---|---|
| A1 | <one line> | <one line> | P1 |
| CD1 | <one line> | <one line> | P4 |

## How it will be built
**Before step 1:** <prerequisites, or "nothing">

| Step | What | Done when |
|---|---|---|
| §1 | <one line> | <short> |

<One line on order, and which steps can run in parallel.>

## Footprint
- **New:** <one line> (Affected Files)
- **Changed:** <one line, or "no existing file"> (Affected Files)
- **Ships to players:** <yes / no, and why> (<C IDs>)

## Risks to watch
- <one line> (Pressure Points: <area>)

## Open for review
| Proposal | Question | Status | Applied for now |
|---|---|---|---|
| P6 | <question> | Default applied | <option> |

<Or "Nothing open.">
```

Keep **Risks to watch** to 3–5 lines, picking the pressure points a reviewer
most needs to know about. **Open for review** follows step 2 of the Procedure.
