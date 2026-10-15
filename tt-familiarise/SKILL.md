---
name: tt-familiarise
description: >
  Conversational exploration of a part of the codebase. Asks what the engineer
  wants to find out, maps relevant code with read-only subagents, explains
  findings in plain words with path:line references, then asks where to dig
  next, one question at a time, until the essence of their interest is clear.
  Keeps an on-disk Focus Log of every topic and the engineer's interest
  (Focus, Context or Parked), so a fresh session can resume or document it.
  Never designs, recommends or plans. Hands off to tt-familiarisation-doc
  for a standalone write-up or the foundation for tt-adversarial-plan.
  In lite mode (a small change), also records the change facts needed for a
  brief and hands the log to tt-lite-brief instead.
  Use when the engineer wants to explore, understand or get familiar with how
  part of the codebase works.
metadata:
  version: "1.0"
---

# tt-familiarise

## Usage

```
/tt-familiarise <what you want to explore>
/tt-familiarise lite <the small change you want to make>
/tt-familiarise resume <focus log>
```

With no seed, ask one open question: "What would you like to explore?"

`lite` (or "Mode: lite" in the invoking prompt, as `tt-workflow-lite` gives it, or
`**Mode:** lite` in the header of the Focus Log being resumed) is for a small change that will go to `tt-lite-brief` rather than a full plan:
read **Lite mode** below.

## How to run this skill

`<skill>` is this skill's folder (`${CLAUDE_SKILL_DIR}`), `<common>` is
`<skill>/../tt-common`, and `<fam>` is the draft folder
`<doc folder>/.tt/<Prefix> - Familiarisation/`.

- Read `<common>/orchestration.md` first: the output budget, drafts on disk,
  stall recovery, subagents and scripts apply throughout.
- The Focus Log template is `<skill>/templates/focus-log.md`, the subagent
  brief `<skill>/briefs/explore.md`. Read each only when you reach it.
- **You hold the conversation.** Subagents only read code. They never talk to
  the engineer, and what they find is material for you to describe, not
  conclusions.
- If you can't spawn subagents, do each brief yourself, still one bounded read
  per response.

## Where this fits

```
tt-familiarise ──► Focus Log ──► tt-familiarisation-doc ──► Familiarisation doc
                                                                   ├─ read on its own, or
                                                                   └─ tt-adversarial-plan (stage 0 of planning)

lite mode:  tt-familiarise ──► Focus Log + Change facts ──► tt-lite-brief ──► tt-execute-lite
```

## Lite mode

For a small change (one request, a few files), when the invoking prompt says
`Mode: lite` or the engineer ran `/tt-familiarise lite …`. A resumed log whose header
has `**Mode:** lite` is in lite mode too, whatever the resuming prompt says. Read the "Lite mode"
appendix of `<skill>/templates/focus-log.md` when you create the log. The Role,
How to talk and Flow below all still apply; these are the differences:

- **Open.** The purpose is "to change it": don't ask. Take the folder and prefix
  from the prompt (ask only if they aren't given). Put `**Mode:** lite` in the
  log's header.
- **Map.** At most 2 mapping subagents, and 1 when the seed names a single
  place.
- **Ask for the change early.** Right after the map, ask in one open question
  what change they want and what they will see when it works. Record both
  verbatim under **Change facts**. That is the engineer's wish, not your design:
  if they ask how it could be built, show how the existing code does the
  nearest similar thing (cited) and record the open choices under **Open
  choices** for `tt-lite-brief`; never recommend one.
- **Dig toward the change.** As you learn them, note under **Change facts** the
  seams (where a change would attach), the precedents to copy, files that a
  tool owns, how the code is built or compile-checked (the repo's agent
  instructions, else ask), and constraints, each cited `path:line`.
- **Boil down** after two or three Dig turns, then every three. Stop digging
  when the Change facts hold: the wanted change, at least one acceptance
  statement, the seams (or "a new file"), and the build or check method.
- **Close.** Show the focus statement, the Focus topics and the Change facts for
  confirmation (the same rule: silence is not confirmation). Then offer, with
  `AskUserQuestion`: **write the lite brief now** (invoke `tt-lite-brief` with
  the Focus Log path) · **write it in a new session** (follow
  `<common>/session-handoff.md`; the session starts the lite brief) ·
  **stop here**. Don't offer
  `tt-familiarisation-doc` unless the engineer asks.

## Role

You are a **guide**. The engineer arrives with a loose question; your job is to
help them find the specific thing they actually want to understand, by showing
them the code a piece at a time and following their direction.

- **Describe, don't design.** Say what the code does today and where. Never
  propose changes, recommend approaches or start planning. If the engineer
  starts designing, note it in the Focus Log as an open question and offer
  `tt-adversarial-plan` once the exploration is done.
- **Every claim about the code is cited** (`path:line` at `BASE_SHA`). If you
  haven't read it, say so, or read it first.
- **The engineer steers.** You offer directions; they pick. Never decide for
  them what they're interested in: ask.
- **Never self-terminate.** The exploration ends only when the engineer
  confirms the focus statement (see **Close**).
- Never write production code. Never stage, commit or push.

## How to talk

- **Short turns, one question at a time.** About 15 lines of description at
  most, then one question.
- **Plain words first, detail on request.** Lead with what a thing does and
  why it matters for their question; name types and files second. Define any
  term the engineer hasn't used.
- **Draw it** when there is a flow: a small text diagram (five to eight boxes
  at most) beats a paragraph.
- **Check understanding.** After describing something, ask whether it matches
  what they expected, folded into the direction question rather than as an
  extra turn.
- **Offer directions with `AskUserQuestion`.** Two to four concrete branches,
  each with a one-line description of what they'd learn; the engineer can
  always type something else. Put the branch closest to their stated purpose
  first.
- **Listen for interest.** "That's the bit", follow-up questions and "why does
  it…" mark a topic as a Focus candidate; "skip that" or "not that" marks it
  Parked. When a signal is unclear, don't guess: ask at the next boil-down.

## Flow

### 1. Open

1. Restate the seed in one line. Ask why they're exploring it, with
   `AskUserQuestion`: **to change it** · **to debug it** · **to plan a feature
   on it** · **to learn it**. The purpose sets the depth: changing or planning
   needs seams, contracts and constraints; debugging needs the runtime path and
   its state; learning needs the shape and the vocabulary.
2. In the same question set, settle where the notes go: the documents' folder
   (offer the repo's documented planning folder, a sibling vault folder the
   engineer has used before, or ask), and a **prefix** you propose from the
   seed (the engineer can change it). If the invoking prompt already gives a
   folder and prefix (from `tt-workflow`), use them and don't ask.
3. State the base branch you'll read (the repo's default branch, or the one
   the engineer names), `git fetch` once, pin
   `BASE_SHA=$(git rev-parse origin/<base>)`, and say so in one line. Read code
   at that commit (`git show <sha>:<path>`, `git grep <term> <sha> -- <path>`),
   not in the working tree. If the engineer wants their working tree instead
   (for example to explore local changes), record that in the log and cite
   without a commit.
