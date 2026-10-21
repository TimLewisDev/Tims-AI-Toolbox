---
name: tt-mr-review
description: >
  Comprehensive code review of a GitLab MR. Fetches the diff, reads changed
  files for context, then reviews in parallel subagents for correctness, logic,
  security, performance, code style, test coverage and the repo's own
  conventions (plus stack-specific checks, e.g. Unity/C#, when the repo uses
  that stack), and has every serious finding independently challenged before
  it's reported. Posts inline comments on specific lines and a summary comment.
  Gated: presents findings for approval before posting anything.
metadata:
  version: "1.0"
---

# tt-mr-review

Perform a comprehensive, line-level code review of a GitLab Merge Request and
(with approval) post the findings as inline comments.

## Overview

1. Resolve the target MR and gather its diff and context.
2. Split the changed files into groups and review the groups in parallel
   subagents, each reading the full changed files.
3. Have each critical or major finding challenged by a separate subagent; drop
   the ones that don't survive.
4. Present all findings to the user for approval.
5. Post approved findings as GitLab inline comments, plus an overall summary.

> All comment posting is **gated on explicit user approval**. Nothing is posted
> without confirmation.

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`~/.claude/tt-plugins/core/skills/tt-common` (or `<skill>/../tt-common` when the skills are linked into one folder). Read `<common>/orchestration.md` first: its output
budget, subagent and concurrency rules apply. `<work>` is a scratch folder
outside the repo: `${TMPDIR:-/tmp}/tt-mr-review/<mr>/`.

Before loading stack-specific references, use
`<common>/scripts/knowledge.sh get` against the initialized project index.
Load `references/unity-csharp.md` only when the project profile or changed files
identify Unity/C#. If the index is absent or stale, inspect the reference
directly and say that routing fell back to the authoritative file.

### Usage

```
/tt-mr-review [mr]
```

**MR** (optional): an **MR number** (e.g. `8421`) or a **source branch** (e.g.
`feature/add-login-screen`). If omitted, resolves from the **current branch**.
If the match is ambiguous, ask the user.

## Preconditions

1. **GitLab auth** — `glab auth status` or GitLab MCP must be available. **FAIL** if not.
2. **MR resolvable** — a single open (or recently merged) MR can be found. **FAIL** if none or ambiguous — ask the user.
3. **Repo is present** — the working tree must exist so changed files can be
   read for full context (not just the diff). If the repo is absent, reviewers
   work from the diff only; note this limitation.

## Steps

### 1. Resolve the MR

```bash
glab mr view <mr>                                                   # by number
glab mr list --source-branch "$(git rev-parse --abbrev-ref HEAD)"   # by current branch
```

Record the **MR number**, **project path** (URL-encoded, e.g.
`my-group%2Fmy-project`), **title**, **description**, **source** and **target
branch**, **head SHA** and **author**. `git fetch` once so `origin/<source>`
and `origin/<target>` are current.

### 2. Fetch the diff

Prefer the GitLab API, so the review targets exactly what GitLab shows, and
page through it all:

```bash
glab api --paginate "projects/<url-encoded-path>/merge_requests/<mr>/diffs?per_page=100" > "<work>/diffs.json"
# or, with the branch available locally:
git diff origin/<target>...origin/<source> > "<work>/mr.diff"
```

For each file record the **path**, **old/new SHA**, **diff hunks** (with line
numbers), **diff line count**, and whether it's **new**, **deleted** or
**modified**.

### 3. Rules, exclusions and intent (main)

- **Repo rules:** read the repo's agent instructions (`AGENTS.md`, `CLAUDE.md`
  or equivalent), `.editorconfig`, and any review checklist they point to.
  They are the source of truth for style and conventions.
- **Stack references:** if the repo uses a stack with a reference in
  `<skill>/references/`, reviewers load it too. Currently:
  `unity-csharp.md` when `ProjectSettings/ProjectVersion.txt` exists.
