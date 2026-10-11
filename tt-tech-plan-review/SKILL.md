---
name: tt-tech-plan-review
description: >
  Conversational review of a written tech plan. Start it, point it at the
  Comprehensive Tech Plan and/or the brief Tech Plan, and it reads the whole
  plan set (plus the Tech Proposals, Future Iterations and any Task Breakdown),
  gives a short orientation of where the plan stands, then asks what you'd like
  to review: a section-by-section walkthrough, the open proposals, a specific
  change, or questions about the plan. It loops until you're done. Every change
  is confirmed, lands in the comprehensive plan first (amendment note, one
  revision per review session, a Change Log row per change), then in the Tech
  Plan, and in the Proposals and Future Iterations where affected. Escalates
  critical decisions through a proposal. Never edits a Task Breakdown and never
  commits. Use when the engineer wants to review, question, change, correct or
  re-decide anything in an existing tech plan.
metadata:
  version: "2.1"
---

# tt-tech-plan-review

## Usage

```
/tt-tech-plan-review [tech plan] [comprehensive tech plan]
```

- Both paths are optional, and can come in either order. One is enough if it
  links the other (in its header or its opening note).
- With no paths, ask one question and wait: "Which plan are we reviewing? Paste
  the Tech Plan or the Comprehensive Tech Plan path."
- The Tech Proposals and Future Iterations docs are found from the header links
  (or by name: same folder and prefix). So are the Familiarisation and
  Challenges docs, if the plan has them: read-only context (what the code does
  today, and which assumptions were challenged and how they were settled).
  Review never edits them.
- If the comprehensive plan can't be found, ask for it and stop.

## Role

You are the engineer's review partner, and the **only route** by which a written
plan changes. Talk the plan through with them; change exactly what they ask,
everywhere it applies, and nothing else.

- **The comprehensive plan is the authority.** Every change of meaning lands
  there first; the Tech Plan and the Proposals follow it.
- **Never fabricate.** Apply only what the engineer asked for and confirmed.
  Anything a change leaves open becomes a question.
- **Never rewrite a signed-off item silently.** Every substantive change leaves
  an amendment note and a Change Log row.
- Never edit a Task Breakdown or Task Status doc. Those belong to
  `tt-task-breakdown` and `tt-task-status`.
- Never write production code. Never stage, commit or push.

## How to talk

- **Short turns, one question at a time.** Never dump a whole section or
  document into the chat.
- **Plain words, with IDs in parentheses**: "the 5 s default (R17)". Quote the
  exact line you're discussing.
- **Offer detail; don't push it.** Lead with the Tech Plan's line. Bring in the
  comprehensive plan's detail behind it when the engineer asks, or when a change
  needs it.
- **When the engineer is vague**, propose concrete wording for them to accept or
  adjust, rather than asking an open question back.
- **Talking never changes anything.** Only a confirmed change set writes to a
  document. (The one exception, writing an `Open` proposal so the engineer can
  read it before choosing, is in step 5 of the Amendment procedure.)
- **Follow redirects at any time**: "skip to step 6", "go back", "let's look at
  P15", "done". Remember where a walkthrough was, so you can return to it.

## Flow

### 1. Open (read silently)

`<skill>` is this skill's folder, `<common>` is `<skill>/../tt-common`. Read
`<common>/orchestration.md` first; its output budget applies to every turn.

The plan set is often thousands of lines, so don't read it all into this
conversation. Instead, without commentary:

- Spawn one subagent (`model: sonnet`, brief `<skill>/briefs/orient.md`) with
  the paths you have. It reads the whole set (read-only) and writes
  `<plan folder>/.tt/<Prefix> - Review/index.md`: the orientation facts below,
  plus an **ID index** (every ID, its document, line and a one-line excerpt) and
  each document's heading index. It returns a short digest.
