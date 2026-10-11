# Template: Critical Decision (as presented to the engineer)

```markdown
## Critical Decision

### Type
Blocking Decision | Non-Blocking Review Item

### Tasks / Units Affected
<IDs>

### Problem
Clear explanation, in the context of the repository and the plan.

### Options

#### Option A
- Explanation
- Benefits
- Risks/Tradeoffs

#### Option B
- Explanation
- Benefits
- Risks/Tradeoffs

### Recommendation
Recommended option and why. Prefer repository consistency and the plan as written.

### Example Implementation
Only where needed for clarity.
```

When a subagent raised the decision, build the options from its escalation
(the evidence and options it saw) and check the evidence yourself before
presenting it. Ask with `AskUserQuestion`, recommended option first.
