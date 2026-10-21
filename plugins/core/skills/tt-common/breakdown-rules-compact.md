# Mandatory breakdown and execution rules

This is the compact operational layer for task-breakdown and execution skills.
`breakdown-rules.md` remains the explanatory reference and source for examples.

## Authority

1. Existing codebase at the plan's base revision.
2. Explicit engineer instructions.
3. Comprehensive Tech Plan and Future Iterations.
4. Task Breakdown.

A card never overrides the plan. A plan/code conflict is a Critical Decision.

## Tasks and work units

- A task has one concern, one executor and no open design choice.
- A work unit groups consecutive tasks and is the validation boundary.
- Validate only at work-unit level.
- A unit must contain everything needed for its checks and leave the project
  whole.

## Status and ownership

- `tt-task-status` owns every Task Status write.
- Save state before code changes and after every state change.
- Keep boards, header, Step Log and Resume Here consistent.
- Do not delete or renumber recorded IDs.

## Escalation

- Stop and escalate ambiguity that changes scope, contracts, task boundaries,
  order, checks or design.
- Record every decision, risk, improvement, amendment and validation attempt.
- A failed check becomes a fix task and the whole unit is validated again.

## Safety

- Slice the approved design; do not redesign it.
- Do not fabricate missing facts.
- Do not stage, commit, push, create branches or create tickets without the
  engineer's go-ahead.

## Optional knowledge

- Route project build/check or stack guidance through `knowledge.sh get` when
  the project context index is available.
- Load only the references needed for the current task or validation question.
- If the index is missing or stale, read the authoritative repository
  instructions directly and report the fallback.
