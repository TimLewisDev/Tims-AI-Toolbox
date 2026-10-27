---
name: tt-branch-review
description: >
  Comprehensive local code review of a git branch, in any repository (GitLab,
  GitHub, Bitbucket, Azure DevOps or none). Needs only git: compares the branch
  with its base, reads the changed files for context, then reviews in parallel
  subagents for correctness, logic, security, performance, code style, test
  coverage and the repo's own conventions (plus stack-specific checks, e.g.
  Unity/C#, when the repo uses that stack), and has every serious finding
  independently challenged before it's reported. Shows the findings and writes a
  report file. Posts nothing anywhere.
metadata:
  version: "2.0"
---

# tt-branch-review

Perform a comprehensive, line-level code review of a git branch, locally. The
result is a findings list in the chat and a report file; nothing is posted to
any hosting service.

## Overview

1. Resolve the branch and the base it is compared with.
2. Gather its diff and intent.
3. Split the changed files into groups and review the groups in parallel
   subagents, each reading the full changed files.
4. Have each critical or major finding challenged by a separate subagent; drop
   the ones that don't survive.
5. Present the findings and write the report.

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`~/.claude/tt-plugins/core/skills/tt-common` (or `<skill>/../tt-common` when the skills are linked into one folder). Read `<common>/orchestration.md` first: its output
budget, subagent and concurrency rules apply. `<work>` is a scratch folder
outside the repo: `${TMPDIR:-/tmp}/tt-branch-review/<slug>/`, where `<slug>` comes
from Step 1.

Before loading stack-specific references, use
`<common>/scripts/knowledge.sh get` against the initialized project index.
Load `references/unity-csharp.md` only when the project profile or changed files
identify Unity/C#. If the index is absent or stale, inspect the reference
directly and say that routing fell back to the authoritative file.

### Usage

```
/tt-branch-review [branch] [against <base>]
```

**branch** (optional): a local or remote branch name (`feature/add-login-screen`),
or any other ref. If omitted, the **checked-out** branch is reviewed.

**against `<base>`** (optional): the branch to compare with. If omitted, the base
is found as described in Step 1.

## Preconditions

1. **A git repository** with the branch in it. The review is local: no hosting
   service, `glab`, `gh` or login is needed, and no network call is made.
2. **A base and a diff** — Step 1 stops with a message if the base can't be
   decided, the branch shares no history with it, or nothing changed.
3. **The working tree is the repo** — changed files are read from the branch's
   commit (`git show`), so the branch need not be checked out. If the repo
   isn't on disk, ask for the path.

## Steps

### 1. Resolve the branch and the base

```bash
bash "<skill>/scripts/resolve-branch.sh" [--repo <path>] [--against <base>] [<branch>]
```

It prints `branch`, `slug`, `head`, `base`, `base_how`, `base_sha`, `merge_base`,
`commits`, `files`, `diff_lines` and `dirty`. Without `--against`, the base is the
remote's default branch (`origin/HEAD`), else the only one of `main`, `master`,
`develop` and `trunk` that exists. Exit 1 prints why it can't go on:

- **Several candidate bases, or none:** ask the user which branch to compare with
  and run it again with `--against`.
- **Unknown ref, no common ancestor, or nothing changed:** tell the user and stop.

Tell the user the branch, the base and how it was chosen (`base_how`), in one
line. When the base was found rather than given (`origin-head` or
`only-candidate`), ask them to confirm it before continuing. When `dirty=yes`,
say that uncommitted changes are not part of the review.

The diff is `git diff <merge_base> <head>`: what the branch changed, not what the
base has gained since. Use the `head` and `base_sha` SHAs from here on, so the
review can't drift if a branch moves.

### 2. Gather the diff

```bash
git -C <repo> diff --no-color --name-status <merge_base> <head>   # status per file
git -C <repo> diff --no-color --numstat <merge_base> <head>       # diff lines per file
git -C <repo> diff --no-color <merge_base> <head> -- <file>       # one file's hunks
```

