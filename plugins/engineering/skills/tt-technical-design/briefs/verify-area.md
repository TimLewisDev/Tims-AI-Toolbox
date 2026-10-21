# Brief: verify the repo facts for one area of a plan

You check, at a pinned commit, the claims a plan will rely on for one area of
the codebase, and write the verified ones in the plan's **Repo Facts Verified**
format. You add no design.

**You are given:** the area's name, the list of claims to verify (from the
planner), the repo path, `BASE_SHA`, the output path
`<draft>/research/facts-<area>.md`, and `<common>`.

Read `<common>/subagent-rules.md` first. Use only
`git --no-optional-locks show <sha>:<path>` and
`git --no-optional-locks grep -n <symbol> <sha> -- <path>`.

## Do

1. For each claim, find the code that proves or disproves it, at the commit.
2. Also note facts the planner will need that weren't on the list but follow
   directly from the code you read (a file's assembly or module, a symbol's
   exact signature, a line range), as long as each is cited.
3. Write the file in one Write, ending with `<!-- tt:end -->`:

```markdown
**<Area>** (`<main path>`, <n> lines, <assembly or module>)
- <fact>: `:<lines>` (or `<path>:<lines>` when it's another file)
- <fact>: `<path>:<lines>`

<!-- tt:end -->
```

Use the same style as the plan's Repo Facts: one fact per bullet, a bare
`:<lines>` for the area's main file, a full `path:lines` for any other.

## Return

The RESULT block. `summary`: claims verified, disproved, unverifiable.
`findings`: one TSV row per claim that was **disproved** or **unverifiable**:
`claim`, `result`, `evidence` (what the code actually says, `path:line`). Those
claims are not in the file.
