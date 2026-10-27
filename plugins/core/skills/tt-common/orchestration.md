# Orchestration rules for tt-* skills

Read this before running any `tt-*` skill that writes a large document or
spawns subagents. These rules exist because a single model response has a
hard time limit (in practice, a few minutes, and thinking counts towards it),
and because one ever-growing context is slow and fragile. A response that
tries to write a whole document, or think through a whole plan, at once can be
cut off; retrying it fails the same way.

`<common>` below means the tt-common folder. It belongs to the core plugin,
so a skill in another plugin (engineering, ...) finds it at
`~/.claude/tt-plugins/core/skills/tt-common`, a pointer core's SessionStart
hook keeps. If that folder is missing, tell the engineer to install core and
restart Claude Code. A core skill, or any skill when the skills are linked
into one folder, finds it at the skill's own directory with `/../tt-common`
appended (`${CLAUDE_SKILL_DIR}/../tt-common` in Claude Code). Scripts are
`<common>/scripts/<name>.sh`.

## 1. Output budget

- **One bounded task per response.** At most about 6k tokens of visible output,
  or about 200 lines of document, and one bounded piece of reasoning:
  "decompose §3", not "decompose the plan"; "write the cards for WU2", not
  "write the breakdown".
- **Never write a large document in one tool call.** Build it from part files
  (section 2) and stitch them with `assemble.sh`, or write a skeleton and
  append one section per response.
- **Never re-emit content that is already on disk.** Point at it, stitch it,
  or Edit the lines that change.
- **Show deltas in chat, not whole documents.** Give the path, and show a full
  section only when the engineer asks, one section per turn.

## 2. Drafts on disk

A long write keeps a draft folder beside its document:

```
<doc folder>/.tt/<Prefix> - <Doc>/
  context.md      the run's facts: paths, revision, BASE_SHA, repo rules, line ranges
  manifest.txt    the final document's part files, in order (one relative path per line)
  parts/          one file per section or card; each ends with the line <!-- tt:end -->
  verify/         subagent verification output
  research/       subagent research output
```

- A part is **complete** only when its last non-blank line is
  `<!-- tt:end -->`. `assemble.sh status <manifest>` lists parts as
  `complete`, `incomplete` or `missing`.
- `assemble.sh build <out> <manifest>` writes the final document (markers
  stripped). It refuses while any part is missing or incomplete.
- Dot-folders are hidden in Obsidian. Delete the draft folder once the final
  document is written and audited, and say so.

## 3. Stall recovery

After a stall, a connection error, or "continue" following one: **never retry
the same output.** Check what exists on disk (`assemble.sh status`, the
draft's header lines), and write the next missing part, smaller than the one
that failed. If one part keeps failing, split it.

On a fresh session, the draft folder and the documents are the state. Read
them; don't regenerate what is already complete.

## 4. Subagents

Spawn subagents for reading, verifying, auditing and writing from an approved
skeleton. Keep every decision, every question to the engineer, and all design
writing in the main agent: only it holds what was agreed.

**The prompt** is short (10–20 lines) and gives:

- the absolute path of the brief to follow ("Read `<path>` and follow it");
- absolute paths of `<common>/scripts`, the documents, the repo and the draft
  folder (subagents don't get `${CLAUDE_SKILL_DIR}`);
- the pinned `BASE_SHA` and any IDs or line ranges it works on.

Never paste a brief, a whole plan or a whole card into the prompt; the
subagent reads them from disk.

**What every subagent must do** is in
[`subagent-rules.md`](subagent-rules.md): never talk to the engineer, never
decide a Critical Decision, no git writes, no planning IDs in code, one part
per Write, details in files, and the RESULT block. Briefs point subagents at
that file, not at this one, so they read only the rules that apply to them.
When you read a RESULT, expect that block.

**Concurrency.**

- At most 4 subagents at once; at most 2 that change code.
- Use parallel foreground calls for fan-out. Waiting on subagents doesn't count
  against the main agent's response time. Use background subagents only to
  overlap with talking to the engineer.
- On a rate-limit or 5xx error, carry on serially. On a budget or quota error,
  stop and tell the engineer.
- Re-spawn a failed subagent for its missing parts only.

**Models.**

- Each spawn names a **role** (`adversary`, `coder`, `explore`, …). Before
  spawning, run `bash "<common>/scripts/model-config.sh" get <role>`; it prints
  `model=<m> effort=<e>` for the engineer's active `tt-config` mode. Pass the
  model and the effort to the Agent tool as given; a `-` means leave that one
  out and let the subagent inherit the session's. If the script fails, leave
  both out.
- The defaults put the strongest model on the few passes that judge or attack
  reasoning (the adversary, the MR refute pass) and Sonnet on everything else:
  verifying, auditing, mapping, writing from an approved skeleton and
  implementation. The engineer changes them with `tt-config`; never hard-code a
  model in a skill. The roles are listed in `model-roles.tsv`.
- The models on offer are the runnable ones of the connected LLM tools
  (`tt-connections`' `llms.sh`); today those are Claude's. A model that is
  listed but not runnable is never passed to the Agent tool.
- If a subagent on the chosen model fails to start, re-run the same brief
  without a model (the session's).

## 5. Git

- The orchestrator runs `git fetch` once per run and pins
  `BASE_SHA=$(git rev-parse origin/<base>)`. Subagents never fetch.
- No `tt-*` skill stages, commits, pushes, or creates branches or worktrees.

## 6. Scripts

```
bash "<common>/scripts/<name>.sh" -h
```

Always quote paths: document names contain spaces. Exit `0` clean, `1`
findings, `2` usage or environment error. Script output is meant for the
agent; summarise it for the engineer.

## 7. Agents without subagents

If you can't spawn subagents, do each brief yourself, in the same order, still
one part per response. If `${CLAUDE_SKILL_DIR}` isn't expanded, `<common>` is
`../tt-common/` relative to the skill's own `SKILL.md` when the skills are
linked into one folder, else the core pointer above.