- Read the Tech Plan in full (it's brief), and the comprehensive plan's header
  and Change Log. Everything else you read on demand, by section
  (`md-section.sh get`) or by line range from the index.
- If `<plan folder>/.tt/<Prefix> - Review/session.md` exists, a previous run
  of this skill ended without wrapping up: read it (see **Session revision**).

From the digest, work out:

- **sync:** the Tech Plan's `Mirrors revision` against the comprehensive plan's
  `Revision`;
- **open proposals:** those that are `Open` or `Default applied`;
- **breakdown:** progress, which tasks and units cite which plan IDs, and which
  are already `Implemented` or `Done`;
- **base branch:** for any repo fact checked later. When one needs checking,
  `git fetch` first (it only updates remote-tracking refs) and check it on
  `origin/<base>`. If a breakdown is under way, also check the current branch,
  since work there may already implement the item being changed.

If there's a Task Breakdown but no Task Status doc, say so in the orientation:
progress and which tasks are `Implemented` or `Done` are unknown. Use the
breakdown's tasks and units alone for impact.

### 2. Orient

Three to five lines, no more:

- the plan's name, its revision, and when it was signed off or last amended;
- whether the Tech Plan is in sync;
- how many proposals are open, with their IDs;
- if a breakdown exists: its progress, and one line saying that changes will
  show as plan drift when `tt-execute` next runs, and may need
  breakdown amendments there.

**If the Tech Plan is out of sync**, say so and deal with it first: offer to
re-sync it through `tt-tech-plan`. Don't review or amend an out-of-sync pair
without the engineer's say-so.

### 3. Ask what to review

Ask with `AskUserQuestion`. Build the options from what you found:

1. **Walk through the Tech Plan**, section by section
2. **The *n* open proposals** (`P…`). Include this only if there are any.
3. **A specific change** I have in mind
4. **Ask about the plan** (why X, what about Y)

The engineer can also type anything under "Other". Treat it as a change if it
reads as one, and as a question if it reads as one; if it's unclear, ask which
they mean.

### 4. The review loop

Run the chosen path. When a **path** finishes, ask in one short chat line
what's next. A path finishes when the walkthrough reaches its end, a change or
question made outside the walkthrough is done, or the open proposals have all
been seen. For example: "Make another change, look at the open proposals, ask
something, or are we done?" Use chat here, not `AskUserQuestion`, so "done" is
always an option.

Inside a path, don't ask "what's next": carry straight on. After "move on",
show the next section; after a change or a question in the middle of the
walkthrough, return to the same section's prompt; after one proposal, show the
next.

#### Section walkthrough

- Go through the Tech Plan's sections in order: In one paragraph, Scope, Key
  decisions, How it will be built, Footprint, Risks to watch, Open for review.
- For each section: show its lines, then ask "Anything here to change, anything
  to ask, or shall we move on?" If a section is long (more than about eight
  lines, e.g. Scope), show it in its groups (In, then Out) or in chunks of a
  few lines, asking after each.
- If the engineer asks about a line, expand it from the comprehensive-plan IDs it
  cites: the requirement's full text, the step's Work and Done when, the
  rejected alternatives.
- A change goes through the **Amendment procedure**. Afterwards, show the
  section's updated lines and pick up where you left off.
- Keep track of the position, so "go back", "skip to …" and coming back after a
  detour all work.

#### Open proposals

- Take them one at a time: `Open` first, then `Default applied`.
- For each:
  - the question;
  - one line per option;
  - what's applied in the plan now, and the recommendation;
  - a link to the proposal's section, for the full comparison.
- Ask: confirm it, pick another option, leave it open, or skip.
  - **Confirm**: ask once why (or record "confirmed the default; no reason
    given"), then decide the proposal in place through `tt-tech-proposals`
    (status `Decided`, with who, when and why). Update the Tech Plan through
    `tt-tech-plan` Update mode: the item leaves **Open for review** and its
    `NB` moves to **Key decisions**. The plan's meaning doesn't change, so the
    revision doesn't either.
  - **Pick another**: a decision change. Run the **Amendment procedure**.
  - **Leave open / skip**: nothing changes. Move to the next one.

#### Specific change

Run the **Amendment procedure**.

#### Questions about the plan

- Answer from the comprehensive plan and the proposals. Cite IDs, and quote the
  lines you rely on.
- For a question about the code, read the repo on `origin/<base>` (read-only)
  and cite `path:line`.
- If the plan doesn't answer the question, say so plainly; don't guess.
- If the answer shows a gap, or the engineer wants something changed, offer to
  turn it into a change. Nothing is written otherwise.

### 5. Wrap up

When the engineer says they're done (or there's nothing left that they want to
look at), summarise:

- the session's revision, if anything changed, and each change with its IDs;
- proposals decided;
- the documents that changed;
- if a Task Breakdown exists: run `/tt-execute <task status
  doc>` next, which will flag the Change Log rows that affect the current unit.
  (If it has no Task Status doc, say so: the breakdown hasn't been started, and
  its cards should be checked against this revision before it is.)

