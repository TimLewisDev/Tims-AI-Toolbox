# Brief: read a plan set and index it for a review session

You read a whole plan set so the review conversation doesn't have to, and write
an index it can navigate by. Read-only, except for the index file. You judge
nothing about the plan's quality.

**You are given:** the paths you have (comprehensive plan and/or Tech Plan),
and `<common>` (the `tt-common` folder).

Read `<common>/subagent-rules.md` first.

## Do

1. Find the set: the comprehensive plan (from the Tech Plan's header link if
   needed), the Tech Plan, the Tech Proposals, Future Iterations,
   Familiarisation and Challenges (header links, or same folder and prefix),
   and, if they exist beside the plan, the Task Breakdown and Task Status. If
   the comprehensive plan can't be found, return `status: blocked`.
2. Work out:
   - **sync:** the Tech Plan's `Mirrors revision` against the plan's `Revision`;
   - **plan:** name, Revision, Status line (signed off or last amended, date);
   - **open proposals:** every `Open` or `Default applied` proposal, from **At a
     glance** (`md-section.sh get <proposals> "## At a glance"`);
   - **breakdown:** if there is one, progress from the Task Status header and
     boards, which tasks and units are `Implemented` or `Done`, and which plan
     IDs each task card traces to (from the Task Map's Traces to column); if
     there's a breakdown but no Task Status, say so;
   - **base branch** from the plan's header.
3. Build the index with the scripts, not by hand:
   `md-section.sh index` on every document, `ids.sh defined` on the plan and
   the proposals, `ids.sh cited` on the Tech Plan.
4. Write `<plan folder>/.tt/<Prefix> - Review/index.md`:

```markdown
# Review index: <Prefix> @ rev <N>

## Orientation
- Plan: <path> · rev <N> · <status line>
- Tech Plan: <path> · mirrors rev <M> · <in sync | out of sync>
- Proposals: <path> · open: <P IDs with status, or none>
- Future Iterations: <path or none>
- Familiarisation: <path or none> · Challenges: <path, counts by outcome, or none>
- Breakdown: <path, progress, or none> · Task Status: <path or none>
- Base branch: `<base>`

## IDs
| ID | Doc | Line | Excerpt |
|---|---|---|---|

## Breakdown traces
| Task | Unit | Status | Traces to |
|---|---|---|---|

## Headings
### <doc name>
<md-section.sh index output>
```

Write it in parts if it's long (the header and Orientation first, then append
the tables).

## Return

The RESULT block: `wrote` the index path, and a `summary` of at most 5 lines
with the orientation facts.
