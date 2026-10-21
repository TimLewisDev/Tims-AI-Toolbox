# Template: delegated result file

In delegated mode you write your task's result to the path the handoff gives
(`<run>/results/<ID>.md`), in one Write, in exactly this shape. The
orchestrator applies it to the Task Status with `status-log.sh`, so keep the
headings and the bullet lines as they are. Write `none` for an empty section.

```markdown
# Result: <ID> — <title>

- Task status: implemented | blocked | interrupted
- Validation: Deferred to <WU ID>

## Files Modified
- new `<path>`: <purpose>
- change `<path>`: <what changed>

## Summary
<What was done, in a few lines. Plain markdown; lists are fine.>

## To validate
<What to check for this task, how (commands for the agent, exact steps for the
engineer), the expected result, and edge cases worth trying. Written so it can
be read out as steps.>

## Follow-up Concerns
<Anything the next task or the engineer should know, or none.>

## Risks
- <one risk per bullet, or none>

## Improvements
### <short name>
- Description: <…>
- Benefits: <…>
- Risks/Tradeoffs: <…>
- Why High Impact: <…>

## Critical Decision
<none, or the Critical Decision block from SKILL.md, its headings one level
down (### Task, ### Issue, ### Options, #### Option 1, …)>
```

- `implemented`: every Step on the card is done.
- `blocked`: you stopped at a Critical Decision, which is in the last section.
- `interrupted`: you stopped early for another reason; say why in Summary.
