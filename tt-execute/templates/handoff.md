# Template: coder handoff

The prompt for one coder subagent (default model, general-purpose,
foreground). `handoff.sh` fills in the `<…>` (all but `<your changed files>`);
send its output as is. Fill it in by hand only if the script fails. Don't
paste the card: the subagent extracts it.

```
Implement exactly one task: <ID> — <title>. Do not start any other task.

Invoke the tt-coder skill and follow it in DELEGATED MODE.
Read <common>/subagent-rules.md first; it applies to you.

Your card: run
  bash "<common>/scripts/md-section.sh" get "<breakdown path>" "### <ID> —"
and treat its output as the task card, verbatim. Read the files under its
"Read first", and the plan sections it links, from <plan path>.

This task belongs to work unit <WU ID> — <name>. It is validated with that
unit, not on its own:
- Do not run compile checks, tests or other validation for this task, and do
  not report it as verified. The unit's validation covers it.
- Do not stage, commit, fetch, branch or run any git command that changes
  anything. The engineer handles all git operations.
- Do not write task, unit, plan or decision IDs (or "L0"-style level names) in
  code, comments, test names or messages. Strip them from any snippet you copy
  from the card, and run
    bash "<common>/scripts/check-planning-ids.sh" <your changed files>
  before you finish.
- Do not write to the Task Status (<status path>).

Repo: <repo path> · base <base> @ <BASE_SHA> · Build check: <method, for reference only>

Escalate any conflict between the card, the plan and the codebase, and every
Critical Decision, and stop; never resolve one yourself. Stop once this task's
Steps are done.

When you stop, for any reason, write your result in one Write to
  <run>/results/<ID>.md
in exactly the format of <common>/../tt-coder/templates/result.md
(Validation: Deferred to <WU ID>). Start from the output of
  bash "<common>/scripts/result-scaffold.sh" "<breakdown path>" <ID> --run "<run>"
and replace every <!-- fill: --> marker. The orchestrator applies that file
with a script, so keep its headings and bullet lines. If you are continued
later, rewrite the whole file. Only change files on your card's Files list;
the orchestrator checks.

Then end with the RESULT block from subagent-rules.md, kept short:
  status, wrote (the result file and nothing else), a 1–3 line summary,
  task_status: implemented | blocked | interrupted
  critical_decision: none | yes (in the result file)
```
