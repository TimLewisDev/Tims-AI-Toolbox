# Standalone mode

Read this only when you were **not** handed a delegated handoff: the engineer
gave you a plan, spec or ticket directly. Everything in `SKILL.md` applies;
this file replaces its delegated-only parts. `<common>` is
`~/.claude/tt-plugins/core/skills/tt-common` (or `${CLAUDE_SKILL_DIR}/../tt-common` when the skills are linked into one folder); read `<common>/orchestration.md` first.

## Scope and the engineer

- Work the plan's steps, in order.
- Talk to the engineer directly: present questions and Critical Decisions in
  chat, using the block in `SKILL.md`.
- **Critical Decision:** stop changing code, mark the step `Blocked` through
  `tt-task-status` (`set`), naming the decision, and present it. Once the
  engineer decides, record it through `tt-task-status` (`record` a decision)
  and continue only within what it allows.
- **Improvements** you spot are recorded through `tt-task-status` (`record` an
  improvement), never implemented.

## Task Status

- `init` a minimal doc from the plan, beside it, if none exists. Never create
  a second Task Status doc.
- Set each step `In Progress` before changing code, log it when done, and set
  it `Done` once its compile check passes.
- Make every change through `tt-task-status` (invoke it once; follow its
  loaded rules for later updates).

## Plans with more than three steps

Act as the orchestrator. Run one subagent per step (model and effort from `model-config.sh get coder`,
general-purpose, foreground), each given this skill in delegated mode, the
plan path and the step, and the Task Status path to leave alone. You record
each step's RESULT through `tt-task-status`, present every Critical Decision,
and run the compile check and inline validation yourself at the end. If you
can't spawn subagents, do the steps yourself in order.

A plan that big is often better broken down with `/tt-task-breakdown` and run
with `/tt-execute`. Suggest it once.

## Validation

Do only the minimum validation needed to confirm the change compiles and
integrates: build or compile-check each module you touched, using the method
the repo's agent instructions (`AGENTS.md`, `CLAUDE.md` or equivalent)
describe. If they don't describe one, or the check needs a human (for example,
an editor that has the project open), ask the engineer how to check it, or
hand that check to them as a validation step. Don't expand into comprehensive
automated testing unless explicitly instructed.

Then give the engineer **inline validation steps** in chat, with no separate
document:

1. A numbered list. Each item says what to do (exact steps), what they should
   see, and what to report back.
2. Edge cases worth trying, as their own items.
3. End with: "Ask me about any step if you need more detail."

Answer follow-up questions in the same session, and record the results through
`tt-task-status`.
