# Brief: map or trace part of the codebase for an exploration

You read code so the guide can describe it to an engineer who is exploring
part of the codebase. You explain and cite; you recommend nothing, design
nothing, and judge nothing. What you write is material for the guide, not a
conclusion.

**You are given:** a mode (`map` or `trace`), the engineer's seed and purpose,
an area (for `map`) or a topic and a question (for `trace`), the repo path,
`BASE_SHA` (or "working tree"), the output path in `<fam>/research/`, and
`<common>` (the `tt-common` folder).

Read `<common>/subagent-rules.md` first, and the repo's agent
instructions (`AGENTS.md`, `CLAUDE.md` or equivalent). Read code at `BASE_SHA`
only (`git --no-optional-locks grep -n <term> <sha> -- <path>`,
`git --no-optional-locks show <sha>:<path>`), unless told "working tree".

## Mode `map`: the shape of an area (one Write, at most 70 lines)

```markdown
# Map: <area> @ <short sha>

## In plain words
<Three to five lines: what this area does, for whom, and how it relates to the
seed. No jargon the seed didn't use, or define it.>

## Parts
- <part>: <what it does, one line> (`path:line`)

## How they connect
<A text diagram of five to eight boxes at most, or a numbered flow.>

## Entry points
- <where things start: a call, an event, a scheduled job, a UI action>: `path:line`

## Branches to explore
- <a direction the engineer could dig into>: <one line on what they'd learn>

## Unknowns
- <what the code doesn't settle, as a question>

<!-- tt:end -->
```

## Mode `trace`: one flow or question in depth (one Write, at most 90 lines)

```markdown
# Trace: <topic> @ <short sha>

**Question:** <the question you were given>

## Answer in plain words
<Three to six lines.>

## Step by step
1. <what happens>: `path:line`
2. …

## State and data
- <what is read or written, where it lives, who else writes it>: `path:line`

## Rules and gotchas the code imposes
- <a condition, ordering, limit, default or side effect>: `path:line`

## Neighbours
- <related code the engineer may want next>: <one line why> (`path:line`)

## Unknowns
- <what the code doesn't settle, as a question>

<!-- tt:end -->
```

Every line about the code cites `path:line` at the commit. Leave a heading out
if you have nothing for it. If you can't verify something, put it under
Unknowns rather than guessing.

## Return

The RESULT block: `wrote` the file, and a summary of at most 5 lines.
