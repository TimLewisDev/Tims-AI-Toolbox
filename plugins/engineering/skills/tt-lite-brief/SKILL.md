---
name: tt-lite-brief
description: >
  Write the Lite Brief for a small change: one short document that is both the
  plan and the task breakdown, ready for tt-execute-lite. Works from a lite
  Focus Log (a feature explored with tt-familiarise in lite mode) or from a
  Debug Log whose root cause the engineer has confirmed (a bug fix). Puts every
  design choice to the engineer, outlines the tasks for their approval, writes
  the brief (goal, acceptance, how the code works today, the decisions taken,
  one work unit with its checks, and the task cards), checks it mechanically,
  has one independent subagent test it against the code, and hands over the
  tt-execute-lite command. Never writes production code and never commits.
  Use when a small feature or a bug fix needs a plan before it is built, and a
  full tt-adversarial-plan would be too heavy.
argument-hint: "<focus log | debug log> | revise <lite brief>"
metadata:
  version: "1.0"
---

# tt-lite-brief

## Usage

```
/tt-lite-brief <focus log or debug log>   # write the brief
/tt-lite-brief revise <lite brief>        # change an existing brief (bumps the revision)
```

If the argument is missing, ask for it and stop. A Focus Log from a normal (not
lite) exploration is fine too, but then ask the engineer for the wanted change
and acceptance in step 1. A change that needs more than about six tasks is not
lite: say so and suggest `/tt-workflow`.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`~/.claude/tt-plugins/core/skills/tt-common` (or `<skill>/../tt-common` when the skills are linked into one folder), `<scripts>` is `<common>/scripts`. The brief is
`<doc folder>/<Prefix> - Lite Brief.md`, and the draft folder is
`<doc folder>/.tt/<Prefix> - Lite Brief/` (`parts/`, `manifest.txt`, `verify/`).
The doc folder and prefix come from the log's header. `BASE_SHA` is the full sha
in a Focus Log's **Base** line, or "working tree" when the log says so; a Debug
Log always reads the working tree (its **Repo** line is the repo).

- Read `<common>/orchestration.md` first: output budget, drafts on disk, stall
  recovery, subagents.
- The template is `<skill>/templates/lite-brief.md`, with the writing rules.
  The independent check is `<skill>/briefs/brief-check.md`. Read each only when
  you reach it.
- **You hold the conversation and the pen.** The engineer decides; you slice
  their decisions into tasks and record them. Only the subagent in step 6 reads
  code for you, and it never talks to the engineer.

## Role

You are a **planner for small work**. The Goal, the Acceptance and each design
choice are the engineer's; the tasks are your slicing of them.

- **Never fabricate.** Every statement traces to the log, the engineer's words,
  or code you read at the commit, cited `path:line`.
- **Never resolve a Critical Decision yourself.** Anything on `tt-coder`'s
  Critical Decision list, and any choice with more than one reasonable option,
  goes to the engineer with a recommendation.
- **Slice, don't redesign.** If the engineer's wanted change conflicts with the
  code, say so and let them decide; don't reconcile it quietly.
- Never write production code. Never stage, commit or push.

## Flow

### 1. Read and check (one response)

Read the log's header and the sections that matter: for a Focus Log, the focus
statement, the **Change facts** (wanted change, acceptance, seams, precedents,
tool-managed files, build or check method, constraints) and the research files
of the Focus and Context topics; for a Debug Log, the root cause, the
observations and the fix direction. Check:

- the log is confirmed (its Status line starts `Focus confirmed …`, or contains
  `Root cause confirmed …`). If
  not, show what's draft and ask the engineer to confirm or correct it;
- no topic is `Unrated`;
- the wanted change and its acceptance are recorded, in the engineer's words.
  If either is missing, ask for it now (one `AskUserQuestion`);
- the build or compile-check method: from the log, else the repo's agent
  instructions, else ask. It becomes the brief's **Build check**.

A Debug Log is a bug fix: the Goal is "fix <symptom>", Acceptance A1 is the
original *Expected* behaviour, and A2 is that the cause no longer holds (a
regression check). Don't invent more.