For each file record the **path**, whether it's **new**, **deleted**, **modified**
or **renamed** (and the old path), and its **diff line count**. Don't write the
whole diff to disk; reviewers read it per file.

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
- **Intent:** the commit subjects and bodies (`git log <base_sha>..<head>`) and
  the branch name. If they name a ticket and an issue-tracker integration (a
  Jira MCP, say) is already available, you may read it; never require one. Write
  a 3–5 line intent summary to `<work>/intent.md` for the reviewers. If the
  intent is unclear, say so there rather than guessing.

### 4. Group the files

Split the remaining files into review groups of about 400 diff lines each,
keeping files of the same module or folder together; a file larger than that
is a group on its own. Write `<work>/groups.tsv` (`group`, `file`, `diff lines`).
A branch under about 400 diff lines in total is one group.

### 5. Review the groups (subagents, in parallel)

One subagent per group, at most 4 at a time (model and effort from
`model-config.sh get branch-review-group`: correctness matters here),
brief `<skill>/briefs/review-group.md`. Give each:
the brief path, `<skill>`, `<common>` (absolute), `<work>`, its group number, the repo path,
the `head`, `base_sha` and `merge_base` SHAs, and which stack references apply.
Each writes `<work>/findings-<group>.tsv` and returns a summary.

With one group, you may do the review yourself following the same brief.

### 6. Challenge serious findings (subagents, in parallel)

For each `critical` or `major` finding, one subagent (model and effort from
`model-config.sh get branch-refute`, at most 4
at a time) following `<skill>/briefs/refute.md`, given the finding row, `<common>` (absolute),
`<work>`, the repo path and the `head`, `base_sha` and `merge_base` SHAs. It tries to prove the finding wrong. Then:

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
   recommend merging, merging with minor fixes, or changes first.

Write the final list to `<work>/final.tsv` (`n`, `file`, `line`, `severity`,
`dimension`, `summary`) and each finding's detail to `<work>/details/<n>.md`.

### 8. Present the review and write the report

Write `<work>/Review.md` with this content, and show the same in the chat:

````
## Branch <branch> vs <base> — Review

**Overall:** <merge / merge with minor fixes / changes first>

<overall summary>

### Findings (<N> total — <C> critical, <M> major, <m> minor, <n> nits)

| # | File | Line | Sev | Dimension | Summary |
|---|------|------|-----|-----------|---------|
| 1 | … | … | critical | correctness | … |

### Finding details

**[1] critical — correctness** `path/to/File.cs:42`
> Summary sentence

Detail paragraph.

```
// proposed fix, if applicable
```
````

For a long review, show the table first and the details in batches of about
ten, one batch per response; the report file always holds everything.

A suggested fix is a plain fenced block showing the replacement, and only when
the fix is mechanical and unambiguous.

### 9. Report

- How many findings, by severity, and how many the challenge step dropped
- The path of `Review.md`
- A reminder that nothing was posted and no files in the repo were changed

## Review dimensions

Apply **all** of these to every changed file, plus the repo's rules and any
stack reference. Be thorough: this is meant to replace a senior engineer's
manual review, not rubber-stamp the code. Every finding records **file**,
**line** (in the **new** file), **severity**
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

- **Read-only.** Change nothing in the repo, and post nothing anywhere. The only
  files written are in `<work>`.
- **Be concrete.** Every finding must have a specific file + line, a clear
  failure scenario, and a suggested fix. Vague "consider refactoring this"
  comments without an actionable suggestion are not acceptable.
- **No false positives.** If you are uncertain whether something is a bug vs.
  intentional design, say so in the finding detail and mark the severity `minor`
  or `nit` rather than `critical`/`major`. Do not manufacture issues to appear
  thorough.
- **Respect scope.** Only flag issues introduced or clearly worsened by this
  branch. Pre-existing problems in unchanged code are out of scope unless the
  branch made them worse.
- **Match the project style.** The repo's rules and `.editorconfig` are the
  style source of truth. Don't impose external style preferences that conflict
  with them.
- **Excluded files** — skip entirely; never comment on them.
- If you can't spawn subagents, review the groups yourself one per response,
  and challenge each serious finding yourself before keeping it.
