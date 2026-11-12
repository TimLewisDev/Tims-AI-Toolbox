# Questions are asked with options, never typed

- **Date:** 2026-11-12
- **Plugins:** core 0.9.0, engineering 0.7.0

## Why
Many hand-backs ended a turn with a question in prose: "Should we start WU2?", "Want me to…?", or a `/tt-…` command to copy and type. They have a few answers, so the engineer had to type a reply to something that should be one pick. About twenty hand-backs already asked with `AskUserQuestion`; the rest said "confirm with the engineer" or "stop and report" and left the wording to the model.

## Added
- `tt-common/orchestration.md` section 8, **Asking the engineer**, which every orchestrating skill already reads first:
  - anything that waits on the engineer is asked with `AskUserQuestion`, two to four named options, the recommended first;
  - one next step is still a question, **Do it** · **Not now**, with **Continue in a new session** added when the conversation is long;
  - on a yes the skill runs the next step itself (invokes the next skill) instead of printing a command; the command is given once, after **Not now**;
  - checklists the engineer does away from the chat (validation, Engineer tasks) stay conversational, so they can ask about a step;
  - the outermost skill asks what comes next: a skill run by `tt-workflow`, `tt-workflow-lite` or `tt-adversarial-plan` reports and leaves that question to its caller.
- `tt-execute <status> confirmed` and `tt-execute-lite <brief> confirmed`: for a skill that has just asked the engineer to start, so they are not asked twice. `tt-task-breakdown`, `tt-lite-brief`, `tt-workflow`, `tt-workflow-lite` and `tt-workflow-quick` pass it.

## Changed
Named options now stand where a step said only "confirm", "offer" or "tell the engineer":
- **Start the next work unit** (`tt-execute`, `tt-execute-lite`): **Start WU2** · **Continue in a new session** · **Not now**.
- **Stage exits** (the planning protocol, `tt-requirements`, `tt-scope`, `tt-approach`, `tt-technical-design`): **<Stage> is complete** · **Not yet**. Only the first confirms the stage.
- **Plan sign-off** (`tt-plan-signoff`): **Sign off the plan** · **Show me a section** · **I have changes**.
- **Hand-offs** that printed commands: after a plan is signed off, a breakdown is written, a lite brief is written, a Familiarisation doc is written, a debug report is written, a plan review is wrapped up, and a stage is run on its own.
- **Smaller choices:** a card file changed or left untouched, a reconcile correction, a fix task, a lite-brief or Familiarisation outline, the base branch of a review, the links back to proposals, and breaking a big plan down.

## Notes
- Nothing about where questions are answered changed: `TT_DECIDE=elsewhere` and the question lists work as before.
- A session that is already running keeps the skills it loaded; the new wording reaches sessions started after the update.
