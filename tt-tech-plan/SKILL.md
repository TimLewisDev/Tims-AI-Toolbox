---
name: tt-tech-plan
description: >
  Render a brief, human-readable Tech Plan from a Comprehensive Tech Plan, so a
  person can review the plan in a few minutes. This is a presentation skill,
  not a planning skill: it mirrors the comprehensive plan in a stripped-down
  form, cites the IDs behind every line, and never adds, infers or
  reinterprets content. Normally called by tt-adversarial-plan at hand-off
  and by tt-tech-plan-review after an amendment; can also be run directly to
  regenerate a Tech Plan. To plan a feature from a spec or ticket, use
  tt-adversarial-plan instead.
metadata:
  version: "2.1"
---

# tt-tech-plan

## Usage

```
/tt-tech-plan <comprehensive tech plan>
```

- The argument is a **Comprehensive Tech Plan** (normally written by
  `tt-adversarial-plan`). If none is given, ask for it and stop.
- If it's handed a spec, ticket, brief or anything that isn't a comprehensive
  plan, stop and point the engineer to `tt-adversarial-plan`. This skill
  doesn't plan.
- The Tech Plan goes beside the comprehensive plan, with the matching name:
  `<Prefix> - Comprehensive Tech Plan.md` → `<Prefix> - Tech Plan.md`. If the
  comprehensive plan's header already links a Tech Plan, use that path.

## Modes

- **Write**: no Tech Plan exists yet. Write it in full.
- **Regenerate**: a Tech Plan exists. Rewrite it in full from the current
  comprehensive plan. Use when the engineer asks, or when the Tech Plan is
  badly out of sync.
- **Update**: called by `tt-tech-plan-review` with the IDs an amendment
  changed, or by `tt-tech-proposals` with `P` IDs it added or whose status
  changed. Change only the lines that cite those IDs (and add or remove lines
  for added or removed IDs). Leave everything else as it is, so the diff shows
  only the amendment. If the step 4 check then finds a gap that was already
  there (an ID missing from the Tech Plan), fix it too and tell the engineer.

In every mode, set `Mirrors revision` to the comprehensive plan's current
`Revision` and the sync date to today.

## Role

You are a **renderer**. The comprehensive plan is the authority; the Tech Plan
is a view of it for human review.

- **Never add, infer or reinterpret content.** Every statement must be
  traceable to the comprehensive plan. The only thing taken from the Tech
  Proposals doc is proposal IDs and statuses. If something seems missing or
  wrong in the plan, say so to the engineer; don't patch it in the Tech Plan.
- **Every bullet and table row cites the IDs it summarises** (`R3–R6`, `S2`,
  `A1`, `§4`, `P2`, or a named section such as "Pressure Points: Stale
  correctness"). The one-paragraph summary cites its IDs once at the end. This
  is how `tt-tech-plan-review` maps an amendment made against either doc.
- **Brief.** Aim for a five-minute read: about 60–120 lines. If it runs longer,
  group more. Group related requirements into one line rather than listing each.
- **Simple.** Plain English and short sentences. Use technical names only where
  a reviewer needs them to judge the plan.
- **No code blocks**, and no file-level detail outside **Footprint**.
- **Don't repeat options.** Decisions get one line; the options live in the
  Tech Proposals doc, so link the `P` instead.
- Never write production code. Never stage, commit or push.

## Procedure

`<common>` is `${CLAUDE_SKILL_DIR}/../tt-common`; scripts are in
`<common>/scripts/`. Follow the output budget in `<common>/orchestration.md`:
write the Tech Plan in at most two responses (header to Key decisions, then the
rest), and in Update mode edit only the affected lines.

1. Read the comprehensive plan in full, and note its `Revision`. **Stop** if its
   Status is `Draft`: it isn't signed off, and there is nothing to mirror yet.
2. Read the Tech Proposals doc it links, for proposal IDs and statuses only:
   its **At a glance** table (`md-section.sh get <proposals> "## At a glance"`)
   and, when you need a proposal's **Decides** line, that one proposal
   (`md-section.sh get <proposals> "## P4 —"`). Never read the whole doc.
   - A decision's `P` link comes from the plan entry. If the plan doesn't link
     one, use the proposal whose **Decides** names that entry. If neither
     exists, write `—`. Use the link format in `tt-tech-proposals`
     (**Linking a proposal**).
   - A decided `Requirement or scope` proposal gets no line of its own: the
     Scope lines citing its `R`, `S` or `C` IDs cover it.
   - **Open for review** lists every proposal that is `Open` or `Default
     applied`.
   - If there is no Tech Proposals doc, the Options column is `—` throughout,
     and **Open for review** lists the plan's `NB` items (each is applied by
     default and open for review) and its Open Items. Say nothing about the
     missing doc beyond that.
3. Write the Tech Plan per the template. Match the comprehensive plan's header
   or tag block and link style.
4. Check before finishing:
   - every cited ID exists in the comprehensive plan, and every cited `P`
     exists in the Tech Proposals doc, and every `R`, `S`, `§`, `A`, `CD` and
     `NB` is cited:
     `bash "<common>/scripts/ids.sh" xref --prefixes R,S,§,A,CD,NB "<tech plan>" "<comprehensive plan>" "<proposals>"`
     (an `UNCITED` `NB` is fine only while it's listed under **Open for review**
     by its `P`);
   - every `R`, `S` and `§` step is covered by at least one line, every `A` and
     `CD` appears under **Key decisions**, and every `NB` appears exactly once:
     under **Open for review** while it's open, otherwise under **Key
     decisions**;
   - nothing is stated that the comprehensive plan doesn't say;
   - it's within the length target.
5. Link the cites, last, so the checks above ran on the plain text:
   `bash "<common>/scripts/ids.sh" linkify --def "<comprehensive plan>" --def "<proposals>" "<tech plan>"`
   (skip `--def "<proposals>"` if there is no Tech Proposals doc). Ranges stay
   as written. Running it again changes nothing, so a regenerated or amended
   Tech Plan can be linked the same way.
6. Report the path and the revision it mirrors.

## Template

The template is in `templates/tech-plan.md`. Read it when writing or
regenerating; in Update mode, follow the existing document's layout.