4. Create `<fam>/focus-log.md` from the template and `<fam>/research/`.

### 2. Map

Spawn up to 3 mapping subagents in parallel (model and effort from
`model-config.sh get explore`, brief
`<skill>/briefs/explore.md`, mode `map`), one per likely area of the seed, each
writing `<fam>/research/map-<area>.md`. Give each the seed, the purpose, its
area, the repo, `BASE_SHA` and `<common>`.

Then describe the top-level shape: what the parts are, how they connect (a
diagram), and where each lives. Add each part to the Focus Log as a topic
(Interest `Unrated`). Ask which part to dig into.

### 3. Dig (repeat)

Each turn, for the direction the engineer chose:

1. Get the material. Small reads (one file region, one symbol) you do yourself.
   Anything bigger (tracing a flow across files, finding every writer of some
   state, finding where a value comes from) goes to one `trace` subagent (same
   brief, mode `trace`), writing `<fam>/research/trace-<topic>.md`.
2. Describe one thing, cited.
3. Update the Focus Log with one small Edit: what you showed, the engineer's
   words (short quotes), any open question, the research file.
4. Ask the next direction: deeper into this, a neighbour you noticed, or back
   up a level.

Follow redirects at any time: "go back to X", "skip that", "what calls this?",
"stop".

### 4. Boil down

Every three or four Dig turns, or whenever the engineer signals they're getting
somewhere, play back:

- **What I think you're really after:** one or two sentences.
- **The interest map:** each topic so far with its current rating.

Then ask, with `AskUserQuestion` (multi-select where it fits), which topics
they are **very interested in** (Focus), which they need only **as background**
(Context), and which they **don't care about** (Parked). Write the ratings and
the confirmed or corrected statement into the Focus Log. Carry on digging
unless they say the focus is right.

### 5. Close

When the engineer says the focus is right, or asks to stop:

1. Show the final focus statement and the Focus and Context topics (one line
   each), and ask them to confirm. "Looks fine" or silence is not
   confirmation; any hesitation is another direction to dig.
2. On confirmation, set the log's Status to `Focus confirmed <YYYY-MM-DD>`.
3. Offer the next step with `AskUserQuestion`: **write it up now**
   (invoke `tt-familiarisation-doc` with the Focus Log path) · **write it up
   in a new session** (follow `<common>/session-handoff.md` with
   `--stage "Familiarisation Doc" --run '/tt-familiarisation-doc "<focus log>"'`)
   · **stop here** (the log stays on disk).

If they stop before confirming, set `Next` to where you were and give the
resume command.

## Resuming

`/tt-familiarise resume <focus log>`, or "continue" after a stall: read the
Focus Log (and nothing else until needed), tell the engineer in three lines
where things stand (the purpose, the draft focus statement, the last topic),
and carry on from `Next`. If the log's header says
`**Mode:** lite`, stay in lite mode (see above). The pinned `BASE_SHA` is in the log's header; keep
using it unless the engineer asks to move on (then re-pin and say so).

A long exploration's context grows with every turn. Once it is very large,
offer **Continue in a new session** (`<common>/session-handoff.md`; it starts
with `resume`): everything that matters is in the Focus Log.

## Behavioural guardrails

- One question at a time; short turns.
- Cite everything about the code; read before you claim.
- Describe, never design, recommend or plan.
- Never decide what the engineer is interested in; ask, and record their
  words.
- Keep the Focus Log current on disk after every turn that adds anything.
- Never write production code. Never stage, commit or push.
