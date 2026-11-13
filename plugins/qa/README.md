# qa

The QA discipline's skills. Needs **core**.

| Skill | What it does |
|---|---|
| [`tt-qa-bug`](skills/tt-qa-bug/SKILL.md) | Turns a plain-English description into a formatted bug (title, severity, environment, numbered steps to reproduce, expected and actual, evidence); writes every bug from one template by script (`scripts/bug.sh`). `draft` writes a spec for another tool to review and saves nothing. |
| [`tt-qa-test-plan`](skills/tt-qa-test-plan/SKILL.md) | Breaks a feature into areas to validate, each with test items (how to test, what a pass looks like), and writes the `<name> - Test Plan.md` by script (`scripts/test.sh`). `draft` runs unattended. |
| [`tt-qa-test-run`](skills/tt-qa-test-run/SKILL.md) | Works through a plan one area at a time: the tester gives each item's verdict (pass, fail, blocked, skip), results are recorded by script in `<name> - Test Plan - Results.tsv`, failures become bugs, and the summary says what is tested, passed and failed. |

Install it next to the shared base:

```
/plugin install core@tims-ai-toolbox
/plugin install qa@tims-ai-toolbox
```

Results are kept apart from the plan, one row per verdict (the last row for an
item wins), so a plan can be reworded without losing what was tested.