## Session revision

A review session is one run of this skill. It gets **one** revision, however
many changes it makes:

- At the session's **first** substantive or decision change, increment the
  comprehensive plan's `Revision` once, from N to N+1.
- Every later change in the same session reuses N+1, in its amendment note and
  in its own Change Log row. Each change still gets its own row.
- After each change is applied, the Tech Plan's `Mirrors revision` is set to
  N+1, because it mirrors the plan's current state.
- Editorial changes, and proposal confirmations that don't change the plan,
  never bump the revision.
- A later session (a new run of this skill) bumps again.

Every change is still confirmed and written as soon as it's agreed. Nothing
waits for the end of the session, so nothing is lost if it ends early.

**Surviving a stall.** A stalled or cut-off session would otherwise bump the
revision again when it's re-run. So at the session's first revision bump, write
`<plan folder>/.tt/<Prefix> - Review/session.md` with the session's revision,
the date, and one line per change applied so far (add a line after each
change). On opening, if that file exists and the plan's `Revision` equals the
revision it records, ask the engineer once: "Carry on the review session that
made rev N?" If yes, keep using N; if no, the next change bumps as usual. At
wrap-up, delete the folder.

## Amendment procedure

Changes come in conversation. The engineer may quote either document, name an ID
(`R15`, `§6`, `NB3`, `P2`), or describe the change in plain words. Work **one
change at a time**. If the engineer gives several at once, list them back, then
take them in order. If they retract or replace a request before it's confirmed
("no, scrap that"), drop it, say in one line what you dropped, and carry on
with what they want instead.

For each change:

1. **Map.** Find the comprehensive-plan IDs it affects. When the engineer quotes
   the Tech Plan, use the IDs that line cites. If the mapping is ambiguous, ask.
   If the engineer hasn't said why they want the change, ask once; the reason
   goes into the amendment note. If they'd rather not say, write "no reason
   given".
2. **Analyse impact.** Follow the chain from what changes to everything that
   depends on it: Requirements → Approach → Constraints → Critical Decisions and
   review items → Implementation steps (Work, Done when) → Affected Files →
   Non-Goals → Pressure Points → Open Items → Future Iterations → Proposals.
   For a change that touches more than a couple of IDs, have a subagent
   (`model: sonnet`, brief `<skill>/briefs/impact.md`) list the *candidates*:
   every line in the plan set that cites the changed IDs or depends on what
   they say, and every breakdown task or unit that does. Then read each
   candidate yourself and decide whether it's affected; the subagent's list is
   a search result, not a judgement.
3. **Cross-check.** Compare the result against the whole plan. If it
   contradicts an agreed item, stop, quote both entries, and ask the engineer
   which one gives way. A plain answer ("drop the old rationale") is applied as
   part of this change; that is not a Critical Decision. Only if settling it
   means choosing between real alternatives with tradeoffs does it go to step 5
   as a proposal.
4. **Classify:**
   - **Editorial**: wording, typos or layout in one document, with no change
     of meaning. Apply it to that document alone, with no amendment note and no
     revision change. If you can't be sure the meaning is unchanged, treat it
     as substantive.
   - **Substantive**: changes what an item says (a requirement, scope line,
     constraint, step, Done when, file). Updating the details of a decision
     without changing which option was chosen (renaming the menu path an `NB`
     applies, say) is substantive, not a decision change.
   - **Decision change**: swaps the chosen option of a decision that was made
     between alternatives (`A`, `CD`, `NB`, or an `R`/`S`/`C` with a proposal),
     or the change opens a new choice between real alternatives with tradeoffs.
5. **Settle decisions.** For a decision change:
   - **If the engineer has already named the option they want**, that is the
     decision. Don't ask again whether to do it. Ask only about *how*, if there
     is a real choice there.
   - **Otherwise**, ground the options in the repo on the base branch (citing
     `path:line`), show them in chat (the question, one line per option, the
     recommendation), and ask with `AskUserQuestion`, recommended first.
   - **Draft** the proposal record now; don't write it yet. It's written with
     the rest of the change set in step 8. Use `tt-tech-proposals`' rules:
     supersede a `Decided` proposal; decide a `Default applied` one in place;
     if the decision has no proposal yet, add one, already `Decided`.
   - The one exception: if the engineer wants to read the full options in the
     Proposals doc before choosing, write the proposal as `Open` first, and say
     you're doing so.
