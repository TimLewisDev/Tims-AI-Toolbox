---
name: tt-workflow-quick
description: >
  The lowest-effort route, for one small request where even tt-workflow-lite's
  conversation is more than the work needs. Given the task, it reads the code
  itself (tt-familiarise in quick mode: subagents, no questions), tells you what
  it found and what it will assume, asks for one go-ahead (Go · Adjust · Stop),
  writes a Lite Brief (tt-lite-brief in quick mode: the recommended answer is
  taken for small design choices; a Critical Decision still stops for you) and
  builds it with tt-execute-lite. Review is offered afterwards, never run. It
  uses the lite route's own documents and folder link, so any lite skill can take
  over at any point. Not for a bug (tt-workflow-lite, then tt-debug) or for a
  change of more than about six tasks. Orchestrates only: never edits documents
  (except to record your go-ahead), stages, commits or pushes. Use when the user
  wants a small change done with the least back-and-forth.
argument-hint: "[<task folder>] [<the task, in words>] | status | unlink"
metadata:
  version: "1.0"
---

# tt-workflow-quick

## Usage

```
/tt-workflow-quick <the task, in words>        # a new task: make its folder, then run
/tt-workflow-quick "<task folder>" [the task]  # link it (replacing the old link), then run or carry on
/tt-workflow-quick                             # carry on with the linked task
/tt-workflow-quick status [<folder>]           # say where it stands; run nothing
/tt-workflow-quick unlink                      # forget the link
```

A task folder holds the documents of **one** small task. The link is the lite
route's, in its own file, so it never touches the folder `tt-workflow` links, and
`tt-workflow-lite` carries a quick task on if you would rather talk it through.

## Start

Tatty, the link and where things stand were printed by a script before you were
loaded:

!`bash "${CLAUDE_SKILL_DIR}/scripts/quick.sh" start`

If there's no output above (the line still starts with `!`), run
`bash "<this skill's folder>/scripts/quick.sh" start` once. Show the robot in a
code block, once per session; add nothing to the quip. Use the script for every
fact below: `quick.sh state`, `link <folder>`, `unlink`, `new <parent> <name>`,
`confirm <focus log>`. Quote paths; they have spaces.

## How to ask

Whenever you wait on the engineer, ask with `AskUserQuestion`: two to four named
options, each a short action, the recommended first, each with a line on what it
leads to. Put what the answer depends on inside the question text. Never end a
turn on a question in prose. When the answer is words (what is wrong, what the
task is), offer the option that leads there, then ask for the words in a plain
chat question. With no `AskUserQuestion` in this agent, ask once as a lettered
list with the recommended option marked, and stop.

## 1. Pick the task

- `status`: read-only. With a folder, `quick.sh state "<folder>"` and leave the
  link as it is; without one, the linked folder. Say where it stands and stop.
- `unlink`: `quick.sh unlink`, say so, stop.
- `<folder>`: `quick.sh link "<folder>"`.
- Only words, no folder: a new task. Ask for the folder with `AskUserQuestion`
  (the parent path: offer the old link's parent and the repo's documented
  planning folder; and a name proposed from the words), then
  `quick.sh new "<parent>" "<name>"`. It creates the folder, links it and prints
  `Folder` and `Prefix`.
- Nothing given: use the link. With none (or its folder missing), ask: **Start a
  new task** (then the words, as above) · **Link an existing task folder** (then
  ask for the path).

The task is whatever follows the folder in the arguments, or the ticket or brief
document the folder already holds or the arguments name (read it; it is not a tt
document). If there is neither, ask for it in one plain question: what the
change is, and what they will see when it works. The prefix is the folder's name
unless `new` printed another.

If the words describe finding out why something fails rather than making a
change, it is a bug: ask **Run it as a bug** (hand to `/tt-workflow-lite bug`,
then stop) · **Treat it as a change**.

## 2. Read the state

`quick.sh state "<folder>"` prints one block per task: `<Prefix>: <where it
stands>` then `→ /<skill> …`. Several tasks: ask which one.

| State | Do |
|---|---|
| `No tt documents in …` | step 3 |
| exploring (quick; the go-ahead is not yet given) | step 4, reading the Focus Log; if it has no Change facts, step 3 with `resume` |
| quick exploration done | step 5 |
| lite brief written; not started · building | step 6 |
| built and validated | step 7 |
| exploring (lite; not quick) · lite exploration done · debugging · anything with a Debug Log | this task was started on the lite route: say so, point at `/tt-workflow-lite "<folder>"`, and stop |
| anything else (a plan, a breakdown, a Familiarisation doc) | the full pipeline: point at `/tt-workflow "<folder>"`, and stop |

## 3. Understand (no questions)

Run `bash "<common>/scripts/model-config.sh" stage-note tt-familiarise` (`<common>`
is `~/.claude/tt-plugins/core/skills/tt-common`, or `<this skill's folder>/../tt-common`
when the skills are linked into one folder). If it prints a line and you are not on
the model it names, say so once, in one line with the `/model` and `/effort`
commands it gives, and carry on.

