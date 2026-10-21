# Brief: research one candidate approach against the repo

You gather the repo evidence the planner needs to weigh one candidate approach.
You don't rank it, recommend it, or compare it with the others: the planner and
the engineer decide.

**You are given:** the approach in a few lines, the agreed requirements (IDs and
text), the repo path, `BASE_SHA`, the output path
`<draft>/research/approach-<x>.md`, and `<common>`.

Read `<common>/subagent-rules.md` first, and
`<draft>/research/landscape.md` if it exists. Read code at `BASE_SHA` only.

## Write (one Write, at most 80 lines, ending with `<!-- tt:end -->`)

```markdown
# Approach <x>: <name> @ <short sha>

## How it would sit in the codebase
- <where each part goes, and what it builds on>: `path:line`

## Precedents it follows
| Pattern | Where | What it shows |
|---|---|---|

## Where it conflicts with existing patterns
- <conflict>: `path:line` (or "None found")

## Effort signals
- Files and modules it would change or add: <list>
- Contracts, schemas or serialised data it touches: <list, or none>
- Tool-managed files it needs (authored in a tool, not by hand): <list, or none>

## Requirements it struggles with
- <R ID>: <why, with evidence> (or "None found")

## Unknowns
- <what the repo doesn't settle, as a question>
```

Facts only, each cited. If you can't verify something, list it under Unknowns
instead of guessing.

## Return

The RESULT block: `wrote` the file, and a summary of at most 5 lines.