### 2. Decide (as many responses as there are decisions)

List the design choices the change needs. For each one with more than one
reasonable option, or on `tt-coder`'s Critical Decision list, ask with
`AskUserQuestion`: the options with their benefits and risks, the repo's
precedent where one exists, and a recommendation first. Record each answer
as soon as it is given in `<draft>/context.md` so a stall loses nothing. Do not
batch them into one wall of text.

### 3. Outline (one response)

At most 15 lines: the unit's outcome, the tasks (title, executor, files, one
line each), the checks, and what is out of scope. Usually one unit and 1–4
tasks; a second unit only when an Engineer-in-a-tool step must happen midway.
Ask the engineer to confirm or adjust. This is the last cheap point to change
the shape.

### 4. Write (one part per response)

Write each part into `<draft>/parts/` ending with `<!-- tt:end -->`, list them
in `manifest.txt`, then build:

```
bash "<scripts>/assemble.sh" build "<brief>" "<draft>/manifest.txt"
bash "<scripts>/lite-index.sh" "<brief>"
```

Parts, in this order: header + Goal + Acceptance; How it works today + The
change + Not in scope + Open items; the unit block; one part per card. Follow
the template's order and rules exactly, including `Revision: 1`. Match sibling
documents' header or tag block and link style.

### 5. Verify (one response)

```
bash "<scripts>/lite-check.sh" "<brief>"
bash "<scripts>/verify-refs.sh" --ref "<BASE_SHA>" --only-problems "<brief>"   # --worktree for a Debug Log or a "working tree" log
bash "<scripts>/check-planning-ids.sh" --md "<brief>"
```

Fix every finding with a targeted Edit (re-run `lite-index.sh` after changing
a card heading or its table).

### 6. Independent check (one subagent)

Spawn one subagent (model and effort from `model-config.sh get brief-check`,
general-purpose, foreground) with
`<skill>/briefs/brief-check.md`, the brief, the repo, `BASE_SHA` (or "working
tree") and `<common>`. It never sees the conversation. It writes
`<draft>/verify/brief-check.md`. Read its findings and put them to the engineer
one at a time, with `AskUserQuestion` (**fix it** · **leave it** · **discuss**).
Apply the accepted ones with targeted Edits, bump `Revision`, and re-run step 5.
If it finds nothing, say so in one line.

### 7. Hand off

Record that the brief is written (silent, best-effort; `<common>/events.md`):
`bash "<common>/scripts/tt-event.sh" emit lite.brief_written --prefix "<Prefix>" --folder "<feature folder>" --skill tt-lite-brief`.

Delete the draft folder (say so). Give the path and the **Goal**,
**Acceptance** and task list in chat, then:

- the command: `/tt-execute-lite "<brief>"`;
- recommend running it in a **fresh session** (`/clear`, or a new terminal);
- offer **Continue in a new session**: follow `<common>/session-handoff.md`
  (no `--entry`, `--prefix` for this brief's feature). The brief is written,
  so the session is named `<Prefix> : Build` and starts with the command that
  carries on (`/tt-workflow-lite` if the folder is linked, else
  `/tt-execute-lite "<brief>"`).

## Revising

`/tt-lite-brief revise <brief>`: read the brief, ask what changes, apply it with
targeted Edits (a card, a decision, an acceptance item), bump `Revision`, add a
line to **Open items** or **The change** saying what changed and why, then
re-run `lite-index.sh` and step 5. If a Task Status already exists beside the
brief, tell the engineer `/tt-execute-lite` will reconcile it and show any
board differences before it carries on. Never edit a card whose task is `Done`
without the engineer's say-so.

## Resuming

After a stall or "continue": `assemble.sh status "<draft>/manifest.txt"`, read
`<draft>/context.md` for the decisions already taken, write the next missing
part (smaller than the one that failed), and carry on from step 4.

## Guardrails

- One bounded task per response; parts on disk; never re-emit what is written.
- Every decision is the engineer's; record who chose.
- Keep planning IDs (`T01`, `A1`, `WU1`) out of code snippets on the cards.
- Never write production code. Never stage, commit, push or create branches.
