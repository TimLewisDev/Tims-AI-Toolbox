# Template: Task Status

Used by `init` (directly, or through `briefs/init.md`). Every other operation
edits this structure in place.

## Task Status (from a Task Breakdown)

```markdown
<header or tag block matching sibling docs>

# Status
- State: Not Started | In Progress | Blocked | Ready to Validate | Complete
- Progress: <n> of <m> units Done · <n> of <m> tasks Implemented or Done
- Current Unit: <WU ID — name, or None>
- Current Task: <ID — title, or None>
- Next: <next task, or "Validate WU<n>", or next unit>
- Last Updated: <YYYY-MM-DD HH:MM>
- Branch: `<working branch>` (base `<base>`)
- Blocking Decisions: <list, or None>
- Outstanding Risks: <list, or None>

# Resume Here
1. Read this document, then <unit ID> and its cards in <Task Breakdown link>.
2. Reconcile: expect branch `<branch>`; <files expected on disk, or none>.
3. Waiting on the engineer: <checks or decisions, or nothing>.
4. Next action: <one concrete action, e.g. "Start T08 — Load saved settings (Agent)" or "Validate WU3 (Agent + Engineer)">.

**Documents:** Comprehensive tech plan <link> · Task Breakdown <link> · Repo `<path>`

# Work Unit Board
| ID | Outcome | Tasks | Validated by | Status | Notes |
|---|---|---|---|---|---|

# Task Board
| ID | Task | Executor | Work unit | Depends on | Status | Notes |
|---|---|---|---|---|---|---|

# Work Unit Validation

## <WU ID> — <name>

### Attempt <n>
- Run: <YYYY-MM-DD HH:MM> (<why: first run, after fix T<nn>, evidence stale after <commit or change>>)
- Results:
  - Check <n> (<check text>) [<Agent | Engineer | Agent + Engineer>]: <passed | failed | pending | blocked | waived>. <evidence>
- Outcome: Done | Failed | Pending (checks <n>, …)

# Decisions Taken
| # | Decision | Resolution | Tasks / Units | Date |
|---|---|---|---|---|

# Breakdown Changes
| Date | Tasks / Units | Change | Why | Approved by |
|---|---|---|---|---|

# Step Log

## <ID> — <title>
- Status:
- Files Modified:
- Summary:
- Validation: Deferred to <WU ID>
- To validate:
- Follow-up Concerns:

# Identified Improvements

## Improvement <n>
- Description:
- Benefits:
- Risks/Tradeoffs:
- Why High Impact:
```

## Task Status (standalone)

The same template without **Current Unit**, the **Work Unit Board**, **Work
Unit Validation** and **Breakdown Changes**. Progress reads `<n> of <m> tasks
Done`. The Documents line links the plan, and the Task Board drops its Work unit
column.
