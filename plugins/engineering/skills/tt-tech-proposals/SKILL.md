---
name: tt-tech-proposals
description: >
  Write and maintain the Tech Proposals doc: the companion to a tech plan that
  lays out every decision point's options for human review, in one clear,
  consistent structure (the question, a side-by-side comparison, each option
  with the same headings, a recommendation, and the decision). This is a
  presentation and record skill: the calling skill (a planning stage run by
  tt-adversarial-plan, or tt-tech-plan-review) supplies repo-grounded
  options, and this skill adds, decides or supersedes proposals without
  inventing options or facts. Can also be run directly to tidy a proposals
  doc, check it against its comprehensive plan, or backfill proposals from the
  options a plan already records.
metadata:
  version: "1.1"
---

# tt-tech-proposals

## Usage

```
/tt-tech-proposals <proposals doc or comprehensive tech plan>
```

Normally this skill is invoked by another skill mid-session, and the operation
(create, add, decide, supersede) follows from what that skill needs. Run
directly, it **tidies and checks**: see **Standalone use**.

Naming follows the comprehensive plan: `<Prefix> - Comprehensive Tech Plan.md`
→ `<Prefix> - Tech Proposals.md`, in the same folder. Match sibling documents'
header or tag block and link style.

## Role

You make decisions easy for a human to review. The reader may be the engineer
mid-session, or a lead reading the doc later in Obsidian, and needs to
understand each choice without the conversation that produced it.

- **The caller owns the content.** The question, the options and every fact
  about them come from the calling skill, grounded in the repo under its rules.
  Rephrase and arrange for clarity; never add an option, a benefit, a risk or a
  fact the caller didn't establish.
- If a field can't be filled from what was established, establish it under the
  calling skill's rules (repo-grounded, verified on the base branch), or write
  `Not assessed`. Never guess.
- Never delete a proposal. History stays readable.
- Never write production code. Never stage, commit or push.

## Statuses

| Status | Meaning |
|---|---|
| `Open` | Waiting for a decision. A `Blocking decision` that is `Open` holds up planning. |
| `Default applied` | A review item. The recommendation is applied in the plan for now and is open for review. |
| `Decided` | The engineer chose. The Decision section says what and why. |
| `Superseded` | Replaced by a later proposal, which it names. Its Decision stays as history. |

Types:

| Type | Use for | Produces |
|---|---|---|
| `Approach` | the overall approach, or a sub-choice of it | `A` entries and Rejected Alternatives |
| `Requirement or scope` | a choice between alternatives about what the feature does, what's in or out, or a constraint | `R`, `S` or `C` entries |
| `Blocking decision` | a Critical Decision that holds up planning | a `CD` |
| `Review item` | a Critical Decision that doesn't | an `NB` |

## Operations

- **Create the doc** on the first proposal: header, intro, status key and an
  empty **At a glance** table.
- **Add** a proposal: the next `P` number not already used in the proposals doc
  or cited in the plan, status `Open` (or `Default applied` for a review item),
  every section filled except **Decision**.
- **Decide**: fill **Decision**, set status `Decided` with the date. A `Default
  applied` proposal that the engineer confirms or overrides is decided in place.
- **Supersede**: a `Decided` proposal is never re-decided. Add a new proposal
  whose question opens with "Reopens Pn because …", and set the old one to
  `Superseded by Pm (<date>)`.
- After every operation, update **At a glance** and **Last updated**.

**How to write.** Proposals docs grow long (hundreds of lines); never rewrite
or re-read the whole doc. `<common>` is `~/.claude/tt-plugins/core/skills/tt-common` (or `${CLAUDE_SKILL_DIR}/../tt-common` when the skills are linked into one folder).

- **Add:** write the proposal to a part file ending with `<!-- tt:end -->`
  (beside the doc in `.tt/<Prefix> - Plan/research/P<n>.md`, or a temp file),
  then `bash "<common>/scripts/assemble.sh" append "<doc>" "<part>"`, then add
  its **At a glance** row with a small Edit. One proposal per response.
- **Decide / supersede:** targeted Edits to that proposal's status row,
  headings and **Decision**, and to its **At a glance** row.
- **Read** one proposal with
  `bash "<common>/scripts/md-section.sh" get "<doc>" "## P<n> —"`, the table
  with `… get "<doc>" "## At a glance"`, and the list of proposals with
  `… index "<doc>"`.

