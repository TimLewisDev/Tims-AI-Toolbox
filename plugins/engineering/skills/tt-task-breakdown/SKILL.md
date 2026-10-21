---
name: tt-task-breakdown
description: >
  Break an execution-ready Comprehensive Tech Plan (from
  tt-adversarial-plan) into atomic, dependency-ordered tasks that an AI agent can implement one at a
  time, grouped into work units: the tasks that are validated together.
  Validation and confirmation happen only per work unit, never per task. Each
  task card and work unit carries a plain-English summary for non-technical
  readers plus every detail, reference and link needed to execute it. Creates
  the Task Status document (through tt-task-status) that tt-execute later
  works from. Never commits. Use when handed a tech plan and asked for a task
  breakdown. To continue, resume or report on an existing breakdown, use
  tt-execute instead.
metadata:
  version: "4.0"
---

# tt-task-breakdown

## Usage

```
/tt-task-breakdown <comprehensive tech plan>
```

- The argument is a Comprehensive Tech Plan: produce the Task Breakdown and
  initialise the Task Status document.
- In this skill, "the plan" and "the tech plan" always mean the **Comprehensive
  Tech Plan**. If you're handed the brief Tech Plan or the Tech Proposals
  instead, follow its header link to the comprehensive plan and use that. Never
  take design from the brief Tech Plan or the Proposals: they are views of the
  comprehensive plan for human review.
- If the argument is a Task Status document, or starts with `continue`,
  `resume` or `status`, reply in one line, "That's `/tt-execute <task status
  doc>`", and stop.
- If the argument is missing or it's unclear which document is meant, ask and
  stop. Do not guess from the working tree.

## How to run this skill

This skill is split into files so a session loads only what it needs. `<skill>`
is this skill's folder (`${CLAUDE_SKILL_DIR}`), and `<common>` is
`~/.claude/tt-plugins/core/skills/tt-common` (or `<skill>/../tt-common` when the skills are linked into one folder).

1. Read `<common>/orchestration.md`: the output budget, drafts on disk, stall
   recovery, subagents and scripts. Every step below follows it.
2. Read `<common>/breakdown-rules-compact.md` for mandatory task, executor,
   amendment, escalation and safety rules. Consult `<common>/breakdown-rules.md`
   for definitions and examples only when needed.
3. Then follow `<skill>/breakdown-mode.md`.
4. Templates are in `<skill>/templates/` (and `<common>/templates/`) and
   subagent briefs in `<skill>/briefs/`. Read a template only when writing
   that document; never read a brief yourself unless you are doing its work
   without a subagent.

If you can't spawn subagents, do each brief yourself, in the same order, still
one part per response.

## Where this fits

```
tt-adversarial-plan ──► tt-task-breakdown ──► tt-execute ──► tt-coder
 (Comprehensive Tech Plan)   (Breakdown + Status)  (works the units)  (one task per subagent)
  ├─ Tech Proposals, Future Iterations
  └─ Tech Plan (brief, for human review, via tt-tech-plan)
tt-tech-plan-review amends the plan and keeps its views in sync
```

This is a **decomposition skill**, not a planning skill and not an
implementation skill:

- It does **not** change the design. The tech plan decided *what* to build;
  this skill decides only how to slice it into tasks, how to group the tasks
  into work units, and in what order.
- It does **not** write production code or run tasks. `tt-execute` works
  through the breakdown, handing each Agent task to a `tt-coder` subagent.
- It does **not** commit. Every git operation (staging, committing, pushing,
  branching) belongs to the engineer.
- It never fills a gap in the plan with an assumption. A gap becomes a
  question, an explicit "Confirm" step on a card, or a Critical Decision.

## Guardrails

The shared guardrails in `<common>/breakdown-rules-compact.md` apply. In
addition:

- Follow the output budget: never write the breakdown in one response.
- Don't start any work unit yourself. When the breakdown is written, hand off
  to `/tt-execute`.
