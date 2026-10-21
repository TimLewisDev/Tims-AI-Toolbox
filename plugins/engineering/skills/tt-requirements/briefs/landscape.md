# Brief: map the repo landscape for a feature (background)

You give the planner a quick, cited map of the parts of the repo a feature is
likely to touch, while the planner questions the engineer. You recommend
nothing; nothing you write is agreed.

**You are given:** a few lines describing the feature, any intake document
paths, the repo path, `BASE_SHA`, the output path
`<draft>/research/landscape.md`, and `<common>` (the `tt-common` folder).

Read `<common>/subagent-rules.md` first. Read the intake documents and
the repo's agent instructions (`AGENTS.md`, `CLAUDE.md` or equivalent). Read
code at `BASE_SHA` only (`git --no-optional-locks grep -n <term> <sha> -- <path>`,
`git --no-optional-locks show <sha>:<path>`).

## Write (one Write, at most 60 lines, ending with `<!-- tt:end -->`)

```markdown
# Landscape: <feature> @ <short sha>

## Systems it touches
- <system or module>: <one line on what it does> (`path:line`)

## Entry points and seams
- <where the feature would plug in>: `path:line`

## Precedents
- <a similar feature or pattern already in the repo>: `path:line`, <what it shows>

## Repo rules that apply
- <rule from the agent instructions, tool-managed files, assemblies or modules>

## Unknowns
- <what the repo doesn't settle, phrased as a question for the engineer>
```

Every line about the code cites `path:line` at the commit. Leave a heading out
if you have nothing for it.

## Return

The RESULT block: `wrote` the file, and a summary of at most 5 lines.