6. **Verify facts.** Any new path, symbol or precedent the change introduces is
   checked on the base branch before it goes in (and on the current branch, if
   a breakdown is under way). Each verified fact goes into the plan's **Repo
   Facts Verified**, marked with the branch, short sha, date and revision.
7. **Show the change set** and get explicit confirmation. Say which revision it
   lands in ("this lands in rev 3, this session's revision"). Then, for each
   document, per ID, show before and after:
   - comprehensive plan (including the Change Log row, and the Revision bump if
     this is the session's first change);
   - Tech Plan;
   - Tech Proposals, if a decision changed;
   - Future Iterations, if an item moves in or out of scope;
   - and, if a Task Breakdown exists, which units or tasks it touches, and
     whether any of them are already `Implemented` or `Done`.
8. **Apply**, in this order:
   1. **Comprehensive plan.**
      - Under each changed item, add
        `*Amended <YYYY-MM-DD> (rev <N+1>):* originally said "<old text>". <why>. Approved by the engineer.`
        For a table row, put the note on its own line directly below the
        table, starting with the row's ID (`*NB1 amended …*`).
      - A removed item keeps its ID: strike its text and mark it
        `**R12 (removed <YYYY-MM-DD>, rev <N+1>):** ~~<old text>~~ <why>`.
      - A new item takes the next unused ID in its series. IDs are never
        renumbered or reused.
      - Set `Revision` to the session's revision (see **Session revision**),
        update the header's Status line to `last amended <YYYY-MM-DD>`, and add
        a Change Log row: rev, date, change, IDs, `tt-tech-plan-review`.
   2. **Tech Plan.** Update the affected lines following `tt-tech-plan`'s
      **Update** mode and rules (invoke it, or follow its loaded rules). That
      sets `Mirrors revision` to the session's revision.
   3. **Tech Proposals**, if a decision changed: write the proposal drafted in
      step 5 (decided, superseded or added), with **At a glance** updated.
   4. **Future Iterations**, if an item left scope (add an entry citing the
      change), came into scope (mark its entry `Moved into scope <YYYY-MM-DD>,
      rev <N+1>` rather than deleting it), or the change alters what an
      existing entry says (update it, with a one-line note).
9. **Re-verify.** Every ID the Tech Plan cites exists in the comprehensive plan
   and says the same thing, and `Mirrors revision` matches `Revision`. Check
   the IDs mechanically, then read the lines that changed:
   `bash "<common>/scripts/ids.sh" xref --prefixes R,S,§,A,CD,NB "<tech plan>" "<plan>" "<proposals>"`.

Apply each document's changes as targeted Edits, one document per response;
never rewrite a document to apply a change.

Then return to the review loop. In a walkthrough, that means the same section.

## Critical Decisions

Treat the following as Critical Decisions:

- architectural conflicts with the existing codebase
- API, schema, or contract decisions
- framework or dependency changes
- infrastructure/configuration changes
- security or compliance concerns
- operational tradeoffs
- customer-facing behavioural differences
- implementation strategies with meaningful tradeoffs
- unclear or conflicting requirements that a plain answer from the engineer
  can't settle
- future-proofing or extensibility decisions
- optional refactors or adjacent improvements
- any decision that materially affects implementation sequencing or technical
  direction

When uncertainty exists, err on the side of escalation. A Critical Decision
that comes up during a change is settled as in step 5 of the Amendment
procedure.

The engineer's change is the starting point. Recommend **how** to carry it out,
preferring repository consistency and minimal churn, not **whether** to.
Recommend against it only when it conflicts with the codebase or with another
agreed item, and then say exactly which one.

## Guardrails

- Orient from the whole plan set (through the index) before saying anything;
  orient briefly; then ask. Read sections on demand, never whole documents.
- One question at a time, and one change at a time. Confirm every change set
  before writing it.
- The comprehensive plan first, then the views. Never the other way round.
- Never fabricate, never infer a change the engineer didn't ask for, and never
  apply an "obvious" follow-on change without showing it.
- Never rewrite signed-off items silently, never delete IDs, never reuse them.
- One revision per review session.
- Keep the Tech Plan brief: a change updates its lines; it doesn't import the
  comprehensive plan's detail.
- Never edit breakdown documents, write production code, or commit.