Then read `<this skill's folder>/../tt-familiarise/SKILL.md` and carry out its
**Quick mode** yourself, in this conversation, as if it had been started with

`lite <the task>. Mode: lite. Pace: quick. Folder: <folder>. Prefix: <prefix>.`

(Its "How to run" and Open, Map and Trace parts, its Focus Log template and its
explore brief apply as that section says; `<skill>` there is that folder.) **Do not
start it with the Skill tool.** A skill that finishes ends the turn, and nothing
has been said to the engineer yet: this skill continues after it. It maps and
traces with subagents, writes the Focus Log, asks nothing, and is done when the
log's Change facts are filled in; then go straight on to step 4 in the same
response. If the Change facts can't be filled in, say what is missing and ask:
**Try again** · **Switch to the lite route** (`/tt-workflow-lite "<folder>"`) ·
**Stop**.

## 4. Report and ask once

Read the Focus Log's **Change facts** and focus statement (not your memory of
them) and write the report, at most 15 lines, in plain words. It goes inside the
question text, so a front end that shows only the question still shows it:

- **The change:** one sentence, in the engineer's words.
- **Attaches at:** one to three `path:line`, with what is there.
- **Copying:** `path:line` of the nearest similar code, or "a new file".
- **Done when:** the acceptance. Items the log marks `(proposed)` are yours, not
  the engineer's: say so, and that Go confirms them.
- **Built and checked by:** the build or check method (or "unknown").
- **Assuming:** what you had to take for granted, and any open choice; "nothing"
  if so.
- **After Go:** a short brief, the recommended answer taken for small design
  choices (anything that is really theirs stops and asks), then the build and
  its checks. Review is offered at the end, not run.

Then ask: **Go** (write the brief and build it; recommended) · **Adjust** (something
is wrong or missing) · **Stop** (it stays on disk).

- **Go:** `bash "<this skill's folder>/scripts/quick.sh" confirm "<focus log>"`, then step 5.
- **Adjust:** ask in a plain question what is wrong. Change the log with targeted
  Edits, or re-run the `tt-familiarise` trace for a place it missed. Report again
  in a few lines: only what changed, and the new line it gives. Ask the same
  question. After a second **Adjust**, add **Move up to the lite route**
  (`/tt-workflow-lite "<folder>"`, which keeps these documents) to the options.
- **Stop:** say it is on disk and give `/tt-workflow-quick "<folder>"` once. Stop.

## 5. Brief (no questions)

Stage note for `tt-lite-brief` as in step 3, then read `<this skill's
folder>/../tt-lite-brief/SKILL.md` and carry out its **Quick mode** yourself, with
the arguments `"<focus log>" quick`, again without the Skill tool (this skill
continues after it). It writes the brief, takes the recommended answer to small
choices and records each as "Default applied (quick)", and stops by itself at a
Critical Decision and asks it as a question list, as it always does. If the change
turns out not to be quick (more than about six tasks, or a fact it needs is
missing), say so and ask: **Move up to the lite route** (`/tt-workflow-lite
"<folder>"`) · **Stop**. When the brief is written and checked, report its Goal,
Acceptance, tasks and defaults applied in a few lines and go straight on to step 6
in the same response.

## 6. Build

Stage note for `tt-execute-lite`, then invoke `tt-execute-lite` with the Skill
tool and the arguments `"<brief>" confirmed`: step 4's Go was the confirmation,
so it doesn't ask to start. (This is the one skill you invoke rather than read:
nothing of yours comes after it but step 7.) It stops by itself at every Critical Decision and Engineer task and gives
its validation checklist when the unit is built.

## 7. Done

Say what was built and what the checks showed, from `tt-execute-lite`'s report.
The commit and the merge request are the engineer's. Ask: **Review the branch**
(invoke `tt-branch-review`) · **Done**. Review is an offer; never run it unasked.

## Guardrails

- State comes from the scripts, never from memory or a guess at the files.
- The only document you write is the go-ahead, through `quick.sh confirm`. Never
  stage, commit, push or create branches.
- One go-ahead, then no more questions of your own until the build is done. The
  skills you invoke keep their gates: a Critical Decision is never resolved for
  the engineer, here or in them.
- Don't end a turn between steps. The Focus Log written and the brief written are
  not the engineer's turn: go on to the next step in the same response. (That is
  why steps 3 and 5 read the skill's Quick mode instead of invoking it: a skill
  that finishes ends the turn.) This skill waits for the engineer in only two
  places: step 4's question, and a Critical Decision or Engineer task.
- Never present a guess as the engineer's words. Acceptance you proposed stays
  marked until they have said Go to it.
- Not quick? Say so early (a bug, more than about six tasks, a design question
  that is really theirs) and offer the lite route; do not stretch this one.