- **Exclude** (don't open, don't comment): binaries (images, models, audio,
  archives, `*.dll`, `*.exe`, `*.so`, `*.a`), generated files (marked
  auto-generated in their header, or listed as generated or tool-managed in the
  repo's rules), lock files, vendored third-party code, and anything the stack
  reference lists.
- **Intent:** the MR description, and the linked issue if the MR references one
  and an issue-tracker integration (a Jira MCP, `glab issue`) is available. Write
  a 3–5 line intent summary to `<work>/intent.md` for the reviewers.

### 4. Group the files

Split the remaining files into review groups of about 400 diff lines each,
keeping files of the same module or folder together; a file larger than that
is a group on its own. Write `<work>/groups.tsv` (`group`, `file`, `diff lines`).
An MR under about 400 diff lines in total is one group.

### 5. Review the groups (subagents, in parallel)

One subagent per group, at most 4 at a time (model and effort from
`model-config.sh get mr-review-group`: correctness matters here),
brief `<skill>/briefs/review-group.md`. Give each:
the brief path, `<skill>`, `<common>` (absolute), `<work>`, its group number, the repo path, the
target and source branches, the head SHA, and which stack references apply.
Each writes `<work>/findings-<group>.tsv` and returns a summary.

With one group, you may do the review yourself following the same brief.

### 6. Challenge serious findings (subagents, in parallel)

For each `critical` or `major` finding, one subagent (model and effort from
`model-config.sh get mr-refute`, at most 4
at a time) following `<skill>/briefs/refute.md`, given the finding row, `<common>` (absolute) and
`<work>`. It tries to prove the finding wrong. Then:

- **refuted:** drop the finding (keep a note in `<work>/dropped.tsv`);
- **confirmed:** keep it;
- **uncertain:** keep it, say so in its detail, and lower it to `minor`.

### 7. Synthesise findings (main)

1. **De-duplicate** findings that are the same issue in different locations,
   into one finding with several locations.
2. **Rank** by severity: `critical` → `major` → `minor` → `nit`.
3. **Prune nits** that are purely stylistic and consistent with the rest of the
   file. The bar for a nit is that a reasonable reviewer would actually mention
   it.
4. **Write an overall summary**: 2–5 sentences covering the nature of the
   change, your overall assessment, the most important issues, and whether you
   recommend approving, approving with minor fixes, or requesting changes.

Write the final list to `<work>/final.tsv` (`n`, `file`, `line`, `severity`,
`dimension`, `summary`) and each finding's comment body to
`<work>/bodies/<n>.md`.

### 8. Present findings for approval

Present the full review **before posting anything**:

```
## MR !<number> — Review: <title>

**Overall:** <approve / approve with minor fixes / request changes>

<overall summary>

### Findings (<N> total — <C> critical, <M> major, <m> minor, <n> nits)

| # | File | Line | Sev | Dimension | Summary |
|---|------|------|-----|-----------|---------|
| 1 | … | … | critical | correctness | … |

### Finding details

**[1] critical — correctness** `path/to/File.cs:42`
> Summary sentence

Detail paragraph.

```suggestion
// proposed fix
```
```

For a long review, show the table first and the details in batches of about
ten, one batch per response. Then ask:

- "Post all findings as inline comments? (y / n / list numbers to skip)"
- "Post the overall summary comment? (y / n)"

Respect partial approvals (e.g. "post 1, 3, 5 but skip the nits").

### 9. Post approved findings

Comment bodies use GitLab-flavoured Markdown:

```markdown
**[<severity>] <dimension>**

<detail paragraph>

```suggestion
<replacement code, if applicable>
```
```

A **suggestion block** must be a drop-in replacement for the line(s) it anchors
to — GitLab renders it as a one-click apply. Only use one when the fix is
mechanical and unambiguous.

Post with the script, which uses the merge base, source head and target head as
the position SHAs, and falls back to a general note when an inline note fails:

```bash
bash "<skill>/scripts/post-notes.sh" --project <url-encoded-path> --mr <mr> \
  --target <target> --source <source> [--summary "<work>/summary.md"] \
  "<work>/approved.tsv" "<work>/bodies"
```

`approved.tsv` holds the approved rows of `final.tsv`. The script prints one
line per finding: posted inline, posted as a general note (fallback), or
failed with the error.

### 10. Report

- How many findings were posted vs. skipped
- Any findings that failed to post (with error), and any that fell back to a
  general note
- The MR URL so the user can see the comments in context
- A reminder that approving the MR is a separate step in the GitLab UI

## Review dimensions

Apply **all** of these to every changed file, plus the repo's rules and any
stack reference. Be thorough: this is meant to replace a senior engineer's
manual review, not rubber-stamp the code. Every finding records **file**,
**line** (in the **new** file, for inline posting), **severity**
(`critical` / `major` / `minor` / `nit`), **dimension**, **summary** (one
sentence), **detail** (why it matters, a concrete scenario where it breaks or
degrades) and **suggestion** (a specific fix, with a snippet where helpful).

- **Correctness & logic:** off-by-one errors and wrong boundaries; null or
  uninitialised references; races in async, concurrent or multi-threaded code;
  wrong state-machine transitions or missing guards; wrong maths (sign, axis,
  units, coordinate space); missing returns or fall-through; methods that
  mutate data they were only meant to read; lifecycle and initialisation-order
  bugs.
- **Security:** user-controlled data reaching shell commands, SQL, file paths
  or URLs unsanitised; hard-coded credentials, keys or secrets (even in
  comments); overly permissive file or directory access; unsafe deserialisation
  of untrusted data; unintended public exposure of internals.
- **Performance:** allocations and expensive lookups in hot paths; repeated
  work that should be cached; O(n²) or worse over large collections; blocking
  calls on latency-sensitive threads; resources created and destroyed where
  they should be pooled.
- **Code style & maintainability:** violations of `.editorconfig` and the
  repo's conventions visible in the diff; unexplained magic numbers or strings;
  dead code; very long methods (over 80 lines is a smell; over 150 a flag);
  deep nesting that early returns would flatten; misleading names; comments
  that are actively misleading; patterns inconsistent with adjacent code;
  `TODO`/`FIXME` without an issue reference.
- **Test coverage:** new public methods or complex paths with no test; changed
  behaviour whose existing tests weren't updated; assertions that are trivially
  true; tests the framework won't run (missing attribute or registration).

## General rules

- **Never post without approval.** All inline comments and the summary note are
  gated on Step 8 confirmation. Honour partial approvals.
- **Be concrete.** Every finding must have a specific file + line, a clear
  failure scenario, and a suggested fix. Vague "consider refactoring this"
  comments without an actionable suggestion are not acceptable.
- **No false positives.** If you are uncertain whether something is a bug vs.
  intentional design, say so in the finding detail and mark the severity `minor`
  or `nit` rather than `critical`/`major`. Do not manufacture issues to appear
  thorough.
- **Respect scope.** Only flag issues introduced or clearly worsened by this MR.
  Pre-existing problems in unchanged code are out of scope unless the MR made
  them worse.
- **Match the project style.** The repo's rules and `.editorconfig` are the
  style source of truth. Don't impose external style preferences that conflict
  with them.
- **Excluded files** — skip entirely; never comment on them.
- **Don't re-review** findings the user explicitly skips — if they decline to
  post a finding, treat it as accepted and move on.
- If you can't spawn subagents, review the groups yourself one per response,
  and challenge each serious finding yourself before keeping it.