**Linking a proposal.** Proposal headings are `## Pn — <question>`. Elsewhere,
link one by that heading: in a vault
`[[<Prefix> - Tech Proposals#Pn — <question>|Pn]]`; elsewhere, a relative
Markdown link to the file that names the ID, e.g.
`[P3](<Login Flow - Tech Proposals.md>)` (the angle brackets allow the spaces
in the file name).

**Linking what a proposal names.** The **Decides** line and the option text cite
plan IDs (`A1`, `CD3`). After writing or changing proposals, run
`bash "<common>/scripts/ids.sh" linkify --def "<plan>" "<doc>"` so those cites
link to the plan entry. The script never links a `P` defined in this doc, and
running it again changes nothing.

## Readability rules

- **Lead with the question**, phrased as a question in plain words. Then the
  comparison table, then the details. A reader who stops after the table should
  still know what's being chosen and what's recommended.
- **Two to four options.** All options in a proposal share one set of
  headings, in one order, so they compare side by side.
- **The recommended option comes first** and is labelled `(Recommended)` in its
  heading and in the comparison table. If no recommendation was ever made (for
  example, in a backfill of an old plan), put the chosen option first and write
  "Recommendation: not recorded".
- **Once decided, mark the chosen option** `(Chosen)` in its comparison-table
  column and its heading, so a reader who stops at the table knows the outcome.
- **Leave out what you have nothing for.** Never pad a section with `Not
  assessed` or filler. Drop a heading or comparison-table row only when it's
  empty for every option; when one option has nothing under a heading the
  others use, write `None recorded` there. Drop an option subsection that would
  only repeat the table. Use `—` for a single empty cell.
- **Use the compact form** when there's little to say: a `Review item`, or any
  proposal whose options are recorded in a line or two each. Compact form is
  the header table, **The question**, **Options at a glance**,
  **Recommendation** and **Decision**, with no option subsections.
- **Short bullets, short sentences.** No walls of prose. One idea per bullet.
- **Concrete over abstract.** Name the systems and precedents (`path:line`)
  rather than describing them generically.
- **Code only where it makes the option clearer**, and kept short.
- Omit **How it would be used** when the option has no user-facing difference;
  don't fill it with filler.

## Standalone use

Work through a long doc one proposal at a time (`md-section.sh index`, then
`get` each), editing in place; never regenerate the doc. For a check against
the plan, `ids.sh defined <plan>` lists the IDs that **Decides** lines must
name.

Given a proposals doc:

- bring every proposal into the template layout without changing its content;
- rebuild **At a glance**;
- check against the comprehensive plan it links: every entry the plan records
  as decided between alternatives (as defined under backfill below) has a
  proposal, every proposal's **Decides** IDs exist,
  and statuses agree with the plan (a `CD` is `Decided`; an `NB` is `Default
  applied` or `Decided`);
- report mismatches. Fix layout only; route content mismatches to
  `tt-tech-plan-review`.

Given a comprehensive plan with no proposals doc, **backfill**:

1. Create one proposal per decision point the plan records with at least two
   alternatives, using only the options, rationale and outcome the plan itself
   records. An alternative counts wherever the plan records it and says why it
   lost: Rejected Alternatives, the `CD` and `NB` tables, correction or
   amendment notes, or "X, not Y" wording. An alternative recorded as `n/a`, or
   one with no reason, doesn't count. A decision with no counted alternative
   gets no proposal.
2. Backfilled proposals are usually thin, so use the compact form unless the
   plan records enough for full option subsections. Leave out what the plan
   doesn't cover; don't mark it `Not assessed`. Write the doc's header and **At
   a glance** first, then append the proposals a few per response.
3. Confirm the location before writing.
4. Then link back: add each proposal's `P` link to the plan entries it decides
   (Chosen Approach, Rejected Alternatives, and the `CD` and `NB` tables). This
   is linking only, so it changes no meaning and no `Revision`. Show the
   engineer the list of links first and add them once they confirm.
5. If a Tech Plan exists, have `tt-tech-plan` update it (Update mode, with
   the new `P` IDs) so its Options column and **Open for review** pick them up.

## Template

The template is in `templates/proposals.md`. Read it when creating the doc or
writing the first proposal of a session.
